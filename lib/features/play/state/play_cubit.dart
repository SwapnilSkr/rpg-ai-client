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
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final int totalEvents;
  final bool hasOlderEvents;

  /// Id of the event whose AI turn is currently being re-woven (streaming a
  /// replay variant). Drives the in-bubble weaving/streaming treatment and is
  /// independent of [isGenerating] (which gates the composer for new turns).
  final String? replayingEventId;

  const PlayState({
    this.instance,
    this.template,
    this.events = const [],
    this.memories = const [],
    this.characters = const [],
    this.isGenerating = false,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
    this.totalEvents = 0,
    this.hasOlderEvents = false,
    this.replayingEventId,
  });

  PlayState copyWith({
    WorldInstance? instance,
    WorldTemplate? template,
    List<GameEvent>? events,
    List<Memory>? memories,
    List<CharacterProfile>? characters,
    bool? isGenerating,
    bool? isConnected,
    bool? isLoading,
    String? error,
    int? totalEvents,
    bool? hasOlderEvents,
    Object? replayingEventId = _kUnset,
  }) {
    return PlayState(
      instance: instance ?? this.instance,
      template: template ?? this.template,
      events: events ?? this.events,
      memories: memories ?? this.memories,
      characters: characters ?? this.characters,
      isGenerating: isGenerating ?? this.isGenerating,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalEvents: totalEvents ?? this.totalEvents,
      hasOlderEvents: hasOlderEvents ?? this.hasOlderEvents,
      replayingEventId: identical(replayingEventId, _kUnset)
          ? this.replayingEventId
          : replayingEventId as String?,
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
    isConnected,
    isLoading,
    error,
    totalEvents,
    hasOlderEvents,
    replayingEventId,
  ];
}

class PlayCubit extends Cubit<PlayState> {
  final WsManager _ws;
  final String instanceId;
  late StreamSubscription _generationSub;
  late StreamSubscription _deltaSub;
  late StreamSubscription _memorySub;
  late StreamSubscription _errorSub;
  late StreamSubscription _connectionSub;
  late StreamSubscription _instanceSub;
  late StreamSubscription _characterCodexSub;
  late StreamSubscription _replayDeltaSub;
  late StreamSubscription _replayCompleteSub;

  /// Accumulates streamed narrative tokens for the in-progress turn.
  String _streamBuffer = '';

  /// In-progress streaming replay of an existing turn.
  String? _replayEventId;
  String _replayBuffer = '';
  String? _replayOriginalResponse;

  /// Safety net: if no replay frames arrive within this window we reset the
  /// loader so the bubble can never spin forever (dropped frame, stale lock,
  /// dead worker, …). Re-armed on every delta as a liveness signal.
  Timer? _replayWatchdog;
  static const _replayTimeout = Duration(seconds: 45);

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

    // Tokens stream in here as the world weaves the tale — grow the in-progress
    // turn's narrator panel in place so the player reads it as it's written.
    _deltaSub = _ws.onGenerationDelta.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      _streamBuffer += msg['delta']?.toString() ?? '';

      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      if (idx < 0) return;
      events[idx] = events[idx].copyWith(aiResponse: _streamBuffer);
      emit(state.copyWith(events: events));
    });

    _generationSub = _ws.onGenerationComplete.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;

      final eventData = msg['event'] as Map<String, dynamic>;
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      final playerInput = idx >= 0 ? events[idx].playerInput : null;

      // Finalize the streamed turn as one event (player input + AI response),
      // matching how the server persists and reloads turns.
      final finalEvent = GameEvent(
        id: eventData['id'] ?? '',
        instanceId: instanceId,
        sequence: eventData['sequence'] ?? 0,
        type: 'narration',
        playerInput: playerInput,
        aiResponse: eventData['narrative'] ?? _streamBuffer,
        sceneTag: eventData['scene_tag'],
        emotionalTone: eventData['emotional_tone'],
        modelUsed: eventData['model_used']?.toString() ?? '',
        createdAt: DateTime.now(),
      );

      if (idx >= 0) {
        events[idx] = finalEvent;
      } else {
        events.add(finalEvent);
      }

      LocalDb.insertEvent(finalEvent);
      _streamBuffer = '';
      final trimmedEvents = _trimEvents(events);
      final nextTotalEvents = finalEvent.sequence > state.totalEvents
          ? finalEvent.sequence
          : state.totalEvents;

      emit(
        state.copyWith(
          events: trimmedEvents,
          isGenerating: false,
          instance: state.instance?.applyStateDiff(eventData['state_diff']),
          totalEvents: nextTotalEvents,
          hasOlderEvents:
              state.hasOlderEvents || nextTotalEvents > trimmedEvents.length,
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
      _replayBuffer += msg['delta']?.toString() ?? '';

      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx < 0) return;
      events[idx] = events[idx].copyWith(aiResponse: _replayBuffer);
      emit(state.copyWith(events: events));
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
        );
        LocalDb.insertEvent(events[idx]);
      }
      _endReplay();
      emit(state.copyWith(events: events, isGenerating: false));
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

      // Outside replay, a stale in-progress notice is benign — ignore it.
      if (msg['code'] == 'GENERATION_IN_PROGRESS') return;

      _streamBuffer = '';
      // Drop the in-progress optimistic turn so the player can retry cleanly.
      final events = state.events.where((e) => !e.isOptimistic).toList();
      emit(
        state.copyWith(
          events: events,
          isGenerating: false,
          error: msg['message'] ?? 'An error occurred',
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
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: message,
    );

    emit(
      state.copyWith(
        events: _trimEvents([...state.events, optimisticEvent]),
        isGenerating: true,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
      ),
    );

    _ws.sendChatMessage(instanceId, message);
  }

  /// Let the world advance the story autonomously — no player message.
  Future<void> continueStory() async {
    if (state.isGenerating || state.replayingEventId != null) return;

    await _flushPendingVariant();

    _streamBuffer = '';
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: '',
    );

    emit(
      state.copyWith(
        events: _trimEvents([...state.events, optimisticEvent]),
        isGenerating: true,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
      ),
    );

    _ws.sendContinue(instanceId);
  }

  void clearError() {
    emit(state.copyWith(error: null));
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

  /// Update in-chat settings (POV, chat mode, reply length). Optimistically reflects the
  /// change locally, then persists; the server busts its session cache so the
  /// next turn uses the new values.
  Future<void> updateSettings({
    String? narrationPov,
    String? mode,
    String? messageLength,
    String? focusCharacterId,
    bool clearFocusCharacter = false,
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
      emit(state.copyWith(instance: nextInst));
    }
    try {
      await ChronicleRepository.updateSettings(
        instanceId,
        narrationPov: narrationPov,
        mode: mode,
        messageLength: messageLength,
        focusCharacterId: focusCharacterId,
        clearFocusCharacter: clearFocusCharacter,
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
      await ChronicleRepository.editEvent(event.id, aiResponse: next);
      await LocalDb.insertEvent(after);
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

  /// Clear all in-flight replay bookkeeping (success path).
  void _endReplay() {
    _replayWatchdog?.cancel();
    _replayWatchdog = null;
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
    await _generationSub.cancel();
    await _deltaSub.cancel();
    await _memorySub.cancel();
    await _errorSub.cancel();
    await _connectionSub.cancel();
    await _instanceSub.cancel();
    await _characterCodexSub.cancel();
    await _replayDeltaSub.cancel();
    await _replayCompleteSub.cancel();
    await _ws.disconnect();
    await super.close();
  }
}
