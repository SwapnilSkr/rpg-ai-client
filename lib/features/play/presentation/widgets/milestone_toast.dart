import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/motion.dart';

/// Brass-seal banner stamped over the play screen when a story landmark is
/// crossed ("A page turns: …"). Auto-dismisses, then notifies [onDismissed]
/// so the cubit can clear the one-shot milestone.
class MilestoneToast extends StatefulWidget {
  final String label;

  /// Re-keys the animation so identical labels still retrigger.
  final int stamp;
  final VoidCallback onDismissed;

  const MilestoneToast({
    super.key,
    required this.label,
    required this.stamp,
    required this.onDismissed,
  });

  @override
  State<MilestoneToast> createState() => _MilestoneToastState();
}

class _MilestoneToastState extends State<MilestoneToast> {
  Timer? _reducedMotionDismiss;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _reducedMotionDismiss?.cancel();
    super.dispose();
  }

  Widget _card() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EverloreTheme.gold.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: EverloreTheme.glow(
          EverloreTheme.gold,
          blur: 28,
          alpha: 0.22,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SealWithBurst(stamp: widget.stamp),
          const SizedBox(height: 10),
          Text(
            'A PAGE TURNS',
            style: EverloreTheme.ui(
              size: 10,
              weight: FontWeight.w700,
              color: EverloreTheme.gold.withValues(alpha: 0.75),
              spacing: 2.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: EverloreTheme.serifDisplay(
              size: 17,
              color: EverloreTheme.parchment,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      // Static card, plain timed dismissal — no scale/fade theatrics.
      _reducedMotionDismiss ??= Timer(
        const Duration(milliseconds: 3200),
        widget.onDismissed,
      );
      return IgnorePointer(
        child: Align(alignment: const Alignment(0, -0.55), child: _card()),
      );
    }

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: _card()
            .animate(key: ValueKey('milestone${widget.stamp}'))
            .fadeIn(duration: 300.ms)
            .scaleXY(begin: 0.88, end: 1, duration: 380.ms, curve: Curves.easeOutBack)
            .then(delay: 2800.ms)
            .fadeOut(duration: 450.ms)
            .then()
            .callback(callback: (_) => widget.onDismissed()),
      ),
    );
  }
}

/// The seal icon ringed by a one-shot ember burst (pure CustomPainter —
/// no assets, GPU-cheap).
class _SealWithBurst extends StatefulWidget {
  final int stamp;
  const _SealWithBurst({required this.stamp});

  @override
  State<_SealWithBurst> createState() => _SealWithBurstState();
}

class _SealWithBurstState extends State<_SealWithBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    final seal = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: EverloreTheme.gold.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: const Icon(
        Icons.auto_stories,
        size: 18,
        color: EverloreTheme.gold,
      ),
    );

    if (reduce) return seal;

    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              size: const Size(72, 56),
              painter: _EmberBurstPainter(progress: _controller.value),
            ),
          ),
          seal
              .animate(key: ValueKey('seal${widget.stamp}'))
              .scaleXY(
                begin: 1.7,
                end: 1,
                duration: 450.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 200.ms),
        ],
      ),
    );
  }
}

class _EmberBurstPainter extends CustomPainter {
  final double progress;
  _EmberBurstPainter({required this.progress});

  static const _particleCount = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(7); // fixed seed: same burst shape every time
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * 2 * math.pi + rng.nextDouble() * 0.4;
      final distance = (18 + rng.nextDouble() * 18) * eased;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final radius = (1.6 + rng.nextDouble() * 1.4) * fade;
      final color = (i.isEven ? EverloreTheme.gold : EverloreTheme.ember)
          .withValues(alpha: 0.85 * fade);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_EmberBurstPainter old) => old.progress != progress;
}
