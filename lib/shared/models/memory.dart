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
  });

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
    );
  }
}
