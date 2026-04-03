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
  final DateTime createdAt;
  final bool isOptimistic;
  final bool isUserEdited;

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
    required this.createdAt,
    this.isOptimistic = false,
    this.isUserEdited = false,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return GameEvent(
      id: json['id'] ?? json['_id'] ?? '',
      instanceId: json['instance_id'] ?? json['instanceId'] ?? '',
      sequence: json['sequence'] ?? 0,
      type: json['type'] ?? 'narration',
      playerInput: data?['player_input'] ?? json['player_input'],
      aiResponse: data?['ai_response'] ?? json['ai_response'] ?? json['narrative'],
      sceneTag: json['scene_tag'] ?? data?['scene_tag'],
      stateMutations: data?['state_mutations'],
      flagMutations: data?['flag_mutations'],
      emotionalTone: json['emotional_tone'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isUserEdited: json['is_user_edited'] ?? false,
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
      createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
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
        'created_at': createdAt.toIso8601String(),
        'is_optimistic': isOptimistic ? 1 : 0,
      };
}
