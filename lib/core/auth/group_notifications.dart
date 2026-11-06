import '../network/api_client.dart';
import 'auth_service.dart';

/// The account's switch for messages from its stories (`group_notifications`).
/// Only an explicit `false` turns it off; an account that never set it reads
/// as on. The user model does not carry the key, so it is read straight from
/// the account's preferences.
class GroupNotificationsPref {
  const GroupNotificationsPref({
    Future<Map<String, dynamic>> Function()? fetchAccount,
    Future<void> Function(bool on)? store,
  }) : _fetchAccount = fetchAccount,
       _store = store;

  final Future<Map<String, dynamic>> Function()? _fetchAccount;
  final Future<void> Function(bool on)? _store;

  Future<bool> read() async {
    final account = await (_fetchAccount ?? _fetch)();
    final prefs = account['preferences'];
    return !(prefs is Map && prefs['group_notifications'] == false);
  }

  Future<void> write(bool on) async {
    final store = _store;
    if (store != null) return store(on);
    await AuthService.updatePreferences({'group_notifications': on});
  }

  static Future<Map<String, dynamic>> _fetch() async {
    final response = await ApiClient.get('/auth/me');
    return response is Map<String, dynamic> ? response : const {};
  }
}
