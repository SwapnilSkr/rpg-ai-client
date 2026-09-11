import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'stage/stage_tokens.dart';

/// A screen of moving mist, held until a room can actually paint.
///
/// Cutting to a dark loader, then to a finished painting, is how every
/// arrival felt like a menu. The land is already under this veil; the
/// veil only lifts when the first frame is ready.
class WorldMist extends StatefulWidget {
  const WorldMist({super.key, this.lifting = false, this.onLifted});

  final bool lifting;
  final VoidCallback? onLifted;

  @override
  State<WorldMist> createState() => _WorldMistState();
}

class _WorldMistState extends State<WorldMist> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: StageMeasure.veil,
  );

  @override
  void initState() {
    super.initState();
    if (widget.lifting) _lift.forward();
    _lift.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onLifted?.call();
    });
  }

  @override
  void didUpdateWidget(WorldMist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lifting && !oldWidget.lifting) {
      _lift.forward();
    } else if (!widget.lifting && oldWidget.lifting) {
      _lift.value = 0;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_drift, _lift]),
      builder: (context, _) {
        final hide = Curves.easeInCubic.transform(_lift.value);
        return IgnorePointer(
          child: Opacity(
            opacity: 1 - hide,
            child: ColoredBox(
              color: const Color(0xE60A0908),
              child: CustomPaint(
                painter: _MistPainter(t: _drift.value),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MistPainter extends CustomPainter {
  const _MistPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t * 2 * math.pi;

    void cloud({
      required Offset center,
      required double radius,
      required double alpha,
    }) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color.fromRGBO(236, 228, 214, alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
      );
    }

    cloud(
      center: Offset(w * (0.18 + 0.06 * math.sin(phase)), h * 0.28),
      radius: w * 0.42,
      alpha: 0.16,
    );
    cloud(
      center: Offset(w * (0.78 + 0.05 * math.cos(phase * 0.7)), h * 0.22),
      radius: w * 0.38,
      alpha: 0.13,
    );
    cloud(
      center: Offset(w * (0.52 + 0.08 * math.sin(phase * 1.3)), h * 0.62),
      radius: w * 0.55,
      alpha: 0.18,
    );
    cloud(
      center: Offset(w * (0.08 + 0.04 * math.cos(phase * 0.9)), h * 0.78),
      radius: w * 0.36,
      alpha: 0.12,
    );
    cloud(
      center: Offset(w * (0.92 - 0.05 * math.sin(phase * 0.6)), h * 0.84),
      radius: w * 0.40,
      alpha: 0.14,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x990A0908),
            Color.fromRGBO(10, 9, 8, 0.15 + 0.08 * math.sin(phase)),
            const Color(0xCC0A0908),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _MistPainter old) => old.t != t;
}
