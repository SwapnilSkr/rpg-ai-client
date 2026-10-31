import 'dart:math';

import 'package:everlore/debug/rig_test/rig_mouth.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

/// One held state of the painted mouth: how long it was on screen, in frames.
typedef _Run = ({bool open, int frames});

/// The painted mouth's runs over [seconds] of a line begun at frame zero.
List<_Run> _paintedRuns({
  required int seed,
  required double seconds,
  double dt = 1 / 60,
}) {
  final flap = MouthFlapper(Random(seed))..start();
  final g = DiscreteMouth();
  final runs = <_Run>[];
  for (var i = 0; i < (seconds / dt).round(); i++) {
    flap.update(dt);
    g.update(dt, rawOpen: flap.isOpen);
    if (runs.isNotEmpty && runs.last.open == g.open) {
      runs[runs.length - 1] = (open: g.open, frames: runs.last.frames + 1);
    } else {
      runs.add((open: g.open, frames: 1));
    }
  }
  return runs;
}

void main() {
  test('stays within 0..1 and actually moves while a line plays', () {
    final m = MouthFlapper(Random(8))..start();
    var lo = 1.0;
    var hi = 0.0;
    for (var i = 0; i < 60 * 10; i++) {
      m.update(1 / 60);
      expect(m.value, inInclusiveRange(0, 1));
      if (m.isOpen) {
        expect(m.target, greaterThanOrEqualTo(RigTuning.mouthMinOpen));
        expect(m.target, lessThanOrEqualTo(1));
      } else {
        expect(m.target, 0);
      }
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

  test('beats alternate, each lasting its tuned span', () {
    final m = MouthFlapper(Random(6))..start();
    const dt = 0.002;
    final spans = <({bool open, double seconds})>[];
    var open = m.isOpen;
    var run = 0.0;
    for (var i = 0; i < 6000; i++) {
      m.update(dt);
      run += dt;
      if (m.isOpen != open) {
        spans.add((open: open, seconds: run));
        run = 0;
        open = m.isOpen;
      }
    }
    // The first span is the shut mouth before the line's first syllable, and the
    // last is cut by the end of the loop.
    final beats = spans.skip(1).toList();
    expect(beats.length, greaterThan(10), reason: 'the mouth flapped');
    for (var i = 0; i < beats.length - 1; i++) {
      expect(beats[i + 1].open, isNot(beats[i].open),
          reason: 'open and shut never meet as two of a kind');
    }
    for (final b in beats.take(beats.length - 1)) {
      // A shut beat is either the gap between syllables or a pause.
      final lo = b.open
          ? RigTuning.mouthOpenMinSeconds
          : RigTuning.mouthShutMinSeconds;
      final hi = b.open
          ? RigTuning.mouthOpenMaxSeconds
          : RigTuning.mouthPauseMaxSeconds;
      expect(b.seconds, greaterThanOrEqualTo(lo - dt),
          reason: 'an ${b.open ? 'open' : 'shut'} beat of ${b.seconds} s');
      expect(b.seconds, lessThanOrEqualTo(hi + dt),
          reason: 'an ${b.open ? 'open' : 'shut'} beat of ${b.seconds} s');
    }
  });

  test('a line starts on an open beat', () {
    final m = MouthFlapper(Random(4))..start();
    m.update(1 / 60);
    expect(m.isOpen, isTrue);
  });

  group('the painted mouth is discrete', () {
    test('property: 12 s of talking never holds one drawing too long', () {
      const dt = 1 / 60;
      for (final seed in [1, 7, 41]) {
        final runs = _paintedRuns(seed: seed, seconds: 12, dt: dt);
        expect(runs.length, greaterThan(20), reason: 'it flapped, seed $seed');
        expect(runs.any((r) => r.open), isTrue, reason: 'seed $seed');
        expect(runs.any((r) => !r.open), isTrue, reason: 'seed $seed');
        // The last run is cut by the end of the loop rather than by the mouth.
        for (var i = 0; i < runs.length - 1; i++) {
          final r = runs[i];
          final where = 'seed $seed run $i: ${r.frames} frames';
          if (r.open) {
            // An open drawing held for more than a fifth of a second is the
            // frozen mouth the owner saw.
            expect(r.frames * dt,
                lessThanOrEqualTo(RigTuning.mouthOpenMaxSeconds + dt),
                reason: 'open too long, $where');
          } else {
            expect(r.frames * dt,
                greaterThanOrEqualTo(RigTuning.mouthMinHoldSeconds - dt),
                reason: 'a shape shown for less than the hold, $where');
          }
        }
        // Every open run is followed by a shut one: the machine alternates, so
        // two runs of a kind can only be separated by the other.
        for (var i = 0; i + 1 < runs.length; i++) {
          expect(runs[i + 1].open, isNot(runs[i].open),
              reason: 'seed $seed run $i');
        }
      }
    });

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
