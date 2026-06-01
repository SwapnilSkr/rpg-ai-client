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
  final String narrativeStyle; // voice preset key; '' = default
  final String styleNotes; // optional free-text refinements
  final String imagePrompt; // visual prompt (auto-suggested, editable)
  final String imageUrl; // generated avatar/background CDN url
  final bool isImageBusy; // suggesting or generating
  final String? imageError;
  final bool isAutofilling; // one-shot AI draft in flight
  final String? autofillError;
  final int autofillStamp; // bumps on each successful autofill (UI sync signal)
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
    this.narrativeStyle = '',
    this.styleNotes = '',
    this.imagePrompt = '',
    this.imageUrl = '',
    this.isImageBusy = false,
    this.imageError,
    this.isAutofilling = false,
    this.autofillError,
    this.autofillStamp = 0,
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
    String? narrativeStyle,
    String? styleNotes,
    String? imagePrompt,
    String? imageUrl,
    bool? isImageBusy,
    String? imageError,
    bool clearImageError = false,
    bool? isAutofilling,
    String? autofillError,
    bool clearAutofillError = false,
    int? autofillStamp,
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
        narrativeStyle: narrativeStyle ?? this.narrativeStyle,
        styleNotes: styleNotes ?? this.styleNotes,
        imagePrompt: imagePrompt ?? this.imagePrompt,
        imageUrl: imageUrl ?? this.imageUrl,
        isImageBusy: isImageBusy ?? this.isImageBusy,
        imageError: clearImageError ? null : (imageError ?? this.imageError),
        isAutofilling: isAutofilling ?? this.isAutofilling,
        autofillError:
            clearAutofillError ? null : (autofillError ?? this.autofillError),
        autofillStamp: autofillStamp ?? this.autofillStamp,
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
        narrativeStyle,
        styleNotes,
        imagePrompt,
        imageUrl,
        isImageBusy,
        imageError,
        isAutofilling,
        autofillError,
        autofillStamp,
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
  void setNarrativeStyle(String v) => emit(state.copyWith(narrativeStyle: v));
  void setStyleNotes(String v) => emit(state.copyWith(styleNotes: v));
  void setImagePrompt(String v) => emit(state.copyWith(imagePrompt: v));
  void setNsfw(bool v) => emit(state.copyWith(isNsfwCapable: v));
  void clearError() => emit(state.copyWith(clearError: true));
  void clearAutofillError() => emit(state.copyWith(clearAutofillError: true));

  /// One-shot AI draft: fills every field from an optional [brief], respecting
  /// the maturity toggle and any locked voice. Everything stays editable.
  Future<void> autofillAll({String brief = ''}) async {
    if (state.isAutofilling) return;
    emit(state.copyWith(isAutofilling: true, clearAutofillError: true));
    try {
      final d = await CreatorRepository.autofill({
        'target': 'character',
        'brief': brief.trim(),
        'is_sentient': true,
        'is_nsfw_capable': state.isNsfwCapable,
        'narrative_style': state.narrativeStyle,
      });
      emit(state.copyWith(
        name: (d['name'] ?? state.name).toString(),
        tagline: (d['tagline'] ?? state.tagline).toString(),
        persona: (d['persona'] ?? state.persona).toString(),
        greeting: (d['greeting'] ?? state.greeting).toString(),
        backstory: (d['backstory'] ?? state.backstory).toString(),
        narrativeStyle:
            (d['narrative_style'] ?? state.narrativeStyle).toString(),
        styleNotes: (d['style_notes'] ?? state.styleNotes).toString(),
        imagePrompt: (d['image_prompt'] ?? state.imagePrompt).toString(),
        isAutofilling: false,
        autofillStamp: state.autofillStamp + 1,
      ));
    } catch (e) {
      emit(state.copyWith(isAutofilling: false, autofillError: _autofillErr(e)));
    }
  }

  String _autofillErr(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 403) return 'AI drafting needs Premium or Creator.';
      if (e.statusCode == 429) return 'Too many AI drafts — try again shortly.';
      return e.message;
    }
    return 'Could not draft the character. Please try again.';
  }


  /// Render (or re-roll) the avatar from the current visual prompt. The prompt
  /// comes from "Generate with AI" or is typed by the creator; the UI disables
  /// this until one exists.
  Future<void> generateImage() async {
    if (state.isImageBusy) return;
    final prompt = state.imagePrompt.trim();
    if (prompt.isEmpty) return;
    emit(state.copyWith(isImageBusy: true, clearImageError: true));
    try {
      final url = await CreatorRepository.generateImage(prompt);
      emit(state.copyWith(imageUrl: url, isImageBusy: false));
    } catch (e) {
      emit(state.copyWith(isImageBusy: false, imageError: _imageErr(e)));
    }
  }

  String _imageErr(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 403) return 'Image generation needs Premium or Creator.';
      if (e.statusCode == 429) return 'Too many image generations — try again shortly.';
      return e.message;
    }
    return 'Could not generate the image. Please try again.';
  }

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
        'narrative_style': state.narrativeStyle,
        'style_notes': state.styleNotes.trim(),
        'image_url': state.imageUrl,
        'image_prompt': state.imagePrompt.trim(),
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
