import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/nexus_theme.dart';
import '../guide_anchor.dart';
import '../guide_beat.dart';

/// The opening cut for a spotlit target: its own outline, grown by [gap].
///
/// The point is that the hole is the widget's shape, not an approximation of
/// it. A rounded rectangle grown by `g` has corners of `r + g`, not `r` — keep
/// the radius fixed while inflating and the corners visibly tighten, which is
/// what made earlier spotlights read as a sticker laid over the control rather
/// than the control itself lit up.
///
/// [shape] overrides what the target declares; [GuideShape.auto] — the default
/// — trusts the target. Clamped to [bounds]: a hole overhanging an edge by a
/// few points is nudged inward, anything further is clipped to what is really
/// visible. Returns null when nothing usable is left.
RRect? guideHoleFor(
  GuideTarget target, {
  GuideShape shape = GuideShape.auto,
  double gap = 3,
  Rect? bounds,
}) {
  var rect = target.rect.inflate(gap);
  final oval =
      shape == GuideShape.circle || (shape == GuideShape.auto && target.isOval);

  // A circle over a non-square target has to be squared up first; asking for a
  // radius larger than half the shorter side just gets scaled back by the
  // rasteriser, which is what made lopsided targets come out egg-shaped.
  if (oval && rect.width != rect.height) {
    final side = math.max(rect.width, rect.height);
    rect = Rect.fromCenter(center: rect.center, width: side, height: side);
  }

  if (bounds != null) {
    if (!rect.overlaps(bounds)) return null;
    final dx =
        math.max(0.0, bounds.left - rect.left) -
        math.max(0.0, rect.right - bounds.right);
    final dy =
        math.max(0.0, bounds.top - rect.top) -
        math.max(0.0, rect.bottom - bounds.bottom);
    // A hole that pokes a few points past the edge is nudged inward rather
    // than cut: clipping a circle against the screen edge flattens one side of
    // it, and a control sitting hard against the bezel is exactly that case.
    //
    // Only a few points, though. Nudging an arbitrary overflow is what made
    // the opening on Explore look nailed to the screen: a tall card scrolled
    // half out of view was dragged bodily back inside the bounds, so the
    // spotlight sat pinned under the status bar, over whichever cards happened
    // to be there, and stayed put while the list moved beneath it. Past that
    // slack the honest answer is the visible part of the target, or nothing.
    const slack = 12.0;
    if (dx.abs() <= slack &&
        dy.abs() <= slack &&
        rect.width <= bounds.width &&
        rect.height <= bounds.height) {
      rect = rect.translate(dx, dy);
    } else {
      rect = rect.intersect(bounds);
    }
  }
  if (rect.width <= 0 || rect.height <= 0) return null;
  // A sliver left over from clipping is not a spotlight, it is a stripe down
  // the edge of the screen. Better no opening at all — the beat still speaks.
  if (rect.width < 24 || rect.height < 24) return null;

  final limit = math.min(rect.width, rect.height) / 2;
  Radius clamp(Radius radius) =>
      Radius.elliptical(radius.x.clamp(0, limit), radius.y.clamp(0, limit));
  Radius grown(Radius radius) =>
      clamp(Radius.elliptical(radius.x + gap, radius.y + gap));

  final declared = target.radius;
  final corners = switch (shape) {
    GuideShape.circle => BorderRadius.all(Radius.circular(limit)),
    GuideShape.pill => BorderRadius.all(Radius.circular(limit)),
    GuideShape.rrect => BorderRadius.all(Radius.circular(12 + gap)),
    GuideShape.auto when oval => BorderRadius.all(Radius.circular(limit)),
    // Nothing beneath the anchor declared an outline — a row of chips, a column
    // of settings. A plain rounded rectangle is the honest shape for a group.
    GuideShape.auto =>
      declared == null
          ? BorderRadius.all(Radius.circular(12 + gap))
          : BorderRadius.only(
              topLeft: grown(declared.topLeft),
              topRight: grown(declared.topRight),
              bottomLeft: grown(declared.bottomLeft),
              bottomRight: grown(declared.bottomRight),
            ),
  };

  return RRect.fromRectAndCorners(
    rect,
    topLeft: clamp(corners.topLeft),
    topRight: clamp(corners.topRight),
    bottomLeft: clamp(corners.bottomLeft),
    bottomRight: clamp(corners.bottomRight),
  );
}

