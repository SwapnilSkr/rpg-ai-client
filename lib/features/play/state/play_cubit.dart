import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/ws_manager.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_db.dart';
import '../../chronicle/data/chronicle_repository.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/world_instance.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/character_profile.dart';

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

  /// Accumulates streamed narrative tokens for the in-progress turn.
  String _streamBuffer = '';

  PlayCubit({required this.instanceId, WsManager? ws})
    : _ws = ws ?? WsManager(),
      super(const PlayState()) {
    _init();
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
              ?.map((e) => CharacterProfile.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [];

      emit(
        state.copyWith(
          instance: instance,
          template: template,
          events: events,
          memories: memories,
          characters: characters,
          isLoading: false,
        ),
      );
    });

    _characterCodexSub = _ws.onCharacterCodexUpdated.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final incoming =
          (msg['characters'] as List?)
              ?.map((e) => CharacterProfile.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [];
      final focused = msg['focused_character_id']?.toString();
      emit(state.copyWith(
        characters: incoming,
        instance: state.instance?.copyWith(
          focusCharacterId: focused == 'null' ? null : focused,
        ),
      ));
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
        createdAt: DateTime.now(),
      );

      if (idx >= 0) {
        events[idx] = finalEvent;
      } else {
        events.add(finalEvent);
      }

      LocalDb.insertEvent(finalEvent);
      _streamBuffer = '';

      emit(
        state.copyWith(
          events: events,
          isGenerating: false,
          instance: state.instance?.applyStateDiff(eventData['state_diff']),
        ),
      );
    });

    _memorySub = _ws.onMemoriesCurated.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final newMems =
          (msg['memories'] as List?)?.map((m) => Memory.fromJson(m)).toList() ??
          [];
      emit(state.copyWith(memories: [...state.memories, ...newMems]));
    });

    _errorSub = _ws.onError.listen((msg) {
      if (msg['code'] == 'GENERATION_IN_PROGRESS') return;
      _streamBuffer = '';
      // Drop the in-progress optimistic turn so the player can retry cleanly.
      final events =
          state.events.where((e) => !e.isOptimistic).toList();
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
        emit(state.copyWith(events: cached));
      }
    } catch (_) {}
  }

  void sendMessage(String message) {
    if (state.isGenerating || message.trim().isEmpty) return;

    _streamBuffer = '';
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: message,
    );

    emit(
      state.copyWith(
        events: [...state.events, optimisticEvent],
        isGenerating: true,
        error: null,
      ),
    );

    _ws.sendChatMessage(instanceId, message);
  }

  /// Let the world advance the story autonomously — no player message.
  void continueStory() {
    if (state.isGenerating) return;

    _streamBuffer = '';
    final optimisticEvent =
        GameEvent.optimistic(instanceId: instanceId, playerInput: '');

    emit(
      state.copyWith(
        events: [...state.events, optimisticEvent],
        isGenerating: true,
        error: null,
      ),
    );

    _ws.sendContinue(instanceId);
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }

  /// Update in-chat settings (narration POV, tone). Optimistically reflects the
  /// change locally, then persists; the server busts its session cache so the
  /// next turn uses the new values.
  Future<void> updateSettings({
    String? narrationPov,
    String? tone,
    String? focusCharacterId,
    bool clearFocusCharacter = false,
  }) async {
    final inst = state.instance;
    if (inst != null) {
      final nextInst = (clearFocusCharacter)
          ? inst.copyWith(
              narrationPov: narrationPov,
              tone: tone,
              focusCharacterId: null,
            )
          : (focusCharacterId != null)
              ? inst.copyWith(
                  narrationPov: narrationPov,
                  tone: tone,
                  focusCharacterId: focusCharacterId,
                )
              : inst.copyWith(
                  narrationPov: narrationPov,
                  tone: tone,
                );
      emit(state.copyWith(
        instance: nextInst,
      ));
    }
    try {
      await ChronicleRepository.updateSettings(
        instanceId,
        narrationPov: narrationPov,
        tone: tone,
        focusCharacterId: focusCharacterId,
        clearFocusCharacter: clearFocusCharacter,
      );
    } catch (_) {
      emit(state.copyWith(error: 'Could not update settings. Please try again.'));
    }
  }

  /// Rewind the story to [sequence]: removes that turn and everything after it.
  /// Optimistically trims the UI, asks the server to roll back state/memories,
  /// then reloads the authoritative state.
  Future<void> rewind(int sequence) async {
    if (state.isGenerating) return;

    final kept =
        state.events.where((e) => e.sequence < sequence).toList();
    emit(state.copyWith(events: kept, error: null));

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
      emit(state.copyWith(
        events: reverted,
        error: 'Could not save edit. Please try again.',
      ));
    }
  }

  @override
  Future<void> close() async {
    await _generationSub.cancel();
    await _deltaSub.cancel();
    await _memorySub.cancel();
    await _errorSub.cancel();
    await _connectionSub.cancel();
    await _instanceSub.cancel();
    await _characterCodexSub.cancel();
    await _ws.disconnect();
    await super.close();
  }
}
