import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/everlore_network_image.dart';

/// Walking-point-of-view travel.
///
/// Cutting straight to a new place makes travel free, and free travel makes a
/// map feel like a menu. This costs about a second and buys the sense of having
/// gone somewhere: the destination eases in from slightly too close while the
/// camera bobs the way a walker's head does, damped to nothing on arrival.
///
/// It is entirely code — no asset, no per-location authoring.
class TravelTransition extends StatefulWidget {
  const TravelTransition({
    super.key,
    required this.backgroundUrl,
    this.duration = const Duration(milliseconds: 900),
  });

  final String? backgroundUrl;
  final Duration duration;

  @override
  State<TravelTransition> createState() => _TravelTransitionState();
}

class _TravelTransitionState extends State<TravelTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  /// Roughly two strides a second, which is a walking pace rather than a run.
  static const _stepsPerSecond = 2.2;
  static const _bobPixels = 6.0;
  static const _rollDegrees = .45;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final seconds = widget.duration.inMilliseconds / 1000;
        final phase = t * seconds * _stepsPerSecond * 2 * math.pi;
        // Damp the gait to zero so the last frame is level. A transition that
        // ends mid-bob reads as a glitch rather than as arriving.
        final damp = 1 - Curves.easeInCubic.transform(t);
        final bob = math.sin(phase) * _bobPixels * damp;
        final roll = math.cos(phase) * _rollDegrees * damp * math.pi / 180;
        final zoom = 1.08 - .08 * Curves.easeOutCubic.transform(t);
        final fade = Curves.easeOut.transform(math.min(1, t * 2.4));

        return IgnorePointer(
          child: Opacity(
            opacity: 1 - Curves.easeIn.transform(math.max(0, (t - .82) / .18)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF0A0908)),
                Opacity(
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(0, bob),
                    child: Transform.rotate(
                      angle: roll,
                      child: Transform.scale(
                        scale: zoom,
                        child: widget.backgroundUrl == null
                            ? const ColoredBox(color: Color(0xFF14100E))
                            // The walk holds this same provider. A
                            // NetworkImage here would paint from a shelf
                            // the gate never warmed, and the destination
                            // would still fade in as an empty room.
                            : EverloreNetworkImage(
                                imageUrl: widget.backgroundUrl!,
                                fit: BoxFit.cover,
                                placeholder: const ColoredBox(
                                  color: Color(0xFF14100E),
                                ),
                                errorWidget: const ColoredBox(
                                  color: Color(0xFF14100E),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                // The vignette breathes once. Most of the felt motion is here
                // rather than in the translation, which stays subtle enough not
                // to be nauseating on a phone held close.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1 - .25 * math.sin(t * math.pi),
                      colors: const [Color(0x00000000), Color(0xCC000000)],
                      stops: const [.55, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
