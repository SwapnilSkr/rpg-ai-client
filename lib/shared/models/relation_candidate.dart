class RelationCandidate {
  final String id;
  final String characterName;
  final String relation;
  final String evidence;

  const RelationCandidate({
    required this.id,
    required this.characterName,
    required this.relation,
    required this.evidence,
  });

  factory RelationCandidate.fromJson(Map<String, dynamic> json) =>
      RelationCandidate(
        id: (json['id'] ?? '').toString(),
        characterName: (json['character_name'] ?? '').toString(),
        relation: (json['relation'] ?? '').toString(),
        evidence: (json['evidence'] ?? '').toString(),
      );
}
