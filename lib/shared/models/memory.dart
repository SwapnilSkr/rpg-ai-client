class Memory {
  final String id;
  final String instanceId;
  final String text;
  final String type;
  final int importance;
  final bool isNsfw;
  final bool isArchived;
  final List<String> sourceEventIds;
  final int accessCount;
  final DateTime? createdAt;

  /// Canonical entity names this memory is about — who acted/felt (rich-atom).
  final List<String> subjects;

  /// Canonical entity names acted upon or affected — places, things, people.
  final List<String> objects;

  /// True while this memory is an open promise/conflict awaiting payoff.
  final bool unresolvedThread;

  const Memory({
    required this.id,
    required this.instanceId,
    required this.text,
    required this.type,
    this.importance = 3,
    this.isNsfw = false,
    this.isArchived = false,
    this.sourceEventIds = const [],
    this.accessCount = 0,
    this.createdAt,
    this.subjects = const [],
    this.objects = const [],
    this.unresolvedThread = false,
  });

  /// Every canonical entity this memory tags (subjects + objects).
  List<String> get entities => [...subjects, ...objects];

  /// Whether this memory concerns [name] (by entity tag or text mention).
  bool concerns(String name) {
    final n = name.toLowerCase();
    if (n.isEmpty) return false;
    return entities.any((s) => s.toLowerCase() == n) ||
        text.toLowerCase().contains(n);
  }

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['_id'] ?? json['id'] ?? '',
      instanceId: json['instance_id'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'observation',
      importance: json['importance'] ?? 3,
      isNsfw: json['is_nsfw'] ?? false,
      isArchived: json['is_archived'] ?? false,
      sourceEventIds: List<String>.from(json['source_event_ids'] ?? []),
      accessCount: json['access_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      subjects:
          (json['subjects'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      objects:
          (json['objects'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      unresolvedThread: json['unresolved_thread'] == true,
    );
  }

  Memory copyWith({
    String? text,
    String? type,
    int? importance,
  }) {
    return Memory(
      id: id,
      instanceId: instanceId,
      text: text ?? this.text,
      type: type ?? this.type,
      importance: importance ?? this.importance,
      isNsfw: isNsfw,
      isArchived: isArchived,
      sourceEventIds: sourceEventIds,
      accessCount: accessCount,
      createdAt: createdAt,
      subjects: subjects,
      objects: objects,
      unresolvedThread: unresolvedThread,
    );
  }
}
