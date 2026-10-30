import 'package:flutter/foundation.dart';

/// Pure rules for story reminders: when they fire, what they say, and when the
/// player is asked. No platform calls here, so every rule is unit-testable.

/// Debug-only shortcut for verifying on a device: reminders fire 1 / 2 / 3
/// minutes after the anchor, ignoring quiet hours, and the second ask comes
/// after two minutes instead of three days.
///
/// `--dart-define=REMINDER_DEBUG_DELAYS=true`. Both operands are compile-time
/// constants and [kDebugMode] is false in release, so the whole branch is
/// dead code there: a release build cannot be switched into it.
const bool reminderDebugDelays =
    kDebugMode && bool.fromEnvironment('REMINDER_DEBUG_DELAYS');

/// How many reminders one anchor schedules.
const int reminderCount = 3;

/// The player can be asked at most this many times.
const int maxReminderAsks = 2;

const List<Duration> _delays = [
  Duration(hours: 22),
  Duration(days: 3),
  Duration(days: 7),
];

const List<Duration> _debugDelays = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 3),
];

/// One sentence each, in the story's voice. Nothing from the story itself, so
/// nothing spoils and nothing adult reaches a lock screen.
const List<String> reminderBodies = [
  'Your story is waiting where you left it.',
  "The story hasn't moved on without you.",
  'Your place in the story is still held.',
];

/// Quiet hours: a reminder lands between 10:00 and 21:30 local time or is
/// moved to this hour.
const int _quietEarliestMinute = 10 * 60;
const int _quietLatestMinute = 21 * 60 + 30;
const int _quietFallbackHour = 19;

/// A reminder that would fire outside 10:00-21:30 moves to 19:00: the same day
/// if that is still ahead of it, otherwise the next day. [t] is read in its own
/// fields, so pass local time.
DateTime shiftOutOfQuietHours(DateTime t) {
  final minute = t.hour * 60 + t.minute;
  if (minute >= _quietEarliestMinute && minute <= _quietLatestMinute) return t;
  if (minute < _quietEarliestMinute) {
    return DateTime(t.year, t.month, t.day, _quietFallbackHour);
  }
  return DateTime(t.year, t.month, t.day + 1, _quietFallbackHour);
}

class PlannedReminder {
  const PlannedReminder({required this.nth, required this.at});

  /// 1-based position in the set, also the analytics `nth`.
  final int nth;
  final DateTime at;

  String get body => reminderBodies[nth - 1];

  @override
  String toString() => 'PlannedReminder($nth, $at)';
}

/// The reminders an anchor at [anchorAt] schedules, in order. Anything that
/// would already be in the past at [now] is left out.
List<PlannedReminder> planReminders(
  DateTime anchorAt, {
  required DateTime now,
  bool debugDelays = reminderDebugDelays,
}) {
  final delays = debugDelays ? _debugDelays : _delays;
  final planned = <PlannedReminder>[];
  for (var i = 0; i < reminderCount; i++) {
    final raw = anchorAt.add(delays[i]);
    final at = debugDelays ? raw : shiftOutOfQuietHours(raw);
    if (!at.isAfter(now)) continue;
    planned.add(PlannedReminder(nth: i + 1, at: at));
  }
  return planned;
}

/// How long after an ask the next one may come.
Duration reminderAskGap({bool debugDelays = reminderDebugDelays}) =>
    debugDelays ? const Duration(minutes: 2) : const Duration(days: 3);

/// Whether to show the ask sheet now. At most twice; the second no sooner than
/// the gap after the first; never once reminders are on.
bool shouldAskForReminders({
  required bool enabled,
  required int askCount,
  required DateTime? lastAskedAt,
  required DateTime now,
  bool debugDelays = reminderDebugDelays,
}) {
  if (enabled) return false;
  if (askCount >= maxReminderAsks) return false;
  if (askCount == 0 || lastAskedAt == null) return true;
  return now.difference(lastAskedAt) >=
      reminderAskGap(debugDelays: debugDelays);
}

/// A tap carries `nth|instanceId`.
String reminderPayload({required int nth, required String instanceId}) =>
    '$nth|$instanceId';

({int nth, String instanceId})? parseReminderPayload(String? payload) {
  if (payload == null) return null;
  final cut = payload.indexOf('|');
  if (cut <= 0 || cut == payload.length - 1) return null;
  final nth = int.tryParse(payload.substring(0, cut));
  if (nth == null || nth < 1 || nth > reminderCount) return null;
  return (nth: nth, instanceId: payload.substring(cut + 1));
}
