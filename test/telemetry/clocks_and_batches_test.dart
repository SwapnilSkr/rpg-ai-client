import 'dart:convert';

import 'package:everlore/core/telemetry/clocks.dart';
import 'package:everlore/core/telemetry/queue.dart';
import 'package:everlore/core/telemetry/sender.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_store.dart';

QueueItem item(
  int n, {
  String kind = 'event',
  String session = 's1',
  DateTime? at,
  String? body,
}) => QueueItem(
  row: n,
  kind: kind,
  itemId: 'id$n',
  sessionId: session,
  appVersion: '1.0.11',
  appBuild: 14,
  atMs: (at ?? DateTime.utc(2026, 10, 24, 10)).millisecondsSinceEpoch,
  body: body ?? jsonEncode({'id': 'id$n', 'seq': n, 'name': 'persona_created'}),
);

const envelope = Envelope(
  installId: 'i',
  appVersion: '1.0.11',
  appBuild: 14,
  device: {'os': 'android'},
);
final now = DateTime.utc(2026, 10, 24, 10, 5);

void main() {
  group('queue', () {
    test('past the cap the oldest go first and order is kept', () async {
      final store = MemoryTelemetryStore();
      final queue = TelemetryQueue(store, cap: 5);
      for (var i = 1; i <= 8; i++) {
        await queue.add(item(i));
      }
      final left = await store.peek(100);
      expect(left.map((i) => i.itemId), ['id4', 'id5', 'id6', 'id7', 'id8']);
    });

    test('the real cap is 2000', () => expect(queueCap, 2000));

    test('a duplicate id is not queued twice', () async {
      final store = MemoryTelemetryStore();
      final queue = TelemetryQueue(store);
      await queue.add(item(1));
      await queue.add(item(1));
      expect(await store.count(), 1);
    });
  });

  group('buildBatch', () {
    test('at most 100 events and 10 errors per request', () {
      final queued = [
        for (var i = 1; i <= 150; i++) item(i),
        for (var i = 151; i <= 165; i++) item(i, kind: 'error'),
      ];
      final batch = buildBatch(
        queued,
        envelope: envelope,
        authed: true,
        now: now,
      );
      final json = jsonDecode(batch.body) as Map<String, dynamic>;
      expect((json['events'] as List).length, 100);
      expect((json['errors'] as List).length, 10);
    });

    test('unauthenticated batches carry at most 20 events', () {
      final batch = buildBatch(
        [for (var i = 1; i <= 60; i++) item(i)],
        envelope: envelope,
        authed: false,
        now: now,
      );
      expect((jsonDecode(batch.body)['events'] as List).length, 20);
    });

    test('the body stays under 64 KB and the rest waits', () {
      final fat = 'x' * 4000;
      final queued = [
        for (var i = 1; i <= 40; i++)
          item(i, body: jsonEncode({'id': 'id$i', 'pad': fat})),
      ];
      final batch = buildBatch(
        queued,
        envelope: envelope,
        authed: true,
        now: now,
      );
      expect(utf8.encode(batch.body).length, lessThanOrEqualTo(64000));
      expect(batch.items.length, lessThan(40));
      expect(batch.items, isNotEmpty);
    });

    test('one request never mixes sessions', () {
      final batch = buildBatch(
        [item(1), item(2, session: 's2'), item(3)],
        envelope: envelope,
        authed: true,
        now: now,
      );
      expect(batch.items.map((i) => i.itemId), ['id1', 'id3']);
      expect(jsonDecode(batch.body)['session_id'], 's1');
    });

    test('items older than the server accepts are discarded, not sent', () {
      final old = now.subtract(const Duration(days: 8));
      final batch = buildBatch(
        [item(1, at: old), item(2)],
        envelope: envelope,
        authed: true,
        now: now,
      );
      expect(batch.items.map((i) => i.itemId), ['id2']);
      expect(batch.discard.map((i) => i.itemId), ['id1']);
    });
  });

  group('FlushBackoff', () {
    test('30 s, doubling, capped at 10 min, cleared by success', () {
      final b = FlushBackoff();
      final t = DateTime.utc(2026, 1, 1);
      expect(b.failed(t), const Duration(seconds: 30));
      expect(b.failed(t), const Duration(minutes: 1));
      expect(b.failed(t), const Duration(minutes: 2));
      for (var i = 0; i < 10; i++) {
        b.failed(t);
      }
      expect(b.failed(t), const Duration(minutes: 10));
      expect(b.blocked(t), isTrue);
      expect(b.blocked(t.add(const Duration(minutes: 11))), isFalse);
      b.succeeded();
      expect(b.blocked(t), isFalse);
      expect(b.failed(t), const Duration(seconds: 30));
    });

    test('Retry-After overrides the schedule', () {
      final b = FlushBackoff();
      final t = DateTime.utc(2026, 1, 1);
      b.retryAfter(const Duration(seconds: 90), t);
      expect(b.blocked(t.add(const Duration(seconds: 89))), isTrue);
      expect(b.blocked(t.add(const Duration(seconds: 91))), isFalse);
    });
  });

  group('SessionClock', () {
    test('a short trip away keeps the session, 30 minutes starts a new one', () {
      var n = 0;
      final clock = SessionClock(newId: () => 's${++n}');
      var t = DateTime.utc(2026, 1, 1, 12);
      expect(clock.id, 's1');
      clock.paused(t);
      expect(clock.resumed(t.add(const Duration(minutes: 29))), isFalse);
      expect(clock.id, 's1');
      t = t.add(const Duration(hours: 1));
      clock.paused(t);
      expect(clock.resumed(t.add(const Duration(minutes: 30))), isTrue);
      expect(clock.id, 's2');
    });
  });

  group('ScreenClock', () {
    test('time in the background is not counted', () {
      final clock = ScreenClock();
      var t = DateTime.utc(2026, 1, 1, 12);
      clock.enter('discover', t);
      t = t.add(const Duration(seconds: 10));
      final partial = clock.pause(t)!;
      expect(partial.durationMs, 10000);
      expect(partial.partial, isTrue);
      // A night in the background.
      t = t.add(const Duration(hours: 9));
      clock.resume(t);
      t = t.add(const Duration(seconds: 5));
      final left = clock.enter('play', t)!;
      expect(left.screen, 'discover');
      expect(left.durationMs, 5000);
      expect(left.partial, isFalse);
      expect(clock.current, 'play');
    });

    test('from names the previous screen; the same screen is not a move', () {
      final clock = ScreenClock();
      final t = DateTime.utc(2026, 1, 1);
      expect(clock.enter('home', t), isNull);
      expect(clock.enter('home', t), isNull);
      clock.enter('discover', t.add(const Duration(seconds: 1)));
      final left = clock.enter('play', t.add(const Duration(seconds: 3)))!;
      expect(left.from, 'home');
      expect(left.toProps()['from'], 'home');
    });
  });
}
