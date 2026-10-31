import 'dart:math';

import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_script.dart';
import 'package:everlore/debug/rig_test/rig_sim.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
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

bool _isGlance(RigEyeState e) =>
    e == RigEyeState.glanceLeft || e == RigEyeState.glanceRight;

/// The invariant: one eye drawing at most, and never a faded one.
void _expectOneEye(RigSim s, [String where = '']) {
  final lit = [
    s.halfAlpha,
    s.closedAlpha,
    s.glanceAlpha(right: false),
    s.glanceAlpha(right: true),
  ].where((a) => a > 0).toList();
  final state = s.eyeState;
  expect(lit.length, lessThanOrEqualTo(1),
      reason: 'two eye drawings in $state $where');
  for (final a in lit) {
    expect(a, 1.0, reason: 'an eye drawing at $a opacity $where');
  }
}

/// The invariant for the face: one patch at most, at exactly full opacity, and
/// it is the expression's own (a neutral face has no patch).
void _expectOnePatch(RigSim s, [String where = '']) {
  final lit =
      RigExpression.values.where((e) => s.patchAlpha(e) > 0).toList();
  expect(lit.length, lessThanOrEqualTo(1), reason: 'two patches $where');
  for (final e in RigExpression.values) {
    final a = s.patchAlpha(e);
    expect(a, anyOf(0.0, 1.0), reason: 'patch ${e.name} at $a $where');
  }
  if (s.expression.shown != RigExpression.neutral) {
    expect(lit, [s.expression.shown], reason: 'the shown patch is not lit $where');
  } else {
    expect(lit, isEmpty, reason: 'the neutral face grew a patch $where');
  }
}

/// The same for the mouth: one open drawing at most, and it belongs to the
/// expression on the face.
void _expectOneMouth(RigSim s, [String where = '']) {
  final lit =
      RigExpression.values.where((e) => s.mouthAlpha(e) > 0).toList();
  expect(lit.length, lessThanOrEqualTo(1), reason: 'two mouths $where');
  for (final e in RigExpression.values) {
    final a = s.mouthAlpha(e);
    expect(a, anyOf(0.0, 1.0), reason: 'mouth ${e.name} at $a $where');
  }
  if (lit.isNotEmpty) {
    expect(lit, [s.expression.shown], reason: 'a stray mouth $where');
  }
}

