import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../guest/guest_session.dart';
import '../network/ws_manager.dart';
import '../push/push_service.dart';
import '../guide/guide_controller.dart';
import '../onboarding/interests_store.dart';
import '../reminders/reminder_service.dart';
import '../storage/secure_storage.dart';
import '../../shared/models/user.dart';
import '../../features/moderation/data/moderation_repository.dart';

class AuthService {
  static final WsManager _wsManager = WsManager();

  /// Bumped on sign-in and sign-out so shell tabs (e.g. Discover) refetch feeds.
  static final ValueNotifier<int> sessionEpoch = ValueNotifier(0);

  static void _bumpSessionEpoch() => sessionEpoch.value++;

  static final StreamController<void> _signedOut =
      StreamController<void>.broadcast();

  /// Fires once per sign-out, after the local session is gone. Holders of
  /// per-account state in memory (the chats list) drop it here.
  static Stream<void> get onSignedOut => _signedOut.stream;

  /// Whether the last sign-in created the account. The server adds
  /// `new_account: true` to the response only when it did.
  static bool _lastSignInCreatedAccount = false;

  /// Reads the flag once for the sign-in that just finished, so a later
  /// sign-in cannot inherit it.
  static bool takeNewAccountFlag() {
    final value = _lastSignInCreatedAccount;
    _lastSignInCreatedAccount = false;
    return value;
  }

  @visibleForTesting
  static bool newAccountFrom(Map<String, dynamic> response) =>
      response['new_account'] == true;

  /// Stores a session the server just issued. [GuestSession] uses this for a
  /// guest it starts; a sign-in goes through the private path below.
  static Future<void> persistSession(Map<String, dynamic> response) =>
      _persistSession(response);

  static Future<void> _persistSession(Map<String, dynamic> response) async {
    _lastSignInCreatedAccount = newAccountFrom(response);
    await SecureStore.saveToken(response['token']);
    await SecureStore.saveUserData(jsonEncode(response['user']));
    await _wsManager.connect(response['token']);
    final user = User.fromJson(response['user']);
    // A claim or merge answers with a user that is no longer a guest, which is
    // what ends the guest state. Reminders and guide state are not touched:
    // only a sign-out clears those.
    GuestSession.instance.noteUser(user);
    await InterestsStore.syncFromUser(user);
    await _hydrateGuide(user);
    _bumpSessionEpoch();
    // This phone now belongs to the signed-in player. Not awaited: sign-in
    // never waits on it, and it skips a guest on its own.
    unawaited(PushService.instance.onSessionStarted());
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
    // Carries the guest along when there is one: the server claims or merges
    // everything they did. Their work may still be settling, so Google retries.
    final response = await GuestSession.instance.exchange('/auth/google', {
      'id_token': idToken,
    }, retryTransfer: true);

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
    // No retry here: a code can only be used once, so on a pending transfer
    // the player is told and asks for a fresh one.
    final response = await GuestSession.instance.exchange('/auth/otp/verify', {
      'phone': phone,
      'code': code,
    });

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

  /// Update user preferences and refresh the locally cached user snapshot.
  static Future<User> updatePreferences(Map<String, dynamic> updates) async {
    if (updates.isEmpty) {
      throw Exception('No preference changes supplied.');
    }

    await ApiClient.put('/auth/preferences', body: updates);
    final response = await ApiClient.get('/auth/me');
    final user = User.fromJson(response);
    await SecureStore.saveUserData(jsonEncode(user.toJson()));
    GuestSession.instance.noteUser(user);
    await InterestsStore.syncFromUser(user);
    await _hydrateGuide(user);
    return user;
  }

  static Future<User> setNsfwEnabled(bool enabled) {
    return updatePreferences({'nsfw_enabled': enabled});
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

  /// Live profile from `/auth/me` (DB tier), with local cache kept in sync.
  /// Falls back to [getCachedUser] if the network call fails.
  static Future<User?> resolveSessionUser() async {
    final fresh = await getCurrentUser();
    if (fresh != null) {
      await SecureStore.saveUserData(jsonEncode(fresh.toJson()));
      GuestSession.instance.noteUser(fresh);
      await InterestsStore.syncFromUser(fresh);
      await _hydrateGuide(fresh);
      return fresh;
    }
    return getCachedUser();
  }

  static bool canAccessForge(User? user) {
    if (user == null) return false;
    return user.canAccessForge;
  }

  /// Permanently deletes the signed-in account and all associated server data.
  static Future<void> deleteAccount() async {
    await ApiClient.delete('/auth/account');
    await logout();
  }

  /// Ends the local session. For a guest that is all it does: nothing is sent,
  /// and the server drops an abandoned guest after 30 days.
  static Future<void> logout() async {
    // First, while the session token still authorises it: the server stops
    // sending character messages to this phone. Bounded, never throws.
    await PushService.instance.onSigningOut();
    GuestSession.instance.clear();
    await _wsManager.disconnect(clearToken: true);
    // Pending reminders would otherwise fire into the next player's session.
    await ReminderService.instance.clear();
    await SecureStore.clearAll();
    // Device guide state goes with the session; the account keeps its record,
    // so signing back in restores it rather than re-touring.
    await guide.onSignedOut();
    // Blocks are per-account. Leaving the previous player's list in memory
    // would hide worlds from whoever signs in next.
    ModerationRepository.clearLocalBlocks();
    _bumpSessionEpoch();
    _signedOut.add(null);
  }

  /// Fold the account's guide record into the device cache. Union semantics —
  /// a second device inherits everything already seen.
  static Future<void> _hydrateGuide(User user) async {
    await guide.hydrateFromAccount(
      user.preferences.guideProgress,
      remoteOptOut: user.preferences.guideOptOut,
    );
  }

  static Future<bool> isLoggedIn() async {
    return (await SecureStore.getToken()) != null;
  }
}
