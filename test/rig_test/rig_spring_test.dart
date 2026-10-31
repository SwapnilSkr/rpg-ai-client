import 'package:everlore/debug/rig_test/rig_spring.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the hair spring overshoots once after a step, then settles', () {
    final s = Spring(
      stiffness: RigTuning.hairStiffness,
      damping: RigTuning.hairDamping,
    );
    var peak = 0.0;
    var risesAboveBand = 0;
    var above = false;
    for (var i = 0; i < 60 * 5; i++) {
      s.step(1, 1 / 60);
      if (s.position > peak) peak = s.position;
      final now = s.position > 1.01;
      if (now && !above) risesAboveBand++;
      above = now;
    }
    expect(peak, inInclusiveRange(1.08, 1.3), reason: 'visible but not wild');
    expect(risesAboveBand, 1, reason: 'one overshoot, not a wobble');
    expect(s.position, closeTo(1, 0.005));
    expect(s.velocity.abs(), lessThan(0.01));
  });

  test('settles back to rest after the head stops', () {
    final s = Spring(stiffness: RigTuning.hairStiffness, damping: RigTuning.hairDamping);
    for (var i = 0; i < 120; i++) {
      s.step(20, 1 / 60); // head slides away
    }
    for (var i = 0; i < 60 * 4; i++) {
      s.step(0, 1 / 60); // and comes back
    }
    expect(s.position.abs(), lessThan(0.05));
  });

  test('a critical spring never overshoots', () {
    final s = Spring.critical(11);
    var peak = 0.0;
    for (var i = 0; i < 300; i++) {
      s.step(1, 1 / 60);
      if (s.position > peak) peak = s.position;
    }
    expect(peak, lessThanOrEqualTo(1.0001));
    expect(s.position, closeTo(1, 0.001));
  });

  test('the result does not depend much on the frame rate', () {
    double run(double dt) {
      final s = Spring(stiffness: 60, damping: 7);
      for (var t = 0.0; t < 1.0; t += dt) {
        s.step(1, dt);
      }
      return s.position;
    }

    expect(run(1 / 30), closeTo(run(1 / 120), 0.03));
  });

  test('a slow frame cannot blow the spring up', () {
    final s = Spring(stiffness: 140, damping: 11);
    for (var i = 0; i < 100; i++) {
      s.step(1, 0.05);
    }
    expect(s.position, closeTo(1, 0.01));
  });
}
