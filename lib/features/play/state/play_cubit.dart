import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/ws_manager.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_db.dart';
import '../../chronicle/data/chronicle_repository.dart';
import '../../home/data/home_repository.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/world_instance.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/character_profile.dart';

/// Sentinel so [PlayState.copyWith] can distinguish "leave unchanged" from
/// "set to null" for nullable fields like [replayingEventId].
const Object _kUnset = Object();
const int _activeEventLimit = 100;
const int _activeMemoryLimit = 50;

class PlayState extends Equatable {
  final WorldInstance? instance;
  final WorldTemplate? template;
  final List<GameEvent> events;
  final List<Memory> memories;
  final List<CharacterProfile> characters;
  final bool isGenerating;

  /// True only while the NARRATIVE prose is still streaming/revealing into the
  /// bubble — drives the in-bubble "still writing" indicator. Distinct from
  /// [isGenerating] (which stays true through post-prose server work — choices,
  /// codex, kinship — and gates the composer). It flips false the instant the
  /// prose reveal finishes, so the typing indicator doesn't hang while the rest
  /// of the turn's bookkeeping completes.
  final bool narrativeStreaming;

  /// True once the narrator's choices have arrived early (the `choices_ready`
  /// event), before generation_complete. Lets the chips render on the still-in-
  /// flight optimistic turn so options appear with the prose. Cleared when the
  /// turn finalizes or a new one starts.
  final bool choicesPreview;

  final bool isConnected;
  final bool isLoading;
  final String? error;
  final int totalEvents;
  final bool hasOlderEvents;

  /// The player input of a turn that failed to send (lock held, error, or
  /// offline), preserved so it can be resent with one tap instead of being
  /// silently lost. Cleared on a successful send or when the error is dismissed.
  final String? lastFailedInput;

  /// Transient status shown while a turn is still in flight — e.g. the server
  /// hit a hiccup and is retrying. Distinct from [error]: the turn isn't dead,
  /// the loader stays up. Cleared once tokens resume or the turn ends/fails.
  final String? notice;

  /// Id of the event whose AI turn is currently being re-woven (streaming a
  /// replay variant). Drives the in-bubble weaving/streaming treatment and is
  /// independent of [isGenerating] (which gates the composer for new turns).
  final String? replayingEventId;

  /// Stat changes from the most recent completed turn — drives the floating
  /// delta chips and bar pulses in the HUD. Cleared when the next turn starts.
  final Map<String, num>? lastStatDeltas;

  /// Milestone label crossed on the latest turn (brass-seal toast), one-shot.
  final String? lastMilestone;

  /// Bumped with every milestone so identical labels still retrigger the toast.
  final int milestoneStamp;

  /// Full story-landmark log (oldest first) for the timeline surface — seeded
  /// from instance meta on load, appended live as milestones unlock.
  final List<Milestone> milestones;

  const PlayState({
    this.instance,
    this.template,
    this.events = const [],
    this.memories = const [],
    this.characters = const [],
    this.isGenerating = false,
    this.narrativeStreaming = false,
    this.choicesPreview = false,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
    this.totalEvents = 0,
    this.hasOlderEvents = false,
    this.lastFailedInput,
    this.notice,
    this.replayingEventId,
    this.lastStatDeltas,
    this.lastMilestone,
    this.milestoneStamp = 0,
    this.milestones = const [],
  });

  PlayState copyWith({
    WorldInstance? instance,
    WorldTemplate? template,
    List<GameEvent>? events,
    List<Memory>? memories,
    List<CharacterProfile>? characters,
    bool? isGenerating,
    bool? narrativeStreaming,
    bool? choicesPreview,
    bool? isConnected,
    bool? isLoading,
    String? error,
    int? totalEvents,
    bool? hasOlderEvents,
    Object? lastFailedInput = _kUnset,
    Object? notice = _kUnset,
    Object? replayingEventId = _kUnset,
    Object? lastStatDeltas = _kUnset,
    Object? lastMilestone = _kUnset,
    int? milestoneStamp,
    List<Milestone>? milestones,
  }) {
    return PlayState(
      instance: instance ?? this.instance,
      template: template ?? this.template,
      events: events ?? this.events,
      memories: memories ?? this.memories,
      characters: characters ?? this.characters,
      isGenerating: isGenerating ?? this.isGenerating,
      narrativeStreaming: narrativeStreaming ?? this.narrativeStreaming,
      choicesPreview: choicesPreview ?? this.choicesPreview,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalEvents: totalEvents ?? this.totalEvents,
      hasOlderEvents: hasOlderEvents ?? this.hasOlderEvents,
      lastFailedInput: identical(lastFailedInput, _kUnset)
          ? this.lastFailedInput
          : lastFailedInput as String?,
      notice: identical(notice, _kUnset) ? this.notice : notice as String?,
      replayingEventId: identical(replayingEventId, _kUnset)
          ? this.replayingEventId
          : replayingEventId as String?,
      lastStatDeltas: identical(lastStatDeltas, _kUnset)
          ? this.lastStatDeltas
          : lastStatDeltas as Map<String, num>?,
      lastMilestone: identical(lastMilestone, _kUnset)
          ? this.lastMilestone
          : lastMilestone as String?,
      milestoneStamp: milestoneStamp ?? this.milestoneStamp,
      milestones: milestones ?? this.milestones,
    );
  }

