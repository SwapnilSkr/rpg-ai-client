import 'dart:ui' as ui;

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
  /// damped spring each. The low tier halves them: the same swing, half the
  /// springs to step and half the vertices to push across that layer.
  static const int hairColumnsHigh = 16;
  static const int hairColumnsLow = 8;

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

  /// The glance layer slides this far as the nudge eases in. The switch itself
  /// is instant (a glance is a saccade); the slide is the follow-through that
  /// makes the whole head read as having moved.
  static const double glanceNudgePx = 2;

  /// How long that slide takes after the switch. A saccade is over in ~40 ms;
  /// this is quick enough to stay after it and slow enough to be seen.
  static const double glanceNudgeSeconds = 0.08;

  /// Blink holds, seconds. Anime eyes are discrete drawings and are never
  /// cross-faded, so a blink is a sequence of holds: on the neutral face
  /// half, shut, half (40 + 60 + 40 ms, 140 ms all told). An expression face
  /// only shuts for the shorter hold, because the half-lid drawing is a
  /// neutral-face painting and would change the eye shape mid-blink.
  static const double blinkHalfHold = 0.04;
  static const double blinkClosedHold = 0.06;
  static const double blinkClosedHoldExpression = 0.09;

  /// One neutral blink, open to open: half, shut, half.
  static const double blinkNeutralSeconds = 2 * blinkHalfHold + blinkClosedHold;

  /// Expression crossfade.
  static const double expressionSeconds = 0.2;

  // ---- Mesh and quality ---------------------------------------------------

  /// Target cell size in canvas px. 40 gives the base ~24 x 36 cells: fine
  /// enough for the depth falloff round the face, ~2k triangles. 64 is a third
  /// of those triangles for a GPU that cannot afford them.
  static const double meshCellPxHigh = 40;
  static const double meshCellPxLow = 64;

  /// Texture sampling. `medium` mip-maps; the art is drawn at ~0.6 scale and
  /// plain bilinear shimmers on hair strands, which is what the low tier
  /// accepts to pay less for every sample.
  static const ui.FilterQuality filterQualityHigh = ui.FilterQuality.medium;
  static const ui.FilterQuality filterQualityLow = ui.FilterQuality.low;

  // ---- Quality auto-select ------------------------------------------------

  /// Only the first seconds of a run are judged: a warm-up frame or a garbage
  /// collection later on is not the GPU's speed.
  static const double autoQualityWindowSeconds = 3;

  /// Raster p90 at which the tier drops. Above 12 ms a 16.7 ms budget is
  /// already gone before the build phase has run, so waiting to miss it is
  /// pointless.
  static const double autoQualityRasterP90Ms = 12;

  // ---- Benchmark ----------------------------------------------------------

  /// Length of the benchmark clip, seconds.
  static const double benchSeconds = 20;

  /// Gap between look-aways while the benchmark runs: constant load, not a
  /// realistic idle.
  static const double benchLookEverySeconds = 5;

  /// The two deadlines a 60 fps budget is judged against, ms.
  static const double frameBudgetMs = 16.7;
  static const double stutterMs = 33;
}
