import 'package:flutter/widgets.dart';

/// How a single beat presents itself.
///
/// [spotlight] dims the screen and cuts a hole around the anchored widget —
/// used when the beat points at one control the player must be able to see in
/// isolation. [card] leaves the screen untouched and floats the Chronicler's
/// card alone; it is the ambient, friction-free default for arrival beats.
enum GuideStyle { spotlight, card }

/// Silhouette of the spotlight cut-out.
///
/// [auto] — the default, and right almost every time — reads the target's own
/// corner radius so the opening is the control's shape to the pixel. The rest
/// are overrides for the cases where a widget declares no outline of its own
/// and a bare rectangle would read wrong.
enum GuideShape { auto, rrect, circle, pill }

/// Which side of the anchor the speech card prefers. [auto] picks whichever
/// half of the screen has more room, which is right almost every time.
enum GuidePlacement { auto, above, below }

/// One line of the Chronicler's guidance, optionally bound to a widget.
///
/// Beats are pure data — they never reach into the widget tree themselves.
/// [anchor] is a stable id registered by a `GuideAnchor`; when it is null (or
/// cannot be resolved on screen) the beat renders as an unanchored card, and
/// when [requiresAnchor] is set it is skipped entirely instead.
@immutable
class GuideBeat {
  /// Stable anchor id from `GuideIds`. Null renders an unanchored card.
  final String? anchor;

  /// Anchor to fall back to when [anchor] is not in the tree at all.
  ///
  /// For beats whose ideal target is only conditionally built — the newest
  /// passage lives inside a lazy list and does not exist until the reader has
  /// scrolled to it — while the surface that contains it always does. Better a
  /// wider opening on the right region than no opening at all.
  final String? fallbackAnchor;

  /// Extends the opening down to a second anchor, so a section heading and
  /// the control it names are lit as one shape.
  ///
  /// Without it the card, placed in whichever band has room, lands on top of
  /// the very control the beat is describing. Ignored when it cannot be
  /// resolved, which keeps the beat working while the pair is mid-scroll.
  final String? anchorEnd;

  /// Ceremonial one-liner, set in Cinzel.
  final String title;

  /// The guidance itself, in narrator prose. Fantasy register — never
  /// "tap the button"; the world explains itself.
  final String body;

  final GuideStyle style;
  final GuideShape shape;
  final GuidePlacement placement;

  /// Breathing room between the target's outline and the cut, in logical
  /// pixels. The corner radius grows with it, so the gap stays even the whole
  /// way round.
  ///
  /// Deliberately tiny. The opening is meant to read as the control itself lit
  /// up, and anything more than a hairline starts reading as a box drawn
  /// around it instead.
  final double inflate;

  /// Drop the beat when its anchor is absent rather than degrading to a
  /// floating card — for beats that are meaningless without their target
  /// (an empty bond rail, a world with no stats).
  final bool requiresAnchor;

  /// Let the highlighted widget be tapped through the scrim, which also
  /// advances the flow. Off by default: the player should never be forced to
  /// fire a real action to escape a tip.
  final bool tapThrough;

  /// Anchors to try in order: the precise target, then the surface it sits on.
  List<String> get anchors => [
    if (anchor != null) anchor!,
    if (fallbackAnchor != null) fallbackAnchor!,
  ];

  const GuideBeat({
    this.anchor,
    this.fallbackAnchor,
    this.anchorEnd,
    required this.title,
    required this.body,
    this.style = GuideStyle.spotlight,
    this.shape = GuideShape.auto,
    this.placement = GuidePlacement.auto,
    this.inflate = 3,
    this.requiresAnchor = false,
    this.tapThrough = false,
  });

  /// Convenience for an unanchored, scrim-free arrival beat.
  const GuideBeat.card({required this.title, required this.body})
    : anchor = null,
      fallbackAnchor = null,
      anchorEnd = null,
      style = GuideStyle.card,
      shape = GuideShape.auto,
      placement = GuidePlacement.auto,
      inflate = 0,
      requiresAnchor = false,
      tapThrough = false;
}

/// An ordered arc of beats for one surface.
///
/// [version] is the server-side replay lever: bump it after a surface changes
/// materially and only that arc runs again, for everyone, exactly once.
@immutable
class GuideFlow {
  final String id;
  final int version;

  /// Human label for this arc. Not shown to players — arcs are never listed,
  /// only met — but it is what names a flow in logs and in the funnel.
  final String label;

  /// Router location this flow belongs to. The controller ends the flow when
  /// the app navigates away, so a tip can never trail onto another screen.
  /// Null pins the flow to whatever route was active when it started.
  final String? route;

  final List<GuideBeat> beats;

  /// Every anchor this arc might point at, in beat order.
  List<String> get anchorIds => [for (final beat in beats) ...beat.anchors];

  const GuideFlow({
    required this.id,
    required this.label,
    required this.beats,
    this.version = 1,
    this.route,
  });
}
