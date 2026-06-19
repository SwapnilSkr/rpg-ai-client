import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/ws_manager.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/memory.dart';
import '../data/chronicle_repository.dart';
import '../data/calendar_data.dart';
import '../data/location_journal.dart';
import '../data/relationship_ledger.dart';
import '../data/threads_data.dart';
import '../data/recap_data.dart';

enum ChronicleTab { recap, timeline, memories, calendar, places, bonds, threads }

class ChronicleState extends Equatable {
  final List<GameEvent> events;
  final List<Memory> memories;
  final CalendarData? calendar;
  final LocationsData? locations;
  final RelationshipLedger? bonds;
  final ThreadsData? threads;
  final RecapData? recap;
  // Echoes (memory) search/filters. Empty strings = unfiltered.
  final String memoryQuery;
  final String memoryType;
  final bool memoryUnresolved;
  final bool memoryHighImportance;
  final bool isLoading;
  final String? error;
  final ChronicleTab activeTab;
  final int totalEvents;
  final int currentPage;

  /// Tabs whose backing projection changed server-side since they were last
  /// loaded. A dirty tab is re-fetched the next time it becomes active.
  final Set<ChronicleTab> dirtyTabs;

  const ChronicleState({
    this.events = const [],
    this.memories = const [],
    this.calendar,
    this.locations,
    this.bonds,
    this.threads,
    this.recap,
    this.memoryQuery = '',
    this.memoryType = '',
    this.memoryUnresolved = false,
    this.memoryHighImportance = false,
    this.isLoading = false,
    this.error,
    this.activeTab = ChronicleTab.recap,
    this.totalEvents = 0,
    this.currentPage = 1,
    this.dirtyTabs = const {},
  });

  ChronicleState copyWith({
    List<GameEvent>? events,
    List<Memory>? memories,
    CalendarData? calendar,
    LocationsData? locations,
    RelationshipLedger? bonds,
    ThreadsData? threads,
    RecapData? recap,
    String? memoryQuery,
    String? memoryType,
    bool? memoryUnresolved,
    bool? memoryHighImportance,
    bool? isLoading,
    String? error,
    ChronicleTab? activeTab,
    int? totalEvents,
    int? currentPage,
    Set<ChronicleTab>? dirtyTabs,
  }) {
    return ChronicleState(
      events: events ?? this.events,
      memories: memories ?? this.memories,
      calendar: calendar ?? this.calendar,
      locations: locations ?? this.locations,
      bonds: bonds ?? this.bonds,
      threads: threads ?? this.threads,
      recap: recap ?? this.recap,
      memoryQuery: memoryQuery ?? this.memoryQuery,
      memoryType: memoryType ?? this.memoryType,
      memoryUnresolved: memoryUnresolved ?? this.memoryUnresolved,
      memoryHighImportance: memoryHighImportance ?? this.memoryHighImportance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeTab: activeTab ?? this.activeTab,
      totalEvents: totalEvents ?? this.totalEvents,
      currentPage: currentPage ?? this.currentPage,
      dirtyTabs: dirtyTabs ?? this.dirtyTabs,
    );
  }

  @override
  List<Object?> get props => [
        events,
        memories,
        calendar,
        locations,
        bonds,
        threads,
        recap,
        memoryQuery,
        memoryType,
        memoryUnresolved,
        memoryHighImportance,
        isLoading,
        error,
        activeTab,
        totalEvents,
        currentPage,
        dirtyTabs,
      ];
}

class ChronicleCubit extends Cubit<ChronicleState> {
  final String instanceId;
  final WsManager _ws;
  StreamSubscription<Map<String, dynamic>>? _projectionSub;