  @override
  List<Object?> get props => [
    instance,
    template,
    events,
    memories,
    characters,
    isGenerating,
    narrativeStreaming,
    choicesPreview,
    isConnected,
    isLoading,
    error,
    totalEvents,
    hasOlderEvents,
    lastFailedInput,
    notice,
    replayingEventId,
    lastStatDeltas,
    lastMilestone,
    milestoneStamp,
    milestones,
  ];
}

class PlayCubit extends Cubit<PlayState> {
  final WsManager _ws;
  final String instanceId;
  late StreamSubscription _generationSub;
  late StreamSubscription _deltaSub;
  late StreamSubscription _streamEndSub;
  late StreamSubscription _choicesReadySub;
  late StreamSubscription _retryingSub;
  late StreamSubscription _memorySub;
  late StreamSubscription _errorSub;
  late StreamSubscription _connectionSub;
  late StreamSubscription _instanceSub;
  late StreamSubscription _characterCodexSub;
  late StreamSubscription _replayDeltaSub;
  late StreamSubscription _replayCompleteSub;
  late StreamSubscription _milestoneSub;

  /// Accumulates streamed narrative tokens for the in-progress turn.
  String _streamBuffer = '';
  String _streamTarget = '';
  Timer? _streamRevealTimer;
  Timer? _generationWatchdog;

  /// Set when the server signals the prose is complete (the choices/bookkeeping
  /// tail may still be generating). Lets the reveal loop know that once it
  /// catches up to the target it can clear [PlayState.narrativeStreaming] — the
  /// story is done even though [isGenerating] stays up for the rest of the turn.
  bool _proseStreamEnded = false;

  /// In-progress streaming replay of an existing turn.
  String? _replayEventId;
  String _replayBuffer = '';
  String? _replayOriginalResponse;

  /// Safety net: if no replay frames arrive within this window we reset the
  /// loader so the bubble can never spin forever (dropped frame, stale lock,
  /// dead worker, …). Re-armed on every delta as a liveness signal.
  Timer? _replayWatchdog;
  Timer? _replayRevealTimer;
  static const _replayTimeout = Duration(seconds: 45);
  static const _generationFirstTokenTimeout = Duration(seconds: 75);
  static const _generationQuietTimeout = Duration(seconds: 45);
  static const _generationFinalizationTimeout = Duration(seconds: 90);
  static const _streamRevealInterval = Duration(milliseconds: 18);

  /// A locally-chosen replay variant awaiting commit. The selection only
  /// becomes the canonical turn ("the truth") when the player takes their next
  /// action (sends a message / continues), at which point it is flushed.
  String? _pendingVariantEventId;
  int? _pendingVariantIndex;

  PlayCubit({required this.instanceId, WsManager? ws})
    : _ws = ws ?? WsManager(),
      super(const PlayState()) {
    _init();
  }

  List<GameEvent> _trimEvents(List<GameEvent> events) {
    if (events.length <= _activeEventLimit) return events;
    return events.sublist(events.length - _activeEventLimit);
  }

  List<Memory> _trimMemories(List<Memory> memories) {
    if (memories.length <= _activeMemoryLimit) return memories;
    return memories.sublist(memories.length - _activeMemoryLimit);
  }

