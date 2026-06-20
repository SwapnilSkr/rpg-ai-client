import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/storage/local_db.dart';
import '../../../shared/models/world_instance.dart';
import '../data/home_repository.dart';

class HomeState extends Equatable {
  final List<WorldInstance> instances;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.instances = const [],
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    List<WorldInstance>? instances,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      instances: instances ?? this.instances,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [instances, isLoading, error];
}

class HomeCubit extends Cubit<HomeState> {
  late final StreamSubscription<RealmChange> _realmChangeSub;

  HomeCubit() : super(const HomeState()) {
    _realmChangeSub = HomeRepository.realmChanges.listen(_onRealmChange);
  }

  void _onRealmChange(RealmChange change) {
    if (isClosed) return;
    switch (change.kind) {
      case RealmChangeKind.created:
        final instance = change.instance;
        if (instance == null) return;
        final exists = state.instances.any((i) => i.id == instance.id);
        if (exists) {
          emit(
            state.copyWith(
              instances: state.instances
                  .map((i) => i.id == instance.id ? instance : i)
                  .toList(),
              error: null,
            ),
          );
        } else {
          emit(
            state.copyWith(
              instances: [instance, ...state.instances],
              error: null,
            ),
          );
        }
        unawaited(loadInstances(silent: true));
        break;
      case RealmChangeKind.updated:
        unawaited(loadInstances(silent: true));
        break;
      case RealmChangeKind.removed:
        emit(
          state.copyWith(
            instances: state.instances
                .where((i) => i.id != change.instanceId)
                .toList(),
            error: null,
          ),
        );
        break;
    }
  }

  Future<void> loadInstances({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!silent) emit(state.copyWith(isLoading: true, error: null));
    try {
      final instances = await HomeRepository.getInstances(
        forceRefresh: forceRefresh,
      );
      emit(state.copyWith(instances: instances, isLoading: false));
    } catch (e) {
      if (!silent) emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<WorldInstance?> createInstance(String templateId) async {
    try {
      final instance = await HomeRepository.createInstance(templateId);
      return instance;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
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
      emit(state.copyWith(instances: before, error: e.toString()));
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
      emit(state.copyWith(instances: before, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _realmChangeSub.cancel();
    return super.close();
  }
}
