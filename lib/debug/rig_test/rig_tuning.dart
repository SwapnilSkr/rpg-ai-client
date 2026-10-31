/// Every number that changes how the rig looks, in one place.
///
/// Distances are canvas pixels (the art is a 1024 x 1536 canvas); turns are
/// fractions, so `headX = 0.12` is "a 12% head turn". If something looks off,
/// the knob is here, with the reason it has its value.
abstract final class RigTuning {
  // ---- Head ---------------------------------------------------------------

  /// Pixels a point at depth 1 moves for a turn of 1.0. 160 makes the 12%
  /// "look away" a ~19 px slide on the face and ~24 px on the bangs.
  static const double turnPxX = 160;

  /// Same for the vertical turn (nod / looking down). Smaller: heads pitch less
  /// than they yaw before the neck has to bend.
  static const double turnPxY = 110;

  /// Half-width of the band around the neck's y where the head's motion fades
  /// out (80 px in all). Wide enough that no seam shows across the neck.
  static const double neckBlendHalf = 40;

  /// How much the side of the face turning away is squeezed, per unit of turn,
  /// and the hard cap. 0.35 x 0.12 = 4%: the cheap 3D trick, kept small so the
  /// face never looks pinched.
  static const double compressPerTurn = 0.35;
  static const double compressMax = 0.06;

  // ---- Depth: how much a layer slides during a head turn -------------------

  static const double depthBackHead = 0.6; // back of the head, hair outline
  static const double depthFace = 1.0;
  static const double depthFeatures = 1.05; // eyes, mouth, expression patches
  static const double depthHairLong = 0.8;
  static const double depthHairFront = 1.25; // bangs: nearest the viewer

  // ---- Body ---------------------------------------------------------------

  /// Sideways sway at the neck for bodyX = 1; fades to 0 at the waist.
  static const double bodyPx = 24;

  /// Breathing: vertical scale about the waist, plus a local lift and widening
  /// of the chest band so the chest rises a little more than the shoulders.
  static const double breathScale = 0.006;
  static const double chestRise = 5;
  static const double chestWiden = 0.004;
  static const double chestY = 850;
  static const double chestSigma = 130;

  // ---- Hair springs -------------------------------------------------------

  /// Number of vertex columns on hair_long (so one fewer cell across), one
  /// damped spring each.
  static const int hairColumns = 16;

  /// Stiffness 60 / damping 7 is a damping ratio of ~0.45: one clear overshoot
  /// of ~20%, then it settles in ~1.4 s. Heavier-feeling hair: lower the
  /// stiffness; floatier: lower the damping.
  static const double hairStiffness = 60;
  static const double hairDamping = 7;

  /// Columns differ a little in stiffness so strands don't swing in lockstep.
  static const double hairColumnVariation = 0.18;

  /// Multiplies how far the hair trails the head. 1 is the physical lag; the
  /// idle drift is small, so a gain above 1 keeps it visible.
  static const double hairLagGain = 1.6;

  /// Lag grows from the root (0) to the tips (1) as `row ^ curve`.
  static const double hairLagCurve = 1.4;

  /// Bangs: a stiffer, smaller spring, and a fraction of the tips' lag.
  static const double frontStiffness = 140;
  static const double frontDamping = 11;
  static const double frontLagScale = 0.45;

  // ---- Face ---------------------------------------------------------------

  /// A glance layer slides this far with eyeX, so it starts moving before the
  /// crossfade has finished.
  static const double glanceNudgePx = 2;

  /// Blink timing: 150 ms from open to open, closing faster than opening.
  static const double blinkSeconds = 0.15;

  /// Under this openness the paper doll shows the closed eyes (about 115 ms of
  /// each blink).
  static const double paperClosedBelow = 0.75;

  /// Expression crossfade.
  static const double expressionSeconds = 0.2;

  // ---- Mesh ---------------------------------------------------------------

  /// Target cell size in canvas px. 40 gives the base ~24 x 36 cells: fine
  /// enough for the depth falloff round the face, ~2k triangles.
  static const double meshCellPx = 40;

  /// Texture sampling. `medium` mip-maps; the art is drawn at ~0.6 scale and
  /// plain bilinear shimmers on hair strands.
  static const bool mipmap = true;
}
