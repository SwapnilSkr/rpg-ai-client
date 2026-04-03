class WorldInstance {
  final String id;
  final String templateId;
  final int templateVersion;
  final String playerId;
  final Map<String, num> worldState;
  final Map<String, dynamic> activeFlags;
  final SceneInfo currentScene;
  final InstanceMeta meta;
  final DateTime? createdAt;
  // Enriched from list endpoint
  final Map<String, dynamic>? template;

  const WorldInstance({
    required this.id,
    required this.templateId,
    this.templateVersion = 1,
    required this.playerId,
    this.worldState = const {},
    this.activeFlags = const {},
    this.currentScene = const SceneInfo(),
    this.meta = const InstanceMeta(),
    this.createdAt,
    this.template,
  });

  factory WorldInstance.fromJson(Map<String, dynamic> json) {
    final ws = <String, num>{};
    if (json['world_state'] is Map) {
      for (final entry in (json['world_state'] as Map).entries) {
        ws[entry.key] = (entry.value as num?) ?? 0;
      }
    }

    return WorldInstance(
      id: json['_id'] ?? json['id'] ?? '',
      templateId: json['template_id'] ?? '',
      templateVersion: json['template_version'] ?? 1,
      playerId: json['player_id'] ?? '',
      worldState: ws,
      activeFlags: Map<String, dynamic>.from(json['active_flags'] ?? {}),
      currentScene: json['current_scene'] != null
          ? SceneInfo.fromJson(json['current_scene'])
          : const SceneInfo(),
      meta: json['meta'] != null
          ? InstanceMeta.fromJson(json['meta'])
          : const InstanceMeta(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      template: json['template'],
    );
  }

  WorldInstance applyStateDiff(Map<String, dynamic>? diff) {
    if (diff == null) return this;

    final newState = Map<String, num>.from(worldState);
    if (diff['world_state'] is Map) {
      for (final entry in (diff['world_state'] as Map).entries) {
        newState[entry.key] = (entry.value as num?) ?? newState[entry.key] ?? 0;
      }
    }

    final newFlags = Map<String, dynamic>.from(activeFlags);
    if (diff['active_flags'] is Map) {
      newFlags.addAll(Map<String, dynamic>.from(diff['active_flags']));
    }

    return WorldInstance(
      id: id,
      templateId: templateId,
      templateVersion: templateVersion,
      playerId: playerId,
      worldState: newState,
      activeFlags: newFlags,
      currentScene: currentScene,
      meta: meta,
      createdAt: createdAt,
      template: template,
    );
  }
}

class SceneInfo {
  final String tag;
  final int turnCount;
  final bool summaryPending;

  const SceneInfo({
    this.tag = 'dialogue',
    this.turnCount = 0,
    this.summaryPending = false,
  });

  factory SceneInfo.fromJson(Map<String, dynamic> json) {
    return SceneInfo(
      tag: json['tag'] ?? 'dialogue',
      turnCount: json['turn_count'] ?? 0,
      summaryPending: json['summary_pending'] ?? false,
    );
  }
}

class InstanceMeta {
  final int totalEvents;
  final int totalMemories;
  final int totalTokensConsumed;
  final DateTime? lastActiveAt;
  final bool isArchived;

  const InstanceMeta({
    this.totalEvents = 0,
    this.totalMemories = 0,
    this.totalTokensConsumed = 0,
    this.lastActiveAt,
    this.isArchived = false,
  });

  factory InstanceMeta.fromJson(Map<String, dynamic> json) {
    return InstanceMeta(
      totalEvents: json['total_events'] ?? 0,
      totalMemories: json['total_memories'] ?? 0,
      totalTokensConsumed: json['total_tokens_consumed'] ?? 0,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'])
          : null,
      isArchived: json['is_archived'] ?? false,
    );
  }
}
