import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/group_chat_gateway.dart';
import '../data/group_chat_repository.dart';
import '../models/group_chat_models.dart';
import 'group_chat_clock.dart';
import 'group_chat_state.dart';

/// Drives one group chat: the group thread and every direct thread, sends,
/// reveals, bonds and actions. A screen reads [GroupChatState] and calls the
/// public methods; it needs no socket or HTTP knowledge.
///
/// What the server guarantees, and what this relies on:
/// - One turn at a time for the whole chat, so one send is in flight and the
///   rest wait here.
/// - A turn's lines can reach us as partial frames, a final frame, the
///   completion frame and later a history read. Every spoken line is shown once
///   by its identity ([GroupLine.spokenKey]), whatever the order or repeats.
/// - Pub/sub frames are lost while the socket is down, so after a reconnect the
///   history is the truth and an unanswered send is reconciled against it.
class GroupChatCubit extends Cubit<GroupChatState> {
  final String instanceId;
  final GroupChatGateway _gateway;
  final GroupChatRepository _repo;
  final GroupChatClock _clock;

  /// A line stamped far ahead (a phone clock running behind the server's) is
  /// shown after at most this long.
  final Duration maxRevealDelay;

  /// No word from a turn for this long: read the history to see what happened.
  final Duration turnWatchdog;

  /// How long a character shows as typing after a thread is opened before the
  /// words arrive.
  final Duration openTypingTimeout;

  /// Gap between history reads while the server is still busy with a turn we
  /// lost the frames of, and how many reads before giving up on it.
  final Duration reconcileDelay;
  final int reconcileAttempts;

  /// A load that never answers is a failed load.
  final Duration loadTimeout;

  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, List<GroupLine>> _hidden = {};
  final Map<String, void Function()> _revealTimers = {};
  final Set<String> _seen = {};
  final Map<String, int> _maxSequence = {};
  final List<_Outgoing> _queue = [];

  /// Thread keys of load requests still unanswered. Only a refused load needs
  /// this: it has no frame of its own, so its error stands in for the oldest.
  final List<String> _loadFifo = [];

  /// Threads whose next history read replaces what is shown instead of
  /// merging into it. A rewind removes lines; a merge would keep them.
  final Set<String> _replacing = {};

  /// Threads a rewind asked to reload and has not heard back from.
  final Set<String> _rewindLoads = {};
  bool _rewindRequestOpen = false;
  void Function()? _rewindTimer;

  final Set<String> _opening = {};
  final Set<String> _opened = {};
  final Map<String, String> _writingFrom = {};
  final Map<String, void Function()> _writingTimers = {};

  /// Bumped when a rewind drops what is shown, so an answer to a selfie asked
  /// before it is not applied to the lines read afterwards.
  int _epoch = 0;

  _Turn? _active;
  int _nextId = 0;
  bool _closed = false;
  void Function()? _loadTimer;

  GroupChatCubit({
    required this.instanceId,
    required GroupChatGateway gateway,
    GroupChatRepository repository = const HttpGroupChatRepository(),
    GroupChatClock clock = const SystemGroupChatClock(),
    this.maxRevealDelay = const Duration(seconds: 20),
    this.turnWatchdog = const Duration(seconds: 90),
    this.openTypingTimeout = const Duration(seconds: 25),
    this.reconcileDelay = const Duration(seconds: 3),
    this.reconcileAttempts = 8,
    this.loadTimeout = const Duration(seconds: 20),
  }) : _gateway = gateway,
       _repo = repository,
       _clock = clock,
       super(GroupChatState(instanceId: instanceId)) {
    _subs
      ..add(_gateway.connectionState.listen(_setConnected))
      ..add(_gateway.instanceLoaded.listen(_onInstanceLoaded))
      ..add(_gateway.groupLines.listen(_onGroupLines))
      ..add(_gateway.ack.listen(_onAck))
      ..add(_gateway.generationComplete.listen(_onComplete))
      ..add(_gateway.errors.listen(_onErrorFrame))
      ..add(_gateway.selfieFrames.listen(_onSelfieFrame));
  }

  // ---------------------------------------------------------------- loading

  /// Connects (or joins the shared connection) and reads the chat.
  Future<void> start() async {
    _loadTimer = _clock.schedule(loadTimeout, () {
      if (state.load != GroupChatLoad.loading) return;
      _emit(
        state.copyWith(
          load: GroupChatLoad.failed,
          error: _gateway.isConnected
              ? GroupChatError.failed
              : GroupChatError.offline,
        ),
      );
    });
    unawaited(refreshThreads());
    try {
      await _gateway.connect();
    } catch (_) {
      // The socket reconnects on its own; a load failure shows via the timer.
    }
    if (_gateway.isConnected) _setConnected(true);
  }

  /// Reads the chat again after a failed load.
  void retryLoad() {
    _emit(state.copyWith(load: GroupChatLoad.loading, error: null));
    _loadTimer?.call();
    _loadTimer = _clock.schedule(loadTimeout, () {
      if (state.load == GroupChatLoad.loading) {
        _emit(state.copyWith(load: GroupChatLoad.failed, error: GroupChatError.offline));
      }
    });
    _requestLoad(kGroupThreadKey);
  }

  Future<void> refreshThreads() async {
    try {
      final rows = await _repo.threads(instanceId);
      _emit(state.copyWith(threadSummaries: rows));
    } catch (_) {
      // The list is a convenience; the threads themselves load by socket.
    }
  }

