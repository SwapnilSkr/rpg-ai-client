class RelationCandidate {
  final String id;
  final String kind;
  final String characterName;
  final String? counterpartCharacterName;
  final String? proposedName;
  final String? replacesRelation;
  final String relation;
  final String evidence;

  const RelationCandidate({
    required this.id,
    this.kind = 'kinship',
    required this.characterName,
    this.counterpartCharacterName,
    this.proposedName,
    this.replacesRelation,
    required this.relation,
    required this.evidence,
  });

  factory RelationCandidate.fromJson(Map<String, dynamic> json) =>
      RelationCandidate(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? 'kinship').toString(),
        characterName: (json['character_name'] ?? '').toString(),
        counterpartCharacterName: json['counterpart_character_name']
            ?.toString(),
        proposedName: json['proposed_name']?.toString(),
        replacesRelation: json['replaces_relation']?.toString(),
        relation: (json['relation'] ?? '').toString(),
        evidence: (json['evidence'] ?? '').toString(),
      );
}
