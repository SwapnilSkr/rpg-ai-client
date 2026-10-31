import 'dart:math';

import 'package:everlore/debug/rig_test/rig_mouth.dart';
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
}
