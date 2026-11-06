import 'package:equatable/equatable.dart';

/// The kinds the app knows how to open. Anything else the server sends later
/// stays in the list and is only marked read when tapped.
enum NotificationKind {
  groupDirect('group_direct'),
  groupSelfie('group_selfie'),
  filmReady('film_ready'),
  storyReply('story_reply');

  const NotificationKind(this.wire);
  final String wire;

  static NotificationKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// One row of the player's notifications, as `GET /notifications` and the
/// live `notification` frame carry it.
class AppNotification extends Equatable {
  final String id;

  /// The raw type; [kind] is null for one this build does not know.
  final String type;
  final String instanceId;
  final String? characterId;

  /// `room` or `direct`, for group saves.
  final String? thread;
  final String? mediaId;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.instanceId,
    this.characterId,
    this.thread,
    this.mediaId,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    this.readAt,
  });

  NotificationKind? get kind => NotificationKind.fromWire(type);
  bool get isUnread => readAt == null;

  AppNotification asRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    instanceId: instanceId,
    characterId: characterId,
    thread: thread,
    mediaId: mediaId,
    title: title,
    body: body,
    imageUrl: imageUrl,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );

  AppNotification asUnread() => AppNotification(
    id: id,
    type: type,
    instanceId: instanceId,
    characterId: characterId,
    thread: thread,
    mediaId: mediaId,
    title: title,
    body: body,
    imageUrl: imageUrl,
    createdAt: createdAt,
  );

  /// Null when the row cannot be shown at all (no id, no time). Optional keys
  /// that are absent, empty or not text read as unset.
  static AppNotification? parse(Object? raw) {
    if (raw is! Map) return null;
    String? text(String key) {
      final v = raw[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final id = text('id');
    final type = text('type');
    final created = DateTime.tryParse(text('created_at') ?? '');
    if (id == null || type == null || created == null) return null;
    return AppNotification(
      id: id,
      type: type,
      instanceId: text('instance_id') ?? '',
      characterId: text('character_id'),
      thread: text('thread'),
      mediaId: text('media_id'),
      title: text('title') ?? '',
      body: text('body') ?? '',
      imageUrl: text('image_url'),
      createdAt: created,
      readAt: DateTime.tryParse(text('read_at') ?? ''),
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    instanceId,
    characterId,
    thread,
    mediaId,
    title,
    body,
    imageUrl,
    createdAt,
    readAt,
  ];
}

/// One page of `GET /notifications`.
class NotificationsPage {
  final List<AppNotification> items;
  final int unread;

  /// The server's page size is 30; fewer than that means the end.
  final bool hasMore;

  const NotificationsPage({
    required this.items,
    required this.unread,
    required this.hasMore,
  });
}
