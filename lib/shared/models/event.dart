/// A tap-to-play suggestion under the latest narrator turn.
///
/// [label] is the chip caption the player reads; [send] is the fully-formatted
/// player input dispatched on tap — a narrated action (wrapped in *asterisks*)
/// or a spoken line (bare). Tapping sends [send], never [label], so the action
/// is performed rather than spoken verbatim.
class Choice {
  final String label;
  final String kind; // 'act' | 'say'
  final String send;

  const Choice({required this.label, required this.kind, required this.send});

  bool get isValid => label.isNotEmpty && send.isNotEmpty;

  /// Tolerant parse: accepts the structured `{label, kind, send}` shape and the
  /// legacy bare-string shape (treated as a narrated action) so older cached or
  /// in-flight turns still render without crashing.
  factory Choice.fromAny(dynamic raw) {
    if (raw is String) {
      final s = raw.replaceAll('*', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return Choice(label: s, kind: 'act', send: s.isEmpty ? '' : '*$s*');
    }
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final label =
          (m['label'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      final kind = m['kind']?.toString() == 'say' ? 'say' : 'act';
      var send = (m['send'] ?? '').toString().trim();
      if (send.isEmpty) {
        final bare =
            label.replaceAll('*', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        send = bare.isEmpty ? '' : (kind == 'say' ? bare : '*$bare*');
      }
      return Choice(label: label, kind: kind, send: send);
    }
    return const Choice(label: '', kind: 'act', send: '');
  }

  static List<Choice> listFromAny(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(Choice.fromAny)
        .where((c) => c.isValid)
        .toList(growable: false);
  }
}

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

  /// Suggested next moves for the player (tap-to-play chips).
  final List<Choice> choices;

  /// Story landmark crossed on this turn (brass-seal moment), if any.
  final String? milestone;

  /// In-story time that passed on a calendar-tick turn (e.g. "several days").
  final String? timeAdvanced;

  /// Open-thread text that seeded this turn's beat (fate came knocking).
  final String? fateThread;

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
    this.choices = const [],
    this.milestone,
    this.timeAdvanced,
    this.fateThread,
  });

  /// True for time-skip turns, which render as interstitial passage cards.
  bool get isTimePassage => type == 'calendar_tick';

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
      choices: choices,
      milestone: milestone,
      timeAdvanced: timeAdvanced,
      fateThread: fateThread,
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
      choices: Choice.listFromAny(data?['choices'] ?? json['choices']),
      milestone: (data?['milestone'] ?? json['milestone'])?.toString(),
      timeAdvanced: (data?['time_advanced'] ?? json['time_advanced'])
          ?.toString(),
      fateThread: (data?['fate_thread'] ?? json['fate_thread'])?.toString(),
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
