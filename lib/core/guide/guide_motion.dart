import 'package:flutter/widgets.dart';

/// The guide's motion vocabulary, in one place.
///
/// Every part of the Chronicler moves on these four timings. Coachmarks read
/// as cheap when each piece invents its own — the scrim snapping on while the
/// card slides and the opening jumps is what makes a walkthrough feel rushed,
/// and a rushed walkthrough is one the player skips.
///
/// The shape of it: things arrive slowly and leave quickly. An entrance is the
/// player's first look at something and wants time to be read; an exit is
/// already understood and only has to get out of the way.
abstract final class GuideMotion {
  /// The overlay arriving: scrim dimming, card rising, opening blooming.
  /// Long enough to register as a deliberate reveal rather than a flash.
  static const enter = Duration(milliseconds: 460);
  static const enterCurve = Curves.easeOutCubic;

  /// The overlay leaving. Deliberately much shorter — the player has decided
  /// to move on, and anything that lingers now reads as lag.
  static const exit = Duration(milliseconds: 220);
  static const exitCurve = Curves.easeInCubic;

  /// The opening travelling from one target to the next.
  ///
  /// Slow, and eased at both ends, because this is the one movement the player
  /// is meant to follow with their eyes: it is how a beat says *this one, now
  /// this one*. A fast tween arrives before the eye does and the connection is
  /// lost, which is the whole point of moving it at all rather than cutting.
  static const travel = Duration(milliseconds: 620);
  static const travelCurve = Curves.easeInOutCubicEmphasized;

  /// How long the opening is allowed to be *interpolated* after it lands on a
  /// new target. Must never be shorter than [travel]: the moment it expires
  /// the opening reverts to tracking its target frame-for-frame, so a window
  /// shorter than the tween cuts the travel off partway and snaps the rest.
  static const settle = Duration(milliseconds: 660);

  /// One beat's words giving way to the next. Slightly asymmetric: the old
  /// line clears out from under the new one rather than dissolving through it,
  /// which is what stops the cross-fade reading as a smear.
  static const swapIn = Duration(milliseconds: 320);
  static const swapOut = Duration(milliseconds: 160);

  /// The card's own box changing height as a longer or shorter beat arrives.
  static const resize = Duration(milliseconds: 420);

  /// How far the card travels on its way in. A hint of rise, not a slide —
  /// the card is arriving, not being flung on.
  static const rise = 14.0;

  /// How far under its final size the opening starts. The bloom has to be
  /// felt rather than seen; at more than a few percent it reads as a zoom.
  static const bloom = 0.94;
}

/// [hole] shrunk towards its own centre by [t], where 1 is its true size.
///
/// The opening blooms open in place. Interpolating an `RRect` from null
/// instead — which is what a bare tween does — scales it from the screen's
/// top-left corner, so the very first spotlight of the whole walkthrough flew
/// in diagonally from behind the status bar.
RRect guideBloomed(RRect hole, double t) {
  if (t >= 1) return hole;
  final scale = GuideMotion.bloom + (1 - GuideMotion.bloom) * t.clamp(0.0, 1.0);
  final rect = hole.outerRect;
  final shrunk = Rect.fromCenter(
    center: rect.center,
    width: rect.width * scale,
    height: rect.height * scale,
  );
  return RRect.fromRectAndCorners(
    shrunk,
    topLeft: hole.tlRadius * scale,
    topRight: hole.trRadius * scale,
    bottomLeft: hole.blRadius * scale,
    bottomRight: hole.brRadius * scale,
  );
}