  /// Tells the cubit which thread is on screen, reads it if it has not been
  /// read, and opens it if it holds a waiting message. [directWith] null is the
  /// group thread.
  void selectThread(String? directWith) {
    final key = directWith ?? kGroupThreadKey;
    _emit(state.copyWith(selectedThread: key));
    if (!state.thread(key).loaded && !_loadFifo.contains(key)) {
      _requestLoad(key);
    }
    _maybeOpenPending();
  }

  void _setConnected(bool connected) {
    if (_closed || state.connected == connected) return;
    _emit(state.copyWith(connected: connected));
    if (!connected) {
      // Answers to requests on a dead socket never come.
      _loadFifo.clear();
      _active?.interrupted = true;
      return;
    }
    _loadFifo.clear();
    final keys = {
      kGroupThreadKey,
      state.selectedThread,
      ?_active?.thread,
      // A selfie frame sent while the socket was down is gone; the history
      // knows how it ended.
      ..._threadsWithPendingSelfie(),
    };
    for (final key in keys) {
      _requestLoad(key);
    }
    unawaited(refreshThreads());
    _pump();
  }

  void _requestLoad(String key) {
    if (!_gateway.isConnected) return;
    _loadFifo.add(key);
    _gateway.loadInstance(
      instanceId,
      directWith: key == kGroupThreadKey ? null : key,
    );
  }

  void _onInstanceLoaded(Map<String, dynamic> msg) {
    final snapshot = GroupSnapshot.parse(msg);
    if (snapshot == null || snapshot.instanceId != instanceId) return;
    // Sent before the rewind finished, so it still holds the removed turns.
    if (_rewindRequestOpen) return;
    // The answer names its thread (omitted for the group), because replies to
    // loads sent together can arrive in either order.
    final key = msg['directWith']?.toString() ?? kGroupThreadKey;
    _loadFifo.remove(key);
    _applyHistory(key, snapshot);
    _settleRewindLoad(key);
  }

  void _applyHistory(String key, GroupSnapshot snapshot) {
    final now = _clock.now();
    final replace = _replacing.remove(key);
    final members = snapshot.members.isEmpty ? state.members : snapshot.members;
    String nameOf(String id) {
      for (final m in members) {
        if (m.id == id) return m.name;
      }
      return '';
    }

    final history = <GroupLine>[];
    var maxSequence = _maxSequence[key] ?? 0;
    String? resolvedClientKey;
    var resolved = false;
    final active = _active;
    for (final event in snapshot.events) {
      if (event.sequence > maxSequence) maxSequence = event.sequence;
      if (event.playerInput.isNotEmpty) {
        history.add(
          GroupLine(
            key: 'p:${event.id}',
            text: event.playerInput,
            shownAt: event.createdAt,
            eventId: event.id,
            sequence: event.sequence,
            isAction: event.playerAction,
          ),
        );
      }
      for (final line in event.lines) {
        history.add(
          line.name.isEmpty ? line.copyWith(name: nameOf(line.characterId!)) : line,
        );
      }
      // Our own unanswered send, saved while we were not listening.
      if (active != null && active.thread == key && event.sequence > active.baseSequence) {
        final send = active.send;
        final mine = send == null
            ? event.origin == 'unprompted'
            : event.playerInput == send.text && event.playerAction == send.action;
        if (mine) {
          resolved = true;
          if (send != null) resolvedClientKey = 'c:${send.clientId}';
        }
      }
    }
    _maxSequence[key] = maxSequence;

    final before = replace ? const <GroupLine>[] : state.thread(key).lines;
    final beforeKeys = {for (final l in before) l.key};
    final beforeByKey = {for (final l in before) l.key: l};
    final hidden = _hidden.putIfAbsent(key, () => []);
    final hiddenKeys = {for (final l in hidden) l.key};
    final historyKeys = {for (final l in history) l.key};

    final visible = <GroupLine>[];
    for (final line in history) {
      if (hiddenKeys.contains(line.key)) {
        final i = hidden.indexWhere((h) => h.key == line.key);
        hidden[i] = _knowing(
          hidden[i].copyWith(eventId: line.eventId, sequence: line.sequence),
          line,
        );
      } else if (beforeKeys.contains(line.key)) {
        // The read is the truth, but a picture already known is not lost to a
        // read that began before it was asked for.
        visible.add(_knowing(line, beforeByKey[line.key]));
      } else if (_seen.add('$key#${line.key}') &&
          line.characterId != null &&
          line.shownAt.isAfter(now)) {
        _insertHidden(hidden, line);
      } else {
        visible.add(line);
      }
    }
    // What history does not hold yet: sends still waiting for their turn, and
    // lines of a turn that has not been saved.
    for (final line in before) {
      if (historyKeys.contains(line.key)) continue;
      if (line.key == resolvedClientKey) continue;
      if (line.status != GroupLineStatus.sent || line.eventId == null) {
        visible.add(line);
      }
    }

    final view = state.thread(key);
    _emit(
      state.copyWith(
        load: GroupChatLoad.ready,
        error: null,
        members: members,
        matureCapable: snapshot.matureCapable,
        title: snapshot.title.isEmpty ? null : snapshot.title,
        imageUrl: snapshot.imageUrl.isEmpty ? null : snapshot.imageUrl,
        pendingFrom: snapshot.pendingFrom,
        threads: {
          ...state.threads,
          key: view.copyWith(lines: visible, loaded: true),
        },
      ),
    );
    _loadTimer?.call();
    _reveal(key);

    if (resolved) {
      _finishTurn();
    } else if (active != null && active.thread == key && (active.interrupted || active.reconciling)) {
      if (snapshot.operation != null) {
        _scheduleRecheck(active);
      } else {
        _failActive(GroupChatError.failed);
      }
    }
    _maybeOpenPending();
  }

