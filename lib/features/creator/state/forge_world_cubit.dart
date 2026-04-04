import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/world_template.dart';
import '../data/creator_repository.dart';

class StatEntry extends Equatable {
  final String name;
  final num defaultValue;
  final num min;
  final num max;
  final String description;

  const StatEntry({
    required this.name,
    this.defaultValue = 50,
    this.min = 0,
    this.max = 100,
    this.description = '',
  });

  StatEntry copyWith({
    String? name,
    num? defaultValue,
    num? min,
    num? max,
    String? description,
  }) =>
      StatEntry(
        name: name ?? this.name,
        defaultValue: defaultValue ?? this.defaultValue,
        min: min ?? this.min,
        max: max ?? this.max,
        description: description ?? this.description,
      );

  @override
  List<Object?> get props => [name, defaultValue, min, max, description];
}

class ForgeWorldState extends Equatable {
  final int step;
  // Step 0 — The Essence
  final String title;
  final String description;
  final bool isSentient;
  final bool isNsfwCapable;
  // Step 1 — Oracle's Voice
  final String seedPrompt;
  // Step 2 — Ancient Lore
  final String globalLore;
  final List<String> sceneTags;
  // Step 3 — Vital Forces
  final List<StatEntry> stats;
  // Step 4 — Arcane Engine
  final String modelLogic;
  final String modelNarrationSfw;
  final String modelNarrationNsfw;
  final String modelSummary;
  final int maxContextMemories;
  final int maxLoreResults;
  // Submission
  final bool isSubmitting;
  final String? error;
  final WorldTemplate? result;

  const ForgeWorldState({
    this.step = 0,
    this.title = '',
    this.description = '',
    this.isSentient = false,
    this.isNsfwCapable = false,
    this.seedPrompt = '',
    this.globalLore = '',
    this.sceneTags = const [],
    this.stats = const [],
    this.modelLogic = 'gpt-4o',
    this.modelNarrationSfw = 'gpt-4o',
    this.modelNarrationNsfw = 'pygmalionai/mythalion-13b',
    this.modelSummary = 'gpt-4o-mini',
    this.maxContextMemories = 25,
    this.maxLoreResults = 10,
    this.isSubmitting = false,
    this.error,
    this.result,
  });

  ForgeWorldState copyWith({
    int? step,
    String? title,
    String? description,
    bool? isSentient,
    bool? isNsfwCapable,
    String? seedPrompt,
    String? globalLore,
    List<String>? sceneTags,
    List<StatEntry>? stats,
    String? modelLogic,
    String? modelNarrationSfw,
    String? modelNarrationNsfw,
    String? modelSummary,
    int? maxContextMemories,
    int? maxLoreResults,
    bool? isSubmitting,
    String? error,
    WorldTemplate? result,
    bool clearError = false,
  }) =>
      ForgeWorldState(
        step: step ?? this.step,
        title: title ?? this.title,
        description: description ?? this.description,
        isSentient: isSentient ?? this.isSentient,
        isNsfwCapable: isNsfwCapable ?? this.isNsfwCapable,
        seedPrompt: seedPrompt ?? this.seedPrompt,
        globalLore: globalLore ?? this.globalLore,
        sceneTags: sceneTags ?? this.sceneTags,
        stats: stats ?? this.stats,
        modelLogic: modelLogic ?? this.modelLogic,
        modelNarrationSfw: modelNarrationSfw ?? this.modelNarrationSfw,
        modelNarrationNsfw: modelNarrationNsfw ?? this.modelNarrationNsfw,
        modelSummary: modelSummary ?? this.modelSummary,
        maxContextMemories: maxContextMemories ?? this.maxContextMemories,
        maxLoreResults: maxLoreResults ?? this.maxLoreResults,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        result: result ?? this.result,
      );

  bool get step0Valid =>
      title.trim().length >= 2 && description.trim().length >= 10;
  bool get step1Valid => seedPrompt.trim().length >= 10;
  bool get step2Valid => globalLore.trim().length >= 10;

  bool get canProceed {
    switch (step) {
      case 0:
        return step0Valid;
      case 1:
        return step1Valid;
      case 2:
        return step2Valid;
      default:
        return true;
    }
  }

  @override
  List<Object?> get props => [
        step,
        title,
        description,
        isSentient,
        isNsfwCapable,
        seedPrompt,
        globalLore,
        sceneTags,
        stats,
        modelLogic,
        modelNarrationSfw,
        modelNarrationNsfw,
        modelSummary,
        maxContextMemories,
        maxLoreResults,
        isSubmitting,
        error,
        result,
      ];
}

class ForgeWorldCubit extends Cubit<ForgeWorldState> {
  final String? existingId;

  ForgeWorldCubit({WorldTemplate? existing})
      : existingId = existing?.id,
        super(existing != null
            ? _fromTemplate(existing)
            : const ForgeWorldState());

