import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/memory.dart';
import '../data/chronicle_repository.dart';
import '../data/calendar_data.dart';

enum ChronicleTab { timeline, memories, calendar }

class ChronicleState extends Equatable {
  final List<GameEvent> events;
  final List<Memory> memories;
  final CalendarData? calendar;
  final bool isLoading;
  final String? error;
  final ChronicleTab activeTab;
  final int totalEvents;
  final int currentPage;

  const ChronicleState({
    this.events = const [],
    this.memories = const [],
    this.calendar,
    this.isLoading = false,
    this.error,
    this.activeTab = ChronicleTab.timeline,
    this.totalEvents = 0,
    this.currentPage = 1,
  });

  ChronicleState copyWith({
    List<GameEvent>? events,
    List<Memory>? memories,
    CalendarData? calendar,
    bool? isLoading,
    String? error,
    ChronicleTab? activeTab,
    int? totalEvents,
    int? currentPage,
  }) {
    return ChronicleState(
      events: events ?? this.events,
      memories: memories ?? this.memories,
      calendar: calendar ?? this.calendar,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeTab: activeTab ?? this.activeTab,
      totalEvents: totalEvents ?? this.totalEvents,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [
        events,
        memories,
        calendar,
        isLoading,
        error,
        activeTab,
        totalEvents,
        currentPage,
      ];
}

class ChronicleCubit extends Cubit<ChronicleState> {
  final String instanceId;

  ChronicleCubit({required this.instanceId}) : super(const ChronicleState());

  Future<void> loadEvents({int page = 1}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await ChronicleRepository.getEvents(instanceId, page: page);
      emit(state.copyWith(
        events: result['events'],
        totalEvents: result['total'],
        currentPage: page,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadMemories({bool includeArchived = false}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final memories = await ChronicleRepository.getMemories(
        instanceId,
        includeArchived: includeArchived,
      );
      emit(state.copyWith(memories: memories, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> editMemory(String memoryId, String text, {String? type, int? importance}) async {
    try {
      await ChronicleRepository.editMemory(
        memoryId,
        text: text,
        type: type,
        importance: importance,
      );
      emit(state.copyWith(
        memories: state.memories.map((m) {
          if (m.id == memoryId) {
            return m.copyWith(text: text, type: type, importance: importance);
          }
          return m;
        }).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteMemory(String memoryId) async {
    try {
      await ChronicleRepository.deleteMemory(memoryId);
      emit(state.copyWith(
        memories: state.memories.where((m) => m.id != memoryId).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> editEvent(String eventId, {String? aiResponse, String? playerInput}) async {
    try {
      await ChronicleRepository.editEvent(
        eventId,
        aiResponse: aiResponse,
        playerInput: playerInput,
      );
      await loadEvents(page: state.currentPage);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> loadCalendar() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final calendar = await ChronicleRepository.getCalendar(instanceId);
      emit(state.copyWith(calendar: calendar, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Switch the active reality/branch, then refresh the almanac so the new
  /// active timeline and its current cursor are reflected.
  Future<void> setActiveTimeline(String timelineId) async {
    try {
      await ChronicleRepository.setActiveTimeline(instanceId, timelineId);
      await loadCalendar();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void switchTab(ChronicleTab tab) {
    emit(state.copyWith(activeTab: tab));
    if (tab == ChronicleTab.timeline && state.events.isEmpty) {
      loadEvents();
    } else if (tab == ChronicleTab.memories && state.memories.isEmpty) {
      loadMemories();
    } else if (tab == ChronicleTab.calendar && state.calendar == null) {
      loadCalendar();
    }
  }
}
