import 'rig_tuning.dart';

enum RigExpression { neutral, happy, shy, surprised }

/// The crossfade between two expressions.
///
/// The outgoing patch stays fully opaque while the incoming one fades in over
/// it, so the face never shows the neutral painting through a half-faded pair.
/// Fading *to* neutral (which has no patch) fades the outgoing one out instead.
/// The painter draws [from] first and [to] on top.
class ExpressionBlend {
  ExpressionBlend([RigExpression start = RigExpression.neutral])
      : from = start,
        to = start;

  RigExpression from;
  RigExpression to;

  /// 0..1 progress; 1 means settled on [to].
  double progress = 1;

  bool get settled => progress >= 1;

  double get _eased => progress * progress * (3 - 2 * progress);

  /// Where it is heading; what the paper doll shows.
  RigExpression get target => to;

  void set(RigExpression e) {
    if (e == to) return;
    // Mid-blend, restart from whichever side is currently winning.
    from = progress >= 0.5 ? to : from;
    to = e;
    progress = 0;
  }

  void update(double dt) {
    if (progress >= 1) return;
    progress = (progress + dt / RigTuning.expressionSeconds).clamp(0.0, 1.0);
    if (progress >= 1) from = to;
  }

  /// Opacity of the brow/eye/blush patch for [e]. Neutral has none.
  double patchAlpha(RigExpression e) {
    if (e == RigExpression.neutral) return 0;
    if (from == to) return e == to ? 1 : 0;
    if (e == from) return to == RigExpression.neutral ? 1 - _eased : 1;
    if (e == to) return _eased;
    return 0;
  }

  /// Weight of the open-mouth layer for [e] (neutral has one); multiply by the
  /// mouth's openness.
  double mouthWeight(RigExpression e) {
    if (from == to) return e == to ? 1 : 0;
    if (e == from) return 1;
    if (e == to) return _eased;
    return 0;
  }
}