  static ForgeWorldState _fromTemplate(WorldTemplate t) {
    final stats = t.baseStatsTemplate.entries
        .map((e) => StatEntry(
              name: e.key,
              defaultValue: e.value.defaultValue,
              min: e.value.min,
              max: e.value.max,
              description: e.value.description,
            ))
        .toList();
    return ForgeWorldState(
      title: t.title,
      description: t.description,
      isSentient: t.isSentient,
      isNsfwCapable: t.isNsfwCapable,
      seedPrompt: t.seedPrompt,
      globalLore: t.globalLore,
      sceneTags: List<String>.from(t.sceneTags),
      stats: stats,
      modelLogic: t.modelPreferences['logic'] ?? 'gpt-4o',
      modelNarrationSfw: t.modelPreferences['narration_sfw'] ?? 'gpt-4o',
      modelNarrationNsfw:
          t.modelPreferences['narration_nsfw'] ?? 'pygmalionai/mythalion-13b',
      modelSummary: t.modelPreferences['summary'] ?? 'gpt-4o-mini',
      maxContextMemories: t.maxContextMemories,
      maxLoreResults: t.maxLoreResults,
    );
  }

  void nextStep() {
    if (state.step < 4 && state.canProceed) {
      emit(state.copyWith(step: state.step + 1, clearError: true));
    }
  }

  void prevStep() {
    if (state.step > 0) {
      emit(state.copyWith(step: state.step - 1, clearError: true));
    }
  }

  void setTitle(String v) => emit(state.copyWith(title: v));
  void setDescription(String v) => emit(state.copyWith(description: v));
  void setIsSentient(bool v) => emit(state.copyWith(isSentient: v));
  void setIsNsfwCapable(bool v) => emit(state.copyWith(isNsfwCapable: v));
  void setSeedPrompt(String v) => emit(state.copyWith(seedPrompt: v));
  void setGlobalLore(String v) => emit(state.copyWith(globalLore: v));

  void addTag(String tag) {
    final t = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (t.isEmpty || state.sceneTags.contains(t)) return;
    emit(state.copyWith(sceneTags: [...state.sceneTags, t]));
  }

  void removeTag(String tag) {
    emit(state.copyWith(
        sceneTags: state.sceneTags.where((t) => t != tag).toList()));
  }

  void addStat(StatEntry stat) {
    emit(state.copyWith(stats: [...state.stats, stat]));
  }

  void updateStat(int index, StatEntry stat) {
    final updated = [...state.stats]..[index] = stat;
    emit(state.copyWith(stats: updated));
  }

  void removeStat(int index) {
    final updated = [...state.stats]..removeAt(index);
    emit(state.copyWith(stats: updated));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void setModelLogic(String v) => emit(state.copyWith(modelLogic: v));
  void setModelNarrationSfw(String v) =>
      emit(state.copyWith(modelNarrationSfw: v));
  void setModelNarrationNsfw(String v) =>
      emit(state.copyWith(modelNarrationNsfw: v));
  void setModelSummary(String v) => emit(state.copyWith(modelSummary: v));
  void setMaxContextMemories(int v) =>
      emit(state.copyWith(maxContextMemories: v));
  void setMaxLoreResults(int v) => emit(state.copyWith(maxLoreResults: v));

  Future<void> forge() async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final payload = _buildPayload();
      final result = existingId != null
          ? await CreatorRepository.update(existingId!, payload)
          : await CreatorRepository.create(payload);
      emit(state.copyWith(isSubmitting: false, result: result));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _friendly(e)));
    }
  }

  Map<String, dynamic> _buildPayload() {
    final statsMap = <String, dynamic>{};
    for (final s in state.stats) {
      statsMap[s.name] = {
        'default': s.defaultValue,
        'min': s.min,
        'max': s.max,
        'description': s.description,
      };
    }
    return {
      'title': state.title.trim(),
      'description': state.description.trim(),
      'is_sentient': state.isSentient,
      'is_nsfw_capable': state.isNsfwCapable,
      'seed_prompt': state.seedPrompt.trim(),
      'global_lore': state.globalLore.trim(),
      'base_stats_template': statsMap,
      'scene_tags': state.sceneTags,
      'model_preferences': {
        'logic': state.modelLogic,
        'narration_sfw': state.modelNarrationSfw,
        'narration_nsfw': state.modelNarrationNsfw,
        'summary': state.modelSummary,
      },
      'max_context_memories': state.maxContextMemories,
      'max_lore_results': state.maxLoreResults,
    };
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('rate limit')) {
      return 'The forge needs rest — only 5 worlds may be crafted per day.';
    }
    if (s.contains('401') || s.contains('unauthorized')) {
      return 'Your session has faded. Sign in to continue.';
    }
    if (s.contains('403')) {
      return 'Only Premium and Creator wielders may forge worlds.';
    }
    if (s.contains('title')) {
      return 'A world without a name cannot be summoned.';
    }
    if (s.contains('seed_prompt')) {
      return "The Oracle's Voice must be at least 10 characters.";
    }
    if (s.contains('global_lore')) {
      return 'The Ancient Lore must be at least 10 characters.';
    }
    return 'The arcane forge flickered. Please try again.';
  }
}