  // ----------------------------------------------------------------- reveal

  void _insertHidden(List<GroupLine> hidden, GroupLine line) {
    var i = hidden.length;
    while (i > 0 && hidden[i - 1].shownAt.isAfter(line.shownAt)) {
      i--;
    }
    hidden.insert(i, line);
  }

  /// Shows every line of [key] whose time has come, in order, and waits for the
  /// next one. A line stamped in the past shows at once.
  void _reveal(String key) {
    _revealTimers.remove(key)?.call();
    if (_closed) return;
    final hidden = _hidden[key] ?? [];
    final now = _clock.now();
    final due = <GroupLine>[];
    while (hidden.isNotEmpty && !hidden.first.shownAt.isAfter(now)) {
      due.add(hidden.removeAt(0));
    }
    if (hidden.isNotEmpty) {
      var delay = hidden.first.shownAt.difference(now);
      if (delay > maxRevealDelay) delay = maxRevealDelay;
      _revealTimers[key] = _clock.schedule(delay, () => _reveal(key));
    }
    final view = state.thread(key);
    final typing = hidden.isNotEmpty ? hidden.first.characterId : _writingFrom[key];
    if (due.isEmpty && view.typingId == typing) return;
    _emit(
      state.copyWith(
        threads: {
          ...state.threads,
          key: view.copyWith(lines: _placed(view.lines, due), typingId: typing),
        },
      ),
    );
  }

  /// Appends [incoming], but a spoken line that was stamped earlier than the
  /// spoken lines just before it goes ahead of them. Frames of one turn can
  /// arrive in any order; this keeps the thread in the order it was said.
  List<GroupLine> _placed(List<GroupLine> lines, List<GroupLine> incoming) {
    final out = [...lines];
    for (final line in incoming) {
      var i = out.length;
      if (line.characterId != null) {
        while (i > 0 &&
            out[i - 1].characterId != null &&
            out[i - 1].shownAt.isAfter(line.shownAt)) {
          i--;
        }
      }
      out.insert(i, line);
    }
    return out;
  }

  /// The player has moved on: whatever is still being revealed in this thread
  /// shows now, so it stays above their next line.
  void _flushHidden(String key) {
    final hidden = _hidden[key];
    if (hidden == null || hidden.isEmpty) return;
    _revealTimers.remove(key)?.call();
    final view = state.thread(key);
    final lines = [...hidden];
    hidden.clear();
    _emit(
      state.copyWith(
        threads: {
          ...state.threads,
          key: view.copyWith(
            lines: _placed(view.lines, lines),
            typingId: _writingFrom[key],
          ),
        },
      ),
    );
  }

  /// Takes a line into a thread if it has not been seen. Returns whether it is
  /// new.
  bool _ingest(String key, GroupLine line) {
    if (!_seen.add('$key#${line.key}')) return false;
    if (_writingFrom.remove(key) != null) _writingTimers.remove(key)?.call();
    _insertHidden(_hidden.putIfAbsent(key, () => []), line);
    return true;
  }

  void _attachEvent(
    String key,
    String eventId,
    Set<String> lineKeys, {
    int? sequence,
  }) {
    final hidden = _hidden[key];
    if (hidden != null) {
      for (var i = 0; i < hidden.length; i++) {
        if (lineKeys.contains(hidden[i].key)) {
          hidden[i] = hidden[i].copyWith(eventId: eventId, sequence: sequence);
        }
      }
    }
    final view = state.thread(key);
    // A line may already know its event (from the frame that carried it) but
    // learn its sequence only from the completion.
    bool needs(GroupLine l) =>
        lineKeys.contains(l.key) &&
        (l.eventId == null || (sequence != null && l.sequence == null));
    if (view.lines.any(needs)) {
      _emit(
        state.copyWith(
          threads: {
            ...state.threads,
            key: view.copyWith(
              lines: [
                for (final l in view.lines)
                  needs(l) ? l.copyWith(eventId: eventId, sequence: sequence) : l,
              ],
            ),
          },
        ),
      );
    }
  }

  // ------------------------------------------------------------------ frames

  void _onGroupLines(Map<String, dynamic> msg) {
    if (msg['instanceId']?.toString() != instanceId) return;
    // A frame in flight when a rewind began belongs to a removed turn.
    if (state.rewinding) return;
    final key = msg['directWith']?.toString() ?? kGroupThreadKey;
    final lines = parseSpokenLines(msg['lines']);
    for (final line in lines) {
      final isNew = _ingest(
        key,
        line.name.isEmpty
            ? line.copyWith(name: state.member(line.characterId!)?.name ?? '')
            : line,
      );
      if (!isNew) _enrich(key, line);
    }
    if (lines.isNotEmpty) _reveal(key);
    final active = _active;
    if (active != null) _armWatchdog(active);
    // An eventId means the turn is saved.
    final eventId = msg['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      final sequence = msg['sequence'];
      _attachEvent(
        key,
        eventId,
        {for (final l in lines) l.key},
        sequence: sequence is num ? sequence.toInt() : null,
      );
    }
  }

