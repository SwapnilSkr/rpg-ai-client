import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'rig_manifest.dart';
import 'rig_tuning.dart';

/// The numbers the deform function reads from the character's own art.
class RigGeometry {
  const RigGeometry({
    required this.neck,
    required this.waist,
    this.headCenter = const Offset(520, 410),
    this.headRadii = const Offset(170, 215),
    this.hairRoot = const Offset(512, 400),
    this.jawY = 608,
  });

  /// Anchors from rig.json; the head centre and radii are measured off the
  /// painted face (the nose sits left of the skull's centre, three-quarter).
  factory RigGeometry.fromManifest(RigManifest m) =>
      RigGeometry(neck: m.anchor('neck'), waist: m.anchor('waist'));

  /// The head's pivot.
  final Offset neck;

  /// Where the torso is held still; breath scales about this point.
  final Offset waist;

  /// Ellipse that encloses the skin of the face; outside it depth falls to the
  /// back-of-head value.
  final Offset headCenter;
  final Offset headRadii;

  /// A point on the scalp the hair springs chase.
  final Offset hairRoot;

  /// The bottom of the painted jaw, in canvas rows, measured off the painting
  /// (the hair_front crop ends on it, 42 px above the neck pivot). The head's
  /// motion is rigid down to here and only fades below it.
  final double jawY;
}

/// What the rig is told to do this frame. Everything is zero / at rest by
/// default, and `deform` is the identity there.
class RigPose {
  /// Head turn, fraction of a full turn: + is toward the viewer's right.
  double headX = 0;

  /// Head pitch: + is down.
  double headY = 0;

  /// Torso sway, -1..1.
  double bodyX = 0;

  /// Breath, 0 (out) .. 1 (in).
  double breath = 0;

  /// -1 left .. 1 right.
  double eyeX = 0;

  /// 0 closed .. 1 fully open.
  double mouthOpen = 0;

  double _tilt = 0;
  double _cos = 1;
  double _sin = 0;

  /// Head roll in radians; + is clockwise on screen. The trig is cached here
  /// because `deform` runs for every vertex of every layer.
  double get headTilt => _tilt;
  set headTilt(double v) {
    _tilt = v;
    _cos = math.cos(v);
    _sin = math.sin(v);
  }

  double get cosTilt => _cos;
  double get sinTilt => _sin;
}

/// ONE deformation for every layer.
///
/// Every layer, however small, is a mesh run through [deform] with the same
/// pose. The eye and mouth patches therefore move exactly as the face under
/// them does; they are never positioned separately, which is what would let
/// them drift off the painting. Layers differ only in the `depth` they pass.
class RigDeformer {
  const RigDeformer(this.geometry);

  final RigGeometry geometry;

  /// 1 above the jaw, 0 a [RigTuning.neckBlendHalf] below the neck, smooth in
  /// between. The band is asymmetric on purpose: it never starts above the jaw,
  /// so the face stays rigid and only the neck bends. A symmetric band would
  /// reach up under the chin — the jaw lagging the face is what reads as a neck
  /// bent sideways — and would drop the hair join rows off the head.
  double headWeight(double y) {
    final n = geometry.neck.dy;
    // Never above the jaw, and never below the pivot: a stand-in character with
    // a shorter neck gets a band from its pivot down, not an inverted one.
    final top =
        math.min(n, math.max(geometry.jawY, n - RigTuning.neckBlendHalf));
    return 1 - smoothstep(top, n + RigTuning.neckBlendHalf, y);
  }

  /// How far a point of the base painting slides in a turn: the face fully,
  /// the back of the head and the hair outline less.
  double baseDepth(Offset p) {
    final c = geometry.headCenter;
    final r = geometry.headRadii;
    final dx = (p.dx - c.dx) / r.dx;
    final dy = (p.dy - c.dy) / r.dy;
    final t = smoothstep(1.0, 1.45, math.sqrt(dx * dx + dy * dy));
    return RigTuning.depthFace + (RigTuning.depthBackHead - RigTuning.depthFace) * t;
  }

  /// Moves a rest-pose canvas point.
  ///
  /// [depth]: nearer the viewer slides further in a turn. [lagWeight] and
  /// [lagX] (the hair's spring lag in px) are for hair; [localDx] is a small
  /// extra slide inside the mesh (the glance nudge).
  Offset deform(
    Offset p,
    RigPose pose, {
    double depth = 1,
    double lagWeight = 0,
    double lagX = 0,
    double localDx = 0,
  }) {
    final neck = geometry.neck;
    final waist = geometry.waist;
    final x = p.dx;
    final y = p.dy;
    var nx = x;
    var ny = y;

    // --- Head: squeeze, roll about the neck, then slide by depth. ---
    final hw = headWeight(y);
    if (hw > 0) {
      final turn = pose.headX;
      if (turn != 0) {
        // The side the head turns toward is foreshortened: pull it toward the
        // face centre, strongest near the face edge and fading out past the
        // hair so the far strands are not dragged.
        final cx = geometry.headCenter.dx;
        final u = (x - cx) / geometry.headRadii.dx;
        final toward = turn > 0 ? u : -u;
        final edge = smoothstep(0.2, 1.0, toward) * (1 - smoothstep(1.3, 2.3, toward));
        final c = math.min(turn.abs() * RigTuning.compressPerTurn, RigTuning.compressMax);
        nx -= (x - cx) * c * edge * hw * depth;
      }
      if (pose.headTilt != 0) {
        double cs;
        double sn;
        if (hw >= 1) {
          cs = pose.cosTilt;
          sn = pose.sinTilt;
        } else {
          final a = pose.headTilt * hw;
          cs = math.cos(a);
          sn = math.sin(a);
        }
        final rx = nx - neck.dx;
        final ry = ny - neck.dy;
        nx = neck.dx + rx * cs - ry * sn;
        ny = neck.dy + rx * sn + ry * cs;
      }
      nx += pose.headX * RigTuning.turnPxX * depth * hw;
      ny += pose.headY * RigTuning.turnPxY * depth * hw;
    }

    // --- Torso: sway grows from the waist (still) to the neck (full). ---
    final up = (waist.dy - y) / (waist.dy - neck.dy);
    nx += pose.bodyX * RigTuning.bodyPx * smoothstep(0, 1, up);

    final b = pose.breath;
    if (b != 0) {
      ny = waist.dy + (ny - waist.dy) * (1 + RigTuning.breathScale * b);
      final d = (y - RigTuning.chestY) / RigTuning.chestSigma;
      final chest = math.exp(-0.5 * d * d);
      ny -= RigTuning.chestRise * b * chest;
      nx += (x - neck.dx) * RigTuning.chestWiden * b * chest;
    }

    nx += lagWeight * lagX + localDx;
    return Offset(nx, ny);
  }

  /// Sideways travel of the scalp for this pose, in px: the target the hair
  /// springs chase. Taken from `deform` itself so a tilt or sway swings the
  /// hair as well as a turn.
  double hairDrive(RigPose pose) {
    final root = geometry.hairRoot;
    return deform(root, pose, depth: RigTuning.depthHairLong).dx - root.dx;
  }
}

/// 0 at or below [a], 1 at or above [b], smooth and flat at both ends between.
double smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
