import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'rig_deform.dart';
import 'rig_expression.dart';
import 'rig_mouth.dart';
import 'rig_quality.dart';
import 'rig_scheduler.dart';
import 'rig_script.dart';
import 'rig_spring.dart';
import 'rig_tuning.dart';

enum RigMode { paperDoll, mesh }

/// The one eye drawing that is visible this frame.
///
/// Anime eyes are discrete drawings, so the rig never cross-fades two of them:
/// the state is either OPEN (which draws nothing — the base painting or the
/// expression patch already carries the open eyes), one of the three neutral
/// lids, or one of the two glance drawings. Both modes read the same state.
enum RigEyeState { open, half, closed, glanceLeft, glanceRight }

/// All the rig's moving parts, with no drawing in it.
///
/// [update] advances time; every input is smoothed toward a target so the
/// painter only reads [pose], [eyeState] and the hair lag. Both modes run this
/// same simulation (the paper doll just reads it more coarsely), so a recorded
/// A clip and B clip share their blinks, glances and mouth beats.
class RigSim extends ChangeNotifier {
  RigSim({
    required this.deformer,
    RigQuality quality = RigQuality.high,
    math.Random? random,
  }) : _quality = quality {
    _build(random ?? math.Random());
  }

  final RigDeformer deformer;

  RigMode mode = RigMode.mesh;
  bool outfit = false;

  /// The one eye drawing on top of the face this frame.
  RigEyeState eyeState = RigEyeState.open;

  /// True while the 30 s record clip runs.
  bool get recording => _recording;

  /// True while the 20 s benchmark clip runs.
  bool get benchmarking => _benchmarking;

  /// Bumped when anything the control bar shows changes.
  final ValueNotifier<int> uiRevision = ValueNotifier<int>(0);

  /// The line being spoken, or null.
  final ValueNotifier<String?> subtitle = ValueNotifier<String?>(null);

  final RigPose pose = RigPose();
  double time = 0;

  late ExpressionBlend expression;
  late MouthFlapper mouth;
  late DiscreteMouth _mouthShape;
  late BlinkScheduler _blink;
  late GlanceScheduler _glance;
  late SmoothNoise _noise;

  RigQuality _quality;
  RigQuality get quality => _quality;

  // Smoothers: critically damped, so a changed target eases in.
  late Spring _headX, _headY, _tilt, _bodyX;

  /// One spring per hair_long vertex column and one for the bangs. The count
  /// follows the quality tier, so a tier switch rebuilds them.
  late List<Spring> _longHair;
  late Spring _frontHair;

  /// How far each hair_long column trails the head, px (already scaled by the
  /// lag gain). Read by the painter.
  late Float64List longHairLag;
  double frontHairLag = 0;

  bool _recording = false;
  double _recordStart = 0;
  int _nextEvent = 0;

  bool _benchmarking = false;
  double _benchAge = 0;
  double _benchLookAge = 0;

  // Talk.
  int _line = -1;
  double _lineAge = 0;
  double _nodAge = double.infinity;

  // Look away. The head's own turn, pitch and roll, and how much of it the
  // torso takes, are RigTuning's (the neck has to absorb the rest).
  static const double lookAwaySeconds = 1.5;
  double _lookAge = double.infinity;
  double _lookSide = 1;
  double _nextLookSide = 1;

  // Glance nudge: the iris switches instantly, then the whole head follows for
  // a few frames.
  double _nudge = 0;
  double _nudgeFrom = 0;
  double _nudgeTo = 0;
  double _nudgeAge = 0;

  bool get isTalking => _line >= 0;
  bool get isLookingAway => _lookAge < lookAwaySeconds;
  double get lookSide => _lookSide;

