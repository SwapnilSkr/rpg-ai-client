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
    );
  }
}
