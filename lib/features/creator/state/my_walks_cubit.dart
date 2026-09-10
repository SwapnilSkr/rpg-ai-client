import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/world_template.dart';
import '../../../core/network/api_client.dart';
import '../../interactive/data/interactive_world_repository.dart';

class MyWalksState extends Equatable {
  final List<WorldTemplate> worlds;
  final bool isLoading;
  final String? error;
  final Set<String> publishingIds;
  final Set<String> deletingIds;

  const MyWalksState({
    this.worlds = const [],
    this.isLoading = false,
    this.error,
    this.publishingIds = const {},
    this.deletingIds = const {},
  });

  MyWalksState copyWith({
    List<WorldTemplate>? worlds,
    bool? isLoading,
    String? error,
    Set<String>? publishingIds,
    Set<String>? deletingIds,
    bool clearError = false,
  }) {
    return MyWalksState(
      worlds: worlds ?? this.worlds,
      isLoading: isLoading ?? this.isLoading,
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
  List<Object?> get props => [worlds, isLoading, error, publishingIds, deletingIds];
}

class MyWalksCubit extends Cubit<MyWalksState> {
  MyWalksCubit() : super(const MyWalksState());

  static const _repo = InteractiveWorldRepository();

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await _repo.listMine();
      emit(state.copyWith(worlds: result.worlds, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _friendly(e)));
    }
  }

  String _keyOf(WorldTemplate world) =>
      world.interactiveWorldKey ?? world.slug;

  Future<bool> publish(WorldTemplate world) async {
    final key = _keyOf(world);
    if (key.isEmpty || state.publishingIds.contains(world.id)) return false;
    emit(state.copyWith(publishingIds: {...state.publishingIds, world.id}));
    try {
      await _repo.publish(key);
      await load();
      return true;
    } catch (e) {
      final cleaned = Set<String>.from(state.publishingIds)..remove(world.id);
      emit(state.copyWith(publishingIds: cleaned, error: _friendly(e)));
      return false;
    }
  }

  Future<bool> delete(WorldTemplate world) async {
    final key = _keyOf(world);
    if (key.isEmpty || state.deletingIds.contains(world.id)) return false;
    emit(
      state.copyWith(
        deletingIds: {...state.deletingIds, world.id},
        clearError: true,
      ),
    );
    try {
      await _repo.delete(key);
      emit(
        state.copyWith(
          worlds: state.worlds.where((w) => w.id != world.id).toList(),
          deletingIds: Set<String>.from(state.deletingIds)..remove(world.id),
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          deletingIds: Set<String>.from(state.deletingIds)..remove(world.id),
          error: _friendly(e),
        ),
      );
      return false;
    }
  }

  String _friendly(Object e) {
    if (e is ApiException) return e.message;
    return 'The walk could not be updated. Please try again.';
  }
}