  void _build(math.Random seedSource) {
    math.Random r() => math.Random(seedSource.nextInt(1 << 30));
    expression = ExpressionBlend();
    mouth = MouthFlapper(r());
    _mouthShape = DiscreteMouth();
    _blink = BlinkScheduler(r());
    _glance = GlanceScheduler(r());
    _noise = SmoothNoise(r());
    _headX = Spring.critical(11);
    _headY = Spring.critical(11);
    _tilt = Spring.critical(10);
    _bodyX = Spring.critical(6);
    _longHair = _hairSprings(_quality.hairColumns);
    _frontHair = Spring(
      stiffness: RigTuning.frontStiffness,
      damping: RigTuning.frontDamping,
    );
    longHairLag = Float64List(_quality.hairColumns);
    frontHairLag = 0;
    time = 0;
    eyeState = RigEyeState.open;
    _line = -1;
    _lineAge = 0;
    _nodAge = double.infinity;
    _lookAge = double.infinity;
    _nextLookSide = 1;
    _nextEvent = 0;
    _benchmarking = false;
    _benchAge = 0;
    _benchLookAge = 0;
    _nudge = 0;
    _nudgeFrom = 0;
    _nudgeTo = 0;
    _nudgeAge = 0;
    pose
      ..headX = 0
      ..headY = 0
      ..headTilt = 0
      ..bodyX = 0
      ..breath = 0
      ..eyeX = 0
      ..mouthOpen = 0;
    subtitle.value = null;
  }

  List<Spring> _hairSprings(int columns) => [
        for (var c = 0; c < columns; c++) _hairSpring(c),
      ];

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

  /// Switches the tier. The hair springs follow the column count; the meshes
  /// are rebuilt by the art set, which the caller changes in the same breath.
  void setQuality(RigQuality q) {
    if (q == _quality) return;
    _quality = q;
    _longHair = _hairSprings(q.hairColumns);
    longHairLag = Float64List(q.hairColumns);
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
    if (_recording || _benchmarking) return;
    _build(math.Random(RecordScript.seed));
    _recording = true;
    _recordStart = 0;
    _touchUi();
    notifyListeners();
  }

