import 'package:flutter/foundation.dart';

/// Where a notification points. The same shape serves two jobs: deciding
/// what a tap opens, and deciding whether the player is already looking at it.
enum PlaceKind { room, direct, play }

@immutable
class Place {
  final PlaceKind kind;
  final String instanceId;

  /// Only for [PlaceKind.direct].
  final String? characterId;

  const Place.room(this.instanceId) : kind = PlaceKind.room, characterId = null;
  const Place.direct(this.instanceId, String this.characterId)
    : kind = PlaceKind.direct;
  const Place.play(this.instanceId) : kind = PlaceKind.play, characterId = null;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.kind == kind &&
      other.instanceId == instanceId &&
      other.characterId == characterId;

  @override
  int get hashCode => Object.hash(kind, instanceId, characterId);
}

/// The place the player is looking at right now, kept by the screens that
/// show one. A screen opened on top of another (a direct thread over its
/// room) is the one on screen until it goes; the one beneath is not visible.
class OnScreen {
  OnScreen();

  static final OnScreen instance = OnScreen();

  final List<(Object, Place)> _stack = [];

  /// Called in a screen's initState. [owner] is the State itself.
  void enter(Object owner, Place place) {
    _stack.removeWhere((e) => identical(e.$1, owner));
    _stack.add((owner, place));
  }

  /// Called in the same screen's dispose.
  void leave(Object owner) => _stack.removeWhere((e) => identical(e.$1, owner));

  Place? get current => _stack.isEmpty ? null : _stack.last.$2;

  bool isShowing(Place? place) => place != null && current == place;

  @visibleForTesting
  void clear() => _stack.clear();
}
