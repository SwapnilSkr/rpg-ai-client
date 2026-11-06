import 'dart:async';

import '../auth/auth_service.dart';
import '../push/push_service.dart';
import '../storage/secure_storage.dart';
import 'reminder_service.dart';

/// The one-time ask for messages from a group chat: after the player's first
/// reply in a group, if the phone doesn't already allow notifications and
/// nobody has asked before. The answer lives in the reminder record, so the
/// story ask and this one never both appear.
///
/// Every outside fact is a seam so tests need no plugin and no storage.
class PushAsk {
  PushAsk({
    Future<bool> Function()? signedIn,
    Future<bool> Function()? permissionGranted,
    bool Function()? stillOpen,
    Future<void> Function()? record,
    Future<bool> Function()? askSystem,
  }) : _signedIn = signedIn ?? _storedNonGuest,
       _permissionGranted =
           permissionGranted ??
           (() => PushService.instance.permissionGranted()),
       _stillOpen = stillOpen ?? (() => ReminderService.instance.pushAskOpen),
       _record = record ?? (() => ReminderService.instance.recordPushAsk()),
       _askSystem = askSystem ?? (() => PushService.instance.askPermission());

  static PushAsk instance = PushAsk();

  final Future<bool> Function() _signedIn;
  final Future<bool> Function() _permissionGranted;
  final bool Function() _stillOpen;
  final Future<void> Function() _record;
  final Future<bool> Function() _askSystem;

  bool _claimed = false;

  /// True when the sheet should be shown now. Cheap answers first, so a
  /// player who has answered never costs a storage or plugin call.
  Future<bool> due() async {
    try {
      if (_claimed || !_stillOpen()) return false;
      if (!await _signedIn()) return false;
      return !await _permissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Takes the right to show the sheet. Two screens can hear that it is due;
  /// only the first to claim shows it.
  bool claim() {
    if (_claimed || !_stillOpen()) return false;
    return _claimed = true;
  }

  /// The player answered. Stored first, so a failed system dialog never
  /// brings the sheet back; a yes then shows the system dialog.
  Future<void> answer({required bool yes}) async {
    try {
      await _record();
    } catch (_) {}
    if (yes) {
      try {
        await _askSystem();
      } catch (_) {}
    }
  }

  /// A stored session that is not a guest's.
  static Future<bool> _storedNonGuest() async {
    if (await SecureStore.getToken() == null) return false;
    final user = await AuthService.getCachedUser();
    return user != null && !user.guest;
  }
}
