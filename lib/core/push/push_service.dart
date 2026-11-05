import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../app_routes.dart';
import '../auth/auth_service.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../telemetry/telemetry.dart';

/// The one Android channel a character's message arrives on. The manifest
/// names it as the default; the server's payload doesn't name a channel.
const pushChannelId = 'character_messages';

/// The phone's side of Firebase Cloud Messaging, kept behind a seam so tests
/// need no plugin and no Firebase.
abstract class PushGateway {
  Future<String?> token();
  Stream<String> get tokenRefreshes;

  /// The data of the message whose tap started the app, if one did.
  Future<Map<String, Object?>?> launchMessage();

  /// The data of a message tapped while the app was in the background.
  Stream<Map<String, Object?>> get openedMessages;

  Future<void> createChannel();
  Future<bool> permissionGranted();
  Future<bool> askPermission();
}

class _FirebaseGateway implements PushGateway {
  _FirebaseGateway()
    : _messaging = FirebaseMessaging.instance,
      _notifications = FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _notifications;

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<Map<String, Object?>?> launchMessage() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Stream<Map<String, Object?>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  // Only a channel is created here. The plugin is shared with story
  // reminders, whose init owns its tap callback; initialising it again would
  // replace that callback.
  @override
  Future<void> createChannel() async {
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        pushChannelId,
        'Messages',
        description: 'Messages from the people in your chats.',
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<bool> permissionGranted() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> askPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;
}

/// Character messages on the phone: registers this device with the server,
/// lets go of it on sign-out, and opens the right thread when a message is
/// tapped. Nothing is shown while the app is open (the app already shows what
/// is pending) and no code runs when a message merely arrives.
class PushService {
  PushService({
    PushGateway? gateway,
    Future<void> Function(String token, int tzOffsetMinutes)? register,
    Future<void> Function(String token)? unregister,
    Future<bool> Function()? signedIn,
    Future<bool> Function()? hasSession,
    int Function()? tzOffsetMinutes,
    Uri? Function()? locate,
    void Function(String location)? open,
    Listenable? routerChanges,
    void Function()? trackOpened,
    Duration signOutBudget = const Duration(seconds: 3),
  }) : _gateway = gateway,
       _register = register ?? _postToken,
       _unregister = unregister ?? _deleteToken,
       _signedIn = signedIn ?? _storedNonGuest,
       _hasSession = hasSession ?? _storedSession,
       _offset = tzOffsetMinutes ?? _deviceOffset,
       _locate = locate ?? _routerLocation,
       _open = open ?? _routerPush,
       _routerChanges = routerChanges,
       _trackOpened = trackOpened ?? _trackPushOpened,
       _signOutBudget = signOutBudget;

  static PushService instance = PushService();

  PushGateway? _gateway;
  final Future<void> Function(String token, int tzOffsetMinutes) _register;
  final Future<void> Function(String token) _unregister;
  final Future<bool> Function() _signedIn;
  final Future<bool> Function() _hasSession;
  final int Function() _offset;
  final Uri? Function() _locate;
  final void Function(String location) _open;
  final Listenable? _routerChanges;
  final void Function() _trackOpened;
  final Duration _signOutBudget;

  bool _ready = false;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<Map<String, Object?>>? _openedSub;

  /// What the server last accepted from this run, so a repeat of the same
  /// pair is not sent again.
  String? _sentToken;
  int? _sentOffset;
  Future<void> _queue = Future.value();

  /// A tapped message waiting for the app to settle on a real screen.
  ({String instanceId, String characterId})? _pendingOpen;
  bool _watchingRouter = false;

  Listenable get _changes => _routerChanges ?? router.routerDelegate;

  /// Wires the channel and the tap handlers, then registers the device if a
  /// player is signed in. Never throws, and never waits on the network: a
  /// failure (Firebase unavailable, no Play services) leaves push off for the
  /// run.
  Future<void> init() async {
    if (_ready) return;
    try {
      final gateway = _gateway ??= _FirebaseGateway();
      await gateway.createChannel();
      _refreshSub = gateway.tokenRefreshes.listen(
        (token) => unawaited(_registerToken(token)),
        onError: (_) {},
      );
      _openedSub = gateway.openedMessages.listen(_onTap, onError: (_) {});
      _ready = true;
      unawaited(_pickUpLaunchMessage(gateway));
      unawaited(onSessionStarted());
    } catch (error) {
      if (kDebugMode) debugPrint('[push] init failed: $error');
    }
  }

  // ── what the UI needs ───────────────────────────────────────────────────

