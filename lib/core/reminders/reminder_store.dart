import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'reminder_record.dart';

/// Device persistence for [ReminderRecord], in the same secure store the rest
/// of the app's small records use.
class ReminderStore {
  const ReminderStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'reminders_record';

  Future<ReminderRecord> load() async {
    try {
      return ReminderRecord.decode(await _storage.read(key: _key));
    } catch (_) {
      return ReminderRecord.empty;
    }
  }

  Future<void> save(ReminderRecord record) async {
    try {
      await _storage.write(key: _key, value: record.encode());
    } catch (_) {
      // Reminders are a convenience; a keychain hiccup must not surface.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
