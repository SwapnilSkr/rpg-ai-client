import '../../models/keepsake_item.dart';

// Shared wording and routing for a Keepsake, so the feed, grid and viewer
// describe the same piece the same way.

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

String formatDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '';
  final seconds = (durationMs / 1000).round();
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// A piece whose world was deleted still shows, under a title that says so.
String keepsakeWorldTitle(KeepsakeWorld? world) {
  if (world == null) return 'A story no longer here';
  return world.title.isNotEmpty ? world.title : 'A story';
}

/// The play route that lands on the turn this piece came from, or null when
/// the piece has no save to return to.
String? keepsakeMomentRoute(KeepsakeItem item) {
  final instanceId = item.instanceId;
  if (instanceId == null || instanceId.isEmpty) return null;

  final eventId = item.eventId;
  return (eventId != null && eventId.isNotEmpty)
      ? '/play/$instanceId?event=$eventId'
      : '/play/$instanceId';
}