  void _onAck(Map<String, dynamic> msg) {
    final active = _active;
    if (active == null || !active.awaitingAck) return;
    final jobId = msg['jobId']?.toString();
    if (jobId == null || jobId.isEmpty) return;
    active.awaitingAck = false;
    active.jobId = jobId;
    final send = active.send;
    if (send != null) _setLineStatus(active.thread, 'c:${send.clientId}', GroupLineStatus.sending);
    _armWatchdog(active);
  }

  void _onComplete(Map<String, dynamic> msg) {
    if (msg['instanceId']?.toString() != instanceId) return;
    if (state.rewinding) return;
    final event = msg['event'];
    final active = _active;
    final jobId = msg['jobId']?.toString();
    final ours = active != null &&
        (active.isOpen || active.jobId == null || active.jobId == jobId);
    if (!ours || event is! Map) {
      // Someone else's turn (or one we hold no record of): the history knows.
      _refreshLoaded();
      return;
    }
    final key = active.thread;
    final eventId = (event['id'] ?? '').toString();
    final rawSequence = event['sequence'];
    final sequence = rawSequence is num ? rawSequence.toInt() : null;
    if (sequence != null && sequence > (_maxSequence[key] ?? 0)) {
      _maxSequence[key] = sequence;
    }

    final send = active.send;
    if (send != null && eventId.isNotEmpty) {
      _replaceOptimistic(
        key,
        send,
        eventId,
        (event['player_input'] ?? send.text).toString(),
        event['player_action'] == true || send.action,
        sequence,
      );
    }
    final lines = parseSpokenLines(
      event['lines'],
      eventId: eventId.isEmpty ? null : eventId,
      sequence: sequence,
    );
    for (final line in lines) {
      final isNew = _ingest(key, line.name.isEmpty
          ? line.copyWith(name: state.member(line.characterId!)?.name ?? '')
          : line);
      if (!isNew) _enrich(key, line);
    }
    if (eventId.isNotEmpty) {
      _attachEvent(key, eventId, {for (final l in lines) l.key}, sequence: sequence);
    }
    _reveal(key);
    _finishTurn();
    // Without its number a saved line cannot be rewound to; the history has it.
    if (sequence == null && eventId.isNotEmpty) _requestLoad(key);
    if (key != kGroupThreadKey) unawaited(refreshThreads());
  }

  void _onErrorFrame(Map<String, dynamic> msg) {
    final failedJob = msg['jobId']?.toString();
    final active = _active;
    final error = _errorFor(msg['code']?.toString());
    if (failedJob != null && failedJob.isNotEmpty) {
      // A failed turn names itself; one that is not ours is none of our business.
      if (active == null || (active.jobId != null && active.jobId != failedJob)) return;
      _failActive(error);
      return;
    }
    if (active != null && active.awaitingAck) {
      _failActive(error);
    } else if (_loadFifo.isNotEmpty) {
      // A refused load has no frame of its own; its error stands in for it.
      final key = _loadFifo.removeAt(0);
      if (_rewindLoads.contains(key)) {
        // Not re-read, so what it shows may still hold removed turns. Showing
        // nothing until it is opened and read again is the honest state.
        _replacing.remove(key);
        if (key != kGroupThreadKey) {
          _emit(state.copyWith(threads: {...state.threads, key: const GroupThreadView()}));
        }
        _settleRewindLoad(key);
      }
      if (key == kGroupThreadKey) {
        _emit(state.copyWith(load: GroupChatLoad.failed, error: error));
      }
    }
  }

  // ----------------------------------------------------------------- selfies

  /// A selfie in flight is not undone by an older word about it: a finished
  /// picture stays finished, and a started one is not queued again.
  static GroupSelfie? _mergeSelfie(GroupSelfie? old, GroupSelfie? next) {
    if (next == null) return old;
    if (old == null) return next;
    if (old.status == SelfieStatus.ready && next.isPending) return old;
    if (old.status == SelfieStatus.processing &&
        next.status == SelfieStatus.queued) {
      return old;
    }
    return next;
  }

  /// [fresh] with what [old] already knew and [fresh] lacks.
  GroupLine _knowing(GroupLine fresh, GroupLine? old) => old == null
      ? fresh
      : fresh.copyWith(
          lineId: fresh.lineId ?? old.lineId,
          selfie: _mergeSelfie(old.selfie, fresh.selfie),
        );

  /// A later frame of a line already taken in (its saved form follows the
  /// partial one) may bring the id and picture the first one lacked.
  void _enrich(String key, GroupLine incoming) {
    if (incoming.lineId == null && incoming.selfie == null) return;
    _patchLines(
      key,
      (l) => l.key == incoming.key,
      (l) => l.copyWith(
        lineId: l.lineId ?? incoming.lineId,
        selfie: _mergeSelfie(l.selfie, incoming.selfie),
      ),
    );
  }

  /// Changes every line of [key] that [match]es, shown or still held back, so
  /// a picture is there when a held line is revealed. Returns whether any
  /// line matched.
  bool _patchLines(
    String key,
    bool Function(GroupLine) match,
    GroupLine Function(GroupLine) change,
  ) {
    var found = false;
    final hidden = _hidden[key];
    if (hidden != null) {
      for (var i = 0; i < hidden.length; i++) {
        if (match(hidden[i])) {
          found = true;
          hidden[i] = change(hidden[i]);
        }
      }
    }
    final view = state.thread(key);
    var changed = false;
    final lines = [
      for (final l in view.lines)
        if (match(l))
          () {
            found = true;
            final next = change(l);
            if (next != l) changed = true;
            return next;
          }()
        else
          l,
    ];
    if (changed) {
      _emit(
        state.copyWith(
          threads: {...state.threads, key: view.copyWith(lines: lines)},
        ),
      );
    }
    return found;
  }

