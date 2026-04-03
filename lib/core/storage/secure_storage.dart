import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> saveUserData(String json) async {
    await _storage.write(key: _userKey, value: json);
  }

  static Future<String?> getUserData() async {
    return _storage.read(key: _userKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
