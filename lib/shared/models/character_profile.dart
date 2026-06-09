/// Structured relationship meters toward the player (0-100), server-clamped.
class RelationshipMeters {
  final int trust;
  final int affection;
  final int fear;
  final int rivalry;

  const RelationshipMeters({
    this.trust = 50,
    this.affection = 50,
    this.fear = 0,
    this.rivalry = 0,
  });

  factory RelationshipMeters.fromJson(Map<String, dynamic> json) {
    int meter(String key, int fallback) =>
        ((json[key] as num?)?.toInt() ?? fallback).clamp(0, 100);
    return RelationshipMeters(
      trust: meter('trust', 50),
      affection: meter('affection', 50),
      fear: meter('fear', 0),
      rivalry: meter('rivalry', 0),
    );
  }
}

class CharacterProfile {
  final String id;
  final String canonicalName;
  final List<String> aliases;
  final String role;
  final String appearance;
  final String persona;
  final List<String> immutableFacts;
  final List<String> mutableState;
  final String dispositionToPlayer;
  final String hiddenThought;
  final int mentionCount;
  final bool isProtagonist;

  /// Present once the story has moved this character's meters at least once.
  final RelationshipMeters? relationship;

  const CharacterProfile({
    required this.id,
    required this.canonicalName,
    this.aliases = const [],
    this.role = '',
    this.appearance = '',
    this.persona = '',
    this.immutableFacts = const [],
    this.mutableState = const [],
    this.dispositionToPlayer = '',
    this.hiddenThought = '',
    this.mentionCount = 0,
    this.isProtagonist = false,
    this.relationship,
  });

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    return CharacterProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      canonicalName: (json['canonical_name'] ?? '').toString(),
      aliases: (json['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      role: (json['role'] ?? '').toString(),
      appearance: (json['appearance'] ?? '').toString(),
      persona: (json['persona'] ?? '').toString(),
      immutableFacts:
          (json['immutable_facts'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      mutableState:
          (json['mutable_state'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dispositionToPlayer: (json['disposition_to_player'] ?? '').toString(),
      hiddenThought: (json['hidden_thought'] ?? '').toString(),
      mentionCount: (json['mention_count'] as num?)?.toInt() ?? 0,
      isProtagonist: json['is_protagonist'] == true,
      relationship: json['relationship'] is Map
          ? RelationshipMeters.fromJson(
              Map<String, dynamic>.from(json['relationship'] as Map),
            )
          : null,
    );
  }
}