  /// Runs the 20 s benchmark: mode B, outfit on, the four lines restarting as
  /// they end and a look away every few seconds. Constant load, so the numbers
  /// mean something on a cheap phone instead of measuring an idle character.
  void startBenchmark() {
    if (_benchmarking || _recording) return;
    _benchmarking = true;
    _benchAge = 0;
    _benchLookAge = 0;
    setMode(RigMode.mesh);
    setOutfit(true);
    talk();
    _touchUi();
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
    _runBenchmark(dt);
    _advanceTalk(dt);
    if (_lookAge < double.infinity) _lookAge += dt;
    if (_nodAge < double.infinity) _nodAge += dt;
    expression.update(dt);
    mouth.update(dt);
    _mouthShape.update(dt, rawOpen: mouth.isOpen);

    final t = time;
    final looking = isLookingAway;
    // The neutral eye drawings match the plain face only: an expression patch
    // carries its own eyes and brows.
    final neutralFace = _neutralFace;

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
    var bodyX = sway;
    if (_nodAge < _nodSeconds) {
      headY += 0.05 * math.sin(math.pi * _nodAge / _nodSeconds);
    }
    var glanceDir = _glance.update(t, enabled: neutralFace);
    if (looking) {
      // Eased in and out so the turn doesn't snap at either end.
      final env = _lookEnvelope(_lookAge);
      headX += _lookSide * RigTuning.lookAwayTurn * env;
      headY += RigTuning.lookAwayPitch * env;
      tilt += _lookSide * RigTuning.lookAwayRoll * env;
      // The shoulders take a share of it, so the neck is not bent under a head
      // that turns while the torso stands still.
      bodyX += _lookSide * RigTuning.lookAwayBodyFollow * env;
      glanceDir = neutralFace ? _lookSide * (env > 0.3 ? 1.0 : 0.0) : 0;
    }

    _headX.step(headX, dt);
    _headY.step(headY, dt);
    _tilt.step(tilt, dt);
    _bodyX.step(bodyX, dt);
    _stepNudge(glanceDir, dt);

    final blink = _blink.phase(t, withHalf: neutralFace);
    // The cover blink is the face change itself: the lids are shut for the
    // whole hold so the patch swap at its midpoint is hidden, whatever the
    // natural blink clock happens to be doing.
    eyeState = expression.covering
        ? RigEyeState.closed
        : switch (blink) {
            BlinkPhase.half => RigEyeState.half,
            BlinkPhase.closed => RigEyeState.closed,
            BlinkPhase.open => glanceDir == 0
                ? RigEyeState.open
                : glanceDir > 0
                    ? RigEyeState.glanceRight
                    : RigEyeState.glanceLeft,
          };

    pose
      ..headX = _headX.position
      ..headY = _headY.position
      ..headTilt = _tilt.position
      ..bodyX = _bodyX.position
      ..breath = 0.5 - 0.5 * math.cos(w * t / 3.6)
      ..eyeX = _nudge
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

  /// True when the face on screen is the plain painting: the neutral patch,
  /// not one of the cut-out expressions. The eye drawings and glances belong
  /// to it alone.
  bool get _neutralFace => expression.shown == RigExpression.neutral;

  static const double _nodSeconds = 0.4;

  /// Eases the little slide that follows a glance's switch over
  /// [RigTuning.glanceNudgeSeconds]. The eye drawings themselves never blend.
  void _stepNudge(double target, double dt) {
    if (target != _nudgeTo) {
      _nudgeFrom = _nudge;
      _nudgeTo = target;
      _nudgeAge = 0;
    }
    if (_nudge == _nudgeTo) return;
    _nudgeAge += dt;
    final u = (_nudgeAge / RigTuning.glanceNudgeSeconds).clamp(0.0, 1.0);
    _nudge = u >= 1 ? _nudgeTo : _nudgeFrom + (_nudgeTo - _nudgeFrom) * _ease(u);
  }

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

  void _runBenchmark(double dt) {
    if (!_benchmarking) return;
    _benchAge += dt;
    _benchLookAge += dt;
    // The four lines take 10 s, so restarting them keeps the mouth and the
    // expression switches running for the whole clip.
    if (!isTalking) talk();
    if (_benchLookAge >= RigTuning.benchLookEverySeconds) {
      _benchLookAge = 0;
      lookAway();
    }
    if (_benchAge >= RigTuning.benchSeconds) {
      _benchmarking = false;
      _touchUi();
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

  /// Opacity of the brow/eye/blush patch for [e]: 1 for the expression on the
  /// face, 0 for every other (neutral has no patch). Never a fraction.
  double patchAlpha(RigExpression e) => expression.patchAlpha(e);

  /// Opacity of the open-mouth layer for [e]: 1 only when [e] is the expression
  /// on the face and the mouth's held beat is open, 0 otherwise. Both modes
  /// read this same pair of drawings.
  double mouthAlpha(RigExpression e) =>
      _mouthShape.open && e == expression.shown ? 1 : 0;

  /// Opacity of the half-lid drawing. Exactly one eye layer is ever above zero,
  /// and it is drawn at full opacity: discrete drawings, never a cross-fade.
  double get halfAlpha => eyeState == RigEyeState.half ? 1 : 0;

  /// Opacity of the closed-lid drawing.
  double get closedAlpha => eyeState == RigEyeState.closed ? 1 : 0;

  /// The face whose shut-eye drawing is the one to draw when
  /// [eyeState] is [RigEyeState.closed].
  ///
  /// It follows [ExpressionBlend.shown], which switches at the cover blink's
  /// midpoint: a cover keeps the old face's lids until the halfway point and
  /// takes the new face's after it, exactly as the patch does. So a blink never
  /// draws one face's brows over another's.
  RigExpression get closedExpression => expression.shown;

  /// Opacity of a glance drawing; the two can never both be lit.
  double glanceAlpha({required bool right}) {
    final glance = right ? RigEyeState.glanceRight : RigEyeState.glanceLeft;
    return eyeState == glance ? 1 : 0;
  }
}
