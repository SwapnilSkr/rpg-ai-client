import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/world_template.dart';
import '../../../core/network/api_client.dart';
import '../data/creator_repository.dart';

class MyWorldsState extends Equatable {
  final List<WorldTemplate> worlds;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final int page;
  final String? error;
  final Set<String> publishingIds;
  final Set<String> deletingIds;

  const MyWorldsState({
    this.worlds = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.page = 1,
    this.error,
    this.publishingIds = const {},
    this.deletingIds = const {},
  });

  MyWorldsState copyWith({
    List<WorldTemplate>? worlds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    int? page,
    String? error,
    Set<String>? publishingIds,
    Set<String>? deletingIds,
    bool clearError = false,
  }) {
    return MyWorldsState(
      worlds: worlds ?? this.worlds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      page: page ?? this.page,
      error: clearError ? null : (error ?? this.error),
      publishingIds: publishingIds ?? this.publishingIds,
      deletingIds: deletingIds ?? this.deletingIds,
    );
  }

  List<WorldTemplate> get drafts =>
      worlds.where((w) => !w.isPublished).toList();
  List<WorldTemplate> get published =>
      worlds.where((w) => w.isPublished).toList();

  @override
  List<Object?> get props => [
    worlds,
    isLoading,
    isLoadingMore,
    hasMore,
    total,
    page,
    error,
    publishingIds,
    deletingIds,
  ];
}

class MyWorldsCubit extends Cubit<MyWorldsState> {
  MyWorldsCubit() : super(const MyWorldsState());

  String _search = '';

  Future<void> load({bool forceRefresh = false, String search = ''}) async {
    _search = search;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await CreatorRepository.listMinePage(search: search);
      emit(
        state.copyWith(
          worlds: result.worlds,
          isLoading: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _friendly(e)));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await CreatorRepository.listMinePage(
        page: state.page + 1,
        search: _search,
      );
      final known = state.worlds.map((w) => w.id).toSet();
      emit(
        state.copyWith(
          worlds: [
            ...state.worlds,
            ...result.worlds.where((world) => known.add(world.id)),
          ],
          isLoadingMore: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: _friendly(e)));
    }
  }

  Future<bool> publish(String templateId) async {
    if (state.publishingIds.contains(templateId)) return false;
    final ids = Set<String>.from(state.publishingIds)..add(templateId);
    emit(state.copyWith(publishingIds: ids));
    try {
      await CreatorRepository.publish(templateId);
      await load(search: _search);
      return true;
    } catch (e) {
      final cleaned = Set<String>.from(state.publishingIds)..remove(templateId);
      emit(state.copyWith(publishingIds: cleaned, error: _friendly(e)));
      return false;
    }
  }

  Future<bool> delete(String templateId) async {
    if (state.deletingIds.contains(templateId)) return false;
    final ids = Set<String>.from(state.deletingIds)..add(templateId);
    emit(state.copyWith(deletingIds: ids, clearError: true));
    try {
      await CreatorRepository.delete(templateId);
      emit(
        state.copyWith(
          worlds: state.worlds.where((w) => w.id != templateId).toList(),
          deletingIds: Set<String>.from(state.deletingIds)..remove(templateId),
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          deletingIds: Set<String>.from(state.deletingIds)..remove(templateId),
          error: _friendly(e),
        ),
      );
      return false;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  String _friendly(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 429 &&
          e.message.toLowerCase().contains('template creation rate')) {
        return 'The forge needs rest — only 5 worlds may be crafted per day.';
      }
      return e.message;
    }
    final s = e.toString().toLowerCase();
    if (s.contains('rate limit')) {
      return 'The forge needs rest — only 5 worlds may be crafted per day.';
    }
    if (s.contains('401') || s.contains('unauthorized')) {
      return 'Your session has faded. Sign in again to continue.';
    }
    if (s.contains('403')) {
      return 'Only Premium and Creator wielders may forge worlds.';
    }
    if (s.contains('already published')) {
      return 'This world has already been released to the realm.';
    }
    return 'The arcane forge flickered. Please try again.';
  }
}
