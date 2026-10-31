import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'rig_deform.dart';
import 'rig_expression.dart';
import 'rig_mouth.dart';
import 'rig_scheduler.dart';
import 'rig_script.dart';
import 'rig_spring.dart';
import 'rig_tuning.dart';

enum RigMode { paperDoll, mesh }

/// All the rig's moving parts, with no drawing in it.
///
/// [update] advances time; every input is smoothed toward a target so the
/// painter only reads [pose], the layer alphas and the hair lag. Both modes run
/// this same simulation (the paper doll just reads it more coarsely), so a
/// recorded A clip and B clip share their blinks, glances and mouth beats.
class RigSim extends ChangeNotifier {
  RigSim({required this.deformer, math.Random? random}) {
    _build(random ?? math.Random());
  }

  final RigDeformer deformer;

  RigMode mode = RigMode.mesh;
  bool outfit = false;

  /// True while the 30 s record clip runs.
  bool get recording => _recording;

  /// Bumped when anything the control bar shows changes.
  final ValueNotifier<int> uiRevision = ValueNotifier<int>(0);

  /// The line being spoken, or null.
  final ValueNotifier<String?> subtitle = ValueNotifier<String?>(null);

  final RigPose pose = RigPose();
  double time = 0;

  late ExpressionBlend expression;
  late MouthFlapper mouth;
  late BlinkScheduler _blink;
  late GlanceScheduler _glance;
  late SmoothNoise _noise;

  // Smoothers: critically damped, so a changed target eases in.
  late Spring _headX, _headY, _tilt, _bodyX, _eyeX;

  /// One spring per hair_long vertex column and one for the bangs.
  late List<Spring> _longHair;
  late Spring _frontHair;

  /// How far each hair_long column trails the head, px (already scaled by the
  /// lag gain). Read by the painter.
  late Float64List longHairLag;
  double frontHairLag = 0;

  bool _recording = false;
  double _recordStart = 0;
  int _nextEvent = 0;

  // Talk.
  int _line = -1;
  double _lineAge = 0;
  double _nodAge = double.infinity;

  // Look away.
  static const double lookAwaySeconds = 1.5;
  static const double lookAwayTurn = 0.12;
  static const double lookAwayPitch = 0.10;
  double _lookAge = double.infinity;
  double _lookSide = 1;
  double _nextLookSide = 1;

  bool get isTalking => _line >= 0;
  bool get isLookingAway => _lookAge < lookAwaySeconds;
  double get lookSide => _lookSide;

  void _build(math.Random seedSource) {
    math.Random r() => math.Random(seedSource.nextInt(1 << 30));
    expression = ExpressionBlend();
    mouth = MouthFlapper(r());
    _blink = BlinkScheduler(r());
    _glance = GlanceScheduler(r());
    _noise = SmoothNoise(r());
    _headX = Spring.critical(11);
    _headY = Spring.critical(11);
    _tilt = Spring.critical(10);
    _bodyX = Spring.critical(6);
    _eyeX = Spring.critical(25);
    _longHair = [
      for (var c = 0; c < RigTuning.hairColumns; c++) _hairSpring(c),
    ];
    _frontHair = Spring(
      stiffness: RigTuning.frontStiffness,
      damping: RigTuning.frontDamping,
    );
    longHairLag = Float64List(RigTuning.hairColumns);
    frontHairLag = 0;
    time = 0;
    _line = -1;
    _lineAge = 0;
    _nodAge = double.infinity;
    _lookAge = double.infinity;
    _nextLookSide = 1;
    _nextEvent = 0;
    pose
      ..headX = 0
      ..headY = 0
      ..headTilt = 0
      ..bodyX = 0
      ..breath = 0
      ..eyeOpen = 1
      ..eyeX = 0
      ..mouthOpen = 0;
    subtitle.value = null;
  }

