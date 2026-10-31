import 'dart:math';

import 'package:everlore/debug/rig_test/rig_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlinkScheduler', () {
    test('blink groups start 2-6 s apart, from any seed', () {
      for (final seed in [1, 7, 42, 2026]) {
        final b = BlinkScheduler(Random(seed));
        final starts = <double>[];
        var seen = 0;
        for (var t = 0.0; t < 600; t += 1 / 60) {
          b.update(t);
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

    test('a blink goes open, half, closed, half, open in about 150 ms', () {
      final b = BlinkScheduler(Random(3));
      final samples = <double>[];
      var start = double.nan;
      for (var t = 0.0; t < 10; t += 0.005) {
        final v = b.update(t);
        if (start.isNaN && b.groups > 0) start = b.lastGroupStart;
        if (!start.isNaN && t >= start && t <= start + 0.15) samples.add(v);
      }
      expect(samples.first, greaterThan(0.9));
      expect(samples.reduce(min), 0);
      expect(samples.any((v) => (v - 0.5).abs() < 0.12), isTrue,
          reason: 'half-closed in-between frame on the way');
      expect(samples.last, greaterThan(0.9));
      // Down then up, no flicker in between.
      final low = samples.indexOf(0);
      for (var i = 1; i < low; i++) {
        expect(samples[i], lessThanOrEqualTo(samples[i - 1] + 1e-9));
      }
    });

    test('same seed, same blinks; and some of them are doubles', () {
      List<double> run() {
        final b = BlinkScheduler(Random(99));
        final out = <double>[];
        for (var t = 0.0; t < 120; t += 0.01) {
          out.add(b.update(t));
        }
        return out;
      }

      final a = run();
      expect(run(), a);
      // A double shows as two closures within ~0.3 s of each other.
      var closures = <int>[];
      for (var i = 1; i < a.length; i++) {
        if (a[i] == 0 && a[i - 1] != 0) closures.add(i);
      }
      var doubles = 0;
      for (var i = 1; i < closures.length; i++) {
        if (closures[i] - closures[i - 1] < 40) doubles++;
      }
      expect(doubles, greaterThan(0));
    });

    test('is open at the very start', () {
      expect(BlinkScheduler(Random(5)).update(0), 1);
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
