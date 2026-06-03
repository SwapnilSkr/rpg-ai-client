import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/models/user.dart';

/// Local cache for the player's onboarding interests and onboarding flag.
///
/// Chosen genre keys drive client-side discovery ranking; they are mirrored to
/// the server via `AuthService.updatePreferences({'interests': [...]})`.
/// Logout clears this store with auth; returning users are re-hydrated from
/// `user.preferences.interests` on sign-in (see `syncFromUser`).
///
/// Keys stored are `narrative_style` keys (see `shared/narrative_styles.dart`).
class InterestsStore {
  static const _storage = FlutterSecureStorage();
  static const _interestsKey = 'user_interests';
  static const _onboardedKey = 'onboarding_done';

  /// Saved interest style keys (e.g. `['noir', 'kdrama']`). Empty if unset.
  static Future<List<String>> getInterests() async {
    final raw = await _storage.read(key: _interestsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  static Future<void> saveInterests(List<String> styleKeys) async {
    await _storage.write(key: _interestsKey, value: jsonEncode(styleKeys));
  }

  /// Whether onboarding has been completed OR skipped on this device.
  static Future<bool> isOnboarded() async {
    return (await _storage.read(key: _onboardedKey)) == 'true';
  }

  /// Mark onboarding finished (completed or skipped) so it isn't shown again.
  static Future<void> markOnboarded() async {
    await _storage.write(key: _onboardedKey, value: 'true');
  }

  /// Restore local interests/onboarding from the account after logout wiped
  /// device state. No-op when the server has no saved picks.
  static Future<void> syncFromUser(User user) async {
    final interests = user.preferences.interests;
    if (interests.isEmpty) return;
    await saveInterests(interests);
    await markOnboarded();
  }

  /// Whether to skip the interests onboarding screen (local flag or server picks).
  static Future<bool> hasCompletedOnboarding({User? user}) async {
    if (await isOnboarded()) return true;
    if (user != null) {
      await syncFromUser(user);
      return await isOnboarded();
    }
    return false;
  }
}
