import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
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
  }) => StatEntry(
    name: name ?? this.name,
    defaultValue: defaultValue ?? this.defaultValue,
    min: min ?? this.min,
    max: max ?? this.max,
    description: description ?? this.description,
  );

  @override
  List<Object?> get props => [name, defaultValue, min, max, description];
}

enum RealmFlagKind { boolean, integer, string }

class FlagEntry extends Equatable {
  final String name;
  final RealmFlagKind kind;
  final Object defaultValue;
  final String description;

  const FlagEntry({
    required this.name,
    required this.kind,
    required this.defaultValue,
    this.description = '',
  });

  FlagEntry copyWith({
    String? name,
    RealmFlagKind? kind,
    Object? defaultValue,
    String? description,
  }) => FlagEntry(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    defaultValue: defaultValue ?? this.defaultValue,
    description: description ?? this.description,
  );

  @override
  List<Object?> get props => [name, kind, defaultValue, description];
}

class ForgeWorldState extends Equatable {
  final int step;
  final String title;
  final String description;
  final bool isSentient;
  final bool isNsfwCapable;
  final String seedPrompt;
  final String globalLore;
  final String narrativeStyle; // voice preset key; '' = default
  final String styleNotes; // optional free-text refinements
  final String imagePrompt; // visual prompt (auto-suggested, editable)
  final String imageUrl; // generated avatar/background CDN url
  final bool isImageBusy;
  final String? imageError;
  final bool isAutofilling; // one-shot AI draft in flight
  final String? autofillError;
  final int autofillStamp; // bumps on each successful autofill (UI sync signal)
  final String openingLine;
  final List<String> sceneTags;
  final List<StatEntry> stats;
  final List<FlagEntry> flags;
  final int maxContextMemories;
  final int maxLoreResults;
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
    this.narrativeStyle = '',
    this.styleNotes = '',
    this.imagePrompt = '',
    this.imageUrl = '',
    this.isImageBusy = false,
    this.imageError,
    this.isAutofilling = false,
    this.autofillError,
    this.autofillStamp = 0,
    this.openingLine = '',
    this.sceneTags = const [],
    this.stats = const [],
    this.flags = const [],
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
    String? openingLine,
    List<String>? sceneTags,
    List<StatEntry>? stats,
    List<FlagEntry>? flags,
    int? maxContextMemories,
    int? maxLoreResults,
    bool? isSubmitting,
    String? error,
    WorldTemplate? result,
    bool clearError = false,
  }) => ForgeWorldState(
    step: step ?? this.step,
    title: title ?? this.title,
    description: description ?? this.description,
    isSentient: isSentient ?? this.isSentient,
    isNsfwCapable: isNsfwCapable ?? this.isNsfwCapable,
    seedPrompt: seedPrompt ?? this.seedPrompt,
    globalLore: globalLore ?? this.globalLore,
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
    openingLine: openingLine ?? this.openingLine,
    sceneTags: sceneTags ?? this.sceneTags,
    stats: stats ?? this.stats,
    flags: flags ?? this.flags,
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
  bool get step3Valid => stats.isNotEmpty;

  bool get canProceed {
    switch (step) {
      case 0:
        return step0Valid;
      case 1:
        return step1Valid;
      case 2:
        return step2Valid;
      case 3:
        return step3Valid;
      default:
        return true; // step 4 (Portrait) is optional
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
    narrativeStyle,
    styleNotes,
    imagePrompt,
    imageUrl,
    isImageBusy,
    imageError,
    isAutofilling,
    autofillError,
    autofillStamp,
    openingLine,
    sceneTags,
    stats,
    flags,
    maxContextMemories,
    maxLoreResults,
    isSubmitting,
    error,
    result,
  ];
}

List<FlagEntry> _flagsFromTemplate(Map<String, dynamic> raw) {
  if (raw.isEmpty) return [];
  return raw.entries.map((e) {
    final m = Map<String, dynamic>.from(e.value as Map? ?? {});
    final type = (m['type'] as String?) ?? 'boolean';
    final kind = switch (type) {
      'integer' => RealmFlagKind.integer,
      'string' => RealmFlagKind.string,
      _ => RealmFlagKind.boolean,
    };
    final def = m['default'];
    Object dv;
    if (def != null) {
      dv = def;
    } else {
      dv = switch (kind) {
        RealmFlagKind.boolean => false,
        RealmFlagKind.integer => 0,
        RealmFlagKind.string => '',
      };
    }
    return FlagEntry(
      name: e.key,
      kind: kind,
      defaultValue: dv,
      description: m['description'] as String? ?? '',
    );
  }).toList();
}

/// Parse the autofill draft's `scene_tags` array into a tag list.
List<String>? _tagsFromDraft(dynamic raw) {
  if (raw is! List) return null;
  return raw
      .map((e) => e.toString().trim().toLowerCase().replaceAll(' ', '_'))
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Parse the autofill draft's `stats` array into StatEntry list.
List<StatEntry>? _statsFromDraft(dynamic raw) {
  if (raw is! List) return null;
  final out = <StatEntry>[];
  for (final e in raw) {
    final m = Map<String, dynamic>.from(e as Map? ?? {});
    final name = (m['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    out.add(StatEntry(
      name: name,
      defaultValue: (m['default'] as num?) ?? 50,
      min: (m['min'] as num?) ?? 0,
      max: (m['max'] as num?) ?? 100,
      description: (m['description'] ?? '').toString(),
    ));
  }
  return out;
}

/// Parse the autofill draft's `flags` array into FlagEntry list.
List<FlagEntry>? _flagsFromDraft(dynamic raw) {
  if (raw is! List) return null;
  final out = <FlagEntry>[];
  for (final e in raw) {
    final m = Map<String, dynamic>.from(e as Map? ?? {});
    final name = (m['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final kind = switch ((m['type'] ?? 'boolean').toString()) {
      'integer' => RealmFlagKind.integer,
      'string' => RealmFlagKind.string,
      _ => RealmFlagKind.boolean,
    };
    final def = m['default'];
    final Object dv = def ??
        switch (kind) {
          RealmFlagKind.boolean => false,
          RealmFlagKind.integer => 0,
          RealmFlagKind.string => '',
        };
    out.add(FlagEntry(
      name: name,
      kind: kind,
      defaultValue: dv,
      description: (m['description'] ?? '').toString(),
    ));
  }
  return out;
}

class ForgeWorldCubit extends Cubit<ForgeWorldState> {
  final String? existingId;

  ForgeWorldCubit({WorldTemplate? existing})
    : existingId = existing?.id,
      super(
        existing != null ? _fromTemplate(existing) : const ForgeWorldState(),
      );

  static ForgeWorldState _fromTemplate(WorldTemplate t) {
    final stats = t.baseStatsTemplate.entries
        .map(
          (e) => StatEntry(
            name: e.key,
            defaultValue: e.value.defaultValue,
            min: e.value.min,
            max: e.value.max,
            description: e.value.description,
          ),
        )
        .toList();
    final flags = _flagsFromTemplate(
      Map<String, dynamic>.from(t.flagDefinitions),
    );
    return ForgeWorldState(
      title: t.title,
      description: t.description,
      isSentient: t.isSentient,
      isNsfwCapable: t.isNsfwCapable,
      seedPrompt: t.seedPrompt,
      globalLore: t.globalLore,
      narrativeStyle: t.narrativeStyle,
      styleNotes: t.styleNotes,
      imagePrompt: t.imagePrompt,
      imageUrl: t.imageUrl,
      openingLine: t.openingLine,
      sceneTags: List<String>.from(t.sceneTags),
      stats: stats,
      flags: flags,
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
  void setNarrativeStyle(String v) => emit(state.copyWith(narrativeStyle: v));
  void setStyleNotes(String v) => emit(state.copyWith(styleNotes: v));
  void setImagePrompt(String v) => emit(state.copyWith(imagePrompt: v));
  void clearAutofillError() => emit(state.copyWith(clearAutofillError: true));

  /// One-shot AI draft: fills every creative field from an optional [brief],
  /// respecting the chosen world type / maturity / locked voice. Everything it
  /// produces is editable. The world TYPE and maturity toggles are preserved.
  Future<void> autofillAll({String brief = ''}) async {
    if (state.isAutofilling) return;
    emit(state.copyWith(isAutofilling: true, clearAutofillError: true));
    try {
      final d = await CreatorRepository.autofill({
        'target': 'world',
        'brief': brief.trim(),
        'is_sentient': state.isSentient,
        'is_nsfw_capable': state.isNsfwCapable,
        'narrative_style': state.narrativeStyle,
      });
      emit(state.copyWith(
        title: (d['title'] ?? state.title).toString(),
        description: (d['description'] ?? state.description).toString(),
        seedPrompt: (d['seed_prompt'] ?? state.seedPrompt).toString(),
        globalLore: (d['global_lore'] ?? state.globalLore).toString(),
        narrativeStyle:
            (d['narrative_style'] ?? state.narrativeStyle).toString(),
        styleNotes: (d['style_notes'] ?? state.styleNotes).toString(),
        openingLine: (d['opening_line'] ?? state.openingLine).toString(),
        sceneTags: _tagsFromDraft(d['scene_tags']) ?? state.sceneTags,
        stats: _statsFromDraft(d['stats']) ?? state.stats,
        flags: _flagsFromDraft(d['flags']) ?? state.flags,
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
      if (e.statusCode == 429) {
        return 'Too many AI drafts — try again shortly.';
      }
      return e.message;
    }
    return 'Could not draft the world. Please try again.';
  }

  /// Render (or re-roll) the world image from the current visual prompt. The
  /// prompt comes from "Generate with AI" or is typed by the creator; the UI
  /// disables this until one exists.
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
  void setOpeningLine(String v) => emit(state.copyWith(openingLine: v));

  void addTag(String tag) {
    final t = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (t.isEmpty || state.sceneTags.contains(t)) return;
    emit(state.copyWith(sceneTags: [...state.sceneTags, t]));
  }

  void removeTag(String tag) {
    emit(
      state.copyWith(
        sceneTags: state.sceneTags.where((t) => t != tag).toList(),
      ),
    );
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

  void addFlag(FlagEntry flag) {
    emit(state.copyWith(flags: [...state.flags, flag]));
  }

  void updateFlag(int index, FlagEntry flag) {
    final updated = [...state.flags]..[index] = flag;
    emit(state.copyWith(flags: updated));
  }

  void removeFlag(int index) {
    final updated = [...state.flags]..removeAt(index);
    emit(state.copyWith(flags: updated));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void setMaxContextMemories(int v) =>
      emit(state.copyWith(maxContextMemories: v));
  void setMaxLoreResults(int v) => emit(state.copyWith(maxLoreResults: v));

  Future<void> forge() async {
    if (state.stats.isEmpty) {
      emit(
        state.copyWith(
          error:
              'Define at least one Vital Force — adventurers need measurable attributes.',
        ),
      );
      return;
    }
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
    final flagsMap = <String, dynamic>{};
    for (final f in state.flags) {
      final typeStr = switch (f.kind) {
        RealmFlagKind.boolean => 'boolean',
        RealmFlagKind.integer => 'integer',
        RealmFlagKind.string => 'string',
      };
      flagsMap[f.name] = {
        'type': typeStr,
        'default': f.defaultValue,
        'description': f.description,
      };
    }
    return {
      'title': state.title.trim(),
      'description': state.description.trim(),
      'is_sentient': state.isSentient,
      'is_nsfw_capable': state.isNsfwCapable,
      'seed_prompt': state.seedPrompt.trim(),
      'narrative_style': state.narrativeStyle,
      'style_notes': state.styleNotes.trim(),
      'image_url': state.imageUrl,
      'image_prompt': state.imagePrompt.trim(),
      'global_lore': state.globalLore.trim(),
      'opening_line': state.openingLine.trim(),
      'base_stats_template': statsMap,
      'flag_definitions': flagsMap,
      'scene_tags': state.sceneTags,
      'max_context_memories': state.maxContextMemories,
      'max_lore_results': state.maxLoreResults,
    };
  }

  String _friendly(Object e) {
    if (e is ApiException) {
      final m = e.message;
      if (e.statusCode == 429 &&
          m.toLowerCase().contains('template creation rate')) {
        return 'The forge needs rest — only 5 worlds may be crafted per day.';
      }
      if (e.statusCode == 403 &&
          m.toLowerCase().contains('premium') &&
          m.toLowerCase().contains('creator')) {
        return 'Only Premium and Creator wielders may forge worlds.';
      }
      return m;
    }
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
    return 'The arcane forge flickered. Please try again.';
  }
}
