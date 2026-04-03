import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
  HomeCubit() : super(const HomeState());

  Future<void> loadInstances() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final instances = await HomeRepository.getInstances();
      emit(state.copyWith(instances: instances, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<WorldInstance?> createInstance(String templateId) async {
    try {
      final instance = await HomeRepository.createInstance(templateId);
      emit(state.copyWith(instances: [instance, ...state.instances]));
      return instance;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return null;
    }
  }

  Future<void> archiveInstance(String instanceId) async {
    try {
      await HomeRepository.archiveInstance(instanceId);
      emit(state.copyWith(
        instances: state.instances.where((i) => i.id != instanceId).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
