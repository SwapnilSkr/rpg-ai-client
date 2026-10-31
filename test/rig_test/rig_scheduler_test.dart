import 'dart:math';

import 'package:everlore/debug/rig_test/rig_scheduler.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every phase change over [seconds], with the time it happened.
List<(double, BlinkPhase)> _changes(
  BlinkScheduler b,
  double seconds, {
  bool withHalf = true,
}) {
  const dt = 0.002;
  final out = <(double, BlinkPhase)>[];
  var last = BlinkPhase.open;
  for (var t = 0.0; t < seconds; t += dt) {
    final p = b.phase(t, withHalf: withHalf);
    if (p != last) out.add((t, p));
    last = p;
  }
  return out;
}

void main() {
  group('BlinkScheduler', () {
    test('blink groups start 2-6 s apart, from any seed', () {
      for (final seed in [1, 7, 42, 2026]) {
        final b = BlinkScheduler(Random(seed));
        final starts = <double>[];
        var seen = 0;
        for (var t = 0.0; t < 600; t += 1 / 60) {
          b.phase(t);
          if (b.groups != seen) {
            seen = b.groups;
            starts.add(b.lastGroupStart);
          }
        }
        expect(starts.length, greaterThan(100));
        for (var i = 1; i < starts.length; i++) {
          final gap = starts[i] - starts[i - 1];
          expect(gap, inInclusiveRange(2, 6), reason: 'seed $seed blink $i');
        }
      }
    });

    test('a blink steps half, shut, half for their tuned holds', () {
      final b = BlinkScheduler(Random(3));
      final changes = _changes(b, 10);
      final firstHalf = changes.indexWhere((c) => c.$2 == BlinkPhase.half);
      expect(firstHalf, greaterThanOrEqualTo(0), reason: 'a blink happened');
      expect(
        changes.sublist(firstHalf, firstHalf + 3).map((c) => c.$2),
        [BlinkPhase.half, BlinkPhase.closed, BlinkPhase.half],
        reason: 'open, half, shut, half, open — never any other order',
      );
      expect(changes[firstHalf + 3].$2, BlinkPhase.open);
      expect(changes[firstHalf + 1].$1 - changes[firstHalf].$1,
          closeTo(RigTuning.blinkHalfHold, 0.003));
      expect(changes[firstHalf + 2].$1 - changes[firstHalf + 1].$1,
          closeTo(RigTuning.blinkClosedHold, 0.003));
      expect(changes[firstHalf + 3].$1 - changes[firstHalf + 2].$1,
          closeTo(RigTuning.blinkHalfHold, 0.003));
    });

    test('without a half step the blink is one shut of its own length', () {
      final b = BlinkScheduler(Random(3));
      final changes = _changes(b, 10, withHalf: false);
      expect(changes.every((c) => c.$2 != BlinkPhase.half), isTrue,
          reason: 'the half-lid drawing is a neutral-face painting');
      final firstClosed = changes.indexWhere((c) => c.$2 == BlinkPhase.closed);
      expect(firstClosed, greaterThanOrEqualTo(0));
      expect(changes[firstClosed + 1].$2, BlinkPhase.open);
      expect(changes[firstClosed + 1].$1 - changes[firstClosed].$1,
          closeTo(RigTuning.blinkClosedHoldExpression, 0.003));
    });

    test('same seed, same blinks; and some of them are doubles', () {
      List<BlinkPhase> run() {
        final b = BlinkScheduler(Random(99));
        final out = <BlinkPhase>[];
        for (var t = 0.0; t < 120; t += 0.01) {
          out.add(b.phase(t));
        }
        return out;
      }

      final a = run();
      expect(run(), a);
      // A double shows as two closures within ~0.3 s of each other.
      final closures = <int>[];
      for (var i = 1; i < a.length; i++) {
        if (a[i] == BlinkPhase.closed && a[i - 1] != BlinkPhase.closed) {
          closures.add(i);
        }
      }
      var doubles = 0;
      for (var i = 1; i < closures.length; i++) {
        if (closures[i] - closures[i - 1] < 40) doubles++;
      }
      expect(doubles, greaterThan(0));
    });

    test('is open at the very start', () {
      expect(BlinkScheduler(Random(5)).phase(0), BlinkPhase.open);
    });
  });

  group('GlanceScheduler', () {
    test('glances start 1.5-4 s apart and hold 0.4-1.2 s', () {
      final g = GlanceScheduler(Random(11));
      final starts = <double>[];
      final holds = <double>[];
      var seen = 0;
      double? heldFrom;
      for (var t = 0.0; t < 400; t += 1 / 120) {
        final v = g.update(t);
        if (g.glances != seen) {
          seen = g.glances;
          starts.add(g.lastStart);
          heldFrom = g.lastStart;
        }
        if (v == 0 && heldFrom != null) {
          holds.add(t - heldFrom);
          heldFrom = null;
        }
      }
      expect(starts.length, greaterThan(80));
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i] - starts[i - 1], inInclusiveRange(1.5, 4));
      }
      for (final h in holds) {
        expect(h, inInclusiveRange(0.4 - 0.01, 1.2 + 0.01));
      }
    });

    test('the target stays within -1..1 and looks both ways', () {
      final g = GlanceScheduler(Random(2));
      var sawLeft = false;
      var sawRight = false;
      for (var t = 0.0; t < 120; t += 0.02) {
        final v = g.update(t);
        expect(v, inInclusiveRange(-1, 1));
        if (v < 0) sawLeft = true;
        if (v > 0) sawRight = true;
      }
      expect(sawLeft && sawRight, isTrue);
    });

    test('nothing starts while it is disabled, and nothing is owed after', () {
      final g = GlanceScheduler(Random(11));
      for (var t = 0.0; t < 60; t += 1 / 60) {
        expect(g.update(t, enabled: false), 0);
      }
      expect(g.glances, 0, reason: 'an expression face never glances');
      // The clock kept running, so the first glance after turning back to
      // neutral is at most one gap away.
      var firstAt = double.nan;
      for (var t = 60.0; t < 65; t += 1 / 60) {
        final was = g.glances;
        g.update(t, enabled: true);
        if (g.glances != was && firstAt.isNaN) firstAt = t;
      }
      expect(g.glances, greaterThan(0));
      expect(firstAt - 60, lessThanOrEqualTo(GlanceScheduler.maxGap + 1 / 60));
    });
  });

  test('SmoothNoise stays in range and is continuous', () {
    final n = SmoothNoise(Random(4));
    var last = n.sample(0);
    for (var t = 0.0; t < 60; t += 0.01) {
      final v = n.sample(t);
      expect(v, inInclusiveRange(-1, 1));
      expect((v - last).abs(), lessThan(0.05));
      last = v;
    }
  });
}
