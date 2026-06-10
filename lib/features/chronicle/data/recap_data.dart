import 'package:equatable/equatable.dart';
import 'relationship_ledger.dart' show RelationshipMeters;

/// Client mirror of `memoryService.buildRecap` (Phase 10 memory-aware recap).
/// A "story so far" card for re-entering a world after time away.

class RecapThread extends Equatable {
  final String id;
  final String text;
  final int importance;

  const RecapThread({required this.id, required this.text, required this.importance});

  factory RecapThread.fromJson(Map<String, dynamic> json) => RecapThread(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        importance: (json['importance'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, text, importance];
}

class RecapBond extends Equatable {
  final String id;
  final String name;
  final String? disposition;
  final RelationshipMeters? meters;

  const RecapBond({
    required this.id,
    required this.name,
    this.disposition,
    this.meters,
  });

  factory RecapBond.fromJson(Map<String, dynamic> json) => RecapBond(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Someone',
        disposition: json['disposition'] as String?,
        meters: json['meters'] != null
            ? RelationshipMeters.fromJson(Map<String, dynamic>.from(json['meters']))
            : null,
      );

  @override
  List<Object?> get props => [id, name, disposition, meters];
}

class RecapData extends Equatable {
  final String? spine;
  final String? where;
  final String? when;
  final List<RecapThread> openThreads;
  final List<RecapBond> bonds;

  const RecapData({
    this.spine,
    this.where,
    this.when,
    this.openThreads = const [],
    this.bonds = const [],
  });

  bool get isEmpty =>
      (spine == null || spine!.trim().isEmpty) &&
      openThreads.isEmpty &&
      bonds.isEmpty &&
      where == null &&
      when == null;

  factory RecapData.fromJson(Map<String, dynamic> json) => RecapData(
        spine: json['spine'] as String?,
        where: json['where'] as String?,
        when: json['when'] as String?,
        openThreads: (json['open_threads'] as List?)
                ?.map((t) => RecapThread.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            const [],
        bonds: (json['bonds'] as List?)
                ?.map((b) => RecapBond.fromJson(Map<String, dynamic>.from(b)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [spine, where, when, openThreads, bonds];
}
