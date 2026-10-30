import 'package:everlore/core/reminders/reminder_policy.dart';
import 'package:everlore/core/reminders/reminder_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shiftOutOfQuietHours', () {
    test('leaves 10:00 to 21:30 alone, edges included', () {
      for (final t in [
        DateTime(2026, 11, 1, 10, 0),
        DateTime(2026, 11, 1, 15, 45),
        DateTime(2026, 11, 1, 21, 30),
      ]) {
        expect(shiftOutOfQuietHours(t), t);
      }
    });

    test('early morning moves to 19:00 the same day', () {
      expect(
        shiftOutOfQuietHours(DateTime(2026, 11, 1, 3, 20)),
        DateTime(2026, 11, 1, 19),
      );
      expect(
        shiftOutOfQuietHours(DateTime(2026, 11, 1, 9, 59)),
        DateTime(2026, 11, 1, 19),
      );
    });

    test('late night moves to 19:00 the next day, across a month end', () {
      expect(
        shiftOutOfQuietHours(DateTime(2026, 11, 1, 21, 31)),
        DateTime(2026, 11, 2, 19),
      );
      expect(
        shiftOutOfQuietHours(DateTime(2026, 11, 30, 23, 59)),
        DateTime(2026, 12, 1, 19),
      );
    });
  });

  group('planReminders', () {
    final now = DateTime(2026, 11, 1, 12);

    test('three reminders at +22h, +3d, +7d, shifted out of quiet hours', () {
      // Anchored 14:00: +22h = 12:00 next day (fine), +3d = 14:00, +7d = 14:00.
      final plan = planReminders(
        DateTime(2026, 11, 1, 14),
        now: now,
        debugDelays: false,
      );
      expect(plan.map((p) => p.nth), [1, 2, 3]);
      expect(plan[0].at, DateTime(2026, 11, 2, 12));
      expect(plan[1].at, DateTime(2026, 11, 4, 14));
      expect(plan[2].at, DateTime(2026, 11, 8, 14));
    });

    test('a reminder landing at night moves to 19:00', () {
      // Anchored 23:00: +22h = 21:00 (fine), +3d = 23:00 -> next day 19:00.
      final plan = planReminders(
        DateTime(2026, 11, 1, 23),
        now: now,
        debugDelays: false,
      );
      expect(plan[0].at, DateTime(2026, 11, 2, 21));
      expect(plan[1].at, DateTime(2026, 11, 5, 19));
      expect(plan[2].at, DateTime(2026, 11, 9, 19));
    });

    test('debug delays are 1, 2, 3 minutes and ignore quiet hours', () {
      final anchor = DateTime(2026, 11, 1, 3);
      final plan = planReminders(
        anchor,
        now: anchor,
        debugDelays: true,
      );
      expect(plan.map((p) => p.at.difference(anchor).inMinutes), [1, 2, 3]);
    });

    test('nothing already in the past is scheduled', () {
      final plan = planReminders(
        DateTime(2026, 10, 1, 14),
        now: DateTime(2026, 10, 5, 12),
        debugDelays: false,
      );
      expect(plan.map((p) => p.nth), [3]);
    });

    test('release builds cannot enable the debug delays', () {
      // The flag is only ever true under kDebugMode plus an explicit define.
      expect(reminderDebugDelays, isFalse);
    });
  });

  group('shouldAskForReminders', () {
    final now = DateTime(2026, 11, 10, 12);

    bool ask({
      bool enabled = false,
      int count = 0,
      DateTime? last,
      DateTime? at,
    }) => shouldAskForReminders(
      enabled: enabled,
      askCount: count,
      lastAskedAt: last,
      now: at ?? now,
      debugDelays: false,
    );

    test('asks at the first anchor', () => expect(ask(), isTrue));

    test('never once reminders are on', () {
      expect(ask(enabled: true), isFalse);
    });

    test('a second ask waits at least three days', () {
      final last = DateTime(2026, 11, 7, 12, 1);
      expect(ask(count: 1, last: last), isFalse);
      expect(ask(count: 1, last: DateTime(2026, 11, 7, 12)), isTrue);
    });

    test('never a third time', () {
      expect(ask(count: 2, last: DateTime(2026, 1, 1)), isFalse);
    });
  });

  group('payload', () {
    test('round trips', () {
      final p = reminderPayload(nth: 2, instanceId: 'abc123');
      final parsed = parseReminderPayload(p)!;
      expect(parsed.nth, 2);
      expect(parsed.instanceId, 'abc123');
    });

    test('rejects junk', () {
      for (final bad in [null, '', 'abc', '|abc', '2|', '9|abc', 'x|abc']) {
        expect(parseReminderPayload(bad), isNull, reason: '$bad');
      }
    });
  });

  group('ReminderRecord', () {
    test('round trips', () {
      final r = ReminderRecord(
        enabled: true,
        askCount: 1,
        lastAskedAt: DateTime(2026, 11, 1, 9),
        anchor: ReminderAnchor(
          instanceId: 'i1',
          worldTitle: 'The Iron Verdict',
          at: DateTime(2026, 11, 1, 10),
        ),
      );
      final back = ReminderRecord.decode(r.encode());
      expect(back.enabled, isTrue);
      expect(back.askCount, 1);
      expect(back.lastAskedAt, DateTime(2026, 11, 1, 9));
      expect(back.anchor!.instanceId, 'i1');
      expect(back.anchor!.worldTitle, 'The Iron Verdict');
    });

    test('corrupt or missing blobs are an empty record', () {
      for (final raw in [null, '', 'not json', '[1]', '{"askCount":"x"}']) {
        final r = ReminderRecord.decode(raw);
        expect(r.enabled, isFalse);
        expect(r.askCount, 0);
        expect(r.anchor, isNull);
      }
    });
  });
}