  bool _isLine(GroupLine l, String lineId, String eventId) =>
      l.lineId == lineId &&
      (eventId.isEmpty || l.eventId == null || l.eventId == eventId);

  Iterable<String> _threadsWithPendingSelfie() sync* {
    for (final key in {...state.threads.keys, ..._hidden.keys}) {
      final lines = [...state.thread(key).lines, ...?_hidden[key]];
      if (lines.any((l) => l.selfie?.isPending ?? false)) yield key;
    }
  }

  void _onSelfieFrame(Map<String, dynamic> msg) {
    if (msg['instanceId']?.toString() != instanceId) return;
    // A frame in flight when a rewind began belongs to a removed turn.
    if (state.rewinding) return;
    final lineId = (msg['line_id'] ?? msg['lineId'])?.toString() ?? '';
    // The media frames also carry every other picture, which have no line.
    if (lineId.isEmpty) return;
    final type = msg['type']?.toString();
    final GroupSelfie? next;
    if (type == 'selfie_started') {
      next = GroupSelfie.parse(msg['selfie']);
    } else if (msg['kind']?.toString() != 'picture') {
      return;
    } else {
      final mediaId = (msg['media_id'] ?? msg['mediaId'])?.toString();
      final id = mediaId == null || mediaId.isEmpty ? null : mediaId;
      next = switch (type) {
        'media_ready' => GroupSelfie.parse({
          'status': 'ready',
          'media_id': id,
          'url': msg['url'],
        }),
        'media_unseen' => GroupSelfie(status: SelfieStatus.unseen, mediaId: id),
        'media_failed' => GroupSelfie(status: SelfieStatus.failed, mediaId: id),
        _ => null,
      };
    }
    if (next == null) return;
    final key = msg['directWith']?.toString() ?? kGroupThreadKey;
    final eventId = msg['eventId']?.toString() ?? '';
    final selfie = next;
    // A line this app has not loaded is not made up from a frame: the thread's
    // next read shows it.
    _patchLines(
      key,
      (l) => _isLine(l, lineId, eventId),
      (l) => l.copyWith(selfie: _mergeSelfie(l.selfie, selfie)),
    );
  }

  /// Asks [line]'s character for a picture of themselves. The frame shows as
  /// queued at once; the answer, or a failure that leaves it retryable,
  /// follows. A picture already asked for or finished, a line not yet saved,
  /// and a rewind in progress do nothing, and neither does a resting
  /// allowance before its reset time (the screen words that time from
  /// [GroupSelfie.resetsAtLocal]).
  Future<void> requestSelfie(GroupLine line) async {
    if (_closed || state.rewinding) return;
    GroupLine? current;
    String? key;
    for (final entry in state.threads.entries) {
      final hit = entry.value.lines.where((l) => l.key == line.key).firstOrNull;
      if (hit != null) {
        current = hit;
        key = entry.key;
        break;
      }
    }
    final eventId = current?.eventId;
    final lineId = current?.lineId;
    final who = current?.characterId;
    if (current == null || key == null) return;
    if (eventId == null || lineId == null || who == null) return;
    final held = current.selfie;
    if (held != null) {
      switch (held.status) {
        case SelfieStatus.queued ||
            SelfieStatus.processing ||
            SelfieStatus.ready:
          return;
        case SelfieStatus.resting:
          if (held.isRestingAt(_clock.now())) return;
        // A picture a check stopped has already given its slot back, and the
        // next try is a new picture, so it is asked for like a failed one.
        case SelfieStatus.unseen || SelfieStatus.failed:
          break;
      }
    }
    final thread = key;
    final epoch = _epoch;
    const asked = GroupSelfie(status: SelfieStatus.queued);
    GroupLine put(GroupLine l, GroupSelfie? s) => l.copyWith(selfie: s);
    _patchLines(thread, (l) => _isLine(l, lineId, eventId), (l) => put(l, asked));

    GroupSelfie? answer;
    try {
      answer = await _repo.requestSelfie(instanceId, eventId, who, current.text);
    } catch (_) {
      answer = null;
    }
    // A rewind that dropped the lines this answer is about has read them
    // again since; the answer is not theirs. One still running is not
    // waited for: if it removes the turn, the reload clears the line.
    if (_closed || epoch != _epoch) return;
    _patchLines(thread, (l) => _isLine(l, lineId, eventId), (l) {
      if (answer != null) return put(l, _mergeSelfie(l.selfie, answer));
      // Only our own tap is undone; a frame may have moved it on.
      return l.selfie == asked ? put(l, const GroupSelfie(status: SelfieStatus.failed)) : l;
    });
  }

  // ----------------------------------------------------------------- sending

  /// Sends the player's line, as a message or, for the group thread, an action.
  /// The line shows at once. A send while a reply is being written waits its
  /// turn. Returns false when the line cannot be sent at all.
  bool send(String text, {String? directWith, bool action = false}) {
    final trimmed = text.trim();
    if (state.rewinding) return false;
    if (trimmed.isEmpty || trimmed.length > 4000) return false;
    // The server refuses an action to one person: it is for everyone.
    if (action && directWith != null) return false;
    final out = _Outgoing(
      clientId: 'c${_nextId++}',
      text: trimmed,
      directWith: directWith,
      action: action,
    );
    final key = directWith ?? kGroupThreadKey;
    _flushHidden(key);
    _appendLine(
      key,
      GroupLine(
        key: 'c:${out.clientId}',
        text: trimmed,
        shownAt: _clock.now(),
        isAction: action,
        status: GroupLineStatus.queued,
      ),
    );
    _queue.add(out);
    _pump();
    return true;
  }

