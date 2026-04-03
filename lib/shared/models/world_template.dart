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

class WorldTemplate {
  final String id;
  final String creatorId;
  final String title;
  final String slug;
  final String description;
  final bool isPublished;
  final bool isSentient;
  final bool isNsfwCapable;
  final int version;
  final String seedPrompt;
  final String globalLore;
  final Map<String, StatDefinition> baseStatsTemplate;
  final Map<String, dynamic> flagDefinitions;
  final List<String> sceneTags;
  final Map<String, String> modelPreferences;
  final int maxContextMemories;
  final int maxLoreResults;
  final DateTime? createdAt;

  const WorldTemplate({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.slug,
    required this.description,
    this.isPublished = false,
    this.isSentient = false,
    this.isNsfwCapable = false,
    this.version = 1,
    this.seedPrompt = '',
    this.globalLore = '',
    this.baseStatsTemplate = const {},
    this.flagDefinitions = const {},
    this.sceneTags = const [],
    this.modelPreferences = const {},
    this.maxContextMemories = 25,
    this.maxLoreResults = 10,
    this.createdAt,
  });

  factory WorldTemplate.fromJson(Map<String, dynamic> json) {
    final statsMap = <String, StatDefinition>{};
    if (json['base_stats_template'] is Map) {
      for (final entry in (json['base_stats_template'] as Map).entries) {
        statsMap[entry.key] = StatDefinition.fromJson(entry.value);
      }
    }

    return WorldTemplate(
      id: json['_id'] ?? json['id'] ?? '',
      creatorId: json['creator_id'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      isPublished: json['is_published'] ?? false,
      isSentient: json['is_sentient'] ?? false,
      isNsfwCapable: json['is_nsfw_capable'] ?? false,
      version: json['version'] ?? 1,
      seedPrompt: json['seed_prompt'] ?? '',
      globalLore: json['global_lore'] ?? '',
      baseStatsTemplate: statsMap,
      flagDefinitions: json['flag_definitions'] ?? {},
      sceneTags: List<String>.from(json['scene_tags'] ?? []),
      modelPreferences: Map<String, String>.from(json['model_preferences'] ?? {}),
      maxContextMemories: json['max_context_memories'] ?? 25,
      maxLoreResults: json['max_lore_results'] ?? 10,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
