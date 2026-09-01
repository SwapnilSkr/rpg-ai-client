import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Where a shipping build talks to.
  ///
  /// Compiled in, deliberately, and never read from the bundled `.env`. That
  /// file is a *developer's* file: it points at whatever server they happened
  /// to be running — a laptop's LAN address, an emulator loopback — and it is
  /// gitignored, so nothing in review or CI ever sees what it says. It is also
  /// bundled as an asset, which means whatever it happened to contain at
  /// `flutter build` time is what ships.
  ///
  /// That combination shipped once. Release 1.0.1 went to the closed track
  /// carrying `API_BASE_URL=http://192.168.0.100:8081`, so every install fell
  /// at the first request: the plaintext guard below threw before a packet was
  /// sent, and both sign-in paths failed for every player on the track. The
  /// guard did its job — it refused — but it could only refuse at *runtime*, on
  /// the player's phone, which is far too late to be useful.
  ///
  /// So the release endpoint is no longer something a build can get wrong by
  /// omission. `--dart-define` still wins when it is set (staging, a device
  /// pointed at a branch server), and debug builds still read `.env` as before.
  /// What is gone is the path where a release quietly inherits a dev machine's
  /// address.
  static const _releaseApiBaseUrl = 'https://api.everloreapp.com';
  static const _releaseWsBaseUrl = 'wss://api.everloreapp.com';

  static String get apiBaseUrl => _resolve(
    key: 'API_BASE_URL',
    compiled: const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
    releaseDefault: _releaseApiBaseUrl,
    devDefault: 'http://localhost:3000',
  );

  static String get wsBaseUrl => _resolve(
    key: 'WS_BASE_URL',
    compiled: const String.fromEnvironment('WS_BASE_URL', defaultValue: ''),
    releaseDefault: _releaseWsBaseUrl,
    devDefault: 'ws://localhost:3000',
  );

  /// The Google web client ID that Firebase brokers the sign-in credential
  /// through.
  ///
  /// Compiled in for the same reason the endpoints above are. This used to be
  /// read straight from the bundled `.env` on the auth screen, which made a
  /// *developer's* gitignored file load-bearing for production sign-in, with a
  /// failure that said nothing: the read is wrapped in a bare catch, a missing
  /// or mistyped key just leaves `_googleReady` false, and the Google button
  /// silently is not there. No crash to report, nothing in review to catch it.
  ///
  /// Not a secret. It is a public identifier, already sitting in
  /// `google-services.json` and readable in any shipped APK — the reason it
  /// belongs here is packaging determinism, not confidentiality.
  static const _releaseGoogleWebClientId =
      '596403299579-cc9d9sdsrceacjd2tf3o2c6ukvblnrnj.apps.googleusercontent.com';

  /// Empty when nothing is configured, which is the auth screen's signal to
  /// hide the Google button rather than offer one that always throws.
  static String get googleWebClientId {
    const compiled = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    );
    if (compiled.isNotEmpty) return compiled.trim();
    if (kReleaseMode) return _releaseGoogleWebClientId;
    return _env('GOOGLE_WEB_CLIENT_ID') ?? '';
  }

  /// An explicit `--dart-define` first, then the compiled-in production
  /// endpoint in release, then `.env` (dev only), then the local default.
  static String _resolve({
    required String key,
    required String compiled,
    required String releaseDefault,
    required String devDefault,
  }) {
    if (compiled.isNotEmpty) {
      return _requireSecureInRelease(
        _normalizeLocalhostForAndroid(compiled),
        key,
      );
    }
    if (kReleaseMode) return releaseDefault;
    return _normalizeLocalhostForAndroid(dotenv.env[key] ?? devDefault);
  }

  /// Schemes a release build is allowed to talk over.
  ///
  /// The Play listing declares that everything this app sends is encrypted in
  /// transit, and that declaration is only honest if there is no way to build a
  /// shipping binary that talks plaintext. Android enforces this itself from
  /// API 28 and iOS enforces it through App Transport Security, so a release
  /// build pointed at `http://` cannot reach the network at all — but what the
  /// player would *see* is every request failing for no stated reason, and what
  /// we would see is a bug report about the server being down.
  ///
  /// So we fail first, and say why. A release build carrying a plaintext base
  /// URL is a packaging mistake — an unset `--dart-define`, a stale bundled
  /// `.env` — and it is caught the moment anyone opens the build rather than
  /// after it reaches a listing.
  ///
  /// Debug and profile builds are untouched: local servers speak `http://` and
  /// `ws://`, and src/debug and src/profile permit exactly that.
  static const _secureSchemes = {'https', 'wss'};

  @visibleForTesting
  static bool isSecureEndpoint(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    return scheme != null && _secureSchemes.contains(scheme);
  }

  static String _requireSecureInRelease(String url, String key) {
    if (!kReleaseMode || isSecureEndpoint(url)) return url;

    throw StateError(
      'Refusing to open an unencrypted connection: $key is "$url". '
      'Release builds must use https:// or wss://. Rebuild with '
      '--dart-define=$key=<secure url>, or fix the bundled .env. '
      'See infra/PROD_NOTES.md for the production hostname.',
    );
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
