import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/everlore_network_image.dart';

/// Walking-point-of-view travel.
///
/// Cutting straight to a new place makes travel free, and free travel makes a
/// map feel like a menu. The destination eases in from slightly too close
/// while the camera bobs the way a walker's head does, damped to nothing on
/// arrival, and then *holds* that last frame. Fading itself out while the
/// road was still resolving is what made the walk feel like a glitch.
class TravelTransition extends StatefulWidget {
  const TravelTransition({
    super.key,
    required this.backgroundUrl,
    this.duration = const Duration(milliseconds: 1200),
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

  static const _stepsPerSecond = 1.6;
  static const _bobPixels = 3.5;
  static const _rollDegrees = 0.28;

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
        final damp = 1 - Curves.easeInCubic.transform(t);
        final bob = math.sin(phase) * _bobPixels * damp;
        final roll = math.cos(phase) * _rollDegrees * damp * math.pi / 180;
        final zoom = 1.06 - 0.06 * Curves.easeOutCubic.transform(t);
        final fade = Curves.easeOut.transform(math.min(1, t * 1.8));

        return IgnorePointer(
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
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.12 - 0.18 * math.sin(t * math.pi),
                    colors: const [Color(0x00000000), Color(0xAA000000)],
                    stops: const [0.58, 1],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
