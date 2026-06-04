class GameEvent {
  final String id;
  final String instanceId;
  final int sequence;
  final String type;
  final String? playerInput;
  final String? aiResponse;
  final String? sceneTag;
  final Map<String, dynamic>? stateMutations;
  final Map<String, dynamic>? flagMutations;
  final String? emotionalTone;
  final String modelUsed;
  final DateTime createdAt;
  final bool isOptimistic;
  final bool isUserEdited;
  final List<ReplayVariant> replayVariants;
  final int selectedReplayIndex;

  const GameEvent({
    required this.id,
    required this.instanceId,
    required this.sequence,
    required this.type,
    this.playerInput,
    this.aiResponse,
    this.sceneTag,
    this.stateMutations,
    this.flagMutations,
    this.emotionalTone,
    this.modelUsed = '',
    required this.createdAt,
    this.isOptimistic = false,
    this.isUserEdited = false,
    this.replayVariants = const [],
    this.selectedReplayIndex = 0,
  });

  GameEvent copyWith({
    String? playerInput,
    String? aiResponse,
    String? sceneTag,
    String? modelUsed,
    bool? isOptimistic,
    bool? isUserEdited,
    List<ReplayVariant>? replayVariants,
    int? selectedReplayIndex,
  }) {
    return GameEvent(
      id: id,
      instanceId: instanceId,
      sequence: sequence,
      type: type,
      playerInput: playerInput ?? this.playerInput,
      aiResponse: aiResponse ?? this.aiResponse,
      sceneTag: sceneTag ?? this.sceneTag,
      stateMutations: stateMutations,
      flagMutations: flagMutations,
      emotionalTone: emotionalTone,
      modelUsed: modelUsed ?? this.modelUsed,
      createdAt: createdAt,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      isUserEdited: isUserEdited ?? this.isUserEdited,
      replayVariants: replayVariants ?? this.replayVariants,
      selectedReplayIndex: selectedReplayIndex ?? this.selectedReplayIndex,
    );
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final replay =
        (data?['replay_variants'] as List?)
            ?.map(
              (v) =>
                  ReplayVariant.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList() ??
        const <ReplayVariant>[];
    final selected = (data?['selected_replay_index'] as num?)?.toInt() ?? 0;
    return GameEvent(
      id: json['id'] ?? json['_id'] ?? '',
      instanceId: json['instance_id'] ?? json['instanceId'] ?? '',
      sequence: json['sequence'] ?? 0,
      type: json['type'] ?? 'narration',
      playerInput: data?['player_input'] ?? json['player_input'],
      aiResponse:
          data?['ai_response'] ?? json['ai_response'] ?? json['narrative'],
      sceneTag: json['scene_tag'] ?? data?['scene_tag'],
      stateMutations: data?['state_mutations'],
      flagMutations: data?['flag_mutations'],
      emotionalTone: json['emotional_tone'],
      modelUsed: (data?['model_used'] ?? json['model_used'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isUserEdited: json['is_user_edited'] ?? false,
      replayVariants: replay,
      selectedReplayIndex: selected,
    );
  }

  factory GameEvent.optimistic({
    required String instanceId,
    required String playerInput,
  }) {
    return GameEvent(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      instanceId: instanceId,
      sequence: -1,
      type: 'player_action',
      playerInput: playerInput,
      createdAt: DateTime.now(),
      isOptimistic: true,
    );
  }

  factory GameEvent.fromSqlite(Map<String, dynamic> row) {
    return GameEvent(
      id: row['id'] as String,
      instanceId: row['instance_id'] as String,
      sequence: row['sequence'] as int,
      type: row['type'] as String,
      playerInput: row['player_input'] as String?,
      aiResponse: row['ai_response'] as String?,
      sceneTag: row['scene_tag'] as String?,
      modelUsed: (row['model_used'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      isOptimistic: (row['is_optimistic'] as int?) == 1,
    );
  }

  Map<String, dynamic> toSqlite() => {
    'id': id,
    'instance_id': instanceId,
    'sequence': sequence,
    'type': type,
    'player_input': playerInput,
    'ai_response': aiResponse,
    'scene_tag': sceneTag,
    'model_used': modelUsed,
    'created_at': createdAt.toIso8601String(),
    'is_optimistic': isOptimistic ? 1 : 0,
  };
}

class ReplayVariant {
  final String id;
  final String narrative;
  final String modelUsed;
  final DateTime? createdAt;

  const ReplayVariant({
    required this.id,
    required this.narrative,
    this.modelUsed = '',
    this.createdAt,
  });

  factory ReplayVariant.fromJson(Map<String, dynamic> json) {
    return ReplayVariant(
      id: (json['id'] ?? '').toString(),
      narrative: (json['narrative'] ?? '').toString(),
      modelUsed: (json['model_used'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
