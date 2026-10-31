import 'dart:math';

import 'package:everlore/debug/rig_test/rig_mouth.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stays within 0..1 and actually moves while a line plays', () {
    final m = MouthFlapper(Random(8))..start();
    var lo = 1.0;
    var hi = 0.0;
    for (var i = 0; i < 60 * 10; i++) {
      m.update(1 / 60);
      expect(m.value, inInclusiveRange(0, 1));
      lo = min(lo, m.value);
      hi = max(hi, m.value);
    }
    expect(hi, greaterThan(0.6));
    expect(lo, lessThan(0.25), reason: 'closed beats between syllables');
  });

  test('closes after the line ends', () {
    final m = MouthFlapper(Random(1))..start();
    for (var i = 0; i < 120; i++) {
      m.update(1 / 60);
    }
    m.stop();
    for (var i = 0; i < 30; i++) {
      m.update(1 / 60); // half a second
    }
    expect(m.value, lessThan(0.01));
    expect(m.isOpen, isFalse);
    // And stays closed.
    for (var i = 0; i < 120; i++) {
      m.update(1 / 60);
      expect(m.value, lessThan(0.01));
    }
  });

  test('is silent until a line starts', () {
    final m = MouthFlapper(Random(1));
    for (var i = 0; i < 60; i++) {
      m.update(1 / 60);
    }
    expect(m.value, 0);
    expect(m.isOpen, isFalse);
  });

  test('beats last 90-160 ms and open beats are at least 0.3', () {
    final m = MouthFlapper(Random(6))..start();
    final lengths = <double>[];
    double? last;
    var run = 0.0;
    const dt = 0.002;
    for (var i = 0; i < 20000; i++) {
      m.update(dt);
      if (last != null && m.target != last) {
        lengths.add(run);
        run = 0;
      }
      if (m.target > 0) expect(m.target, greaterThanOrEqualTo(0.3));
      last = m.target;
      run += dt;
    }
    // Consecutive open beats have different targets, so each change is a beat
    // boundary; none can be shorter than the minimum interval.
    for (final l in lengths.skip(1)) {
      expect(l, greaterThanOrEqualTo(0.09 - 0.003));
    }
  });

  group('the painted mouth is discrete', () {
    test('a beat that flips every frame still holds each shape', () {
      final g = DiscreteMouth();
      const dt = 1 / 60;
      final runs = <int>[];
      var frames = 0;
      var last = g.open;
      var raw = true;
      for (var i = 0; i < 120; i++) {
        raw = !raw; // the worst case: the flapper is unsettled every frame
        g.update(dt, rawOpen: raw);
        frames++;
        if (g.open != last) {
          runs.add(frames);
          frames = 0;
          last = g.open;
        }
      }
      expect(runs, isNotEmpty);
      // The first entry is the time the constructor's shut shape spent on
      // screen before the first beat arrived, counted from the first frame;
      // it had been held since long before, so skip it.
      for (final r in runs.skip(1)) {
        expect(r * dt, greaterThanOrEqualTo(RigTuning.mouthMinHoldSeconds - dt),
            reason: 'a shape lasted $r frames');
      }
    });

    test('a beat that comes after the hold changes at once', () {
      final g = DiscreteMouth();
      const dt = 1 / 60;
      g.update(dt, rawOpen: true);
      expect(g.open, isTrue, reason: 'the first switch is not delayed');
      for (var i = 0; i < 4; i++) {
        g.update(dt, rawOpen: false);
        expect(g.open, isTrue, reason: 'inside the hold');
      }
      g.update(dt, rawOpen: false);
      expect(g.open, isFalse, reason: 'held five frames, then shut');
    });

    test('stays shut while the beat is shut', () {
      final g = DiscreteMouth();
      for (var i = 0; i < 120; i++) {
        g.update(1 / 60, rawOpen: false);
        expect(g.open, isFalse);
      }
    });
  });
}
