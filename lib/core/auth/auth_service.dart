import 'dart:convert';
import '../network/api_client.dart';
import '../network/ws_manager.dart';
import '../storage/secure_storage.dart';
import '../../shared/models/user.dart';

class AuthService {
  static final WsManager _wsManager = WsManager();

  static Future<void> _persistSession(Map<String, dynamic> response) async {
    await SecureStore.saveToken(response['token']);
    await SecureStore.saveUserData(jsonEncode(response['user']));
    await _wsManager.connect(response['token']);
  }

  static Future<User> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await ApiClient.post(
      '/auth/register',
      body: {'email': email, 'username': username, 'password': password},
    );

    await _persistSession(response);
    final user = User.fromJson(response['user']);
    return user;
  }

  static Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    await _persistSession(response);
    final user = User.fromJson(response['user']);
    return user;
  }

  static Future<User> loginWithGoogle(String idToken) async {
    final response = await ApiClient.post(
      '/auth/google',
      body: {'id_token': idToken},
    );

    await _persistSession(response);
    final user = User.fromJson(response['user']);
    return user;
  }

  static Future<bool> sendOtp(String phone) async {
    final response = await ApiClient.post(
      '/auth/otp/send',
      body: {'phone': phone},
    );
    return response['success'] == true;
  }

  static Future<User> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await ApiClient.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
    );

    await _persistSession(response);
    final user = User.fromJson(response['user']);
    return user;
  }

  static Future<User?> getCurrentUser() async {
    try {
      final token = await SecureStore.getToken();
      if (token == null) return null;

      final response = await ApiClient.get('/auth/me');
      return User.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  static Future<User?> getCachedUser() async {
    final data = await SecureStore.getUserData();
    if (data == null) return null;
    try {
      return User.fromJson(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    await _wsManager.disconnect();
    await SecureStore.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    return (await SecureStore.getToken()) != null;
  }
}
