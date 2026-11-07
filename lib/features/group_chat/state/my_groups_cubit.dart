import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';
import '../../creator/data/creator_repository.dart';
import '../data/group_create_repository.dart';

class MyGroupsState extends Equatable {
  final List<WorldTemplate> groups;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final int page;
  final String? error;
  final Set<String> deletingIds;

  const MyGroupsState({
    this.groups = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.page = 1,
    this.error,
    this.deletingIds = const {},
  });

  MyGroupsState copyWith({
    List<WorldTemplate>? groups,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    int? page,
    String? error,
    Set<String>? deletingIds,
    bool clearError = false,
  }) => MyGroupsState(
    groups: groups ?? this.groups,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    total: total ?? this.total,
    page: page ?? this.page,
    error: clearError ? null : (error ?? this.error),
    deletingIds: deletingIds ?? this.deletingIds,
  );

  @override
  List<Object?> get props => [
    groups,
    isLoading,
    isLoadingMore,
    hasMore,
    total,
    page,
    error,
    deletingIds,
  ];
}

/// "Your groups": the player's own groups, a page at a time. Reloads when any
/// creator write lands (a save in the editor, a publish elsewhere).
class MyGroupsCubit extends Cubit<MyGroupsState> {
  final Future<CreatorWorldPage> Function({int page, int limit}) _fetchPage;
  final Future<void> Function(String id) _deleteFn;
  final ValueNotifier<int> _changesNotifier;
  late final VoidCallback _repoListener;

  int _ignoreRepoSignals = 0;

  /// Bumped per load, so a slow answer that was overtaken is dropped.
  int _loadSeq = 0;

  MyGroupsCubit({
    Future<CreatorWorldPage> Function({int page, int limit})? fetchPage,
    Future<void> Function(String id)? deleteFn,
    ValueNotifier<int>? changesNotifier,
  }) : _fetchPage = fetchPage ?? GroupCreateRepository.listMine,
       _deleteFn = deleteFn ?? GroupCreateRepository.delete,
       _changesNotifier = changesNotifier ?? CreatorRepository.changes,
       super(const MyGroupsState()) {
    _repoListener = _onRepoChanged;
    _changesNotifier.addListener(_repoListener);
  }

  void _onRepoChanged() {
    if (isClosed || _ignoreRepoSignals > 0) return;
    load();
  }

  @override
  Future<void> close() {
    _changesNotifier.removeListener(_repoListener);
    return super.close();
  }

  Future<void> load() async {
    if (isClosed) return;
    final seq = ++_loadSeq;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await _fetchPage();
      if (isClosed || seq != _loadSeq) return;
      emit(
        state.copyWith(
          groups: result.worlds,
          isLoading: false,
          isLoadingMore: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _loadSeq) return;
      emit(state.copyWith(isLoading: false, error: _friendly(e)));
    }
  }

  Future<void> loadMore() async {
    if (isClosed || state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    final seq = _loadSeq;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _fetchPage(page: state.page + 1);
      if (isClosed || seq != _loadSeq) return;
      final known = state.groups.map((g) => g.id).toSet();
      emit(
        state.copyWith(
          groups: [
            ...state.groups,
            ...result.worlds.where((group) => known.add(group.id)),
          ],
          isLoadingMore: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _loadSeq) return;
      emit(state.copyWith(isLoadingMore: false, error: _friendly(e)));
    }
  }

  Future<bool> delete(String id) async {
    if (state.deletingIds.contains(id)) return false;
    emit(
      state.copyWith(deletingIds: {...state.deletingIds, id}, clearError: true),
    );
    // The delete signals a change; the list is updated here, not reloaded.
    _ignoreRepoSignals++;
    try {
      await _deleteFn(id);
      if (isClosed) return false;
      emit(
        state.copyWith(
          groups: state.groups.where((g) => g.id != id).toList(),
          deletingIds: {...state.deletingIds}..remove(id),
        ),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          deletingIds: {...state.deletingIds}..remove(id),
          error: _friendly(e),
        ),
      );
      return false;
    } finally {
      _ignoreRepoSignals--;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  static String _friendly(Object e) {
    if (e is ApiException &&
        const {400, 403, 404, 429}.contains(e.statusCode)) {
      return e.message;
    }
    return 'Try again in a moment.';
  }
}
