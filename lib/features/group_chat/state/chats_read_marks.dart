import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identity of one conversation on the Chats tab: a group's room, or one
/// direct thread inside it. The same key names the row in `ChatsState`.
String chatKey(String instanceId, [String? memberId]) =>
    memberId == null || memberId.isEmpty ? instanceId : '$instanceId|$memberId';

/// When each conversation was last opened on this device. The server keeps no
/// read state, so "unread" is a line newer than this mark.
///
/// Stored in secure storage like the app's other small stores (there is no
/// preferences plugin in this app). One JSON map holds every mark. Every read
/// and write is trapped: a storage failure means "no marks" and never breaks
/// the list.
class ChatsReadMarks {
  static const String _storageKey = 'chats_read_marks';

  final FlutterSecureStorage _storage;

  const ChatsReadMarks([this._storage = const FlutterSecureStorage()]);

  Future<Map<String, DateTime>> read() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is int)
            e.key.toString(): DateTime.fromMillisecondsSinceEpoch(
              e.value as int,
              isUtc: true,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, DateTime> marks) async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode({
          for (final e in marks.entries) e.key: e.value.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // The mark lives on in memory for this session; losing it only means an
      // already-seen line may show as unread next launch.
    }
  }
}
