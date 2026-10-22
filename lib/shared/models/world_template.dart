class StatDefinition {
  final num defaultValue;
  final num min;
  final num max;
  final String description;

  const StatDefinition({
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.description,
  });

  factory StatDefinition.fromJson(Map<String, dynamic> json) {
    return StatDefinition(
      defaultValue: json['default'] ?? 50,
      min: json['min'] ?? 0,
      max: json['max'] ?? 100,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'default': defaultValue,
    'min': min,
    'max': max,
    'description': description,
  };
}

enum WorldReviewState {
  unpublished,
  private,
  pending,
  approved,
  changesRequested,
}

class WorldTemplate {
  final String id;
  final String creatorId;
  final String title;
  final String slug;
  final String description;
  final String kind; // 'world' | 'character'
  final bool isPublished;
  final bool isSentient;
  final bool isNsfwCapable;
  final int version;
  final String seedPrompt;
  final String globalLore;
  final String narrativeStyle;
  final String styleNotes;
  final String imageUrl;
  final String imagePrompt;
  final String openingLine;
  final Map<String, StatDefinition> baseStatsTemplate;
  final Map<String, dynamic> flagDefinitions;
  final List<String> sceneTags;
  final Map<String, String> modelPreferences;
  final int maxContextMemories;
  final int maxLoreResults;
  final DateTime? createdAt;
  final String? visibility;
  final String? reviewStatus;
  final String? reviewNote;
  final String? genre;

  const WorldTemplate({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.slug,
    required this.description,
    this.kind = 'world',
    this.isPublished = false,
    this.isSentient = false,
    this.isNsfwCapable = false,
    this.version = 1,
    this.seedPrompt = '',
    this.globalLore = '',
    this.narrativeStyle = '',
    this.styleNotes = '',
    this.imageUrl = '',
    this.imagePrompt = '',
    this.openingLine = '',
    this.baseStatsTemplate = const {},
    this.flagDefinitions = const {},
    this.sceneTags = const [],
    this.modelPreferences = const {},
    this.maxContextMemories = 25,
    this.maxLoreResults = 10,
    this.createdAt,
    this.visibility,
    this.reviewStatus,
    this.reviewNote,
    this.genre,
  });

  bool get isCharacter => kind == 'character';

  WorldReviewState get reviewState {
    if (!isPublished) return WorldReviewState.unpublished;
    if (visibility == 'private') return WorldReviewState.private;
    return switch (reviewStatus) {
      'pending' => WorldReviewState.pending,
      'changes_requested' => WorldReviewState.changesRequested,
      'approved' || null => WorldReviewState.approved,
      _ => WorldReviewState.approved,
    };
  }

  String get reviewStateLabel {
    return switch (reviewState) {
      WorldReviewState.unpublished => 'Draft',
      WorldReviewState.private => 'Just for you',
      WorldReviewState.pending => 'Awaiting the seal',
      WorldReviewState.approved => 'Shared with all',
      WorldReviewState.changesRequested => 'Needs changes',
    };
  }

  WorldTemplate copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? slug,
    String? description,
    String? kind,
    bool? isPublished,
    bool? isSentient,
    bool? isNsfwCapable,
    int? version,
    String? seedPrompt,
    String? globalLore,
    String? narrativeStyle,
    String? styleNotes,
    String? imageUrl,
    String? imagePrompt,
    String? openingLine,
    Map<String, StatDefinition>? baseStatsTemplate,
    Map<String, dynamic>? flagDefinitions,
    List<String>? sceneTags,
    Map<String, String>? modelPreferences,
    int? maxContextMemories,
    int? maxLoreResults,
    DateTime? createdAt,
    String? visibility,
    String? reviewStatus,
    String? reviewNote,
    String? genre,
  }) {
    return WorldTemplate(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      isPublished: isPublished ?? this.isPublished,
      isSentient: isSentient ?? this.isSentient,
      isNsfwCapable: isNsfwCapable ?? this.isNsfwCapable,
      version: version ?? this.version,
      seedPrompt: seedPrompt ?? this.seedPrompt,
      globalLore: globalLore ?? this.globalLore,
      narrativeStyle: narrativeStyle ?? this.narrativeStyle,
      styleNotes: styleNotes ?? this.styleNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      openingLine: openingLine ?? this.openingLine,
      baseStatsTemplate: baseStatsTemplate ?? this.baseStatsTemplate,
      flagDefinitions: flagDefinitions ?? this.flagDefinitions,
      sceneTags: sceneTags ?? this.sceneTags,
      modelPreferences: modelPreferences ?? this.modelPreferences,
      maxContextMemories: maxContextMemories ?? this.maxContextMemories,
      maxLoreResults: maxLoreResults ?? this.maxLoreResults,
      createdAt: createdAt ?? this.createdAt,
      visibility: visibility ?? this.visibility,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewNote: reviewNote ?? this.reviewNote,
      genre: genre ?? this.genre,
    );
  }

  factory WorldTemplate.fromJson(Map<String, dynamic> json) {
    final statsMap = <String, StatDefinition>{};
    if (json['base_stats_template'] is Map) {
      for (final entry in (json['base_stats_template'] as Map).entries) {
        statsMap[entry.key] = StatDefinition.fromJson(entry.value);
      }
    }

    return WorldTemplate(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      creatorId: json['creator_id']?.toString() ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      kind: (json['kind'] ?? 'world').toString(),
      isPublished: json['is_published'] ?? false,
      isSentient: json['is_sentient'] ?? false,
      isNsfwCapable: json['is_nsfw_capable'] ?? false,
      version: json['version'] ?? 1,
      seedPrompt: json['seed_prompt'] ?? '',
      globalLore: json['global_lore'] ?? '',
      narrativeStyle: json['narrative_style'] ?? '',
      styleNotes: json['style_notes'] ?? '',
      imageUrl: json['image_url'] ?? '',
      imagePrompt: json['image_prompt'] ?? '',
      openingLine: json['opening_line'] ?? '',
      baseStatsTemplate: statsMap,
      flagDefinitions: Map<String, dynamic>.from(
        json['flag_definitions'] ?? {},
      ),
      sceneTags: List<String>.from(json['scene_tags'] ?? []),
      modelPreferences: Map<String, String>.from(
        json['model_preferences'] ?? {},
      ),
      maxContextMemories: json['max_context_memories'] ?? 25,
      maxLoreResults: json['max_lore_results'] ?? 10,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      visibility: json['visibility'] as String?,
      reviewStatus: json['review_status'] as String?,
      reviewNote: json['review_note'] as String?,
      genre: json['genre'] as String?,
    );
  }
}
