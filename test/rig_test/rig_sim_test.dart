import 'dart:math';

import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:everlore/debug/rig_test/rig_script.dart';
import 'package:everlore/debug/rig_test/rig_sim.dart';
import 'package:flutter_test/flutter_test.dart';

RigSim _sim([int seed = 1]) => RigSim(
      deformer: const RigDeformer(
        RigGeometry(neck: Offset(512, 650), waist: Offset(512, 1536)),
      ),
      random: Random(seed),
    );

void _run(RigSim s, double seconds, {double dt = 1 / 60}) {
  for (var t = 0.0; t < seconds; t += dt) {
    s.update(dt);
  }
}

void main() {
  test('idle drift stays small: about 3% turn and 1.5 degrees of roll', () {
    final s = _sim();
    var turn = 0.0;
    var roll = 0.0;
    for (var t = 0.0; t < 120; t += 1 / 60) {
      s.update(1 / 60);
      turn = max(turn, s.pose.headX.abs());
      roll = max(roll, s.pose.headTilt.abs());
    }
    expect(turn, inInclusiveRange(0.015, 0.04));
    expect(roll, inInclusiveRange(0.012, 0.03));
  });

  test('breath is a 3.6 s cycle between 0 and 1', () {
    final s = _sim();
    var lo = 1.0;
    var hi = 0.0;
    _run(s, 3.6);
    for (var t = 0.0; t < 7.2; t += 1 / 60) {
      s.update(1 / 60);
      lo = min(lo, s.pose.breath);
      hi = max(hi, s.pose.breath);
    }
    expect(lo, lessThan(0.02));
    expect(hi, greaterThan(0.98));
  });

  test('Talk plays the four lines in order, each with its expression', () {
    final s = _sim();
    final seen = <String>[];
    s.subtitle.addListener(() {
      if (s.subtitle.value != null) seen.add(s.subtitle.value!);
    });
    final expressions = <RigExpression>[];
    s.talk();
    for (var t = 0.0; t < 11; t += 1 / 60) {
      s.update(1 / 60);
      if (expressions.isEmpty || expressions.last != s.expression.target) {
        expressions.add(s.expression.target);
      }
    }
    expect(seen, [for (final l in talkLines) l.text]);
    expect(expressions, [
      RigExpression.neutral, // line one is neutral, so it is already there
      RigExpression.happy,
      RigExpression.shy,
      RigExpression.surprised,
      RigExpression.neutral, // back to rest when the last line ends
    ]);
    expect(s.isTalking, isFalse);
    expect(s.subtitle.value, isNull);
  });

  test('the mouth opens while a line plays and is shut when it is over', () {
    final s = _sim();
    s.talk();
    var peak = 0.0;
    for (var t = 0.0; t < 2.0; t += 1 / 60) {
      s.update(1 / 60);
      peak = max(peak, s.pose.mouthOpen);
    }
    expect(peak, greaterThan(0.5));
    _run(s, 9);
    expect(s.pose.mouthOpen, lessThan(0.01));
  });

  test('a line nods the head at its start', () {
    final s = _sim();
    _run(s, 0.5);
    final before = s.pose.headY;
    s.talk();
    var peak = before;
    for (var t = 0.0; t < 0.6; t += 1 / 60) {
      s.update(1 / 60);
      peak = max(peak, s.pose.headY);
    }
    expect(peak - before, greaterThan(0.015));
  });

  test('Look away turns about 12%, glances the same way, and comes back', () {
    final s = _sim();
    _run(s, 0.5);
    s.lookAway();
    var turn = 0.0;
    var glance = 0.0;
    for (var t = 0.0; t < 1.4; t += 1 / 60) {
      s.update(1 / 60);
      turn = max(turn, s.pose.headX);
      glance = max(glance, s.pose.eyeX);
    }
    expect(turn, inInclusiveRange(0.10, 0.16));
    expect(glance, greaterThan(0.8));
    _run(s, 2.5);
    expect(s.isLookingAway, isFalse);
    expect(s.pose.headX.abs(), lessThan(0.05));
    expect(s.pose.eyeX.abs(), lessThan(0.05));
  });

  test('hair trails the head and settles when it stops', () {
    final s = _sim();
    s.lookAway();
    var lag = 0.0;
    for (var t = 0.0; t < 1.5; t += 1 / 60) {
      s.update(1 / 60);
      for (final v in s.longHairLag) {
        lag = max(lag, v.abs());
      }
    }
    expect(lag, greaterThan(1), reason: 'the tips visibly trail');
    expect(lag, lessThan(40), reason: 'but not absurdly');
    _run(s, 3);
    for (final v in s.longHairLag) {
      expect(v.abs(), lessThan(1.5));
    }
  });

  test('every layer alpha stays within 0..1 over a long run', () {
    final s = _sim(5)..talk();
    for (var t = 0.0; t < 60; t += 1 / 60) {
      if (t.floor() % 12 == 5) s.lookAway();
      if (t.floor() % 7 == 3) s.nextExpression();
      s.update(1 / 60);
      for (final e in RigExpression.values) {
        expect(s.patchAlpha(e), inInclusiveRange(0, 1));
        expect(s.mouthAlpha(e), inInclusiveRange(0, 1));
      }
      for (final a in [
        s.halfAlpha,
        s.closedAlpha,
        s.glanceAlpha(right: true),
        s.glanceAlpha(right: false),
      ]) {
        expect(a, inInclusiveRange(0, 1));
      }
    }
  });

  test('the paper doll switches layers instead of blending them', () {
    final s = _sim()..setMode(RigMode.paperDoll);
    s.nextExpression(); // happy
    _run(s, 0.05);
    expect(s.patchAlpha(RigExpression.happy), 1);
    s.talk();
    final seen = <double>{};
    for (var t = 0.0; t < 3; t += 1 / 60) {
      s.update(1 / 60);
      seen.add(s.mouthAlpha(s.expression.target));
      seen.add(s.closedAlpha);
      seen.add(s.halfAlpha);
    }
    expect(seen.difference({0.0, 1.0}), isEmpty);
    expect(seen, contains(1.0));
  });

  test('the paper doll shows a glance only while looking away', () {
    final s = _sim()..setMode(RigMode.paperDoll);
    _run(s, 20);
    expect(s.glanceAlpha(right: true) + s.glanceAlpha(right: false), 0);
    s.lookAway();
    _run(s, 0.8);
    expect(s.glanceAlpha(right: true) + s.glanceAlpha(right: false), 1);
  });

  group('record', () {
    test('runs the 30 s script, then gives the controls back', () {
      final s = _sim();
      s.startRecord();
      expect(s.recording, isTrue);
      final lines = <String>[];
      s.subtitle.addListener(() {
        if (s.subtitle.value != null) lines.add(s.subtitle.value!);
      });
      var lookedAt = -1.0;
      for (var t = 0.0; t < 29.9; t += 1 / 60) {
        s.update(1 / 60);
        if (s.isLookingAway && lookedAt < 0) lookedAt = t;
      }
      expect(s.recording, isTrue);
      expect(lines.length, 4);
      expect(lookedAt, closeTo(20, 0.1));
      _run(s, 0.2);
      expect(s.recording, isFalse);
    });

    test('is identical every time, whatever the sim was seeded with', () {
      final a = _sim(1)..startRecord();
      final b = _sim(2)..startRecord();
      for (var i = 0; i < 60 * 12; i++) {
        a.update(1 / 60);
        b.update(1 / 60);
        expect(a.pose.eyeOpen, b.pose.eyeOpen);
        expect(a.pose.mouthOpen, b.pose.mouthOpen);
        expect(a.pose.eyeX, b.pose.eyeX);
        expect(a.pose.headX, b.pose.headX);
      }
    });

    test('the script adds up to 30 s: 8 idle, 10 of lines, look away, 4 idle', () {
      final talk = RecordScript.events.first;
      final look = RecordScript.events.last;
      expect(talk.at, 8);
      expect(talk.at + talkLines.fold<double>(0, (a, l) => a + l.seconds), 18);
      expect(look.at, greaterThanOrEqualTo(18));
      expect(look.at + RigSim.lookAwaySeconds + 4, lessThanOrEqualTo(RecordScript.total));
      expect(RecordScript.total, 30);
    });
  });
}
