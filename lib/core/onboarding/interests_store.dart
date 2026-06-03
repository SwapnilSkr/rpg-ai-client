import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local (device-only) persistence for the player's onboarding interests.
///
/// Phase 1 of the interests → discovery feature: the chosen genre keys live
/// on-device and drive client-side world ranking. Phase 2 mirrors them to the
/// server via `AuthService.updatePreferences({'interests': [...]})`.
///
/// Keys stored are `narrative_style` keys (see `shared/narrative_styles.dart`).
/// Shares the same underlying secure store as auth, so `SecureStore.clearAll()`
/// on logout also resets onboarding — intended.
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
}