  /// The system lets messages show as banners. Registration does not depend
  /// on it: with it off the player still finds the message inside the app.
  Future<bool> permissionGranted() async {
    try {
      return await _gateway?.permissionGranted() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system permission dialog. True if the player allowed it.
  Future<bool> askPermission() async {
    try {
      return await _gateway?.askPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── the device ──────────────────────────────────────────────────────────

  /// A session has started: sign-in, or the app opening on a stored one.
  /// Registers this device for the signed-in player; a guest is skipped.
  /// Repeats are cheap and quiet, and a failure waits for the next start.
  Future<void> onSessionStarted() async {
    if (!_ready) return;
    try {
      final token = await _gateway?.token();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Retried on the next start.
    }
  }

  /// One at a time, so a refresh landing mid-registration cannot send the
  /// same pair twice or let an older answer overwrite a newer one.
  Future<void> _registerToken(String token) {
    final done = _queue.then((_) async {
      final offset = _offset();
      if (token == _sentToken && offset == _sentOffset) return;
      try {
        if (!await _signedIn()) return;
        await _register(token, offset);
        _sentToken = token;
        _sentOffset = offset;
      } catch (_) {
        // Quiet by design; the token is never logged.
      }
    });
    _queue = done;
    return done;
  }

  /// Sign-out, before the session token is cleared: the server stops sending
  /// to this phone. Bounded, so a bad network cannot hold sign-out up, and a
  /// failure is dropped (the server also forgets a token its provider
  /// rejects).
  Future<void> onSigningOut() async {
    try {
      await _forgetDevice().timeout(_signOutBudget);
    } catch (_) {}
    _sentToken = null;
    _sentOffset = null;
    _pendingOpen = null;
  }

  Future<void> _forgetDevice() async {
    if (!_ready || !await _signedIn()) return;
    final token = _sentToken ?? await _gateway?.token();
    if (token == null || token.isEmpty) return;
    await _unregister(token);
  }

  // ── taps ────────────────────────────────────────────────────────────────

  Future<void> _pickUpLaunchMessage(PushGateway gateway) async {
    try {
      final data = await gateway.launchMessage();
      if (data != null) _onTap(data);
    } catch (_) {}
  }

  void _onTap(Map<String, Object?> data) {
    // Only a direct message from a character opens anything; the ids are
    // checked here because the data is whatever the sender put in it.
    if (data['type'] != 'group_direct') return;
    final instanceId = data['instanceId'];
    final characterId = data['characterId'];
    if (instanceId is! String || instanceId.isEmpty) return;
    if (characterId is! String || characterId.isEmpty) return;
    _pendingOpen = (instanceId: instanceId, characterId: characterId);
    unawaited(_tryOpen());
    if (_pendingOpen != null && !_watchingRouter) {
      _watchingRouter = true;
      _changes.addListener(_listen);
    }
  }

  void _listen() => unawaited(_tryOpen());

  /// Same rules as a tapped reminder: wait for the splash to finish, then
  /// open on top of wherever the player landed; a signed-out player (welcome,
  /// sign-in, onboarding) is left alone, quietly.
  Future<void> _tryOpen() async {
    final pending = _pendingOpen;
    if (pending == null) return;
    final here = _locate();
    // An empty path means the router hasn't resolved its first location yet.
    if (here == null || here.path.isEmpty || here.path == '/splash') return;
    _pendingOpen = null;
    if (_watchingRouter) {
      _watchingRouter = false;
      _changes.removeListener(_listen);
    }
    _trackOpened();
    const preAuth = {'/welcome', '/auth', '/onboarding'};
    if (preAuth.contains(here.path)) return;
    // Already looking at this very thread: a second copy would need two backs.
    if (here.path == '/group/${pending.instanceId}' &&
        here.queryParameters['member'] == pending.characterId) {
      return;
    }
    if (!await _hasSession()) return;
    _open(
      '/group/${Uri.encodeComponent(pending.instanceId)}'
      '?member=${Uri.encodeQueryComponent(pending.characterId)}',
    );
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
    if (_watchingRouter) {
      _watchingRouter = false;
      _changes.removeListener(_listen);
    }
    _ready = false;
    _gateway = null;
    _sentToken = null;
    _sentOffset = null;
    _pendingOpen = null;
  }

  // ── defaults ────────────────────────────────────────────────────────────

  // No ids: the event only says a message was tapped.
  static void _trackPushOpened() => Telemetry.instance.track('push_opened');

  static int _deviceOffset() => DateTime.now().timeZoneOffset.inMinutes;

  static Future<void> _postToken(String token, int tzOffsetMinutes) =>
      ApiClient.post(
        '/auth/push-token',
        body: {
          'token': token,
          'platform': 'android',
          'tz_offset_minutes': tzOffsetMinutes,
        },
      );

  // ApiClient.delete carries no body and the route reads the token from one.
  static Future<void> _deleteToken(String token) async {
    final session = await SecureStore.getToken();
    final request = http.Request(
      'DELETE',
      Uri.parse('${AppConfig.apiBaseUrl}/auth/push-token'),
    );
    request.headers['Content-Type'] = 'application/json';
    if (session != null) request.headers['Authorization'] = 'Bearer $session';
    request.body = jsonEncode({'token': token});
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(statusCode: response.statusCode, message: 'refused');
    }
  }

  /// A stored session that is not a guest's. Read from storage rather than
  /// from the guest state, which may not be loaded yet at a cold start.
  static Future<bool> _storedNonGuest() async {
    if (await SecureStore.getToken() == null) return false;
    final user = await AuthService.getCachedUser();
    return user != null && !user.guest;
  }

  static Future<bool> _storedSession() async =>
      await SecureStore.getToken() != null;

  static Uri? _routerLocation() {
    try {
      final config = router.routerDelegate.currentConfiguration;
      final last = config.matches.isEmpty ? null : config.matches.last;
      if (last is ImperativeRouteMatch) return last.matches.uri;
      return config.uri;
    } catch (_) {
      return null;
    }
  }

  static void _routerPush(String location) => router.push(location);
}
