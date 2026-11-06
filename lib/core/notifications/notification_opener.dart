import 'package:flutter/widgets.dart';

import '../../app_routes.dart';
import '../../features/keepsakes/data/keepsakes_repository.dart';
import '../../features/keepsakes/models/keepsake_item.dart';
import '../../features/keepsakes/presentation/widgets/keepsakes_viewer_screen.dart';
import '../../features/notifications/models/app_notification.dart';
import '../../shared/widgets/everlore_notice.dart';
import '../network/api_client.dart';
import 'on_screen.dart';

/// What a tap carries, whether it came from a row, a banner or a system
/// message. Optional parts are absent rather than empty.
@immutable
class NotificationTap {
  final String type;
  final String instanceId;
  final String? characterId;
  final String? thread;
  final String? mediaId;

  const NotificationTap({
    required this.type,
    required this.instanceId,
    this.characterId,
    this.thread,
    this.mediaId,
  });

  factory NotificationTap.fromItem(AppNotification n) => NotificationTap(
    type: n.type,
    instanceId: n.instanceId,
    characterId: n.characterId,
    thread: n.thread,
    mediaId: n.mediaId,
  );

  /// A system message's data, or null when it names nothing the app opens.
  /// The ids are checked here because the data is whatever the sender put in
  /// it.
  static NotificationTap? fromPush(Map<String, Object?> data) {
    String? text(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final type = text('type');
    final kind = NotificationKind.fromWire(type);
    final instanceId = text('instanceId');
    if (kind == null || instanceId == null) return null;
    final tap = NotificationTap(
      type: type!,
      instanceId: instanceId,
      characterId: text('characterId'),
      thread: text('thread'),
      mediaId: text('mediaId'),
    );
    if (kind == NotificationKind.groupDirect && tap.characterId == null) {
      return null;
    }
    if (kind == NotificationKind.filmReady && tap.mediaId == null) return null;
    return tap;
  }

  /// The place this opens, or null for a film (opened in the viewer) and for
  /// a type this build does not know.
  Place? get place {
    if (instanceId.isEmpty) return null;
    final id = characterId;
    switch (NotificationKind.fromWire(type)) {
      case NotificationKind.groupDirect:
        return id == null
            ? Place.room(instanceId)
            : Place.direct(instanceId, id);
      case NotificationKind.groupSelfie:
        return thread == 'direct' && id != null
            ? Place.direct(instanceId, id)
            : Place.room(instanceId);
      case NotificationKind.storyReply:
        if (thread == 'room') return Place.room(instanceId);
        if (thread == 'direct') {
          return id == null
              ? Place.room(instanceId)
              : Place.direct(instanceId, id);
        }
        return Place.play(instanceId);
      case NotificationKind.filmReady:
      case null:
        return null;
    }
  }

  bool get opensFilm =>
      NotificationKind.fromWire(type) == NotificationKind.filmReady &&
      mediaId != null;
}

/// Router location for a place.
String locationOf(Place place) {
  final id = Uri.encodeComponent(place.instanceId);
  return switch (place.kind) {
    PlaceKind.room => '/group/$id',
    PlaceKind.direct =>
      '/group/$id?member=${Uri.encodeQueryComponent(place.characterId!)}',
    PlaceKind.play => '/play/$id',
  };
}

enum OpenResult {
  /// Went to the place or the film.
  opened,

  /// Nothing to open (a type this build does not know).
  nothing,

  /// The save or the film is no longer there; the player was told.
  gone,
}

/// The one function behind every tap: a row, a banner and a system message
/// all end here, so they all land in the same place.
class NotificationOpener {
  NotificationOpener({
    Future<bool> Function(String instanceId)? saveExists,
    void Function(String location)? push,
    Future<bool> Function(String mediaId)? openFilm,
    void Function(String message)? notice,
    this.onGone,
  }) : _saveExists = saveExists ?? _remoteSaveExists,
       _push = push ?? _routerPush,
       _openFilm = openFilm ?? _viewFilm,
       _notice = notice ?? _showNotice;

  /// The app's own opener.
  static final NotificationOpener instance = NotificationOpener();

  final Future<bool> Function(String instanceId) _saveExists;
  final void Function(String location) _push;
  final Future<bool> Function(String mediaId) _openFilm;
  final void Function(String message) _notice;

  /// Told when a save is gone, so a screen that holds rows for it can drop
  /// them. Set by the app wiring; a tap from a row also gets [OpenResult.gone].
  void Function(String instanceId)? onGone;

  Future<OpenResult> open(NotificationTap tap) async {
    if (tap.opensFilm) {
      if (await _openFilm(tap.mediaId!)) return OpenResult.opened;
      _notice('That film is no longer there.');
      return OpenResult.gone;
    }
    final place = tap.place;
    if (place == null) return OpenResult.nothing;
    if (!await _saveExists(tap.instanceId)) {
      _notice('That story is no longer there.');
      onGone?.call(tap.instanceId);
      return OpenResult.gone;
    }
    _push(locationOf(place));
    return OpenResult.opened;
  }

  // ── defaults ────────────────────────────────────────────────────────────

  /// A deleted save falls through; a network failure does not (the screen it
  /// opens has its own offline handling).
  static Future<bool> _remoteSaveExists(String instanceId) async {
    try {
      await ApiClient.get('/instances/${Uri.encodeComponent(instanceId)}');
      return true;
    } on ApiException catch (e) {
      return !(e.statusCode == 404 || e.statusCode == 403);
    } catch (_) {
      return true;
    }
  }

  static void _routerPush(String location) => router.push(location);

  static void _showNotice(String message) {
    final context = rootOverlayContext;
    if (context != null) showEverloreNotice(context, message);
  }

  /// Finds the film among the player's films, newest first, and plays it in
  /// the same viewer Keepsakes uses. False when it is not there (hidden or
  /// gone). A network failure reads the same: the player is told and can
  /// try again from the list.
  static Future<bool> _viewFilm(String mediaId) async {
    final context = rootOverlayContext;
    if (context == null) return false;
    try {
      final repo = HttpKeepsakesRepository();
      String? before;
      for (var pages = 0; pages < 5; pages++) {
        final page = await repo.getKeepsakes(
          filter: KeepsakesFilter.films,
          before: before,
          limit: 40,
        );
        for (final item in page.items) {
          if (item.mediaId == mediaId) {
            if (!context.mounted) return false;
            // ignore: unawaited_futures
            KeepsakesViewerScreen.show(context, items: [item]);
            return true;
          }
        }
        if (!page.hasMore) return false;
        before = page.nextBefore;
      }
    } catch (_) {}
    return false;
  }
}