/// The corner radii for a ring drawn [gap] outside [hole], so the halo keeps
/// the same shape as the opening instead of rounding it off.
BorderRadius guideRingRadius(RRect hole, double gap) => BorderRadius.only(
  topLeft: Radius.elliptical(hole.tlRadiusX + gap, hole.tlRadiusY + gap),
  topRight: Radius.elliptical(hole.trRadiusX + gap, hole.trRadiusY + gap),
  bottomLeft: Radius.elliptical(hole.blRadiusX + gap, hole.blRadiusY + gap),
  bottomRight: Radius.elliptical(hole.brRadiusX + gap, hole.brRadiusY + gap),
);

/// Dims the screen except for one rounded hole, and lets real taps inside that
/// hole reach the widget underneath.
///
/// The hit-testing is the whole trick. A painted hole is still a solid pane as
/// far as the gesture system is concerned, so the render box below reports a
/// miss inside the hole; the enclosing `Stack` then continues to the app layer
/// and the actual control receives the touch. Outside the hole it absorbs,
/// and the tap advances the guide.
class GuideCutout extends StatelessWidget {
  final RRect? hole;
  final Color accent;

  /// How far the overlay has arrived, 0 to 1. The scrim dims with it and the
  /// rim lights with it, so the spotlight fades up on the scene instead of
  /// being switched on.
  final double progress;

  /// Tap anywhere outside the hole — advances rather than dismissing, so a
  /// stray touch never costs the player the rest of the arc.
  final VoidCallback onTapOutside;

  /// When false the hole is painted but sealed, so the highlighted control
  /// cannot be fired mid-explanation.
  final bool tapThrough;

  const GuideCutout({
    super.key,
    required this.hole,
    required this.onTapOutside,
    this.progress = 1,
    this.accent = EverloreTheme.gold,
    this.tapThrough = false,
  });

  @override
  Widget build(BuildContext context) {
    return _CutoutBarrier(
      hole: hole,
      accent: accent,
      progress: progress,
      // Sealed until the overlay has actually arrived: letting a control be
      // fired through an opening that is still fading up means the player hits
      // something they have not been shown yet.
      passThrough: tapThrough && progress > 0.9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapOutside,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CutoutBarrier extends SingleChildRenderObjectWidget {
  final RRect? hole;
  final Color accent;
  final double progress;
  final bool passThrough;

  const _CutoutBarrier({
    required this.hole,
    required this.accent,
    required this.progress,
    required this.passThrough,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCutoutBarrier(
    hole: hole,
    accent: accent,
    progress: progress,
    passThrough: passThrough,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCutoutBarrier renderObject,
  ) {
    renderObject
      ..hole = hole
      ..accent = accent
      ..progress = progress
      ..passThrough = passThrough;
  }
}

class _RenderCutoutBarrier extends RenderProxyBox {
  _RenderCutoutBarrier({
    required RRect? hole,
    required Color accent,
    required double progress,
    required bool passThrough,
  }) : _hole = hole,
       _accent = accent,
       _progress = progress,
       _passThrough = passThrough;

  RRect? _hole;
  set hole(RRect? value) {
    if (value == _hole) return;
    _hole = value;
    markNeedsPaint();
  }

  Color _accent;
  set accent(Color value) {
    if (value == _accent) return;
    _accent = value;
    markNeedsPaint();
  }

  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsPaint();
  }

  bool _passThrough;
  set passThrough(bool value) {
    if (value == _passThrough) return;
    _passThrough = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hole = _hole;
    // Reporting a miss inside the hole is what lets the live control below the
    // overlay receive the touch; anywhere else this layer swallows it.
    if (_passThrough && hole != null && hole.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final bounds = offset & size;
    final hole = _hole;

    final t = _progress.clamp(0.0, 1.0);
    if (t <= 0) {
      super.paint(context, offset);
      return;
    }
    final scrim = Paint()
      ..color = EverloreTheme.void0.withValues(alpha: 0.8 * t);
    if (hole == null) {
      canvas.drawRect(bounds, scrim);
    } else {
      final shifted = hole.shift(offset);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(bounds),
          Path()..addRRect(shifted),
        ),
        scrim,
      );
      // A brass rim and a soft bloom so the opening reads as lit from within
      // rather than punched out.
      canvas.drawRRect(
        shifted.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _accent.withValues(alpha: 0.72 * t),
      );
      canvas.drawRRect(
        shifted.inflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = _accent.withValues(alpha: 0.10 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    super.paint(context, offset);
  }
}
