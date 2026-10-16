import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/keepsakes_repository.dart';
import '../models/keepsake_item.dart';
import 'keepsakes_state.dart';

class KeepsakesCubit extends Cubit<KeepsakesState> {
  final KeepsakesRepository _repository;

  KeepsakesCubit({
    required KeepsakesRepository repository,
  })  : _repository = repository,
        super(const KeepsakesState());

  List<KeepsakeItem> _dedupe(List<KeepsakeItem> list) {
    final seen = <String>{};
    return list.where((i) => seen.add(i.mediaId)).toList();
  }

  Future<KeepsakesPage> _fetchNonEmptyPage({
    required KeepsakesFilter filter,
    String? before,
    int limit = 20,
    int maxAutoPages = 5,
  }) async {
    var page = await _repository.getKeepsakes(
      filter: filter,
      before: before,
      limit: limit,
    );
    int autoPages = 0;
    while (page.items.isEmpty &&
        page.nextBefore != null &&
        page.nextBefore!.isNotEmpty &&
        autoPages < maxAutoPages) {
      autoPages++;
      page = await _repository.getKeepsakes(
        filter: filter,
        before: page.nextBefore,
        limit: limit,
      );
    }
    return page;
  }

  Future<void> loadInitial() async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      clearNextPageError: true,
    ));

    try {
      final hasSaves = await _repository.hasAnySaves();
      final page = await _fetchNonEmptyPage(
        filter: state.filter,
        limit: 20,
      );

      final deduped = _dedupe(page.items);
      emit(state.copyWith(
        items: deduped,
        nextBefore: page.nextBefore,
        hasMore: page.nextBefore != null && page.nextBefore!.isNotEmpty,
        isLoading: false,
        hasAnySaves: hasSaves,
        hasAnyKeepsakesOverall: state.hasAnyKeepsakesOverall || deduped.isNotEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> setFilter(KeepsakesFilter newFilter) async {
    if (state.filter == newFilter) return;

    final wasOverall = state.hasAnyKeepsakesOverall || state.items.isNotEmpty;

    emit(state.copyWith(
      filter: newFilter,
      items: const [],
      nextBefore: null,
      hasMore: false,
      isLoading: true,
      clearError: true,
      clearNextPageError: true,
      hasAnyKeepsakesOverall: wasOverall,
    ));

    try {
      final page = await _fetchNonEmptyPage(
        filter: newFilter,
        limit: 20,
      );

      final deduped = _dedupe(page.items);
      emit(state.copyWith(
        items: deduped,
        nextBefore: page.nextBefore,
        hasMore: page.nextBefore != null && page.nextBefore!.isNotEmpty,
        isLoading: false,
        hasAnyKeepsakesOverall: wasOverall || deduped.isNotEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  void setMode(KeepsakesViewMode newMode) {
    if (state.mode == newMode) return;
    emit(state.copyWith(mode: newMode));
  }

  Future<void> refresh() async {
    emit(state.copyWith(
      isRefreshing: true,
      clearError: true,
      clearNextPageError: true,
    ));

    try {
      final hasSaves = await _repository.hasAnySaves();
      final page = await _fetchNonEmptyPage(
        filter: state.filter,
        limit: 20,
      );

      final deduped = _dedupe(page.items);
      final hasKeepsakes = state.hasAnyKeepsakesOverall || deduped.isNotEmpty;

      emit(state.copyWith(
        items: deduped,
        nextBefore: page.nextBefore,
        hasMore: page.nextBefore != null && page.nextBefore!.isNotEmpty,
        isRefreshing: false,
        hasAnySaves: hasSaves,
        hasAnyKeepsakesOverall: hasKeepsakes,
      ));
    } catch (e) {
      emit(state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingNextPage || !state.hasMore) return;
    if (state.nextBefore == null || state.nextBefore!.isEmpty) return;

    emit(state.copyWith(
      isLoadingNextPage: true,
      clearNextPageError: true,
    ));

    try {
      final page = await _fetchNonEmptyPage(
        filter: state.filter,
        before: state.nextBefore,
        limit: 20,
      );

      // Append without duplicates
      final existingIds = state.items.map((i) => i.mediaId).toSet();
      final deduped = page.items.where((i) => !existingIds.contains(i.mediaId)).toList();
      final combined = [...state.items, ...deduped];

      emit(state.copyWith(
        items: combined,
        nextBefore: page.nextBefore,
        hasMore: page.nextBefore != null && page.nextBefore!.isNotEmpty,
        isLoadingNextPage: false,
      ));
    } catch (e) {
      // Retain previously loaded items!
      emit(state.copyWith(
        isLoadingNextPage: false,
        nextPageError: e.toString(),
      ));
    }
  }

  Future<void> removeKeepsake(String mediaId) async {
    final previous = state.items;
    final updated = state.items.where((item) => item.mediaId != mediaId).toList();
    emit(state.copyWith(items: updated));

    try {
      await _repository.hideKeepsake(mediaId);
    } catch (e) {
      // Revert if hide call failed
      emit(state.copyWith(items: previous, error: e.toString()));
    }
  }
}
