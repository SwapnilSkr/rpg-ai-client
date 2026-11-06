import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../app_routes.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../telemetry/telemetry.dart';
import 'reminder_policy.dart';
import 'reminder_record.dart';
import 'reminder_store.dart';

/// The player's answer to our own ask sheet (before any system dialog).
enum ReminderAskAnswer { yes, notNow }

/// What the profile switch should do after [ReminderService.setEnabled].
enum ReminderToggleResult {
  /// Reminders are now on (and scheduled, if there is a story to point at).
  on,

  /// Reminders are now off and everything pending is cancelled.
  off,

  /// The system permission is denied; the app's notification settings were
  /// opened so the player can allow it there. The switch stays off.
  needsSystemSettings,
}

/// Story reminders: local notifications that bring a player back to the story
/// they left. One owner for scheduling, the persisted record, the ask policy
/// and tap routing. The ask sheet and the profile switch are thin UI over it.
class ReminderService {
  ReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    ReminderStore store = const ReminderStore(),
    DateTime Function() now = DateTime.now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _store = store,
       _now = now;

  static ReminderService instance = ReminderService();

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderStore _store;
  final DateTime Function() _now;

  static const _channelId = 'story_reminders';
  static const _smallIcon = 'ic_stat_everlore';
  static const _settingsChannel = MethodChannel('everlore/reminders');

  /// Fixed ids so a new anchor replaces the old set instead of stacking.
  static const _idBase = 7101;

  /// True when the ask sheet should be shown now. [PlayCubit] raises it after
  /// the first anchor if [shouldAsk]; the sheet listens, shows itself, and the
  /// answer ([recordAsk]) lowers it.
  final ValueNotifier<bool> askNow = ValueNotifier(false);

  ReminderRecord _record = ReminderRecord.empty;
  bool _ready = false;
  Future<void> _queue = Future.value();

  /// A tapped reminder waiting for the app to settle on a real screen.
  ({int nth, String instanceId})? _pendingOpen;
  bool _watchingRouter = false;