  void _pump() {
    if (_closed) return;
    if (_active == null && _queue.isNotEmpty && _gateway.isConnected) {
      final out = _queue.removeAt(0);
      final key = out.directWith ?? kGroupThreadKey;
      final turn = _Turn(
        thread: key,
        send: out,
        baseSequence: _maxSequence[key] ?? 0,
      );
      _active = turn;
      _setLineStatus(key, 'c:${out.clientId}', GroupLineStatus.sending);
      _armWatchdog(turn);
      _gateway.sendChat(
        instanceId,
        out.text,
        directWith: out.directWith,
        action: out.action,
      );
    }
    _syncFlags();
  }

  void _syncFlags() {
    if (state.turnInFlight == (_active != null) && state.queuedSends == _queue.length) return;
    _emit(state.copyWith(turnInFlight: _active != null, queuedSends: _queue.length));
  }

  void _finishTurn() {
    _endOpen(_active);
    _active?.cancelTimers();
    _active = null;
    _pump();
  }

  /// The turn did not go through. The player's text goes to [GroupChatState.failedSends]
  /// and the queue moves on. A refusal that would hit every send (no Ink, signed
  /// out) fails everything waiting at once rather than one by one.
  void _failActive(GroupChatError error) {
    final active = _active;
    if (active == null) return;
    final failed = <FailedSend>[];
    final send = active.send;
    if (send != null) {
      failed.add(_failedFrom(send, error));
      _dropLine(active.thread, 'c:${send.clientId}');
    }
    if (active.isOpen) _clearWriting(active.thread);
    _endOpen(active);
    active.cancelTimers();
    _active = null;
    if (const {
      GroupChatError.insufficientInk,
      GroupChatError.signInRequired,
      GroupChatError.resting,
      GroupChatError.notFound,
    }.contains(error)) {
      for (final queued in _queue) {
        failed.add(_failedFrom(queued, error));
        _dropLine(queued.directWith ?? kGroupThreadKey, 'c:${queued.clientId}');
      }
      _queue.clear();
    }
    _emit(state.copyWith(failedSends: [...state.failedSends, ...failed]));
    _pump();
  }

  FailedSend _failedFrom(_Outgoing out, GroupChatError error) => FailedSend(
    id: out.clientId,
    text: out.text,
    directWith: out.directWith,
    isAction: out.action,
    error: error,
  );

  /// Sends a failed line again. Its old entry goes away and it queues like a new
  /// send.
  bool retryFailed(String id) {
    final failed = state.failedSends.where((f) => f.id == id).firstOrNull;
    if (failed == null || state.rewinding) return false;
    discardFailed(id);
    return send(failed.text, directWith: failed.directWith, action: failed.isAction);
  }

  void discardFailed(String id) {
    _emit(state.copyWith(failedSends: [for (final f in state.failedSends) if (f.id != id) f]));
  }

  void _armWatchdog(_Turn turn) {
    turn.cancelWatchdog?.call();
    turn.cancelWatchdog = _clock.schedule(turnWatchdog, () {
      if (_active != turn) return;
      turn.reconciling = true;
      if (_gateway.isConnected) {
        _requestLoad(turn.thread);
      }
      _armWatchdog(turn);
    });
  }

  void _scheduleRecheck(_Turn turn) {
    if (turn.cancelRecheck != null) return;
    turn.cancelRecheck = _clock.schedule(reconcileDelay, () {
      turn.cancelRecheck = null;
      if (_active != turn) return;
      if (++turn.rechecks > reconcileAttempts) {
        _failActive(GroupChatError.failed);
        return;
      }
      _requestLoad(turn.thread);
    });
  }

  void _appendLine(String key, GroupLine line) {
    final view = state.thread(key);
    _emit(
      state.copyWith(
        threads: {...state.threads, key: view.copyWith(lines: [...view.lines, line])},
      ),
    );
  }

  void _dropLine(String key, String lineKey) {
    final view = state.thread(key);
    if (!view.lines.any((l) => l.key == lineKey)) return;
    _emit(
      state.copyWith(
        threads: {
          ...state.threads,
          key: view.copyWith(lines: [for (final l in view.lines) if (l.key != lineKey) l]),
        },
      ),
    );
  }

  void _setLineStatus(String key, String lineKey, GroupLineStatus status) {
    final view = state.thread(key);
    if (!view.lines.any((l) => l.key == lineKey && l.status != status)) return;
    _emit(
      state.copyWith(
        threads: {
          ...state.threads,
          key: view.copyWith(
            lines: [for (final l in view.lines) l.key == lineKey ? l.copyWith(status: status) : l],
          ),
        },
      ),
    );
  }

  /// The saved copy of the player's line takes the place of the one shown
  /// while it was being sent.
  void _replaceOptimistic(
    String key,
    _Outgoing send,
    String eventId,
    String text,
    bool action,
    int? sequence,
  ) {
    final view = state.thread(key);
    final index = view.lines.indexWhere((l) => l.key == 'c:${send.clientId}');
    final saved = GroupLine(
      key: 'p:$eventId',
      text: text,
      shownAt: index < 0 ? _clock.now() : view.lines[index].shownAt,
      eventId: eventId,
      sequence: sequence,
      isAction: action,
    );
    _seen.add('$key#${saved.key}');
    if (index < 0) return;
    final lines = [...view.lines]..[index] = saved;
    _emit(state.copyWith(threads: {...state.threads, key: view.copyWith(lines: lines)}));
  }

