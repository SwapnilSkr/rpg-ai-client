class RealmStorySummary {
  final String id;
  final DateTime? lastActiveAt;
  final int totalEvents;

  const RealmStorySummary({
    required this.id,
    this.lastActiveAt,
    this.totalEvents = 0,
  });

  factory RealmStorySummary.fromJson(Map<String, dynamic> json) {
    return RealmStorySummary(
      id: json['id'] ?? '',
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString())
          : null,
      totalEvents: json['total_events'] ?? 0,
    );
  }
}

class RealmPlayStatus {
  final bool hasPlayed;
  final int count;
  final String? latestInstanceId;
  final List<RealmStorySummary> stories;

  const RealmPlayStatus({
    this.hasPlayed = false,
    this.count = 0,
    this.latestInstanceId,
    this.stories = const [],
  });

  factory RealmPlayStatus.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'];
    return RealmPlayStatus(
      hasPlayed: json['has_played'] == true,
      count: json['count'] ?? 0,
      latestInstanceId: json['latest_instance_id']?.toString(),
      stories: rawStories is List
          ? rawStories
              .map((e) => RealmStorySummary.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class RealmStoryDetail {
  final RealmStorySummary summary;
  final String preview;
  final int storyIndex;
  final Map<String, dynamic>? template;

  const RealmStoryDetail({
    required this.summary,
    this.preview = '',
    this.storyIndex = 1,
    this.template,
  });
}

class RealmTemplateStories {
  final Map<String, dynamic>? template;
  final List<RealmStoryDetail> stories;

  const RealmTemplateStories({
    this.template,
    this.stories = const [],
  });

  factory RealmTemplateStories.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'];
    final list = rawStories is List ? rawStories : const [];
    return RealmTemplateStories(
      template: json['template'] is Map
          ? Map<String, dynamic>.from(json['template'])
          : null,
      stories: list.map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final meta = item['meta'] is Map
            ? Map<String, dynamic>.from(item['meta'])
            : <String, dynamic>{};
        return RealmStoryDetail(
          summary: RealmStorySummary(
            id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
            lastActiveAt: meta['last_active_at'] != null
                ? DateTime.tryParse(meta['last_active_at'].toString())
                : null,
            totalEvents: meta['total_events'] ?? 0,
          ),
          preview: item['preview']?.toString() ?? '',
          storyIndex: item['story_index'] ?? 1,
          template: item['template'] is Map
              ? Map<String, dynamic>.from(item['template'])
              : null,
        );
      }).toList(),
    );
  }
}
