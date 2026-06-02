import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

/// Shared ambient backdrop for the gate → threshold journey (splash, welcome,
/// auth). Renders the void vignette + drifting embers, and — when
/// [showPortraits] is true — a faint, slowly-drifting band of character
/// portraits near the top ("the worlds await"), kept dim so it never fights
/// form legibility. Place content as [child]; it sits above the backdrop.
class RealmBackdrop extends StatefulWidget {
  final Widget child;
  final bool showPortraits;
  const RealmBackdrop({super.key, required this.child, this.showPortraits = true});

  @override
  State<RealmBackdrop> createState() => _RealmBackdropState();
}

// The portraits drifting in the band (a subset of the splash orbit set).
const List<String> _bandKeys = [
  'tsundere', 'cyberpunk', 'kdrama', 'epic_fantasy', 'noir', 'shonen',
  'dark_romance', 'cozy_comfort', 'yandere', 'litrpg', 'dark_academia', 'horror',
];

const double _discSize = 46;
const double _discGap = 18;
double get _bandSpan => _bandKeys.length * (_discSize + _discGap);

class _RealmBackdropState extends State<RealmBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _embers;
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _embers = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
  }

  @override
  void dispose() {
    _embers.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Vignette + embers.
        AnimatedBuilder(
          animation: _embers,
          builder: (context, _) =>
              CustomPaint(painter: _AmbientPainter(_embers.value)),
        ),
        // Drifting portrait band near the top, behind a soft fade.
        if (widget.showPortraits)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 132,
            child: ClipRect(
              child: Opacity(
                opacity: 0.16,
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(-_drift.value * _bandSpan, 36),
                    child: const _PortraitBand(),
                  ),
                ),
              ),
            ),
          ),
        // Scrim to guarantee content legibility over the band.
        if (widget.showPortraits)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000A0807), EverloreTheme.void0],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// Two seamless copies of the portrait row so the drift wraps without a seam.
class _PortraitBand extends StatelessWidget {
  const _PortraitBand();

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in _bandKeys)
          Padding(
            padding: const EdgeInsets.only(right: _discGap),
            child: _BandDisc(assetKey: key),
          ),
      ],
    );
    return OverflowBox(
      maxWidth: double.infinity,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [row, row]),
    );
  }
}

class _BandDisc extends StatelessWidget {
  final String assetKey;
  const _BandDisc({required this.assetKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _discSize,
      height: _discSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/splash/$assetKey.webp',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => const ColoredBox(
            color: EverloreTheme.void3,
          ),
        ),
      ),
    );
  }
}

/// Background vignette + a field of slow-drifting ember motes.
class _AmbientPainter extends CustomPainter {
  final double t;
  _AmbientPainter(this.t);

  static final List<_Ember> _embers = List.generate(16, (i) {
    final rnd = math.Random(i * 7 + 3);
    return _Ember(
      x: rnd.nextDouble(),
      baseY: rnd.nextDouble(),
      speed: 0.3 + rnd.nextDouble() * 0.7,
      size: 0.8 + rnd.nextDouble() * 1.8,
      phase: rnd.nextDouble(),
      gold: rnd.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.0,
          colors: [
            EverloreTheme.void2.withValues(alpha: 0.5),
            EverloreTheme.void0,
          ],
        ).createShader(Offset.zero & size),
    );

    for (final e in _embers) {
      final prog = (t * e.speed + e.phase) % 1.0;
      final y = (e.baseY - prog) % 1.0;
      final twinkle =
          0.3 + 0.7 * (0.5 + 0.5 * math.sin((prog + e.phase) * math.pi * 4));
      final dx =
          e.x * size.width + math.sin((prog + e.phase) * math.pi * 2) * 10;
      final dy = y * size.height;
      final color =
          e.gold ? EverloreTheme.goldGlow : EverloreTheme.violetBright;
      canvas.drawCircle(
        Offset(dx, dy),
        e.size,
        Paint()
          ..color = color.withValues(alpha: 0.08 + twinkle * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t;
}

class _Ember {
  final double x, baseY, speed, size, phase;
  final bool gold;
  const _Ember({
    required this.x,
    required this.baseY,
    required this.speed,
    required this.size,
    required this.phase,
    required this.gold,
  });
}