  Spring _hairSpring(int column) {
    // A fixed wobble per column; the damping scales with sqrt(stiffness) so
    // every column keeps the same damping ratio and only its tempo differs.
    final k = RigTuning.hairStiffness *
        (1 + RigTuning.hairColumnVariation * math.sin(column * 2.1 + 0.7));
    final c = RigTuning.hairDamping * math.sqrt(k / RigTuning.hairStiffness);
    return Spring(stiffness: k, damping: c);
  }

  // ---- Commands -----------------------------------------------------------

  void setMode(RigMode m) {
    if (m == mode) return;
    mode = m;
    _touchUi();
  }

  void setOutfit(bool on) {
    if (on == outfit) return;
    outfit = on;
    _touchUi();
  }

  void nextExpression() {
    if (isTalking) return;
    final all = RigExpression.values;
    expression.set(all[(expression.target.index + 1) % all.length]);
    _touchUi();
  }

  /// Plays the four scripted lines.
  void talk() {
    if (isTalking) return;
    _beginLine(0);
    _touchUi();
  }

  void lookAway() {
    if (isLookingAway) return;
    _lookSide = _nextLookSide;
    _nextLookSide = -_nextLookSide;
    _lookAge = 0;
  }

  /// Restarts the simulation from a fixed seed and plays the 30 s script.
  void startRecord() {
    if (_recording) return;
    _build(math.Random(RecordScript.seed));
    _recording = true;
    _recordStart = 0;
    _touchUi();
    notifyListeners();
  }

  void _touchUi() => uiRevision.value++;

  void _beginLine(int i) {
    _line = i;
    _lineAge = 0;
    _nodAge = 0;
    expression.set(talkLines[i].expression);
    mouth.start();
    subtitle.value = talkLines[i].text;
    _touchUi();
  }

  void _endTalk() {
    _line = -1;
    mouth.stop();
    expression.set(RigExpression.neutral);
    subtitle.value = null;
    _touchUi();
  }

  // ---- Frame --------------------------------------------------------------

  void update(double dt) {
    dt = dt.clamp(0.0, 0.05);
    time += dt;
    _runScript();
    _advanceTalk(dt);
    if (_lookAge < double.infinity) _lookAge += dt;
    if (_nodAge < double.infinity) _nodAge += dt;
    expression.update(dt);
    mouth.update(dt);

    final t = time;
    final looking = isLookingAway;

    // Idle drift: two incommensurate slow sines plus a little noise.
    const w = 2 * math.pi;
    final turn = 0.03 *
            (0.62 * math.sin(w * t / 7.3) + 0.38 * math.sin(w * t / 11.9 + 1.3)) +
        0.004 * _noise.sample(t);
    final pitch = 0.015 *
            (0.6 * math.sin(w * t / 8.9 + 0.5) + 0.4 * math.sin(w * t / 5.3)) +
        0.003 * _noise.sample(t + 91.7);
    final roll = 0.0262 *
        (0.6 * math.sin(w * t / 9.1 + 2) + 0.4 * math.sin(w * t / 5.9));
    final sway = 0.28 * math.sin(w * t / 8.3 + 0.9);

    var headX = turn;
    var headY = pitch;
    var tilt = roll;
    if (_nodAge < _nodSeconds) {
      headY += 0.05 * math.sin(math.pi * _nodAge / _nodSeconds);
    }
    var eyeTarget = _glance.update(t);
    if (looking) {
      // Eased in and out so the turn doesn't snap at either end.
      final env = _lookEnvelope(_lookAge);
      headX += _lookSide * lookAwayTurn * env;
      headY += lookAwayPitch * env;
      tilt += _lookSide * 0.02 * env;
      eyeTarget = _lookSide * (env > 0.3 ? 1.0 : 0.0);
    }

    _headX.step(headX, dt);
    _headY.step(headY, dt);
    _tilt.step(tilt, dt);
    _bodyX.step(sway, dt);
    _eyeX.step(eyeTarget, dt);

    pose
      ..headX = _headX.position
      ..headY = _headY.position
      ..headTilt = _tilt.position
      ..bodyX = _bodyX.position
      ..breath = 0.5 - 0.5 * math.cos(w * t / 3.6)
      ..eyeOpen = _blink.update(t)
      ..eyeX = _eyeX.position
      ..mouthOpen = mouth.value;

    // Hair: each column chases where the scalp is; the lag is the difference.
    final drive = deformer.hairDrive(pose);
    for (var c = 0; c < _longHair.length; c++) {
      _longHair[c].step(drive, dt);
      longHairLag[c] = (_longHair[c].position - drive) * RigTuning.hairLagGain;
    }
    _frontHair.step(drive, dt);
    frontHairLag = (_frontHair.position - drive) *
        RigTuning.hairLagGain *
        RigTuning.frontLagScale;

    if (_recording && time - _recordStart >= RecordScript.total) {
      _recording = false;
      _touchUi();
    }
    notifyListeners();
  }