  ChronicleCubit({required this.instanceId, WsManager? ws})
      : _ws = ws ?? WsManager(),
        super(const ChronicleState()) {
    _projectionSub = _ws.onWorldProjectionUpdated.listen((msg) {
      if (msg['instance_id']?.toString() != instanceId) return;
      final scopes = (msg['scopes'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          const <String>[];
      markProjectionDirty(scopes);
    });
  }

  @override
  Future<void> close() {
    _projectionSub?.cancel();
    return super.close();
  }

  /// Maps a server projection scope to the Chronicle tab(s) it backs. Returns
  /// an empty set for scopes the Chronicle doesn't render (e.g. 'presence').
  static Set<ChronicleTab> _tabsForScope(String scope) {
    switch (scope) {
      case 'bonds':
        return {ChronicleTab.bonds};
      case 'threads':
        return {ChronicleTab.threads};
      case 'recap':
        return {ChronicleTab.recap};
      case 'places':
        return {ChronicleTab.places};
      case 'calendar':
        return {ChronicleTab.calendar};
      // A codex change can shift both the relationship ledger and the recap.
      case 'codex':
        return {ChronicleTab.bonds, ChronicleTab.recap};
      case 'presence':
      default:
        return const {};
    }
  }

  /// Marks the tabs affected by [scopes] as dirty. The currently-active tab is
  /// auto-refreshed immediately; the rest are lazily refreshed when next viewed
  /// (see [switchTab]).
  void markProjectionDirty(List<String> scopes) {
    final affected = <ChronicleTab>{};
    for (final s in scopes) {
      affected.addAll(_tabsForScope(s));
    }
    if (affected.isEmpty) return;

    emit(state.copyWith(dirtyTabs: {...state.dirtyTabs, ...affected}));

    if (affected.contains(state.activeTab)) {
      _refreshTab(state.activeTab);
    }
  }

  /// Re-fetch a tab's backing projection and clear its dirty flag.
  void _refreshTab(ChronicleTab tab) {
    _clearDirty(tab);
    switch (tab) {
      case ChronicleTab.recap:
        loadRecap();
        break;
      case ChronicleTab.timeline:
        loadEvents(page: state.currentPage);
        break;
      case ChronicleTab.memories:
        loadMemories();
        break;
      case ChronicleTab.calendar:
        loadCalendar();
        break;
      case ChronicleTab.places:
        loadLocations();
        break;
      case ChronicleTab.bonds:
        loadBonds();
        break;
      case ChronicleTab.threads:
        loadThreads();
        break;
    }
  }

  void _clearDirty(ChronicleTab tab) {
    if (!state.dirtyTabs.contains(tab)) return;
    emit(state.copyWith(dirtyTabs: {...state.dirtyTabs}..remove(tab)));
  }

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
        query: state.memoryQuery,
        type: state.memoryType,
        minImportance: state.memoryHighImportance ? 4 : null,
        unresolvedOnly: state.memoryUnresolved,
      );
      emit(state.copyWith(memories: memories, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Update the Echoes search/filters and reload. Only the provided fields
  /// change; pass an empty string to clear the query or type.
  Future<void> setMemoryFilters({
    String? query,
    String? type,
    bool? unresolved,
    bool? highImportance,
  }) async {
    emit(state.copyWith(
      memoryQuery: query,
      memoryType: type,
      memoryUnresolved: unresolved,
      memoryHighImportance: highImportance,
    ));
    await loadMemories();
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

  Future<void> loadLocations() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final locations = await ChronicleRepository.getLocations(instanceId);
      emit(state.copyWith(locations: locations, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadBonds() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final bonds = await ChronicleRepository.getRelationships(instanceId);
      emit(state.copyWith(bonds: bonds, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadThreads() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final threads = await ChronicleRepository.getThreads(instanceId);
      emit(state.copyWith(threads: threads, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadRecap() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final recap = await ChronicleRepository.getRecap(instanceId);
      emit(state.copyWith(recap: recap, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void switchTab(ChronicleTab tab) {
    emit(state.copyWith(activeTab: tab));

    // A tab marked dirty by a projection update is always re-fetched on view,
    // even if it already holds (now-stale) data.
    if (state.dirtyTabs.contains(tab)) {
      _refreshTab(tab);
      return;
    }

    if (tab == ChronicleTab.recap && state.recap == null) {
      loadRecap();
    } else if (tab == ChronicleTab.timeline && state.events.isEmpty) {
      loadEvents();
    } else if (tab == ChronicleTab.memories && state.memories.isEmpty) {
      loadMemories();
    } else if (tab == ChronicleTab.calendar && state.calendar == null) {
      loadCalendar();
    } else if (tab == ChronicleTab.places && state.locations == null) {
      loadLocations();
    } else if (tab == ChronicleTab.bonds && state.bonds == null) {
      loadBonds();
    } else if (tab == ChronicleTab.threads && state.threads == null) {
      loadThreads();
    }
  }
}
