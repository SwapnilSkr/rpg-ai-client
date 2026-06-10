import 'package:equatable/equatable.dart';
import 'calendar_data.dart' show TimeAnchor;

/// Client mirror of `locationService` (Phase 10 Location Journal surface).

class LocationPlace extends Equatable {
  final String entityId;
  final String name;
  final int eventCount;
  final int memoryCount;
  final int? firstSeenSequence;
  final int? lastSeenSequence;

  const LocationPlace({
    required this.entityId,
    required this.name,
    this.eventCount = 0,
    this.memoryCount = 0,
    this.firstSeenSequence,
    this.lastSeenSequence,
  });

  factory LocationPlace.fromJson(Map<String, dynamic> json) => LocationPlace(
        entityId: json['entity_id'] as String? ?? '',
        name: json['name'] as String? ?? 'An unnamed place',
        eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
        memoryCount: (json['memory_count'] as num?)?.toInt() ?? 0,
        firstSeenSequence: (json['first_seen_sequence'] as num?)?.toInt(),
        lastSeenSequence: (json['last_seen_sequence'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props =>
      [entityId, name, eventCount, memoryCount, firstSeenSequence, lastSeenSequence];
}

class LocationCursor extends Equatable {
  final String? entityId;
  final String name;

  const LocationCursor({this.entityId, required this.name});

  factory LocationCursor.fromJson(Map<String, dynamic> json) => LocationCursor(
        entityId: json['entity_id'] as String?,
        name: json['name'] as String? ?? '',
      );

  @override
  List<Object?> get props => [entityId, name];
}

class LocationsData extends Equatable {
  final LocationCursor? currentLocation;
  final List<LocationPlace> places;

  const LocationsData({this.currentLocation, this.places = const []});

  factory LocationsData.fromJson(Map<String, dynamic> json) => LocationsData(
        currentLocation: json['current_location'] != null
            ? LocationCursor.fromJson(
                Map<String, dynamic>.from(json['current_location']))
            : null,
        places: (json['places'] as List?)
                ?.map((p) => LocationPlace.fromJson(Map<String, dynamic>.from(p)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [currentLocation, places];
}

/// One place's recorded history: anchored events + memories.
class LocationEventEntry extends Equatable {
  final String id;
  final int sequence;
  final String type;
  final String? sceneTag;
  final TimeAnchor? anchor;
  final String? milestone;

  const LocationEventEntry({
    required this.id,
    required this.sequence,
    required this.type,
    this.sceneTag,
    this.anchor,
    this.milestone,
  });

  factory LocationEventEntry.fromJson(Map<String, dynamic> json) =>
      LocationEventEntry(
        id: json['id'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'event',
        sceneTag: json['scene_tag'] as String?,
        anchor: json['time_anchor'] != null
            ? TimeAnchor.fromJson(Map<String, dynamic>.from(json['time_anchor']))
            : null,
        milestone: json['milestone'] as String?,
      );

  @override
  List<Object?> get props => [id, sequence, type, sceneTag, milestone];
}

class LocationMemoryEntry extends Equatable {
  final String id;
  final String text;
  final String type;
  final int importance;
  final String? emotionalValence;
  final TimeAnchor? anchor;

  const LocationMemoryEntry({
    required this.id,
    required this.text,
    required this.type,
    required this.importance,
    this.emotionalValence,
    this.anchor,
  });

  factory LocationMemoryEntry.fromJson(Map<String, dynamic> json) =>
      LocationMemoryEntry(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        type: json['type'] as String? ?? 'memory',
        importance: (json['importance'] as num?)?.toInt() ?? 0,
        emotionalValence: json['emotional_valence'] as String?,
        anchor: json['time_anchor'] != null
            ? TimeAnchor.fromJson(Map<String, dynamic>.from(json['time_anchor']))
            : null,
      );

  @override
  List<Object?> get props => [id, text, type, importance, emotionalValence];
}

class LocationJournal extends Equatable {
  final String entityId;
  final String name;

  /// Enduring canon about this place ("built over a buried god").
  final List<String> permanentFacts;

  /// The place's current mutable condition ("the gate now lies in ruins").
  final List<String> currentState;
  final List<LocationEventEntry> events;
  final List<LocationMemoryEntry> memories;

  const LocationJournal({
    required this.entityId,
    required this.name,
    this.permanentFacts = const [],
    this.currentState = const [],
    this.events = const [],
    this.memories = const [],
  });

  factory LocationJournal.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'])
        : <String, dynamic>{};
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return LocationJournal(
      entityId: loc['entity_id'] as String? ?? '',
      name: loc['name'] as String? ?? 'This place',
      permanentFacts: strList(loc['permanent_facts']),
      currentState: strList(loc['current_state']),
      events: (json['events'] as List?)
              ?.map((e) => LocationEventEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      memories: (json['memories'] as List?)
              ?.map((m) =>
                  LocationMemoryEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props =>
      [entityId, name, permanentFacts, currentState, events, memories];
}
