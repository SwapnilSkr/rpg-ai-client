import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/ws_manager.dart';
import '../../../core/storage/local_db.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/world_instance.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/models/memory.dart';

class PlayState extends Equatable {
  final WorldInstance? instance;
  final WorldTemplate? template;
  final List<GameEvent> events;
  final List<Memory> memories;
  final bool isGenerating;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  const PlayState({
    this.instance,
    this.template,
    this.events = const [],
    this.memories = const [],
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
      isGenerating: isGenerating ?? this.isGenerating,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [instance, template, events, memories, isGenerating, isConnected, isLoading, error];
}

class PlayCubit extends Cubit<PlayState> {
  final WsManager _ws;
  final String instanceId;
  late StreamSubscription _generationSub;
  late StreamSubscription _memorySub;
  late StreamSubscription _errorSub;
  late StreamSubscription _connectionSub;
  late StreamSubscription _instanceSub;

  PlayCubit({
    required this.instanceId,
    WsManager? ws,
  })  : _ws = ws ?? WsManager(),
        super(const PlayState()) {
    _init();
  }

  void _init() {
    _loadCachedEvents();
    _ws.loadInstance(instanceId);

    _instanceSub = _ws.onInstanceLoaded.listen((msg) {
      final data = msg['data'];
      if (data == null) return;

      final instance = WorldInstance.fromJson(data['instance']);
      final template = data['template'] != null
          ? WorldTemplate.fromJson(data['template'])
          : null;
      final events = (data['recentEvents'] as List?)
              ?.map((e) => GameEvent.fromJson(e))
              .toList() ??
          [];
      final memories = (data['memories'] as List?)
              ?.map((e) => Memory.fromJson(e))
              .toList() ??
          [];

      emit(state.copyWith(
        instance: instance,
        template: template,
        events: events,
        memories: memories,
        isLoading: false,
      ));
    });

    _generationSub = _ws.onGenerationComplete.listen((msg) {
      if (msg['instanceId'] != instanceId) return;

      final eventData = msg['event'] as Map<String, dynamic>;
      final newEvent = GameEvent(
        id: eventData['id'] ?? '',
        instanceId: instanceId,
        sequence: eventData['sequence'] ?? 0,
        type: 'narration',
        aiResponse: eventData['narrative'],
        sceneTag: eventData['scene_tag'],
        emotionalTone: eventData['emotional_tone'],
        createdAt: DateTime.now(),
      );

      LocalDb.insertEvent(newEvent);

      emit(state.copyWith(
        events: [...state.events, newEvent],
        isGenerating: false,
        instance: state.instance?.applyStateDiff(eventData['state_diff']),
      ));
    });

    _memorySub = _ws.onMemoriesCurated.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final newMems = (msg['memories'] as List?)
              ?.map((m) => Memory.fromJson(m))
              .toList() ??
          [];
      emit(state.copyWith(memories: [...state.memories, ...newMems]));
    });

    _errorSub = _ws.onError.listen((msg) {
      if (msg['code'] == 'GENERATION_IN_PROGRESS') return;
      emit(state.copyWith(
        isGenerating: false,
        error: msg['message'] ?? 'An error occurred',
      ));
    });

    _connectionSub = _ws.onConnectionState.listen((connected) {
      emit(state.copyWith(isConnected: connected));
    });
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

    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: message,
    );

    emit(state.copyWith(
      events: [...state.events, optimisticEvent],
      isGenerating: true,
      error: null,
    ));

    _ws.sendChatMessage(instanceId, message);
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }

  @override
  Future<void> close() {
    _generationSub.cancel();
    _memorySub.cancel();
    _errorSub.cancel();
    _connectionSub.cancel();
    _instanceSub.cancel();
    return super.close();
  }
}
