import 'package:equatable/equatable.dart';
import 'relationship_ledger.dart' show RelationshipMeters;

class SideChatCharacter extends Equatable {
  final String id;
  final String name;
  final String? role;
  final String? appearance;
  final RelationshipMeters? relationship;

  const SideChatCharacter({
    required this.id,
    required this.name,
    this.role,
    this.appearance,
    this.relationship,
  });

  factory SideChatCharacter.fromJson(Map<String, dynamic> json) =>
      SideChatCharacter(
        id: json['id'] as String? ?? '',
        name:
            json['canonical_name'] as String? ??
            json['name'] as String? ??
            'Someone',
        role: json['role'] as String?,
        appearance: json['appearance'] as String?,
        relationship: json['relationship'] is Map
            ? RelationshipMeters.fromJson(
                Map<String, dynamic>.from(json['relationship'] as Map),
              )
            : null,
      );

  @override
  List<Object?> get props => [id, name, role, appearance, relationship];
}

class SideChatTurn extends Equatable {
  final String id;
  final int sequence;
  final String playerInput;
  final String narrative;
  final DateTime? createdAt;
  final bool isStreaming;
  final bool isOptimistic;

  const SideChatTurn({
    required this.id,
    required this.sequence,
    required this.playerInput,
    required this.narrative,
    this.createdAt,
    this.isStreaming = false,
    this.isOptimistic = false,
  });

  factory SideChatTurn.fromJson(Map<String, dynamic> json) => SideChatTurn(
    id: json['id'] as String? ?? '',
    sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    playerInput: json['player_input'] as String? ?? '',
    narrative: json['narrative'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );

  SideChatTurn copyWith({
    String? id,
    int? sequence,
    String? playerInput,
    String? narrative,
    DateTime? createdAt,
    bool? isStreaming,
    bool? isOptimistic,
  }) => SideChatTurn(
    id: id ?? this.id,
    sequence: sequence ?? this.sequence,
    playerInput: playerInput ?? this.playerInput,
    narrative: narrative ?? this.narrative,
    createdAt: createdAt ?? this.createdAt,
    isStreaming: isStreaming ?? this.isStreaming,
    isOptimistic: isOptimistic ?? this.isOptimistic,
  );

  @override
  List<Object?> get props => [
    id,
    sequence,
    playerInput,
    narrative,
    createdAt,
    isStreaming,
    isOptimistic,
  ];
}

class SideChatThread extends Equatable {
  final SideChatCharacter? character;
  final List<SideChatTurn> events;
  final int total;
  final int page;

  const SideChatThread({
    this.character,
    this.events = const [],
    this.total = 0,
    this.page = 1,
  });

  factory SideChatThread.fromJson(Map<String, dynamic> json) => SideChatThread(
    character: json['character'] is Map
        ? SideChatCharacter.fromJson(
            Map<String, dynamic>.from(json['character'] as Map),
          )
        : null,
    events:
        (json['events'] as List?)
            ?.map((e) => SideChatTurn.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
  );

  @override
  List<Object?> get props => [character, events, total, page];
}
