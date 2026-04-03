import 'dart:convert';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../../shared/models/user.dart';

class AuthService {
  static Future<User> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await ApiClient.post('/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
    });

    await SecureStore.saveToken(response['token']);
    final user = User.fromJson(response['user']);
    await SecureStore.saveUserData(jsonEncode(response['user']));
    return user;
  }

  static Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    await SecureStore.saveToken(response['token']);
    final user = User.fromJson(response['user']);
    await SecureStore.saveUserData(jsonEncode(response['user']));
    return user;
  }

  static Future<User> loginWithGoogle(String idToken) async {
    final response = await ApiClient.post('/auth/google', body: {
      'id_token': idToken,
    });

    await SecureStore.saveToken(response['token']);
    final user = User.fromJson(response['user']);
    await SecureStore.saveUserData(jsonEncode(response['user']));
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
    await SecureStore.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    return (await SecureStore.getToken()) != null;
  }
}
