import 'rig_tuning.dart';

enum RigExpression { neutral, happy, shy, surprised }

/// The expression on the face, changed the way limited animation does it: a
/// drawing is swapped, never cross-faded.
///
/// Two paintings of the same face half-visible at once read as a smeared,
/// doubled image, and on a phone screen the face is drawn about one-to-one, so
/// the doubling is the first thing the eye sees. Instead a change starts a
/// cover blink — the lids shut for [RigTuning.blinkClosedHoldExpression] — and
/// [shown] swaps from the old expression to the new one at the midpoint of
/// that hold, while the eyes are most covered. Brows, lids and blush then
/// change under a shut pair of eyes, which is the most any one frame can hide.
class ExpressionBlend {
  ExpressionBlend([RigExpression start = RigExpression.neutral])
      : shown = start,
        target = start;

  /// The expression whose patch is on the face this frame. Exactly one patch
  /// is drawn, at opacity 1, or none on the neutral face.
  RigExpression shown;

  /// Where the face is heading. A request names this at once, so the control
  /// bar can show what the next press will leave behind.
  RigExpression target;

  /// True for the whole cover blink; the eye state is shut while it runs.
  bool get covering => _covering;

  /// True when no switch is pending.
  bool get settled => !_covering;

  static const double _coverSeconds = RigTuning.blinkClosedHoldExpression;
  static const double _midpoint = _coverSeconds / 2;

  bool _covering = false;

  /// Whether the one switch this cover is allowed has already happened. A
  /// request before it retargets that switch; one after gets a new cover.
  bool _switched = false;
  double _coverAge = 0;

  /// Requests [e].
  ///
  /// Asked for the expression already on the face, there is nothing to swap and
  /// no blink. Asked for another one before the midpoint, the pending switch is
  /// retargeted, so the patch still switches once, to the latest request.
  /// Asked for one after the midpoint, this cover has spent its switch: a fresh
  /// cover starts, one switch each.
  void set(RigExpression e) {
    if (_covering) {
      if (!_switched || e == shown) {
        target = e;
        return;
      }
      _startCover(e);
      return;
    }
    if (e == shown) return;
    _startCover(e);
  }

  void _startCover(RigExpression e) {
    target = e;
    _covering = true;
    _switched = false;
    _coverAge = 0;
  }

  void update(double dt) {
    if (!_covering) return;
    _coverAge += dt;
    if (!_switched && _coverAge >= _midpoint) {
      shown = target;
      _switched = true;
    }
    if (_coverAge >= _coverSeconds) {
      shown = target;
      _covering = false;
      _switched = false;
      _coverAge = 0;
    }
  }

  /// Opacity of the brow/eye/blush patch for [e]: 0 or 1, never between.
  double patchAlpha(RigExpression e) =>
      e != RigExpression.neutral && e == shown ? 1 : 0;
}