  /// Loads the record, wires the plugin and picks up a cold-start tap. Never
  /// throws: a failure leaves reminders off for the run.
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Falls back to UTC for the plugin; times are still computed from the
        // device's own clock below, so the instant is right either way.
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_smallIcon),
        ),
        onDidReceiveNotificationResponse: (r) => _onTap(r.payload),
      );
      _record = await _store.load();
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _onTap(launch?.notificationResponse?.payload);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[reminders] init failed: $error');
    }
  }

  // ── state for the UI ────────────────────────────────────────────────────

  /// Reminders are switched on and the system allows them.
  Future<bool> isActive() async {
    if (!_ready || !_record.enabled) return false;
    return _systemAllows();
  }

  /// The switch position, as the player set it.
  bool get enabled => _record.enabled;

  /// Whether to show the ask sheet now (spec §1.3).
  Future<bool> shouldAsk() async {
    if (!_ready || _record.pushAsked) return false;
    return shouldAskForReminders(
      enabled: _record.enabled,
      askCount: _record.askCount,
      lastAskedAt: _record.lastAskedAt,
      now: _now(),
    );
  }

  /// Whether the group-chat messages ask is still open: nobody has answered
  /// it, and the story ask has not been answered either.
  bool get pushAskOpen => _ready && !_record.pushAsked && _record.askCount == 0;

  /// The player answered the group-chat messages ask. Closes it for good, and
  /// the story ask with it, so nobody is asked twice by either sheet.
  Future<void> recordPushAsk() => _serial(() async {
    if (!_ready) return;
    _record = _record.copyWith(pushAsked: true, lastAskedAt: _now());
    await _store.save(_record);
    askNow.value = false;
  });

  // ── the anchor ──────────────────────────────────────────────────────────

  /// A turn the player sent just finished. Moves the anchor, replaces every
  /// pending reminder with three new ones (when allowed), and raises [askNow]
  /// if it is time to ask.
  Future<void> onAnchor({
    required String instanceId,
    required String worldTitle,
  }) => _serial(() async {
    if (!_ready || instanceId.isEmpty) return;
    final anchor = ReminderAnchor(
      instanceId: instanceId,
      worldTitle: worldTitle,
      at: _now(),
    );
    _record = _record.copyWith(anchor: anchor);
    await _store.save(_record);
    await _reschedule();
    if (await shouldAsk()) askNow.value = true;
  });

  /// The player answered our sheet. Counts as one ask, which is what limits
  /// the sheet to twice.
  Future<void> recordAsk(ReminderAskAnswer answer) => _serial(() async {
    if (!_ready) return;
    _record = _record.copyWith(
      askCount: (_record.askCount + 1).clamp(1, maxReminderAsks),
      lastAskedAt: _now(),
    );
    await _store.save(_record);
    askNow.value = false;
    Telemetry.instance.track('reminder_prompt', {
      'answer': answer == ReminderAskAnswer.yes ? 'yes' : 'not_now',
      'attempt': _record.askCount,
    });
  });

  /// Shows the system permission dialog (Android 13+; granted by default
  /// below). On a yes, reminders turn on and schedule from the last anchor.
  /// Call after [recordAsk] with [ReminderAskAnswer.yes].
  Future<bool> requestSystemPermission() => _serial(() async {
    if (!_ready) return false;
    final granted = await _askSystem();
    if (_record.askCount >= 1) {
      Telemetry.instance.track('reminder_prompt', {
        'answer': granted ? 'granted' : 'denied',
        'attempt': _record.askCount,
      });
    }
    await _applyEnabled(granted);
    return granted;
  });

  /// The profile switch. Turning on with the system permission denied opens
  /// the app's notification settings and leaves the switch off. Turning off
  /// cancels everything and ends the asking: the player has decided.
  Future<ReminderToggleResult> setEnabled(bool value) => _serial(() async {
    if (!_ready) return ReminderToggleResult.off;
    if (!value) {
      _record = _record.copyWith(enabled: false, askCount: maxReminderAsks);
      await _store.save(_record);
      await _cancelAll();
      askNow.value = false;
      return ReminderToggleResult.off;
    }
    if (!await _askSystem()) {
      await openSystemSettings();
      return ReminderToggleResult.needsSystemSettings;
    }
    await _applyEnabled(true);
    return ReminderToggleResult.on;
  });

  /// Opens the app's system notification settings. False if it could not.
  Future<bool> openSystemSettings() async {
    try {
      return await _settingsChannel.invokeMethod<bool>(
            'openNotificationSettings',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Sign-out and account deletion: cancel everything and forget the record.
  Future<void> clear() => _serial(() async {
    _record = ReminderRecord.empty;
    _pendingOpen = null;
    askNow.value = false;
    await _cancelAll();
    await _store.clear();
  });

  // ── scheduling ──────────────────────────────────────────────────────────

  Future<void> _applyEnabled(bool on) async {
    _record = _record.copyWith(enabled: on);
    await _store.save(_record);
    if (on) {
      await _reschedule();
    } else {
      await _cancelAll();
    }
  }

  Future<void> _reschedule() async {
    await _cancelAll();
    final anchor = _record.anchor;
    if (anchor == null || !_record.enabled || !await _systemAllows()) return;
    final title = anchor.worldTitle.trim().isEmpty
        ? 'Everlore'
        : anchor.worldTitle.trim();
    final now = _now();
    for (final r in planReminders(anchor.at, now: now)) {
      try {
        await _plugin.zonedSchedule(
          id: _idBase + r.nth,
          title: title,
          body: r.body,
          // An instant, so the device's own clock decides the wall time even
          // when the zone lookup above fell back to UTC.
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Story reminders',
              channelDescription: 'A gentle nudge when your story is waiting.',
              icon: _smallIcon,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminderPayload(nth: r.nth, instanceId: anchor.instanceId),
        );
      } catch (error) {
        if (kDebugMode) debugPrint('[reminders] schedule failed: $error');
      }
    }
  }

  Future<void> _cancelAll() async {
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {}
  }

  Future<bool> _systemAllows() async {
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _askSystem() async {
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Operations run one at a time, so two quick anchors cannot interleave
  /// their cancel and schedule steps.
  Future<T> _serial<T>(Future<T> Function() op) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await op());
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  // ── taps ────────────────────────────────────────────────────────────────

  void _onTap(String? payload) {
    final parsed = parseReminderPayload(payload);
    if (parsed == null) return;
    _pendingOpen = parsed;
    _tryOpen();
    if (_pendingOpen != null && !_watchingRouter) {
      _watchingRouter = true;
      router.routerDelegate.addListener(_tryOpen);
    }
  }

  /// Splash and the first route decide where a player lands. Wait for them to
  /// settle, then open the story on top of wherever that is; a signed-out
  /// player (welcome, sign-in, onboarding) is left alone, quietly.
  Future<void> _tryOpen() async {
    final pending = _pendingOpen;
    if (pending == null) return;
    final here = _location();
    // An empty path means the router hasn't resolved its first location yet.
    // `/` is the Realms tab, a real place to open from.
    if (here == null || here.isEmpty || here == '/splash') return;
    _pendingOpen = null;
    if (_watchingRouter) {
      _watchingRouter = false;
      router.routerDelegate.removeListener(_tryOpen);
    }
    Telemetry.instance.track('reminder_opened', {'nth': pending.nth});
    const preAuth = {'/welcome', '/auth', '/onboarding'};
    if (preAuth.contains(here)) return;
    final target = '/play/${pending.instanceId}';
    if (here == target) return;
    if (await SecureStore.getToken() == null) return;
    if (!await _saveExists(pending.instanceId)) return;
    router.push(target);
  }

  /// A deleted save falls through; a network failure does not (the play screen
  /// has its own offline handling).
  Future<bool> _saveExists(String instanceId) async {
    try {
      await ApiClient.get('/instances/$instanceId');
      return true;
    } on ApiException catch (e) {
      return !(e.statusCode == 404 || e.statusCode == 403);
    } catch (_) {
      return true;
    }
  }

  String? _location() {
    try {
      final config = router.routerDelegate.currentConfiguration;
      final last = config.matches.isEmpty ? null : config.matches.last;
      if (last is ImperativeRouteMatch) return last.matches.uri.path;
      return config.uri.path;
    } catch (_) {
      return null;
    }
  }
}
