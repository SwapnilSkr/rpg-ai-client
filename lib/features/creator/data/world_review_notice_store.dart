import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and checks whether a review notice (changes_requested or approved)
/// has already been displayed to the creator for a given world review state.
class WorldReviewNoticeStore {
  final FlutterSecureStorage _storage;

  const WorldReviewNoticeStore([this._storage = const FlutterSecureStorage()]);

  static String storageKey(String worldId, String reviewState) =>
      'world_review_notice_${worldId}_$reviewState';

  Future<bool> hasSeenNotice(String worldId, String reviewState) async {
    try {
      final value = await _storage.read(key: storageKey(worldId, reviewState));
      return value != null && value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> markNoticeSeen(String worldId, String reviewState) async {
    try {
      await _storage.write(
        key: storageKey(worldId, reviewState),
        value: 'seen',
      );
    } catch (_) {}
  }
}
