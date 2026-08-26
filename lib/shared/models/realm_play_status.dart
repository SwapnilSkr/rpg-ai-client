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
                .map(
                  (e) =>
                      RealmStorySummary.fromJson(Map<String, dynamic>.from(e)),
                )
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
  final int total;
  final int page;

  const RealmTemplateStories({
    this.template,
    this.stories = const [],
    this.total = 0,
    this.page = 1,
  });

  /// Server sends `total` + `page` when paginated; fallback to list length
  /// so old cached / non-paged responses still render.
  bool get hasMore =>
      stories.isNotEmpty && stories.length + (page - 1) * 12 < total;

  factory RealmTemplateStories.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'];
    final list = rawStories is List ? rawStories : const [];
    final parsed = list.map((raw) {
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
    }).toList();
    return RealmTemplateStories(
      template: json['template'] is Map
          ? Map<String, dynamic>.from(json['template'])
          : null,
      stories: parsed,
      total: (json['total'] as num?)?.toInt() ?? parsed.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
    );
  }

  RealmTemplateStories copyWith({
    Map<String, dynamic>? template,
    List<RealmStoryDetail>? stories,
    int? total,
    int? page,
  }) => RealmTemplateStories(
    template: template ?? this.template,
    stories: stories ?? this.stories,
    total: total ?? this.total,
    page: page ?? this.page,
  );
}