/// The state of every frame, run-length encoded: (state, frames).
List<({RigEyeState state, int frames})> _runs(List<RigEyeState> states) {
  final out = <({RigEyeState state, int frames})>[];
  for (final st in states) {
    if (out.isNotEmpty && out.last.state == st) {
      out[out.length - 1] = (state: st, frames: out.last.frames + 1);
    } else {
      out.add((state: st, frames: 1));
    }
  }
  return out;
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

  test('Look away turns about 8%, leans the torso with it, and comes back', () {
    final s = _sim();
    _run(s, 0.5);
    s.lookAway();
    var turn = 0.0;
    var glance = 0.0;
    var body = 0.0;
    for (var t = 0.0; t < 1.4; t += 1 / 60) {
      s.update(1 / 60);
      turn = max(turn, s.pose.headX);
      glance = max(glance, s.pose.eyeX);
      body = max(body, s.pose.bodyX);
    }
    // The look away's own 8% plus the idle drift, which is up to 3% by itself.
    expect(turn, inInclusiveRange(0.06, 0.12));
    expect(glance, greaterThan(0.8));
    // The sway alone tops out at 0.28; the shoulders take a share of the turn.
    expect(body, greaterThan(0.4));
    _run(s, 2.5);
    expect(s.isLookingAway, isFalse);
    expect(s.pose.headX.abs(), lessThan(0.05));
    expect(s.pose.eyeX.abs(), lessThan(0.05));
  });

  test('the glance nudge eases in behind the switch, in about 80 ms', () {
    final s = _sim();
    _run(s, 0.5);
    s.lookAway();
    var frames = 0;
    while (!_isGlance(s.eyeState) && frames++ < 60) {
      s.update(1 / 60);
    }
    expect(_isGlance(s.eyeState), isTrue, reason: 'the drawing switched');
    expect(s.pose.eyeX.abs(), lessThan(0.2), reason: 'before the slide');
    _run(s, RigTuning.glanceNudgeSeconds);
    expect(s.pose.eyeX.abs(), closeTo(1, 0.05));
    expect(_isGlance(s.eyeState), isTrue);
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
      _expectOneEye(s);
    }
  });

  test('the paper doll switches layers instead of blending them', () {
    final s = _sim()..setMode(RigMode.paperDoll);
    s.nextExpression(); // happy
    _run(s, 0.1); // past the cover blink's midpoint
    expect(s.patchAlpha(RigExpression.happy), 1);
    s.talk();
    final seen = <double>{};
    for (var t = 0.0; t < 3; t += 1 / 60) {
      s.update(1 / 60);
      seen.add(s.mouthAlpha(s.expression.shown));
      seen.add(s.closedAlpha);
      seen.add(s.halfAlpha);
    }
    expect(seen.difference({0.0, 1.0}), isEmpty);
    expect(seen, contains(1.0));
  });

  test('both modes read the same eye state', () {
    final a = _sim(9);
    final b = _sim(9)..setMode(RigMode.paperDoll);
    for (var i = 0; i < 60 * 30; i++) {
      if (i == 60 * 12) a.lookAway();
      if (i == 60 * 12) b.lookAway();
      a.update(1 / 60);
      b.update(1 / 60);
      expect(b.eyeState, a.eyeState, reason: 'frame $i');
      _expectOneEye(b, 'paper doll');
    }
  });

  test('the paper doll shows a glance while looking away', () {
    final s = _sim()..setMode(RigMode.paperDoll);
    s.lookAway();
    _run(s, 0.8);
    expect(s.glanceAlpha(right: true) + s.glanceAlpha(right: false), 1);
  });

  group('expressions', () {
    test('a change is covered by a shut blink, and the patch swaps mid-hold', () {
      final s = _sim(3);
      const dt = 1 / 60;
      _run(s, 0.5);
      s.nextExpression(); // happy
      final states = <RigEyeState>[];
      final shown = <RigExpression>[];
      for (var i = 0; i < 12; i++) {
        s.update(dt);
        states.add(s.eyeState);
        shown.add(s.expression.shown);
      }
      var closed = 0;
      while (closed < states.length && states[closed] == RigEyeState.closed) {
        closed++;
      }
      expect(closed, greaterThan(0), reason: 'the cover blink ran');
      expect(closed * dt, closeTo(RigTuning.blinkClosedHoldExpression, dt));

      // The patch swaps while the eyes are shut, at the middle of the hold.
      final switchFrame = shown.indexOf(RigExpression.happy);
      expect(switchFrame, greaterThan(0), reason: 'the patch switched');
      expect(switchFrame, lessThan(closed), reason: 'within the shut hold');
      final midpoint = RigTuning.blinkClosedHoldExpression / 2 / dt;
      expect((switchFrame + 1 - midpoint).abs(), lessThanOrEqualTo(1.0));

      expect(s.eyeState, RigEyeState.open, reason: 'reopened on the new face');
      expect(s.patchAlpha(RigExpression.happy), 1);
    });

    test('two quick requests switch the patch once per cover, to the latest', () {
      final s = _sim(3);
      const dt = 1 / 60;
      _run(s, 0.5);
      s.nextExpression(); // happy starts a cover
      s.update(dt); // still before its midpoint
      s.nextExpression(); // shy retargets the pending switch
      var closed = s.eyeState == RigEyeState.closed ? 1 : 0;
      final shown = <RigExpression>[s.expression.shown];
      for (var i = 0; i < 12; i++) {
        s.update(dt);
        if (s.eyeState == RigEyeState.closed) closed++;
        if (shown.last != s.expression.shown) shown.add(s.expression.shown);
      }
      expect(shown, [RigExpression.neutral, RigExpression.shy],
          reason: 'one switch, to the latest');
      expect(s.expression.shown, RigExpression.shy);
      expect(s.expression.target, RigExpression.shy);
      expect(closed * dt, closeTo(RigTuning.blinkClosedHoldExpression, dt),
          reason: 'the retarget did not restart the hold');
    });

    test('while talking no mouth shape is held less than the minimum', () {
      final s = _sim(11)..talk();
      const dt = 1 / 60;
      var last = s.mouthAlpha(s.expression.shown) > 0;
      var run = 0.0;
      final runs = <double>[];
      for (var i = 0; i < 60 * 12; i++) {
        s.update(dt);
        final open = s.mouthAlpha(s.expression.shown) > 0;
        if (open != last) {
          runs.add(run);
          run = 0;
          last = open;
        }
        run += dt;
      }
      expect(runs.length, greaterThan(20), reason: 'the mouth flapped');
      // The first entry ends on the opening beat of the line; nothing was on
      // screen before it.
      for (final r in runs.skip(1)) {
        expect(r, greaterThanOrEqualTo(RigTuning.mouthMinHoldSeconds - dt),
            reason: 'a mouth shape lasted only $r s');
      }
    });

    test('property: 30 s of mode B draws one patch, one mouth, one eye layer', () {
      final rec = _sim(7)..startRecord();
      for (var i = 0; i < 60 * 30; i++) {
        rec.update(1 / 60);
        final where = 'record ${(i / 60).toStringAsFixed(2)} s';
        _expectOnePatch(rec, where);
        _expectOneMouth(rec, where);
        _expectOneEye(rec, where);
      }
    });
  });

  group('eyes', () {
    test('property: 30 s of mode B never draws two eye layers', () {
      final rec = _sim(7)..startRecord();
      for (var i = 0; i < 60 * 30; i++) {
        rec.update(1 / 60);
        _expectOneEye(rec, 'record ${(i / 60).toStringAsFixed(2)} s');
      }
      for (final seed in [1, 2, 3]) {
        final s = _sim(seed)..talk();
        for (var i = 0; i < 60 * 30; i++) {
          if (i % 600 == 0) s.lookAway();
          if (i % 420 == 0) s.nextExpression();
          s.update(1 / 60);
          _expectOneEye(s, 'seed $seed frame $i');
        }
      }
    });

    test('a neutral blink holds half, shut, half for its tuned times', () {
      final s = _sim(3);
      const dt = 1 / 60;
      final states = <RigEyeState>[];
      for (var i = 0; i < 60 * 40; i++) {
        s.update(dt);
        states.add(s.eyeState);
      }
      final runs = _runs(states);
      var at = -1;
      for (var i = 0; i + 2 < runs.length; i++) {
        if (runs[i].state == RigEyeState.half &&
            runs[i + 1].state == RigEyeState.closed &&
            runs[i + 2].state == RigEyeState.half) {
          at = i;
          break;
        }
      }
      expect(at, greaterThan(0), reason: 'half, shut, half happened');
      expect(runs[at].frames * dt, closeTo(RigTuning.blinkHalfHold, dt));
      expect(runs[at + 1].frames * dt, closeTo(RigTuning.blinkClosedHold, dt));
      expect(runs[at + 2].frames * dt, closeTo(RigTuning.blinkHalfHold, dt));
    });

    test('a blink on an expression face never shows the half lid', () {
      final s = _sim(4)..nextExpression(); // happy
      _run(s, 0.3);
      const dt = 1 / 60;
      final closedRuns = <int>[];
      var run = 0;
      for (var i = 0; i < 60 * 20; i++) {
        s.update(dt);
        expect(s.eyeState, anyOf(RigEyeState.open, RigEyeState.closed),
            reason: 'frame $i, happy face');
        if (s.eyeState == RigEyeState.closed) {
          run++;
        } else if (run > 0) {
          closedRuns.add(run);
          run = 0;
        }
      }
      expect(closedRuns, isNotEmpty, reason: 'it did blink');
      for (final r in closedRuns) {
        expect(r * dt, closeTo(RigTuning.blinkClosedHoldExpression, dt));
      }
    });

    test('no glance happens while the face is not neutral', () {
      final s = _sim(5)..nextExpression()..nextExpression(); // shy
      _run(s, 0.3);
      for (var i = 0; i < 60 * 20; i++) {
        s.update(1 / 60);
        expect(_isGlance(s.eyeState), isFalse, reason: 'frame $i');
      }
    });

    test('changing the expression drops a running glance', () {
      final s = _sim(2);
      var frames = 0;
      while (!_isGlance(s.eyeState) && frames++ < 60 * 60) {
        s.update(1 / 60);
      }
      expect(_isGlance(s.eyeState), isTrue, reason: 'a glance got going');
      s.nextExpression();
      s.update(1 / 60);
      expect(_isGlance(s.eyeState), isFalse);
    });

    test('a blink during a glance is covered by the lids, which give it back', () {
      final s = _sim(13);
      var recoveries = 0;
      var blinked = false;
      for (var i = 0; i < 60 * 120; i++) {
        if (i % 180 == 0) s.lookAway(); // a 1.5 s glance every 3 s
        s.update(1 / 60);
        if (!s.isLookingAway) {
          blinked = false;
          continue;
        }
        if (s.eyeState == RigEyeState.half ||
            s.eyeState == RigEyeState.closed) {
          blinked = true;
        } else if (blinked && _isGlance(s.eyeState)) {
          recoveries++;
          blinked = false;
        }
      }
      expect(recoveries, greaterThan(0),
          reason: 'the lids covered a running glance, then the glance returned');
    });

    test('an expression change only ever shows open or shut eyes', () {
      final s = _sim(6);
      for (final e in [
        RigExpression.happy,
        RigExpression.shy,
        RigExpression.surprised,
        RigExpression.neutral,
      ]) {
        s.expression.set(e);
        for (var i = 0; i < 6; i++) {
          s.update(1 / 60);
          expect(s.eyeState, anyOf(RigEyeState.open, RigEyeState.closed),
              reason: 'during the cover blink to ${e.name}');
          _expectOnePatch(s, 'during the cover blink to ${e.name}');
        }
      }
    });
  });

  group('benchmark', () {
    test('runs 20 s in mode B with the outfit, talking and looking away', () {
      final s = _sim()..startBenchmark();
      expect(s.benchmarking, isTrue);
      expect(s.mode, RigMode.mesh);
      expect(s.outfit, isTrue);
      var looks = 0;
      var wasLooking = false;
      var talkingFrames = 0;
      for (var i = 0; i < 60 * 21; i++) {
        s.update(1 / 60);
        if (s.isLookingAway && !wasLooking) looks++;
        wasLooking = s.isLookingAway;
        if (s.isTalking) talkingFrames++;
        if (i < 60 * 19) expect(s.benchmarking, isTrue);
      }
      expect(s.benchmarking, isFalse);
      expect(looks, greaterThanOrEqualTo(3), reason: 'a look away every few s');
      expect(talkingFrames, greaterThan(60 * 18), reason: 'constant load');
    });

    test('a record clip and the benchmark never run together', () {
      final s = _sim()..startBenchmark();
      s.startRecord();
      expect(s.recording, isFalse);
      expect(s.benchmarking, isTrue);
      final r = _sim()..startRecord();
      r.startBenchmark();
      expect(r.benchmarking, isFalse);
      expect(r.recording, isTrue);
    });
  });

  group('quality', () {
    test('the low tier halves the hair springs, which still swing', () {
      final s = _sim();
      expect(s.longHairLag.length, RigTuning.hairColumnsHigh);
      s.setQuality(RigQuality.low);
      expect(s.longHairLag.length, RigTuning.hairColumnsLow);
      s.lookAway();
      _run(s, 1.5);
      var lag = 0.0;
      for (final v in s.longHairLag) {
        expect(v.isFinite, isTrue);
        lag = max(lag, v.abs());
      }
      expect(lag, greaterThan(0.5), reason: 'the remaining springs still swing');
    });
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
        expect(a.eyeState, b.eyeState);
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
