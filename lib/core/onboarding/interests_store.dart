import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/models/user.dart';

/// Local cache for post-auth onboarding progress and genre interests.
///
/// Flow: name (required) → gender (skippable) → interests (skippable).
/// Genre keys drive discovery ranking and mirror to the server via
/// `AuthService.updatePreferences`. Logout clears this store; returning users
/// re-hydrate from `user.preferences` on sign-in (see `syncFromUser`).
class InterestsStore {
  static const _storage = FlutterSecureStorage();
  static const _interestsKey = 'user_interests';
  static const _onboardedKey = 'onboarding_done';
  static const _genderStepKey = 'onboarding_gender_done';

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

  /// Whether interests onboarding has been completed OR skipped on this device.
  static Future<bool> isOnboarded() async {
    return (await _storage.read(key: _onboardedKey)) == 'true';
  }

  /// Mark interests step finished (completed or skipped).
  static Future<void> markOnboarded() async {
    await _storage.write(key: _onboardedKey, value: 'true');
  }

  static Future<bool> isGenderStepDone() async {
    return (await _storage.read(key: _genderStepKey)) == 'true';
  }

  static Future<void> markGenderStepDone() async {
    await _storage.write(key: _genderStepKey, value: 'true');
  }

  /// Restore local state from the account after logout wiped device storage.
  static Future<void> syncFromUser(User user) async {
    final interests = user.preferences.interests;
    if (interests.isNotEmpty) {
      await saveInterests(interests);
      await markOnboarded();
    }
    if (user.preferences.gender != null) {
      await markGenderStepDone();
    }
  }

  /// Whether to skip the full onboarding flow (name + gender + interests done).
  static Future<bool> hasCompletedOnboarding({User? user}) async {
    if (user != null) await syncFromUser(user);

    final name = user?.preferences.playerName ?? '';
    if (name.trim().length < 2) return false;
    if (!await isGenderStepDone()) return false;
    return await isOnboarded();
  }

  /// Resume step for the multi-step onboarding screen (0 = name, 1 = gender, 2 = interests).
  static Future<int> resolveStartStep({User? user}) async {
    if (user != null) await syncFromUser(user);
    final name = user?.preferences.playerName ?? '';
    if (name.trim().length < 2) return 0;
    if (!await isGenderStepDone()) return 1;
    return 2;
  }
}