  void _refreshLoaded() {
    for (final entry in state.threads.entries) {
      if (entry.value.loaded) _requestLoad(entry.key);
    }
  }

  // --------------------------------------------------- opening a waiting thread

  void _maybeOpenPending() {
    final key = state.selectedThread;
    if (state.rewinding) return;
    if (key == kGroupThreadKey || !state.pendingFrom.contains(key)) return;
    if (_opened.contains(key) || !_opening.add(key)) return;
    unawaited(_openPending(key));
  }

  Future<void> _openPending(String characterId) async {
    bool writing;
    try {
      writing = await _repo.openThread(instanceId, characterId);
    } catch (_) {
      // Nothing is lost: the message stays waiting for the next time.
      _opening.remove(characterId);
      return;
    }
    _opening.remove(characterId);
    if (_closed || !writing) return;
    _opened.add(characterId);
    _emit(
      state.copyWith(
        pendingFrom: [for (final id in state.pendingFrom) if (id != characterId) id],
      ),
    );
    // The server holds the chat's one turn for this message; sends wait.
    if (_active == null) {
      final turn = _Turn(
        thread: characterId,
        baseSequence: _maxSequence[characterId] ?? 0,
      );
      _active = turn;
      _armWatchdog(turn);
      _syncFlags();
    }
    _writingFrom[characterId] = characterId;
    _reveal(characterId);
    _writingTimers[characterId] = _clock.schedule(openTypingTimeout, () {
      _clearWriting(characterId);
      final turn = _active;
      if (turn != null && turn.isOpen && turn.thread == characterId) {
        turn.reconciling = true;
        _requestLoad(characterId);
      }
    });
  }

  /// A waiting message is spent once its turn ends, so the same character's
  /// next one opens again.
  void _endOpen(_Turn? turn) {
    if (turn != null && turn.isOpen) _opened.remove(turn.thread);
  }

  void _clearWriting(String key) {
    _writingTimers.remove(key)?.call();
    if (_writingFrom.remove(key) != null) _reveal(key);
  }

  // ------------------------------------------------------------------ rewind

  /// Removes the turn at [sequence] and everything after it, in the room and
  /// in every direct thread, then shows the server's truth in all of them.
  /// Does nothing while a reply is being written or queued, or another rewind
  /// runs. [GroupChatState.rewindError] says why a rewind did not go through.
  Future<void> rewind(int sequence) async {
    if (_closed ||
        state.rewinding ||
        sequence <= 1 ||
        _active != null ||
        _queue.isNotEmpty ||
        _opening.isNotEmpty) {
      return;
    }
    _emit(state.copyWith(rewinding: true, rewindError: null));
    _rewindRequestOpen = true;
    Object? failure;
    try {
      await _repo.rewind(instanceId, sequence);
    } catch (e) {
      failure = e;
    }
    _rewindRequestOpen = false;
    if (_closed) return;

    if (failure != null) {
      final error = _errorOf(failure);
      // A refusal changed nothing. Anything else (a lost reply) may have
      // removed the turns, so it is treated as if it had.
      final unchanged = failure is ApiException &&
          const {400, 401, 403, 404, 409, 429}.contains(failure.statusCode);
      _emit(state.copyWith(rewindError: error));
      _reloadAfterRewind(replace: !unchanged, clearSends: false);
      return;
    }
    _reloadAfterRewind(replace: true, clearSends: true);
    unawaited(refreshThreads());
    // Bonds and the action list are the server's to count: read them again if
    // they were ever read.
    if (state.bonds.isNotEmpty) unawaited(loadBonds());
    if (state.actions.isNotEmpty || state.actionsNext != null) {
      unawaited(loadActions());
    }
  }

  /// Reads every thread held again. [replace] drops what is shown first, so a
  /// line the server no longer has cannot stay on screen or in the reveal
  /// buffer. The lines already seen stay in [_seen]: a late frame of a removed
  /// turn is then taken for a repeat and ignored.
  void _reloadAfterRewind({required bool replace, required bool clearSends}) {
    final keys = <String>{
      kGroupThreadKey,
      state.selectedThread,
      ...state.threads.keys,
    };
    var threads = state.threads;
    if (replace) {
      for (final cancel in _revealTimers.values) {
        cancel();
      }
      _revealTimers.clear();
      for (final cancel in _writingTimers.values) {
        cancel();
      }
      _writingTimers.clear();
      _writingFrom.clear();
      _hidden.clear();
      _epoch++;
      _maxSequence.clear();
      _opened.clear();
      _replacing.addAll(keys);
      // A thread nobody is looking at is read again when it is opened, even if
      // the socket is down now.
      threads = {
        for (final e in threads.entries)
          e.key: (e.key == kGroupThreadKey || e.key == state.selectedThread)
              ? e.value.copyWith(typingId: null)
              : const GroupThreadView(),
      };
    }
    _loadFifo.clear();
    _rewindLoads
      ..clear()
      ..addAll(keys);
    _emit(
      state.copyWith(
        threads: threads,
        failedSends: clearSends ? const [] : null,
      ),
    );
    _rewindTimer?.call();
    _rewindTimer = _clock.schedule(loadTimeout, _finishRewind);
    for (final key in keys) {
      _requestLoad(key);
    }
    // Nothing could be asked (socket down), or nothing was removed: the veil
    // must not wait for the answers.
    if (!replace || !_gateway.isConnected) _finishRewind();
  }