  void _init() {
    _loadCachedEvents();
    _connectAndLoad();

    _instanceSub = _ws.onInstanceLoaded.listen((msg) {
      final data = msg['data'];
      if (data == null) return;

      final instance = WorldInstance.fromJson(data['instance']);
      final template = data['template'] != null
          ? WorldTemplate.fromJson(data['template'])
          : null;
      final events =
          (data['recentEvents'] as List?)
              ?.map((e) => GameEvent.fromJson(e))
              .toList() ??
          [];
      final memories =
          (data['memories'] as List?)
              ?.map((e) => Memory.fromJson(e))
              .toList() ??
          [];
      final characters =
          (data['characters'] as List?)
              ?.map(
                (e) => CharacterProfile.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      final eventWindow = data['eventWindow'] as Map?;
      final totalEvents =
          (eventWindow?['total'] as num?)?.toInt() ?? instance.meta.totalEvents;
      final hasOlderEvents =
          eventWindow?['hasOlder'] == true || totalEvents > events.length;

      emit(
        state.copyWith(
          instance: instance,
          template: template,
          events: _trimEvents(events),
          memories: _trimMemories(memories),
          characters: characters,
          totalEvents: totalEvents,
          hasOlderEvents: hasOlderEvents,
          milestones: instance.meta.milestones,
          isLoading: false,
        ),
      );
    });

    _characterCodexSub = _ws.onCharacterCodexUpdated.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final incoming =
          (msg['characters'] as List?)
              ?.map(
                (e) => CharacterProfile.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      final focused = msg['focused_character_id']?.toString();
      emit(
        state.copyWith(
          characters: incoming,
          instance: state.instance?.copyWith(
            focusCharacterId: focused == 'null' ? null : focused,
          ),
        ),
      );
    });

    // Tokens stream in here as the world weaves the tale. We buffer raw chunks
    // and reveal them on a short cadence so large network frames do not snap
    // abruptly into the narrator panel.
    _deltaSub = _ws.onGenerationDelta.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      _armGenerationWatchdog(_generationQuietTimeout);
      // Tokens are flowing again — drop any "retrying" notice.
      if (state.notice != null) emit(state.copyWith(notice: null));
      _queueGenerationText(msg['delta']?.toString() ?? '');
    });

    // A turn hit a transient failure and is being retried server-side. Keep the
    // loader up and tell the player it's still coming, rather than a dead stream.
    _retryingSub = _ws.onGenerationRetrying.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      if (!state.isGenerating) return;
      _armGenerationWatchdog(_generationQuietTimeout);
      emit(state.copyWith(notice: 'The world stumbled — trying again…'));
    });

    _streamEndSub = _ws.onGenerationStreamEnd.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final narrative = msg['narrative']?.toString();
      if (narrative != null && narrative.length > _streamTarget.length) {
        _streamTarget = narrative;
      }
      // The story prose is complete (any choices/bookkeeping tail is hidden and
      // still generating). Mark it so the reveal loop can drop the "writing"
      // indicator once it finishes painting the remaining buffered text — the
      // composer stays locked via isGenerating until generation_complete.
      _proseStreamEnded = true;
      _armGenerationWatchdog(_generationFinalizationTimeout);
      _startGenerationReveal();
    });

    // The narrator's choices arrive ahead of generation_complete. Attach them to
    // the in-flight optimistic turn so the chips appear with the settled prose,
    // instead of after the post-prose bookkeeping. generation_complete will later
    // replace the event with the final (audited) choices.
    _choicesReadySub = _ws.onChoicesReady.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final choices = Choice.listFromAny(msg['choices']);
      if (choices.isEmpty) return;
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      if (idx < 0) return;
      events[idx] = events[idx].copyWith(choices: choices);
      emit(state.copyWith(events: events, choicesPreview: true));
    });

    _generationSub = _ws.onGenerationComplete.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;

      final eventData = msg['event'] as Map<String, dynamic>;
      final narrative = eventData['narrative']?.toString() ?? _streamTarget;
      _finishGenerationReveal(narrative);
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      final playerInput = idx >= 0 ? events[idx].playerInput : null;

      // Finalize the streamed turn as one event (player input + AI response),
      // matching how the server persists and reloads turns.
      final finalEvent = GameEvent(
        id: eventData['id'] ?? '',
        instanceId: instanceId,
        sequence: eventData['sequence'] ?? 0,
        type: eventData['event_type']?.toString() ?? 'narration',
        playerInput: playerInput,
        aiResponse: narrative,
        sceneTag: eventData['scene_tag'],
        emotionalTone: eventData['emotional_tone'],
        modelUsed: eventData['model_used']?.toString() ?? '',
        createdAt: DateTime.now(),
        choices: Choice.listFromAny(eventData['choices']),
        milestone: eventData['milestone']?.toString(),
        timeAdvanced: eventData['time_advanced']?.toString(),
        fateThread: eventData['fate_thread']?.toString(),
        presentCharacters: GameEvent.presentFromAny(
          eventData['present_characters'],
        ),
        trackableMentions: TrackableMention.listFromAny(
          eventData['trackable_mentions'],
        ),
      );

      // Stat deltas vs the pre-turn state — drives HUD pulses + delta chips.
      Map<String, num>? statDeltas;
      final stateDiff = eventData['state_diff'];
      if (stateDiff is Map &&
          stateDiff['world_state'] is Map &&
          state.instance != null) {
        final old = state.instance!.worldState;
        final next = Map<String, dynamic>.from(stateDiff['world_state'] as Map);
        final deltas = <String, num>{};
        next.forEach((key, value) {
          final nv = value is num ? value : num.tryParse(value.toString());
          if (nv == null) return;
          final ov = old[key];
          if (ov != null && nv != ov) deltas[key] = nv - ov;
        });
        if (deltas.isNotEmpty) statDeltas = deltas;
      }

      if (idx >= 0) {
        events[idx] = finalEvent;
      } else {
        events.add(finalEvent);
      }

      LocalDb.insertEvent(finalEvent);
      _clearGenerationTimers();
      _streamBuffer = '';
      _streamTarget = '';
      final trimmedEvents = _trimEvents(events);
      final nextTotalEvents = finalEvent.sequence > state.totalEvents
          ? finalEvent.sequence
          : state.totalEvents;

      emit(
        state.copyWith(
          events: trimmedEvents,
          isGenerating: false,
          narrativeStreaming: false,
          choicesPreview: false,
          notice: null,
          instance: state.instance?.applyStateDiff(eventData['state_diff']),
          totalEvents: nextTotalEvents,
          hasOlderEvents:
              state.hasOlderEvents || nextTotalEvents > trimmedEvents.length,
          lastStatDeltas: statDeltas,
        ),
      );
    });

    _milestoneSub = _ws.onMilestoneUnlocked.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final raw = msg['milestone'];
      final label = (raw is Map ? raw['label'] : raw)?.toString();
      if (label == null || label.isEmpty) return;
      // Append to the timeline log (dedup by sequence) so the story-spine grows
      // live, in addition to firing the one-shot toast.
      final seq = (raw is Map ? raw['sequence'] as num? : null)?.toInt();
      final milestones = [...state.milestones];
      if (seq != null && !milestones.any((m) => m.sequence == seq)) {
        milestones.add(
          Milestone(label: label, sequence: seq, at: DateTime.now()),
        );
      }
      emit(
        state.copyWith(
          lastMilestone: label,
          milestoneStamp: DateTime.now().millisecondsSinceEpoch,
          milestones: milestones,
        ),
      );
    });

    // Replay streams an alternative for an existing turn — grow that event's
    // narrator panel in place as tokens arrive (same feel as a fresh turn).
    _replayDeltaSub = _ws.onReplayDelta.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final eventId = msg['eventId']?.toString();
      if (eventId == null || eventId != _replayEventId) return;
      _armReplayWatchdog(); // tokens are flowing — keep the timeout fresh
      _queueReplayText(eventId, msg['delta']?.toString() ?? '');
    });

    _replayCompleteSub = _ws.onReplayComplete.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final eventId = msg['eventId']?.toString();
      if (eventId == null) return;

      final variants =
          (msg['variants'] as List?)
              ?.map(
                (v) =>
                    ReplayVariant.fromJson(Map<String, dynamic>.from(v as Map)),
              )
              .toList() ??
          const <ReplayVariant>[];
      final selected = (msg['selected_index'] as num?)?.toInt() ?? 0;
      final narrative = msg['narrative']?.toString() ?? _replayBuffer;
      _finishReplayReveal(eventId, narrative);
      final selectedVariant = selected >= 0 && selected < variants.length
          ? variants[selected]
          : null;

      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        events[idx] = events[idx].copyWith(
          aiResponse: narrative,
          modelUsed: selectedVariant?.modelUsed,
          replayVariants: variants,
          selectedReplayIndex: selected,
          // Fresh chips + scene presence, regenerated server-side from the new
          // variant (the old ones reflected the replaced prose).
          choices: Choice.listFromAny(msg['choices']),
          presentCharacters: GameEvent.presentFromAny(
            msg['present_characters'],
          ),
          trackableMentions: TrackableMention.listFromAny(
            msg['trackable_mentions'],
          ),
        );
        LocalDb.insertEvent(events[idx]);
      }
      _endReplay();

      // A replay can re-fold instance state (world_state / flags / scene /
      // location / time). The server now ships that snapshot on the frame; apply
      // it inline so the HUD + scene reflect the chosen variant without a
      // round-trip. If the snapshot is absent (older server), fall back to a
      // full reload to stay consistent.
      final instanceState = msg['instance_state'];
      if (instanceState is Map &&
          instanceState.isNotEmpty &&
          state.instance != null) {
        final updated = state.instance!.applyInstanceState(
          Map<String, dynamic>.from(instanceState),
        );
        emit(
          state.copyWith(
            events: events,
            instance: updated,
            isGenerating: false,
          ),
        );
      } else {
        emit(state.copyWith(events: events, isGenerating: false));
        _ws.loadInstance(instanceId);
      }
    });

    _memorySub = _ws.onMemoriesCurated.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final newMems =
          (msg['memories'] as List?)?.map((m) => Memory.fromJson(m)).toList() ??
          [];
      emit(
        state.copyWith(
          memories: _trimMemories([...state.memories, ...newMems]),
        ),
      );
    });

    _errorSub = _ws.onError.listen((msg) {
      // A replay in flight takes precedence: ANY error frame (including
      // GENERATION_IN_PROGRESS) must tear the replay down so the loader can
      // never get stranded. Restore the turn's original prose.
      if (_replayEventId != null) {
        _restoreReplayedEvent(
          msg['message']?.toString() ?? 'Could not replay this response.',
        );
        return;
      }

      if (msg['code'] == 'GENERATION_IN_PROGRESS') {
        final events = [...state.events];
        final idx = events.lastIndexWhere(
          (e) => e.isOptimistic && ((e.aiResponse ?? '').trim().isEmpty),
        );
        // Preserve the input so it isn't silently lost, and TELL the player why
        // nothing happened (the prior turn's lock is still held) instead of a
        // confusing no-op.
        final droppedInput = idx >= 0 ? events[idx].playerInput : null;
        if (idx >= 0) events.removeAt(idx);
        _clearGenerationTimers();
        emit(
          state.copyWith(
            events: events,
            isGenerating: false,
            notice: null,
            error:
                'Still finishing your previous turn — give it a moment, then resend.',
            lastFailedInput: droppedInput,
          ),
        );
        return;
      }

      final optimisticEvents = [...state.events];
      final optimisticIdx = optimisticEvents.lastIndexWhere(
        (e) => e.isOptimistic,
      );
      final hasVisibleOptimisticText =
          optimisticIdx >= 0 &&
          ((optimisticEvents[optimisticIdx].aiResponse ?? '')
              .trim()
              .isNotEmpty);
      if (hasVisibleOptimisticText) {
        _finishGenerationReveal(_streamTarget);
        _clearGenerationTimers();
        _ws.loadInstance(instanceId);
        emit(
          state.copyWith(
            events: optimisticEvents,
            isGenerating: false,
            notice: null,
            error: null,
          ),
        );
        return;
      }

      _streamBuffer = '';
      _streamTarget = '';
      _clearGenerationTimers();
      // Drop the in-progress optimistic turn but KEEP its text so the player can
      // resend with one tap rather than re-typing the whole message.
      final droppedOptimistic = state.events
          .where((e) => e.isOptimistic)
          .toList();
      final droppedInput = droppedOptimistic.isNotEmpty
          ? droppedOptimistic.last.playerInput
          : null;
      final events = state.events.where((e) => !e.isOptimistic).toList();
      emit(
        state.copyWith(
          events: events,
          isGenerating: false,
          notice: null,
          error: msg['message'] ?? 'An error occurred',
          lastFailedInput: droppedInput,
        ),
      );
    });

    _connectionSub = _ws.onConnectionState.listen((connected) {
      emit(state.copyWith(isConnected: connected));
    });
  }

  Future<void> _connectAndLoad() async {
    final token = await SecureStore.getToken();
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Please sign in to load this world.',
        ),
      );
      return;
    }

    await _ws.connect(token, force: true);
    _ws.loadInstance(instanceId);
  }

  Future<void> _loadCachedEvents() async {
    try {
      final cached = await LocalDb.getEvents(instanceId, limit: 50);
      if (cached.isNotEmpty && state.events.isEmpty) {
        emit(
          state.copyWith(
            events: cached,
            totalEvents: cached.length,
            hasOlderEvents: false,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    if (state.isGenerating ||
        state.replayingEventId != null ||
        message.trim().isEmpty) {
      return;
    }

    // Lock in any variant the player browsed to before this turn is generated,
    // so the world weaves forward from the prose they actually chose.
    await _flushPendingVariant();

    _streamBuffer = '';
    _streamTarget = '';
    _proseStreamEnded = false;
    _clearGenerationTimers();
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: message,
    );

    emit(
      state.copyWith(
        events: _trimEvents([...state.events, optimisticEvent]),
        isGenerating: true,
        narrativeStreaming: true,
        choicesPreview: false,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
        notice: null,
        lastFailedInput: null,
        lastStatDeltas: null,
      ),
    );

    _armGenerationWatchdog(_generationFirstTokenTimeout);
    _ws.sendChatMessage(instanceId, message);
  }

  /// Resend the input from a turn that failed to send (lock held, error, or
  /// offline) without making the player re-type it.
  void retryLastFailed() {
    final pending = state.lastFailedInput;
    if (pending == null || pending.trim().isEmpty) return;
    if (state.isGenerating || state.replayingEventId != null) return;
    sendMessage(pending);
  }

  /// Let the world advance the story autonomously — no player message.
  /// [advance] turns the quiet continue into a time skip (calendar tick):
  /// 'hours' | 'day' | 'days' | 'season'.
  Future<void> continueStory({String? advance}) async {
    if (state.isGenerating || state.replayingEventId != null) return;

    await _flushPendingVariant();

    _streamBuffer = '';
    _streamTarget = '';
    _proseStreamEnded = false;
    _clearGenerationTimers();
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: '',
    );

    emit(
      state.copyWith(
        events: _trimEvents([...state.events, optimisticEvent]),
        isGenerating: true,
        narrativeStreaming: true,
        choicesPreview: false,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
        lastStatDeltas: null,
      ),
    );

    _armGenerationWatchdog(_generationFirstTokenTimeout);
    _ws.sendContinue(instanceId, advance: advance);
  }

  /// One-shot acknowledgement of the milestone toast.
  void clearMilestone() {
    if (state.lastMilestone != null) {
      emit(state.copyWith(lastMilestone: null));
    }
  }

  void clearError() {
    // Dismissing the error also abandons the retry — drop the held input.
    emit(state.copyWith(error: null, lastFailedInput: null));
  }

  bool _protagonistPrompted = false;

  /// GM worlds (non-sentient) need the player to define their own character
  /// (the locked protagonist) on first play. True until done or skipped.
  bool get shouldOnboardProtagonist {
    final t = state.template;
    if (t == null || state.isLoading || _protagonistPrompted) return false;
    if (t.isSentient) return false; // sentient protagonist is the AI persona
    return !state.characters.any((c) => c.isProtagonist);
  }

  void skipProtagonistOnboarding() => _protagonistPrompted = true;

  /// Persist a player edit to a character/protagonist card and reflect it locally.
  Future<void> editCharacter(
    String characterId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updated = await ChronicleRepository.editCharacter(
        characterId,
        updates,
      );
      final list = state.characters
          .map((c) => c.id == characterId ? updated : c)
          .toList();
      emit(state.copyWith(characters: list));
    } catch (_) {
      emit(state.copyWith(error: 'Could not save character changes.'));
    }
  }

  /// Establish the player's character as the instance protagonist.
  Future<void> setPlayerProtagonist(String name, {String? identity}) async {
    _protagonistPrompted = true;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // Optimistically add a protagonist card so onboarding won't re-trigger.
    final optimistic = CharacterProfile(
      id: 'pending-protagonist',
      canonicalName: trimmed,
      role: 'protagonist (the player)',
      isProtagonist: true,
    );
    emit(state.copyWith(characters: [optimistic, ...state.characters]));
    try {
      await ChronicleRepository.setProtagonist(
        instanceId,
        name: trimmed,
        identity: identity,
      );
    } catch (_) {
      // Best-effort: the card still seeds emergently on the next turn.
    }
  }

  /// Player-driven CORRECTION / PROMOTE surface ("Track this character" /
  /// "This person is my sister"). Mints/updates a codex card for a name visible
  /// in the prose that the projection pipeline missed, optionally asserting a
  /// typed kinship tie. Server-side this writes an EVENT-DERIVED projection
  /// (delta fold + stub promotion + typed edge + ledger entry), so the card is
  /// canonical and rewind-replayable. On success the codex list is refreshed;
  /// the WS `character_codex_updated` frame will also arrive to reconcile.
  Future<bool> trackEntity(
    String name, {
    String? role,
    String? appearance,
    String? persona,
    String? relationKind,
    String? relationLabel,
    String? relationTo,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      final result = await ChronicleRepository.trackEntity(
        instanceId,
        name: trimmed,
        role: role,
        appearance: appearance,
        persona: persona,
        relationKind: relationKind,
        relationLabel: relationLabel,
        relationTo: relationTo,
      );
      // Optimistically splice the tracked card in (dedup by id); the WS frame
      // will reconcile authoritatively when it arrives.
      final list = [
        ...state.characters.where((c) => c.id != result.character.id),
        result.character,
      ];
      emit(state.copyWith(characters: list));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          error: 'Could not track this character. Please try again.',
        ),
      );
      return false;
    }
  }

  /// Update in-chat settings (POV, chat mode, reply length). Optimistically reflects the
  /// change locally, then persists; the server busts its session cache so the
  /// next turn uses the new values.
  Future<void> updateSettings({
    String? narrationPov,
    String? mode,
    String? messageLength,
    String? focusCharacterId,
    String? personaId,
    bool clearFocusCharacter = false,
    bool clearPersona = false,
  }) async {
    final inst = state.instance;
    if (inst != null) {
      // Apply non-focus fields first, then touch focus ONLY when explicitly
      // clearing or setting it (copyWith's _unset sentinel keeps it otherwise).
      var nextInst = inst.copyWith(
        narrationPov: narrationPov,
        mode: mode,
        messageLength: messageLength,
      );
      if (clearFocusCharacter) {
        nextInst = nextInst.copyWith(focusCharacterId: null);
      } else if (focusCharacterId != null) {
        nextInst = nextInst.copyWith(focusCharacterId: focusCharacterId);
      }
      if (clearPersona) {
        nextInst = nextInst.copyWith(personaId: null);
      } else if (personaId != null) {
        nextInst = nextInst.copyWith(personaId: personaId);
      }
      emit(state.copyWith(instance: nextInst));
    }
    try {
      await ChronicleRepository.updateSettings(
        instanceId,
        narrationPov: narrationPov,
        mode: mode,
        messageLength: messageLength,
        focusCharacterId: focusCharacterId,
        personaId: personaId,
        clearFocusCharacter: clearFocusCharacter,
        clearPersona: clearPersona,
      );
    } catch (_) {
      emit(
        state.copyWith(error: 'Could not update settings. Please try again.'),
      );
    }
  }

  /// Reset the entire playthrough to its opening line. Server wipes all events,
  /// memories, scene summaries, characters (+ Pinecone vectors) and restores
  /// default state; we clear local cache and reload the fresh opening turn.
  Future<void> resetChat() async {
    if (state.isGenerating || state.replayingEventId != null) return;
    _pendingVariantEventId = null;
    _pendingVariantIndex = null;
    emit(
      state.copyWith(
        events: const [],
        totalEvents: 0,
        hasOlderEvents: false,
        isLoading: true,
        error: null,
      ),
    );
    try {
      await HomeRepository.resetInstance(instanceId);
      await LocalDb.clearInstanceCache(instanceId);
      _ws.loadInstance(instanceId); // pull the re-seeded opening line + state
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not reset the chat. Please try again.',
        ),
      );
      _ws.loadInstance(instanceId); // resync to server truth on failure
    }
  }

  /// Rewind the story to [sequence]: removes that turn and everything after it.
  /// Optimistically trims the UI, asks the server to roll back state/memories,
  /// then reloads the authoritative state.
  Future<void> rewind(int sequence) async {
    if (state.isGenerating) return;

    final kept = state.events.where((e) => e.sequence < sequence).toList();
    emit(
      state.copyWith(
        events: kept,
        totalEvents: kept.length,
        hasOlderEvents: false,
        error: null,
      ),
    );

    try {
      await ChronicleRepository.rewind(instanceId, sequence);
      await LocalDb.clearInstanceCache(instanceId);
      // Pull the rolled-back state (events, stats, memories) back from the server.
      _ws.loadInstance(instanceId);
    } catch (_) {
      emit(state.copyWith(error: 'Could not rewind. Please try again.'));
      _ws.loadInstance(instanceId); // resync to server truth on failure
    }
  }

  /// Edit a generated AI response and persist it to the backend. Memories
  /// sourced from that turn are re-curated server-side.
  Future<void> editAiResponse(GameEvent event, String aiResponse) async {
    if (state.isGenerating || event.id.isEmpty || event.isOptimistic) return;

    final next = aiResponse.trim();
    if (next.isEmpty || next == (event.aiResponse ?? '').trim()) return;

    final idx = state.events.indexWhere((e) => e.id == event.id);
    if (idx < 0) return;

    final before = state.events[idx];
    final after = before.copyWith(aiResponse: next, isUserEdited: true);
    final optimistic = [...state.events];
    optimistic[idx] = after;
    emit(state.copyWith(events: optimistic, error: null));

    try {
      final meta = await ChronicleRepository.editEvent(
        event.id,
        aiResponse: next,
      );
      // Swap in the server-regenerated chips + presence for the rewritten prose
      // (the optimistic copy carried the old ones).
      final settled = meta == null
          ? after
          : after.copyWith(
              choices: meta.choices,
              presentCharacters: meta.presentCharacters,
              // Refresh underline data for the rewritten prose; the optimistic
              // copy carried the pre-edit mentions.
              trackableMentions: meta.trackableMentions,
            );
      final committed = [...state.events];
      final cIdx = committed.indexWhere((e) => e.id == event.id);
      if (cIdx >= 0) {
        committed[cIdx] = settled;
        emit(state.copyWith(events: committed));
      }
      await LocalDb.insertEvent(settled);
    } catch (_) {
      final reverted = [...state.events];
      final revertIdx = reverted.indexWhere((e) => e.id == before.id);
      if (revertIdx >= 0) {
        reverted[revertIdx] = before;
      }
      emit(
        state.copyWith(
          events: reverted,
          error: 'Could not save edit. Please try again.',
        ),
      );
    }
  }

  /// Stream a fresh alternative for [event] in place, the same way a normal
  /// turn streams. The bubble drops into a "weaving" state and the narration
  /// rewrites itself token-by-token.
  void replayAiResponse(GameEvent event) {
    if (state.isGenerating ||
        state.replayingEventId != null ||
        event.id.isEmpty ||
        event.isOptimistic) {
      return;
    }

    _replayEventId = event.id;
    _replayBuffer = '';
    _replayOriginalResponse = event.aiResponse;

    // Clear the displayed prose so the bubble shows the weaving indicator until
    // the first token lands, then streams in — exactly like a fresh turn.
    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) events[idx] = events[idx].copyWith(aiResponse: '');

    emit(
      state.copyWith(
        events: events,
        replayingEventId: event.id,
        isGenerating: true,
        error: null,
      ),
    );
    _armReplayWatchdog();
    _ws.sendReplay(instanceId, event.id);
  }

  /// (Re)start the liveness timer for an in-flight replay.
  void _armReplayWatchdog() {
    _replayWatchdog?.cancel();
    _replayWatchdog = Timer(_replayTimeout, () {
      if (_replayEventId == null) return;
      _restoreReplayedEvent('The replay timed out. Please try again.');
    });
  }

  void _armGenerationWatchdog(Duration timeout) {
    _generationWatchdog?.cancel();
    _generationWatchdog = Timer(timeout, () {
      if (!state.isGenerating || state.replayingEventId != null) return;
      _generationWatchdog = null;

      _finishGenerationReveal(_streamTarget);
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      final hasVisibleText =
          idx >= 0 && ((events[idx].aiResponse ?? '').trim().isNotEmpty);

      if (hasVisibleText) {
        _ws.loadInstance(instanceId);
        emit(state.copyWith(events: events, isGenerating: false, error: null));
        return;
      }

      _streamBuffer = '';
      _streamTarget = '';
      _ws.loadInstance(instanceId);
      emit(
        state.copyWith(
          events: events.where((e) => !e.isOptimistic).toList(),
          isGenerating: false,
          error: null,
        ),
      );
    });
  }

  void _clearGenerationTimers() {
    _generationWatchdog?.cancel();
    _generationWatchdog = null;
    _streamRevealTimer?.cancel();
    _streamRevealTimer = null;
  }

  void _queueGenerationText(String chunk) {
    if (chunk.isEmpty) return;
    _streamTarget += chunk;
    _startGenerationReveal();
  }

  void _startGenerationReveal() {
    if (_streamRevealTimer != null) return;
    _streamRevealTimer = Timer.periodic(_streamRevealInterval, (_) {
      if (_streamBuffer.length >= _streamTarget.length) {
        _streamRevealTimer?.cancel();
        _streamRevealTimer = null;
        // Reveal has caught up to the prose. If the server already signalled the
        // prose is done, the story is fully painted — drop the "writing"
        // indicator now instead of holding it until generation_complete.
        if (_proseStreamEnded && state.narrativeStreaming) {
          emit(state.copyWith(narrativeStreaming: false));
        }
        return;
      }

      final remaining = _streamTarget.length - _streamBuffer.length;
      final step = remaining <= 18
          ? remaining
          : (remaining / 3).ceil().clamp(8, 36);
      _streamBuffer = _streamTarget.substring(0, _streamBuffer.length + step);
      _replaceOptimisticAiResponse(_streamBuffer);
    });
  }

  void _finishGenerationReveal(String narrative) {
    _streamRevealTimer?.cancel();
    _streamRevealTimer = null;
    _proseStreamEnded = false;
    if (narrative.isEmpty) return;
    _streamTarget = narrative;
    _streamBuffer = narrative;
    _replaceOptimisticAiResponse(narrative);
  }

  void _replaceOptimisticAiResponse(String text) {
    if (text.isEmpty || isClosed) return;
    final events = [...state.events];
    final idx = events.lastIndexWhere((e) => e.isOptimistic);
    if (idx < 0) return;
    events[idx] = events[idx].copyWith(aiResponse: text);
    emit(state.copyWith(events: events));
  }

  void _queueReplayText(String eventId, String chunk) {
    if (chunk.isEmpty) return;
    _replayBuffer += chunk;
    if (_replayRevealTimer != null) return;
    _replayRevealTimer = Timer.periodic(_streamRevealInterval, (_) {
      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx < 0) {
        _replayRevealTimer?.cancel();
        _replayRevealTimer = null;
        return;
      }

      final current = events[idx].aiResponse ?? '';
      if (current.length >= _replayBuffer.length) {
        _replayRevealTimer?.cancel();
        _replayRevealTimer = null;
        return;
      }

      final remaining = _replayBuffer.length - current.length;
      final step = remaining <= 18
          ? remaining
          : (remaining / 3).ceil().clamp(8, 36);
      events[idx] = events[idx].copyWith(
        aiResponse: _replayBuffer.substring(0, current.length + step),
      );
      emit(state.copyWith(events: events));
    });
  }

  void _finishReplayReveal(String eventId, String narrative) {
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayBuffer = narrative;
    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      events[idx] = events[idx].copyWith(aiResponse: narrative);
      emit(state.copyWith(events: events));
    }
  }

  /// Clear all in-flight replay bookkeeping (success path).
  void _endReplay() {
    _replayWatchdog?.cancel();
    _replayWatchdog = null;
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayEventId = null;
    _replayBuffer = '';
    _replayOriginalResponse = null;
    if (state.replayingEventId != null) {
      emit(state.copyWith(replayingEventId: null));
    }
  }

  /// Failure path: put the turn's original prose back, surface a message, and
  /// release the loader.
  void _restoreReplayedEvent(String message) {
    final id = _replayEventId;
    final original = _replayOriginalResponse;
    final events = [...state.events];
    if (id != null && original != null) {
      final idx = events.indexWhere((e) => e.id == id);
      if (idx >= 0) events[idx] = events[idx].copyWith(aiResponse: original);
    }
    _replayWatchdog?.cancel();
    _replayWatchdog = null;
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayEventId = null;
    _replayBuffer = '';
    _replayOriginalResponse = null;
    emit(
      state.copyWith(
        events: events,
        isGenerating: false,
        replayingEventId: null,
        error: message,
      ),
    );
  }

  /// Browse to a replay variant. This is LOCAL ONLY — it previews the variant
  /// and remembers it as pending; the choice is committed as canonical when the
  /// player next acts (see [_flushPendingVariant]).
  void selectReplayVariant(GameEvent event, int index) {
    if (state.isGenerating || state.replayingEventId != null) return;
    if (index < 0 || index >= event.replayVariants.length) return;

    _pendingVariantEventId = event.id;
    _pendingVariantIndex = index;

    final next = [...state.events];
    final idx = next.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      next[idx] = next[idx].copyWith(
        aiResponse: event.replayVariants[index].narrative,
        modelUsed: event.replayVariants[index].modelUsed,
        selectedReplayIndex: index,
        // Show the browsed variant's OWN chips + presence + underline mentions
        // (all stored per variant) so the preview is internally consistent.
        choices: event.replayVariants[index].choices,
        presentCharacters: event.replayVariants[index].presentCharacters,
        trackableMentions: event.replayVariants[index].trackableMentions,
      );
    }
    emit(state.copyWith(events: next, error: null));
  }

  /// Commit a pending variant selection to the backend so the chosen prose
  /// becomes the canonical turn the next generation reads as history. Awaited
  /// before dispatching the next turn so there is no read-after-write race.
  Future<void> _flushPendingVariant() async {
    final id = _pendingVariantEventId;
    final index = _pendingVariantIndex;
    _pendingVariantEventId = null;
    _pendingVariantIndex = null;
    if (id == null || index == null) return;
    try {
      final updated = await ChronicleRepository.selectReplayVariant(id, index);
      final next = [...state.events];
      final idx = next.indexWhere((e) => e.id == id);
      if (idx >= 0) next[idx] = updated;
      await LocalDb.insertEvent(updated);
      emit(state.copyWith(events: next));
    } catch (_) {
      // Non-fatal: the locally-previewed variant still shows; selection simply
      // wasn't persisted. Surfacing an error here would block the next turn.
    }
  }

  @override
  Future<void> close() async {
    _replayWatchdog?.cancel();
    _clearGenerationTimers();
    _replayRevealTimer?.cancel();
    await _generationSub.cancel();
    await _deltaSub.cancel();
    await _streamEndSub.cancel();
    await _choicesReadySub.cancel();
    await _retryingSub.cancel();
    await _memorySub.cancel();
    await _errorSub.cancel();
    await _connectionSub.cancel();
    await _instanceSub.cancel();
    await _characterCodexSub.cancel();
    await _replayDeltaSub.cancel();
    await _replayCompleteSub.cancel();
    await _milestoneSub.cancel();
    await _ws.disconnect();
    await super.close();
  }
}
