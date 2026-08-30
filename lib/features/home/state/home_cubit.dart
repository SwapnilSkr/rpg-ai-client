import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/storage/local_db.dart';
import '../../../shared/models/world_instance.dart';
import '../data/home_repository.dart';
import '../domain/realm_group.dart';
import '../../../core/errors/user_message.dart';

class HomeState extends Equatable {
  final List<WorldInstance> instances;
  final List<RealmGroup> realms;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final int page;
  final String? error;

  const HomeState({
    this.instances = const [],
    this.realms = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.page = 1,
    this.error,
  });

  HomeState copyWith({
    List<WorldInstance>? instances,
    List<RealmGroup>? realms,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    int? page,
    String? error,
  }) {
    return HomeState(
      instances: instances ?? this.instances,
      realms: realms ?? this.realms,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      page: page ?? this.page,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    instances,
    realms,
    isLoading,
    isLoadingMore,
    hasMore,
    total,
    page,
    error,
  ];
}

class HomeCubit extends Cubit<HomeState> {
  late final StreamSubscription<RealmChange> _realmChangeSub;
  String _search = '';

  HomeCubit() : super(const HomeState()) {
    _realmChangeSub = HomeRepository.realmChanges.listen(_onRealmChange);
  }

  void _onRealmChange(RealmChange change) {
    if (isClosed) return;
    switch (change.kind) {
      case RealmChangeKind.created:
        unawaited(loadInstances(silent: true));
        break;
      case RealmChangeKind.updated:
        unawaited(loadInstances(silent: true));
        break;
      case RealmChangeKind.removed:
        unawaited(loadInstances(silent: true));
        break;
    }
  }

  Future<void> loadInstances({
    bool silent = false,
    bool forceRefresh = false,
    String? search,
  }) async {
    _search = search ?? _search;
    if (!silent) emit(state.copyWith(isLoading: true, error: null));
    try {
      final result = await HomeRepository.getRealmPage(search: _search);
      emit(
        state.copyWith(
          realms: result.realms,
          isLoading: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      if (!silent) {
        emit(
          state.copyWith(
            isLoading: false,
            error: userFacingError(e, fallback: 'Could not load your realms.'),
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await HomeRepository.getRealmPage(
        page: state.page + 1,
        search: _search,
      );
      final known = state.realms.map((realm) => realm.templateId).toSet();
      emit(
        state.copyWith(
          realms: [
            ...state.realms,
            ...result.realms.where((realm) => known.add(realm.templateId)),
          ],
          isLoadingMore: false,
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          error: userFacingError(e, fallback: 'Could not load more realms.'),
        ),
      );
    }
  }

  Future<WorldInstance?> createInstance(String templateId) async {
    try {
      final instance = await HomeRepository.createInstance(templateId);
      return instance;
    } catch (e) {
      emit(
        state.copyWith(
          error: userFacingError(e, fallback: 'Could not open that realm.'),
        ),
      );
      return null;
    }
  }

  Future<void> archiveInstance(String instanceId) async {
    final before = state.instances;
    emit(
      state.copyWith(
        instances: before.where((i) => i.id != instanceId).toList(),
        error: null,
      ),
    );
    try {
      await HomeRepository.archiveInstance(instanceId);
    } catch (e) {
      emit(
        state.copyWith(
          instances: before,
          error: userFacingError(e, fallback: 'Could not archive that realm.'),
        ),
      );
    }
  }

  Future<void> deleteInstance(String instanceId) async {
    final before = state.instances;
    emit(
      state.copyWith(
        instances: before.where((i) => i.id != instanceId).toList(),
        error: null,
      ),
    );
    try {
      await HomeRepository.deleteInstance(instanceId);
      await LocalDb.clearInstanceCache(instanceId);
    } catch (e) {
      emit(
        state.copyWith(
          instances: before,
          error: userFacingError(e, fallback: 'Could not delete that realm.'),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _realmChangeSub.cancel();
    return super.close();
  }
}