  void _settleRewindLoad(String key) {
    if (!_rewindLoads.remove(key)) return;
    if (_rewindLoads.isEmpty) _finishRewind();
  }

  void _finishRewind() {
    _rewindTimer?.call();
    _rewindTimer = null;
    _rewindLoads.clear();
    if (!state.rewinding) return;
    _emit(state.copyWith(rewinding: false));
    _maybeOpenPending();
  }

  // ------------------------------------------------------------ bonds, actions

  Future<void> loadBonds() async {
    _emit(state.copyWith(bondsLoading: true, bondsError: null));
    try {
      final bonds = await _repo.bonds(instanceId);
      if (_closed) return;
      _emit(state.copyWith(bonds: bonds, bondsLoading: false));
    } catch (e) {
      if (_closed) return;
      _emit(state.copyWith(bondsLoading: false, bondsError: _errorOf(e)));
    }
  }

  /// Sets meters directly. The server's answer is what the screen shows.
  /// Returns false when nothing was sent or the server refused.
  Future<bool> setBond(String characterId, Map<String, int> meters) async {
    if (meters.isEmpty || meters.values.any((v) => v < 0 || v > 100)) return false;
    try {
      final result = await _repo.setBond(instanceId, characterId, meters);
      if (_closed) return false;
      _emit(
        state.copyWith(
          bondsError: null,
          bonds: [
            for (final b in state.bonds)
              b.characterId == characterId ? b.withMeters(result) : b,
          ],
        ),
      );
      return true;
    } catch (e) {
      if (!_closed) _emit(state.copyWith(bondsError: _errorOf(e)));
      return false;
    }
  }

  var _actionsRequest = 0;

  /// The newest page, replacing what is shown.
  Future<void> loadActions() => _loadActions(before: null);

  /// The next, older page.
  Future<void> loadMoreActions() async {
    final next = state.actionsNext;
    if (next == null || state.actionsLoading) return;
    await _loadActions(before: next);
  }

  Future<void> _loadActions({int? before}) async {
    final request = ++_actionsRequest;
    _emit(state.copyWith(actionsLoading: true, actionsError: null));
    try {
      final page = await _repo.actions(instanceId, before: before);
      // A newer request supersedes this one.
      if (_closed || request != _actionsRequest) return;
      _emit(
        state.copyWith(
          actions: before == null ? page.actions : [...state.actions, ...page.actions],
          actionsNext: page.next,
          actionsLoading: false,
        ),
      );
    } catch (e) {
      if (_closed || request != _actionsRequest) return;
      _emit(state.copyWith(actionsLoading: false, actionsError: _errorOf(e)));
    }
  }

  // ------------------------------------------------------------------- errors

  static GroupChatError _errorFor(String? code) => switch (code) {
    'GENERATION_IN_PROGRESS' => GroupChatError.busy,
    'RATE_LIMITED' => GroupChatError.rateLimited,
    'INSUFFICIENT_INK' => GroupChatError.insufficientInk,
    'SIGN_IN_REQUIRED' || 'UNAUTHENTICATED' => GroupChatError.signInRequired,
    'STORY_RESTING' => GroupChatError.resting,
    'NOT_FOUND' => GroupChatError.notFound,
    'BAD_REQUEST' || 'FORBIDDEN' => GroupChatError.rejected,
    _ => GroupChatError.failed,
  };

  static GroupChatError _errorOf(Object e) {
    if (e is ApiException) {
      if (e.code == 'sign_in_required') return GroupChatError.signInRequired;
      return switch (e.statusCode) {
        401 => GroupChatError.signInRequired,
        400 || 403 => GroupChatError.rejected,
        404 => GroupChatError.notFound,
        409 => GroupChatError.busy,
        429 => GroupChatError.rateLimited,
        _ => GroupChatError.failed,
      };
    }
    if (e is SocketException) return GroupChatError.offline;
    return GroupChatError.failed;
  }

  void _emit(GroupChatState next) {
    if (!_closed) emit(next);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _loadTimer?.call();
    _rewindTimer?.call();
    for (final cancel in _revealTimers.values) {
      cancel();
    }
    _revealTimers.clear();
    for (final cancel in _writingTimers.values) {
      cancel();
    }
    _writingTimers.clear();
    _active?.cancelTimers();
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}

class _Outgoing {
  final String clientId;
  final String text;
  final String? directWith;
  final bool action;

  _Outgoing({
    required this.clientId,
    required this.text,
    this.directWith,
    this.action = false,
  });
}

/// The chat's one turn in flight: a send of ours, or a waiting message the
/// server is writing ([send] null).
class _Turn {
  final String thread;
  final _Outgoing? send;

  /// The newest sequence known in the thread when the turn started. Anything
  /// saved after it can be this turn's.
  final int baseSequence;
  String? jobId;
  bool awaitingAck;
  bool interrupted = false;
  bool reconciling = false;
  int rechecks = 0;
  void Function()? cancelWatchdog;
  void Function()? cancelRecheck;

  _Turn({required this.thread, this.send, required this.baseSequence})
    : awaitingAck = send != null;

  bool get isOpen => send == null;

  void cancelTimers() {
    cancelWatchdog?.call();
    cancelRecheck?.call();
    cancelWatchdog = null;
    cancelRecheck = null;
  }
}
