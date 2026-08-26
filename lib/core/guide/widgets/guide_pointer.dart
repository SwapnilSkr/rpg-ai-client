import 'package:flutter/widgets.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/motion.dart';

/// A slow brass ring breathing around the spotlit target.
///
/// The one piece of ornament the guide allows itself — enough to draw the eye
/// to the opening without the arcade pointing-hand that would read wrong
/// against Everlore's chrome. Collapses to a static ring when the platform
/// asks for reduced motion.
class GuidePulse extends StatefulWidget {
  final Color accent;

  /// Fades with the overlay's arrival, and holds off entirely until it is
  /// nearly there — a halo pulsing around an opening that is still blooming
  /// reads as two animations arguing rather than one arrival.
  final double progress;

  /// Corners of the opening it rings, so the halo is the target's shape and
  /// not an approximation of it — a left-rounded button gets a left-rounded
  /// ring, a circle gets a circle.
  final BorderRadius borderRadius;

  const GuidePulse({
    super.key,
    this.progress = 1,
    this.accent = EverloreTheme.gold,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  State<GuidePulse> createState() => _GuidePulseState();
}

class _GuidePulseState extends State<GuidePulse>
    with SingleTickerProviderStateMixin {
  // Built eagerly rather than lazily. `build` returns early while the overlay
  // is still arriving, and a `late final` controller that was never touched
  // gets created for the first time inside `dispose` — which asks a
  // deactivated element for its TickerMode and trips an assertion.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ramps over the last third of the arrival, so the ring is the last thing
    // to appear rather than something that races the opening.
    final fade = ((widget.progress - 0.65) / 0.35).clamp(0.0, 1.0);
    if (fade <= 0) return const SizedBox.shrink();
    final border = Border.all(
      color: widget.accent.withValues(alpha: 0.5 * fade),
      width: 1.2,
    );
    final shape = widget.borderRadius;

    if (reducedMotion(context)) {
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(border: border, borderRadius: shape),
        ),
      );
    }

    // Growth is a fixed number of pixels, never a scale factor. A percentage
    // looks identical on a 56px button and catastrophic on a full-width tab
    // strip, where 9% is thirty pixels a side and the ring swells straight off
    // the screen — which is exactly how the halo came to look broken.
    const grow = 7.0;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (!width.isFinite ||
              !height.isFinite ||
              width <= 0 ||
              height <= 0) {
            return const SizedBox.shrink();
          }
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeOut.transform(_controller.value);
              return Transform.scale(
                scaleX: 1 + (t * grow * 2 / width),
                scaleY: 1 + (t * grow * 2 / height),
                child: Opacity(opacity: (1 - t) * 0.65 * fade, child: child),
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(border: border, borderRadius: shape),
            ),
          );
        },
      ),
    );
  }
}
