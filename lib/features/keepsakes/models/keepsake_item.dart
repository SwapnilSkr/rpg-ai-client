enum KeepsakeKind {
  picture,
  video,
  portrait;

  static KeepsakeKind fromString(String val) {
    return switch (val) {
      'picture' => KeepsakeKind.picture,
      'video' => KeepsakeKind.video,
      'portrait' => KeepsakeKind.portrait,
      _ => KeepsakeKind.picture,
    };
  }

  String get apiValue => switch (this) {
    KeepsakeKind.picture => 'picture',
    KeepsakeKind.video => 'video',
    KeepsakeKind.portrait => 'portrait',
  };
}

enum KeepsakesFilter {
  all('All', 'all'),
  pictures('Pictures', 'picture'),
  films('Films', 'video'),
  faces('Faces', 'portrait');

  final String label;
  final String apiKind;
  const KeepsakesFilter(this.label, this.apiKind);
}

enum KeepsakesViewMode {
  feed,
  grid,
}

class KeepsakeWorld {
  final String title;
  final String? coverUrl;

  const KeepsakeWorld({
    required this.title,
    this.coverUrl,
  });

  factory KeepsakeWorld.fromJson(Map<String, dynamic> json) => KeepsakeWorld(
    title: json['title'] as String? ?? '',
    coverUrl: json['cover_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    if (coverUrl != null) 'cover_url': coverUrl,
  };
}

class KeepsakeCharacter {
  final String id;
  final String name;

  const KeepsakeCharacter({
    required this.id,
    required this.name,
  });

  factory KeepsakeCharacter.fromJson(Map<String, dynamic> json) => KeepsakeCharacter(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}

class KeepsakeItem {
  final String mediaId;
  final KeepsakeKind kind;
  final String url;
  final String? posterUrl;
  final int? durationMs;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final String? instanceId;
  final String? eventId;
  final KeepsakeWorld? world;
  final String? saveLabel;
  final String? excerpt;
  final String? speakerName;
  final KeepsakeCharacter? character;

  const KeepsakeItem({
    required this.mediaId,
    required this.kind,
    required this.url,
    this.posterUrl,
    this.durationMs,
    this.width,
    this.height,
    required this.createdAt,
    this.instanceId,
    this.eventId,
    this.world,
    this.saveLabel,
    this.excerpt,
    this.speakerName,
    this.character,
  });

  bool get isVideo => kind == KeepsakeKind.video;
  bool get isPortrait => kind == KeepsakeKind.portrait;
  bool get isLineFilm => isVideo && speakerName != null && speakerName!.isNotEmpty;

  factory KeepsakeItem.fromJson(Map<String, dynamic> json) {
    return KeepsakeItem(
      mediaId: json['media_id'] as String? ?? '',
      kind: KeepsakeKind.fromString(json['kind'] as String? ?? 'picture'),
      url: json['url'] as String? ?? '',
      posterUrl: json['poster_url'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      instanceId: json['instance_id'] as String?,
      eventId: json['event_id'] as String?,
      world: json['world'] != null
          ? KeepsakeWorld.fromJson(Map<String, dynamic>.from(json['world'] as Map))
          : null,
      saveLabel: json['save_label'] as String?,
      excerpt: json['excerpt'] as String?,
      speakerName: json['speaker_name'] as String?,
      character: json['character'] != null
          ? KeepsakeCharacter.fromJson(Map<String, dynamic>.from(json['character'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'media_id': mediaId,
    'kind': kind.apiValue,
    'url': url,
    if (posterUrl != null) 'poster_url': posterUrl,
    if (durationMs != null) 'duration_ms': durationMs,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'created_at': createdAt.toIso8601String(),
    if (instanceId != null) 'instance_id': instanceId,
    if (eventId != null) 'event_id': eventId,
    'world': world?.toJson(),
    if (saveLabel != null) 'save_label': saveLabel,
    if (excerpt != null) 'excerpt': excerpt,
    if (speakerName != null) 'speaker_name': speakerName,
    if (character != null) 'character': character?.toJson(),
  };
}

class KeepsakesPage {
  final List<KeepsakeItem> items;
  final String? nextBefore;

  const KeepsakesPage({
    required this.items,
    this.nextBefore,
  });

  bool get hasMore => nextBefore != null && nextBefore!.isNotEmpty;

  factory KeepsakesPage.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return KeepsakesPage(
      items: list
          .map((e) => KeepsakeItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      nextBefore: json['next_before'] as String?,
    );
  }
}
