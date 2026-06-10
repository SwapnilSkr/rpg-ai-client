import 'package:equatable/equatable.dart';

/// Client mirror of `characterCodexService.listRelationships` (Phase 10
/// Relationship Ledger surface). Meters are 0-100 toward the player.

class RelationshipMeters extends Equatable {
  final int trust;
  final int affection;
  final int fear;
  final int rivalry;

  const RelationshipMeters({
    required this.trust,
    required this.affection,
    required this.fear,
    required this.rivalry,
  });

  factory RelationshipMeters.fromJson(Map<String, dynamic> json) =>
      RelationshipMeters(
        trust: (json['trust'] as num?)?.toInt() ?? 0,
        affection: (json['affection'] as num?)?.toInt() ?? 0,
        fear: (json['fear'] as num?)?.toInt() ?? 0,
        rivalry: (json['rivalry'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [trust, affection, fear, rivalry];
}

class BondMoment extends Equatable {
  final String label;
  final int sequence;

  const BondMoment({required this.label, required this.sequence});

  factory BondMoment.fromJson(Map<String, dynamic> json) => BondMoment(
        label: json['label'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [label, sequence];
}

class RelationshipEntry extends Equatable {
  final String id;
  final String name;
  final String? role;
  final String? disposition;
  final RelationshipMeters? meters;
  final int mentionCount;
  final List<BondMoment> moments;

  const RelationshipEntry({
    required this.id,
    required this.name,
    this.role,
    this.disposition,
    this.meters,
    this.mentionCount = 0,
    this.moments = const [],
  });

  factory RelationshipEntry.fromJson(Map<String, dynamic> json) =>
      RelationshipEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Someone',
        role: json['role'] as String?,
        disposition: json['disposition'] as String?,
        meters: json['meters'] != null
            ? RelationshipMeters.fromJson(Map<String, dynamic>.from(json['meters']))
            : null,
        mentionCount: (json['mention_count'] as num?)?.toInt() ?? 0,
        moments: (json['moments'] as List?)
                ?.map((m) => BondMoment.fromJson(Map<String, dynamic>.from(m)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props =>
      [id, name, role, disposition, meters, mentionCount, moments];
}

class RelationshipLedger extends Equatable {
  final List<RelationshipEntry> characters;

  const RelationshipLedger({this.characters = const []});

  factory RelationshipLedger.fromJson(Map<String, dynamic> json) =>
      RelationshipLedger(
        characters: (json['characters'] as List?)
                ?.map((c) =>
                    RelationshipEntry.fromJson(Map<String, dynamic>.from(c)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [characters];
}