  static const double _nodSeconds = 0.4;

  static double _lookEnvelope(double age) {
    // 0.25 s in, hold, 0.35 s out.
    const inT = 0.25;
    const outT = 0.35;
    if (age < inT) return _ease(age / inT);
    if (age > lookAwaySeconds - outT) {
      return _ease((lookAwaySeconds - age) / outT);
    }
    return 1;
  }

  static double _ease(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  void _runScript() {
    if (!_recording) return;
    final events = RecordScript.events;
    while (_nextEvent < events.length &&
        time - _recordStart >= events[_nextEvent].at) {
      switch (events[_nextEvent].action) {
        case ScriptAction.talk:
          talk();
        case ScriptAction.lookAway:
          lookAway();
      }
      _nextEvent++;
    }
  }

  void _advanceTalk(double dt) {
    if (_line < 0) return;
    _lineAge += dt;
    final line = talkLines[_line];
    if (mouth.talking && _lineAge >= line.seconds - TalkLine.closingBeat) {
      mouth.stop();
    }
    if (_lineAge >= line.seconds) {
      if (_line + 1 < talkLines.length) {
        _beginLine(_line + 1);
      } else {
        _endTalk();
      }
    }
  }

  // ---- What to draw -------------------------------------------------------

  bool get _mesh => mode == RigMode.mesh;

  /// Opacity of the brow/eye/blush patch for [e].
  double patchAlpha(RigExpression e) {
    if (_mesh) return expression.patchAlpha(e);
    return e != RigExpression.neutral && e == expression.target ? 1 : 0;
  }

  /// Opacity of the open-mouth layer for [e].
  double mouthAlpha(RigExpression e) {
    if (_mesh) return pose.mouthOpen * expression.mouthWeight(e);
    return mouth.isOpen && e == expression.target ? 1 : 0;
  }

  double get _lidClosedness => 1 - ((pose.eyeOpen - 0.5) * 2).clamp(0.0, 1.0);

  double get halfAlpha {
    if (!_mesh) return 0;
    // Fades in as the lid starts down; stays under the closed layer.
    return pose.eyeOpen >= 0.5 ? (1 - pose.eyeOpen) * 2 : 1;
  }

  double get closedAlpha {
    if (!_mesh) return pose.eyeOpen < RigTuning.paperClosedBelow ? 1 : 0;
    return pose.eyeOpen >= 0.5 ? 0 : (0.5 - pose.eyeOpen) * 2;
  }

  /// Opacity of the glance layers: -1 left, +1 right.
  double glanceAlpha({required bool right}) {
    if (_mesh) {
      final side = right ? pose.eyeX : -pose.eyeX;
      return side.clamp(0.0, 1.0) * (1 - _lidClosedness);
    }
    if (!isLookingAway || pose.eyeOpen < RigTuning.paperClosedBelow) return 0;
    return (_lookSide > 0) == right ? 1 : 0;
  }
}
