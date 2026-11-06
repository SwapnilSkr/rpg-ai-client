import '../../../core/network/api_client.dart';
import '../models/app_notification.dart';

const notificationsPageSize = 30;

/// The HTTP side of the player's notifications.
abstract class NotificationsRepository {
  /// Newest first. [before] is the id of the last row already held.
  Future<NotificationsPage> page({String? before});

  /// Marks specific rows read (at most 100). Returns the unread count.
  Future<int> markIds(List<String> ids);

  Future<int> markAll();

  /// Marks the row for one film. Returns the unread count.
  Future<int> markMedia(String mediaId);
}

class HttpNotificationsRepository implements NotificationsRepository {
  const HttpNotificationsRepository();

  @override
  Future<NotificationsPage> page({String? before}) async {
    final query = before == null || before.isEmpty
        ? ''
        : '?before=${Uri.encodeQueryComponent(before)}';
    final body = await ApiClient.get('/notifications$query');
    final rows = body is Map ? body['items'] : null;
    final items = [
      if (rows is List)
        for (final row in rows) ?AppNotification.parse(row),
    ];
    return NotificationsPage(
      items: items,
      unread: _count(body),
      // Counted on what the server sent, not on what parsed.
      hasMore: rows is List && rows.length >= notificationsPageSize,
    );
  }

  @override
  Future<int> markIds(List<String> ids) => _mark({'ids': ids});

  @override
  Future<int> markAll() => _mark({'all': true});

  @override
  Future<int> markMedia(String mediaId) => _mark({'media_id': mediaId});

  Future<int> _mark(Map<String, dynamic> body) async =>
      _count(await ApiClient.post('/notifications/read', body: body));

  static int _count(Object? body) {
    final n = body is Map ? body['unread'] : null;
    return n is num && n >= 0 ? n.toInt() : 0;
  }
}
