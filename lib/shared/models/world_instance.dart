class WorldInstance {
  static const _unset = Object();
  final String id;
  final String templateId;
  final int templateVersion;
  final String playerId;
  final Map<String, num> worldState;
  final Map<String, dynamic> activeFlags;
  final SceneInfo currentScene;
  final String narrationPov; // 'first' | 'third'
  final String mode; // chat mode key; 'free_play' = default
  final String messageLength; // 'short' | 'medium' | 'long'
  final String? focusCharacterId;
  final String? personaId;
  /// Snapshot of the persona name selected for this instance (sentient worlds).
  /// Parsed from the server's `persona_snapshot.name` so the client can exclude
  /// the player persona from client-side miss-audit / track suggestions without
  /// a persona fetch.
  final String? personaName;
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
    this.narrationPov = 'third',
    this.mode = 'free_play',
    this.messageLength = 'medium',
    this.focusCharacterId,
    this.personaId,
    this.personaName,
    this.meta = const InstanceMeta(),
    this.createdAt,
    this.template,
  });

  WorldInstance copyWith({
    String? narrationPov,
    String? mode,
    String? messageLength,
    Object? focusCharacterId = _unset,
    Object? personaId = _unset,
    Object? personaName = _unset,
  }) {
    return WorldInstance(
      id: id,
      templateId: templateId,
      templateVersion: templateVersion,
      playerId: playerId,
      worldState: worldState,
      activeFlags: activeFlags,
      currentScene: currentScene,
      narrationPov: narrationPov ?? this.narrationPov,
      mode: mode ?? this.mode,
      messageLength: messageLength ?? this.messageLength,
      focusCharacterId:
          identical(focusCharacterId, _unset) ? this.focusCharacterId : focusCharacterId as String?,
      personaId: identical(personaId, _unset) ? this.personaId : personaId as String?,
      personaName:
          identical(personaName, _unset) ? this.personaName : personaName as String?,
      meta: meta,
      createdAt: createdAt,
      template: template,
    );
  }

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
      narrationPov: json['narration_pov'] ?? 'third',
      mode: json['mode'] ?? 'free_play',
      messageLength: json['message_length'] ?? 'medium',
      focusCharacterId: json['focus_character_id']?.toString(),
      personaId: json['persona_id']?.toString(),
      personaName: json['persona_snapshot'] is Map
          ? (json['persona_snapshot']['name'] as String?)?.toString()
          : null,
      meta: json['meta'] != null
          ? InstanceMeta.fromJson(json['meta'])
          : const InstanceMeta(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      template: json['template'],
    );
  }

  /// Apply an authoritative `instance_state` snapshot (as shipped on the
  /// `replay_complete` frame): world_state + active_flags are merged like a diff,
  /// and current_scene is replaced when present. current_location and
  /// current_time_anchor are not modeled on the instance and are left to the
  /// Chronicle's own projections.
  WorldInstance applyInstanceState(Map<String, dynamic> snapshot) {
    final merged = applyStateDiff(snapshot);
    final scene = snapshot['current_scene'];
    return WorldInstance(
      id: merged.id,
      templateId: merged.templateId,
      templateVersion: merged.templateVersion,
      playerId: merged.playerId,
      worldState: merged.worldState,
      activeFlags: merged.activeFlags,
      currentScene: scene is Map
          ? SceneInfo.fromJson(Map<String, dynamic>.from(scene))
          : merged.currentScene,
      narrationPov: merged.narrationPov,
      mode: merged.mode,
      messageLength: merged.messageLength,
      focusCharacterId: merged.focusCharacterId,
      personaId: merged.personaId,
      personaName: merged.personaName,
      meta: merged.meta,
      createdAt: merged.createdAt,
      template: merged.template,
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
      narrationPov: narrationPov,
      mode: mode,
      messageLength: messageLength,
      focusCharacterId: focusCharacterId,
      personaId: personaId,
      personaName: personaName,
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

/// A story landmark crossed during play (brass-seal moment), persisted in the
/// instance meta and rendered on the story timeline.
class Milestone {
  final String label;
  final int sequence;
  final DateTime? at;

  const Milestone({required this.label, required this.sequence, this.at});

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      label: (json['label'] ?? '').toString(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      at: json['at'] != null ? DateTime.tryParse(json['at'].toString()) : null,
    );
  }
}

class InstanceMeta {
  final int totalEvents;
  final int totalMemories;
  final int totalTokensConsumed;
  final DateTime? lastActiveAt;
  final bool isArchived;

  /// Story landmarks crossed so far (oldest first), capped server-side at 50.
  final List<Milestone> milestones;

  const InstanceMeta({
    this.totalEvents = 0,
    this.totalMemories = 0,
    this.totalTokensConsumed = 0,
    this.lastActiveAt,
    this.isArchived = false,
    this.milestones = const [],
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
      milestones:
          (json['milestones'] as List?)
              ?.map((e) => Milestone.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}
