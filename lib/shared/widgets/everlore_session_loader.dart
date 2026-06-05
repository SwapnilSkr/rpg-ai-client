import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';
import 'neu.dart';

/// Full-screen forged loader while a quick session check runs.
Future<T?> showEverloreSessionLoading<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: EverloreTheme.void0.withValues(alpha: 0.88),
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(child: EverloreSessionLoader(message: message)),
    ),
  );
  try {
    return await task();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Compact forged-orbit loader for short session resolves (profile tab, etc.).
/// Matches the splash sigil language without the full character theatre.
class EverloreSessionLoader extends StatefulWidget {
  final String? message;

  const EverloreSessionLoader({super.key, this.message});

  @override
  State<EverloreSessionLoader> createState() => _EverloreSessionLoaderState();
}

class _EverloreSessionLoaderState extends State<EverloreSessionLoader>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbit, _pulse]),
      builder: (context, _) {
        final glow = 0.35 + 0.3 * _pulse.value;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: CustomPaint(
                painter: _SessionOrbitPainter(
                  orbit: _orbit.value,
                  glow: glow,
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.88 + 0.12 * _pulse.value,
                    child: const ForgeMark(size: 76),
                  ),
                ),
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 26),
              Text(
                widget.message!.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.ash.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SessionOrbitPainter extends CustomPainter {
  final double orbit;
  final double glow;

  const _SessionOrbitPainter({required this.orbit, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = EverloreTheme.goldDim.withValues(alpha: 0.22 + glow * 0.2);

    _ellipse(canvas, center, 72, 28, ringPaint);
    _ellipse(canvas, center, 48, 18, ringPaint..color = EverloreTheme.violet.withValues(alpha: 0.18 + glow * 0.15));

    const beadCount = 8;
    for (var i = 0; i < beadCount; i++) {
      final t = orbit * 2 * math.pi + (i / beadCount) * 2 * math.pi;
      final outer = i.isEven;
      final rx = outer ? 72.0 : 48.0;
      final ry = outer ? 28.0 : 18.0;
      final speed = outer ? 1.0 : -1.35;
      final angle = t * speed + (outer ? 0.0 : 0.6);
      final pos = Offset(
        center.dx + rx * math.cos(angle),
        center.dy + ry * math.sin(angle),
      );
      final depth = 0.5 + 0.5 * math.sin(angle);
      final r = (outer ? 5.0 : 4.0) * (0.75 + 0.25 * depth);
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = (outer ? EverloreTheme.gold : EverloreTheme.violet)
              .withValues(alpha: 0.35 + depth * 0.45),
      );
    }

    // Specular sweep across the sigil disc.
    final sweep = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + orbit * 2, -0.5),
        end: Alignment(orbit * 2, 0.5),
        colors: [
          Colors.transparent,
          EverloreTheme.goldGlow.withValues(alpha: 0.08 + glow * 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 42));
    canvas.drawCircle(center, 42, sweep);
  }

  void _ellipse(Canvas canvas, Offset center, double rx, double ry, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, ry / rx);
    canvas.drawCircle(Offset.zero, rx, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SessionOrbitPainter old) =>
      old.orbit != orbit || old.glow != glow;
}
