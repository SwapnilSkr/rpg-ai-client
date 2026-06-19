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
      final label = (m['label'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final kind = m['kind']?.toString() == 'say' ? 'say' : 'act';
      var send = (m['send'] ?? '').toString().trim();
      if (send.isEmpty) {
        final bare = label
            .replaceAll('*', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
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

/// A backend-OWNED trackable mention: a person the prose surfaced this turn that
/// isn't already present/carded, with a confidence [tier] the SERVER decided
/// (confirmed > probable > mentioned_only). The client renders these instead of
/// running its own canon-gap detection, so the two can't drift.
class TrackableMention {
  final String key;
  final String display;
  final String tier; // 'confirmed' | 'probable' | 'mentioned_only'

  const TrackableMention({
    required this.key,
    required this.display,
    required this.tier,
  });

  factory TrackableMention.fromAny(dynamic raw) {
    if (raw is! Map) {
      return const TrackableMention(
        key: '',
        display: '',
        tier: 'mentioned_only',
      );
    }

    late final Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(raw);
    } on Object {
      return const TrackableMention(
        key: '',
        display: '',
        tier: 'mentioned_only',
      );
    }

    return TrackableMention(
      key: (m['key'] ?? '').toString(),
      display: (m['display'] ?? '').toString(),
      tier: (m['tier'] ?? 'mentioned_only').toString(),
    );
  }

  /// Parse the `trackable_mentions` payload. Returns null when the field is ABSENT
  /// (a legacy turn that predates backend-owned mentions → the client falls back
  /// to local detection), and a (possibly empty) list when the backend supplied it
  /// (empty meaning "the backend found none" — authoritative, no local fallback).
  static List<TrackableMention>? listFromAny(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return const [];
    return raw
        .map(TrackableMention.fromAny)
        .where((m) => m.display.isNotEmpty)
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

  /// Present on travel turns: where the protagonist moved between.
  final TravelMove? travel;

  /// Open-thread text that seeded this turn's beat (fate came knocking).
  final String? fateThread;

  /// Characters present in the scene at the end of this turn. Drives
  /// scene-aware bond actions (approach when here, seek out when elsewhere).
  /// Empty when the viewpoint was alone or presence is unknown.
  final List<String> presentCharacters;

  /// Backend-owned trackable mentions for this turn. null = a legacy turn with no
  /// backend mentions (client falls back to local gap detection); non-null (even
  /// empty) = authoritative backend list.
  final List<TrackableMention>? trackableMentions;

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
    this.travel,
    this.fateThread,
    this.presentCharacters = const [],
    this.trackableMentions,
  });

  /// True for time-skip turns, which render as interstitial passage cards.
  bool get isTimePassage => type == 'calendar_tick';
  bool get isTravel => type == 'travel';

  GameEvent copyWith({
    String? playerInput,
    String? aiResponse,
    String? sceneTag,
    String? modelUsed,
    bool? isOptimistic,
    bool? isUserEdited,
    List<ReplayVariant>? replayVariants,
    int? selectedReplayIndex,
    List<Choice>? choices,
    List<String>? presentCharacters,
    List<TrackableMention>? trackableMentions,
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
      choices: choices ?? this.choices,
      milestone: milestone,
      timeAdvanced: timeAdvanced,
      travel: travel,
      fateThread: fateThread,
      presentCharacters: presentCharacters ?? this.presentCharacters,
      trackableMentions: trackableMentions ?? this.trackableMentions,
    );
  }

  /// Parse a present-characters payload (array of names) into clean strings.
  static List<String> presentFromAny(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      final s = e?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (s.isEmpty) continue;
      final key = s.toLowerCase();
      if (seen.add(key)) out.add(s);
    }
    return out;
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
      travel: TravelMove.fromAny(data?['travel'] ?? json['travel']),
      fateThread: (data?['fate_thread'] ?? json['fate_thread'])?.toString(),
      presentCharacters: GameEvent.presentFromAny(
        data?['present_characters'] ?? json['present_characters'],
      ),
      trackableMentions: TrackableMention.listFromAny(
        data?['trackable_mentions'] ?? json['trackable_mentions'],
      ),
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

class TravelMove {
  final String? from;
  final String? to;

  const TravelMove({this.from, this.to});

  bool get hasRoute =>
      (from != null && from!.trim().isNotEmpty) ||
      (to != null && to!.trim().isNotEmpty);

  String get label {
    final f = from?.trim();
    final t = to?.trim();
    if (f != null && f.isNotEmpty && t != null && t.isNotEmpty) {
      return 'Traveled from $f to $t';
    }
    if (t != null && t.isNotEmpty) return 'Traveled to $t';
    if (f != null && f.isNotEmpty) return 'Departed $f';
    return 'Traveled';
  }

  static TravelMove? fromAny(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final move = TravelMove(
      from: map['from']?.toString(),
      to: map['to']?.toString(),
    );
    return move.hasRoute ? move : null;
  }
}

class ReplayVariant {
  final String id;
  final String narrative;
  final String modelUsed;
  final DateTime? createdAt;

  /// Tap-to-play chips + scene presence derived from THIS variant's prose, so
  /// browsing to a variant shows its own choices without a round-trip.
  final List<Choice> choices;
  final List<String> presentCharacters;

  const ReplayVariant({
    required this.id,
    required this.narrative,
    this.modelUsed = '',
    this.createdAt,
    this.choices = const [],
    this.presentCharacters = const [],
  });

  factory ReplayVariant.fromJson(Map<String, dynamic> json) {
    return ReplayVariant(
      id: (json['id'] ?? '').toString(),
      narrative: (json['narrative'] ?? '').toString(),
      modelUsed: (json['model_used'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      choices: Choice.listFromAny(json['choices']),
      presentCharacters: GameEvent.presentFromAny(json['present_characters']),
    );
  }
}
