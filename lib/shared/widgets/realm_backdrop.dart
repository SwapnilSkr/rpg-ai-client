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

// Two counter-drifting bands. Top band = one set, bottom band = the other, each
// flowing the opposite direction. Keys map to assets/splash/<key>.webp; missing
// art falls back to a faint rimmed disc, so genres without a portrait yet still
// read as intentional silhouettes.
const List<String> _bandKeysTop = [
  'tsundere', 'kdrama', 'epic_fantasy', 'noir', 'dark_romance', 'cozy_comfort',
  'litrpg', 'modern_casual', 'romcom', 'slice_of_life', 'anime',
];
const List<String> _bandKeysBottom = [
  'cyberpunk', 'shonen', 'yandere', 'dark_academia', 'horror', 'grimdark',
  'flirty', 'regency', 'whimsical', 'chaotic_comedy',
];

const double _discSize = 46;
const double _discGap = 18;
const double _bandGapV = 22; // vertical gap between the two bands

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
    // The bands sit in the Stack OUTSIDE the child's SafeArea, so push them
    // below the status bar / notch ourselves with the top inset.
    final topInset = MediaQuery.paddingOf(context).top;
    final topBandY = topInset + 12;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Vignette + embers.
        AnimatedBuilder(
          animation: _embers,
          builder: (context, _) =>
              CustomPaint(painter: _AmbientPainter(_embers.value)),
        ),
        // Two counter-drifting portrait bands near the top, behind a soft fade.
        if (widget.showPortraits) ...[
          _DriftBand(
            drift: _drift,
            keys: _bandKeysTop,
            top: topBandY,
            reverse: false,
          ),
          _DriftBand(
            drift: _drift,
            keys: _bandKeysBottom,
            top: topBandY + _discSize + _bandGapV,
            reverse: true,
          ),
          // Scrim to guarantee content legibility below the bands.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topBandY + (_discSize * 2) + _bandGapV + 64,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000A0807), EverloreTheme.void0],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
        widget.child,
      ],
    );
  }
}

/// One horizontally-drifting band of portrait discs. [reverse] flips the drift
/// direction so two stacked bands flow opposite ways. Positioned at [top].
class _DriftBand extends StatelessWidget {
  final AnimationController drift;
  final List<String> keys;
  final double top;
  final bool reverse;
  const _DriftBand({
    required this.drift,
    required this.keys,
    required this.top,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context) {
    final span = keys.length * (_discSize + _discGap);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _discSize,
      child: ClipRect(
        child: Opacity(
          opacity: 0.16,
          child: AnimatedBuilder(
            animation: drift,
            builder: (context, _) {
              // forward: 0 → -span (drifts left). reverse: -span → 0 (drifts right).
              final dx =
                  reverse ? (drift.value - 1) * span : -drift.value * span;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: _PortraitBand(keys: keys),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Two seamless copies of the portrait row so the drift wraps without a seam.
class _PortraitBand extends StatelessWidget {
  final List<String> keys;
  const _PortraitBand({required this.keys});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in keys)
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
