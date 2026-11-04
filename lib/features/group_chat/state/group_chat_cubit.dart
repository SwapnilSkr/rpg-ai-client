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

  final Set<String> _opening = {};
  final Set<String> _opened = {};
  final Map<String, String> _writingFrom = {};
  final Map<String, void Function()> _writingTimers = {};

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
      ..add(_gateway.errors.listen(_onErrorFrame));
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
    // The answer names its thread (omitted for the group), because replies to
    // loads sent together can arrive in either order.
    final key = msg['directWith']?.toString() ?? kGroupThreadKey;
    _loadFifo.remove(key);
    _applyHistory(key, snapshot);
  }

  void _applyHistory(String key, GroupSnapshot snapshot) {
    final now = _clock.now();
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

    final before = state.thread(key).lines;
    final beforeKeys = {for (final l in before) l.key};
    final hidden = _hidden.putIfAbsent(key, () => []);
    final hiddenKeys = {for (final l in hidden) l.key};
    final historyKeys = {for (final l in history) l.key};

    final visible = <GroupLine>[];
    for (final line in history) {
      if (hiddenKeys.contains(line.key)) {
        final i = hidden.indexWhere((h) => h.key == line.key);
        hidden[i] = hidden[i].copyWith(eventId: line.eventId);
      } else if (beforeKeys.contains(line.key)) {
        visible.add(line);
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

  void _attachEvent(String key, String eventId, Set<String> lineKeys) {
    final hidden = _hidden[key];
    if (hidden != null) {
      for (var i = 0; i < hidden.length; i++) {
        if (lineKeys.contains(hidden[i].key)) {
          hidden[i] = hidden[i].copyWith(eventId: eventId);
        }
      }
    }
    final view = state.thread(key);
    if (view.lines.any((l) => lineKeys.contains(l.key) && l.eventId == null)) {
      _emit(
        state.copyWith(
          threads: {
            ...state.threads,
            key: view.copyWith(
              lines: [
                for (final l in view.lines)
                  lineKeys.contains(l.key) && l.eventId == null
                      ? l.copyWith(eventId: eventId)
                      : l,
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
    final key = msg['directWith']?.toString() ?? kGroupThreadKey;
    final lines = parseSpokenLines(msg['lines']);
    for (final line in lines) {
      _ingest(
        key,
        line.name.isEmpty
            ? line.copyWith(name: state.member(line.characterId!)?.name ?? '')
            : line,
      );
    }
    if (lines.isNotEmpty) _reveal(key);
    final active = _active;
    if (active != null) _armWatchdog(active);
    // An eventId means the turn is saved.
    final eventId = msg['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      _attachEvent(key, eventId, {for (final l in lines) l.key});
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
    final sequence = event['sequence'];
    if (sequence is num && sequence.toInt() > (_maxSequence[key] ?? 0)) {
      _maxSequence[key] = sequence.toInt();
    }

    final send = active.send;
    if (send != null && eventId.isNotEmpty) {
      _replaceOptimistic(
        key,
        send,
        eventId,
        (event['player_input'] ?? send.text).toString(),
        event['player_action'] == true || send.action,
      );
    }
    final lines = parseSpokenLines(event['lines'], eventId: eventId.isEmpty ? null : eventId);
    for (final line in lines) {
      _ingest(key, line.name.isEmpty
          ? line.copyWith(name: state.member(line.characterId!)?.name ?? '')
          : line);
    }
    if (eventId.isNotEmpty) _attachEvent(key, eventId, {for (final l in lines) l.key});
    _reveal(key);
    _finishTurn();
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
      if (key == kGroupThreadKey) {
        _emit(state.copyWith(load: GroupChatLoad.failed, error: error));
      }
    }
  }

  // ----------------------------------------------------------------- sending

  /// Sends the player's line, as a message or, for the group thread, an action.
  /// The line shows at once. A send while a reply is being written waits its
  /// turn. Returns false when the line cannot be sent at all.
  bool send(String text, {String? directWith, bool action = false}) {
    final trimmed = text.trim();
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
    if (failed == null) return false;
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
  void _replaceOptimistic(String key, _Outgoing send, String eventId, String text, bool action) {
    final view = state.thread(key);
    final index = view.lines.indexWhere((l) => l.key == 'c:${send.clientId}');
    final saved = GroupLine(
      key: 'p:$eventId',
      text: text,
      shownAt: index < 0 ? _clock.now() : view.lines[index].shownAt,
      eventId: eventId,
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
