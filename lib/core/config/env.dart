import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    const compiled = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final raw = compiled.isNotEmpty
        ? compiled
        : (dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000');
    return _normalizeLocalhostForAndroid(raw);
  }

  static String get wsBaseUrl {
    const compiled = String.fromEnvironment('WS_BASE_URL', defaultValue: '');
    final raw = compiled.isNotEmpty
        ? compiled
        : (dotenv.env['WS_BASE_URL'] ?? 'ws://localhost:3000');
    return _normalizeLocalhostForAndroid(raw);
  }

  /// Rehearsal mode for the Chronicler's walkthrough.
  ///
  /// Normally a player is walked through a surface the first time they open it
  /// and never again: the record lives on the account and is cached on the
  /// device, so a reinstall, a second phone, and a fresh sign-in all keep their
  /// place. That is what makes the guide impossible to *look* at while building
  /// it — one run per account, ever.
  ///
  /// With this on, signing in hands the guide a blank record instead of the
  /// player's own history, so the whole walkthrough runs again, surface by
  /// surface, in the order a first-time player meets them. Log out, log back in
  /// with the same number, and walk the entire thing again. Nothing else
  /// changes: within a session the arcs, their triggers, and the once-only rule
  /// behave exactly as they do in production.
  ///
  /// Set it in `.env`:
  ///
  /// ```
  /// GUIDE_REHEARSAL=true
  /// ```
  ///
  /// `.env` is bundled as an asset, so a change needs a full restart rather
  /// than a hot reload. `--dart-define=GUIDE_REHEARSAL=true` wins over the file
  /// when both are set, which is the one to reach for on CI or a device build.
  ///
  /// Forced off in release builds. A shipped app that re-tours a returning
  /// player on every sign-in is a worse bug than never touring them at all, and
  /// a switch that can only be wrong in one direction is the kind worth having.
  static bool get guideRehearsal {
    if (kReleaseMode) return false;
    const compiled = String.fromEnvironment(
      'GUIDE_REHEARSAL',
      defaultValue: '',
    );
    return _isTrue(compiled.isNotEmpty ? compiled : _env('GUIDE_REHEARSAL'));
  }

  /// Read a key without requiring `.env` to have loaded — tests and the very
  /// first frames of a cold start both run before it does.
  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key]?.trim();
  }

  static bool _isTrue(String? value) => switch (value?.toLowerCase()) {
    'true' || '1' || 'yes' || 'on' => true,
    _ => false,
  };

  /// Android emulators cannot reach the dev machine via `localhost` (that is
  /// the guest itself). The host loopback is routed as `10.0.2.2`.
  ///
  /// Debug/profile builds remap `localhost` and `127.0.0.1` to [ANDROID_DEV_HOST]
  /// if set, otherwise `10.0.2.2`. Release builds are unchanged.
  ///
  /// Use `SKIP_ANDROID_LOCALHOST_REMAP=true` with `adb reverse` on a physical
  /// device, or set `ANDROID_DEV_HOST` to your machine's LAN IP.
  static String _normalizeLocalhostForAndroid(String url) {
    if (kReleaseMode) return url;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return url;
    }

    final skip = dotenv.env['SKIP_ANDROID_LOCALHOST_REMAP'];
    if (skip == 'true' || skip == '1') return url;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return url;

    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') return url;

    final custom = dotenv.env['ANDROID_DEV_HOST']?.trim();
    final replacement = (custom != null && custom.isNotEmpty)
        ? custom
        : '10.0.2.2';

    return uri.replace(host: replacement).toString();
  }
}
