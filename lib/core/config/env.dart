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
    final replacement =
        (custom != null && custom.isNotEmpty) ? custom : '10.0.2.2';

    return uri.replace(host: replacement).toString();
  }
}
