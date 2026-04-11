import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/world_template.dart';
import '../../../core/network/api_client.dart';
import '../data/creator_repository.dart';

class MyWorldsState extends Equatable {
  final List<WorldTemplate> worlds;
  final bool isLoading;
  final String? error;
  final Set<String> publishingIds;

  const MyWorldsState({
    this.worlds = const [],
    this.isLoading = false,
    this.error,
    this.publishingIds = const {},
  });

  MyWorldsState copyWith({
    List<WorldTemplate>? worlds,
    bool? isLoading,
    String? error,
    Set<String>? publishingIds,
    bool clearError = false,
  }) {
    return MyWorldsState(
      worlds: worlds ?? this.worlds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      publishingIds: publishingIds ?? this.publishingIds,
    );
  }

  List<WorldTemplate> get drafts =>
      worlds.where((w) => !w.isPublished).toList();
  List<WorldTemplate> get published =>
      worlds.where((w) => w.isPublished).toList();

  @override
  List<Object?> get props => [worlds, isLoading, error, publishingIds];
}

class MyWorldsCubit extends Cubit<MyWorldsState> {
  MyWorldsCubit() : super(const MyWorldsState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final worlds = await CreatorRepository.listMine();
      emit(state.copyWith(worlds: worlds, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _friendly(e)));
    }
  }

  Future<void> publish(String templateId) async {
    final ids = Set<String>.from(state.publishingIds)..add(templateId);
    emit(state.copyWith(publishingIds: ids));
    try {
      await CreatorRepository.publish(templateId);
      await load();
    } catch (e) {
      final cleaned = Set<String>.from(state.publishingIds)..remove(templateId);
      emit(state.copyWith(publishingIds: cleaned, error: _friendly(e)));
    }
  }

  Future<void> delete(String templateId) async {
    try {
      await CreatorRepository.delete(templateId);
      emit(
        state.copyWith(
          worlds: state.worlds.where((w) => w.id != templateId).toList(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _friendly(e)));
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
