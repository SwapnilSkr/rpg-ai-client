import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../data/creator_repository.dart';
import '../../home/data/home_repository.dart';

class CreateCharacterState extends Equatable {
  final String name;
  final String tagline;
  final String persona;
  final String greeting;
  final String backstory;
  final bool isNsfwCapable;
  final bool isSubmitting;
  final String? error;

  /// Set when creation succeeds — the instance to drop the user straight into.
  final String? instanceId;

  const CreateCharacterState({
    this.name = '',
    this.tagline = '',
    this.persona = '',
    this.greeting = '',
    this.backstory = '',
    this.isNsfwCapable = false,
    this.isSubmitting = false,
    this.error,
    this.instanceId,
  });

  CreateCharacterState copyWith({
    String? name,
    String? tagline,
    String? persona,
    String? greeting,
    String? backstory,
    bool? isNsfwCapable,
    bool? isSubmitting,
    String? error,
    String? instanceId,
    bool clearError = false,
  }) => CreateCharacterState(
        name: name ?? this.name,
        tagline: tagline ?? this.tagline,
        persona: persona ?? this.persona,
        greeting: greeting ?? this.greeting,
        backstory: backstory ?? this.backstory,
        isNsfwCapable: isNsfwCapable ?? this.isNsfwCapable,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        instanceId: instanceId ?? this.instanceId,
      );

  bool get canCreate =>
      name.trim().length >= 2 &&
      tagline.trim().length >= 3 &&
      persona.trim().length >= 10;

  @override
  List<Object?> get props => [
        name,
        tagline,
        persona,
        greeting,
        backstory,
        isNsfwCapable,
        isSubmitting,
        error,
        instanceId,
      ];
}

class CreateCharacterCubit extends Cubit<CreateCharacterState> {
  CreateCharacterCubit() : super(const CreateCharacterState());

  void setName(String v) => emit(state.copyWith(name: v));
  void setTagline(String v) => emit(state.copyWith(tagline: v));
  void setPersona(String v) => emit(state.copyWith(persona: v));
  void setGreeting(String v) => emit(state.copyWith(greeting: v));
  void setBackstory(String v) => emit(state.copyWith(backstory: v));
  void setNsfw(bool v) => emit(state.copyWith(isNsfwCapable: v));
  void clearError() => emit(state.copyWith(clearError: true));

  /// Builds the character template, publishes it, spins up an instance, and
  /// returns the instance id so the UI can jump straight into the chat.
  Future<void> create() async {
    if (!state.canCreate) {
      emit(state.copyWith(
          error: 'Give your character a name, a tagline, and a personality.'));
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final name = state.name.trim();
      final tagline = state.tagline.trim();
      final persona = state.persona.trim();
      // Compose a proper sentient seed so the engine speaks AS the character.
      final seed = 'You are $name. $tagline.\n\n$persona';

      final payload = <String, dynamic>{
        'title': name,
        'description': tagline,
        'kind': 'character',
        'is_sentient': true,
        'is_nsfw_capable': state.isNsfwCapable,
        'seed_prompt': seed,
        'global_lore': state.backstory.trim(),
        'opening_line': state.greeting.trim(),
        'protagonist': {
          'name': name,
          'persona': tagline,
        },
        'base_stats_template': <String, dynamic>{},
      };

      final template = await CreatorRepository.create(payload);
      await CreatorRepository.publish(template.id);
      final instance = await HomeRepository.createInstance(template.id);
      emit(state.copyWith(isSubmitting: false, instanceId: instance.id));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _friendly(e)));
    }
  }

  String _friendly(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 403) {
        return 'Character creation needs a Premium or Creator account.';
      }
      if (e.statusCode == 429) {
        return 'Too many creations for now — please try again later.';
      }
      return e.message;
    }
    return 'Something went wrong creating your character. Please try again.';
  }
}
