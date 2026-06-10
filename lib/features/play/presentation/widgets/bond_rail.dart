import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/character_profile.dart';

/// Always-on relationship presence — the active cast as tappable bond tokens.
///
/// Lifts the relationship ledger out of the buried Thoughts sheet onto the play
/// screen: each token is a character's initial wrapped in a ring whose color +
/// sweep track their most salient meter. The arc eases to new values, so when a
/// `character_codex_updated` turn lands the player watches a bond shift in
/// place. Tapping a token opens the same contextual bond-action sheet.
class BondRail extends StatelessWidget {
  final List<CharacterProfile> characters;
  final ValueChanged<CharacterProfile> onTapCharacter;

  /// Lowercased names present in the current scene, or null when presence is
  /// unknown. Tokens for characters who are elsewhere render dimmed.
  final Set<String>? presentNames;

  const BondRail({
    super.key,
    required this.characters,
    required this.onTapCharacter,
    this.presentNames,
  });

  @override
  Widget build(BuildContext context) {
    // Only side characters the story has actually bonded with — protagonist
    // excluded (the player has no meters toward themself), and meterless cards
    // omitted so a fresh scene stays uncluttered. Most-mentioned first.
    final cast =
        characters
            .where((c) => !c.isProtagonist && c.relationship != null)
            .toList()
          ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
    final shown = cast.take(5).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        physics: const BouncingScrollPhysics(),
        itemCount: shown.length,
        itemBuilder: (context, i) => _BondToken(
          character: shown[i],
          // Unknown presence (null) → treat as here, so existing worlds are
          // unaffected; only a known-absent character dims.
          present:
              presentNames?.contains(shown[i].canonicalName.toLowerCase()) ??
              true,
          onTap: () {
            HapticFeedback.lightImpact();
            onTapCharacter(shown[i]);
          },
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
      ),
    );
  }
}

/// Resolve a character's most salient meter into a (value, color) the ring
/// renders. Mirrors [BondMeters]' colour language so the two surfaces read the
/// same. Fear/rivalry win when elevated (they are dramatic and start at 0);
/// otherwise the highest of trust/affection leads.
({int value, Color color}) _dominantMeter(RelationshipMeters m) {
  final candidates = <({int value, Color color, int priority})>[
    (value: m.fear, color: EverloreTheme.violetBright, priority: 1),
    (value: m.rivalry, color: EverloreTheme.crimson, priority: 1),
    (value: m.trust, color: EverloreTheme.verdant, priority: 0),
    (value: m.affection, color: EverloreTheme.ember, priority: 0),
  ];
  ({int value, Color color, int priority})? best;
  for (final c in candidates) {
    // Weight fear/rivalry so a moderate dread outshines neutral trust/affection.
    final weighted = c.value + (c.priority == 1 && c.value >= 40 ? 30 : 0);
    final bestWeighted = best == null
        ? -1
        : best.value + (best.priority == 1 && best.value >= 40 ? 30 : 0);
    if (best == null || weighted > bestWeighted) best = c;
  }
  return (value: best!.value, color: best.color);
}

class _BondToken extends StatelessWidget {
  final CharacterProfile character;
  final bool present;
  final VoidCallback onTap;

  const _BondToken({
    required this.character,
    required this.present,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meter = _dominantMeter(character.relationship!);
    final name = character.canonicalName.trim();
    final firstName = name.contains(' ') ? name.split(' ').first : name;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedOpacity(
        // Elsewhere → dimmed so the in-scene cast reads at a glance.
        opacity: present ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 300),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (meter.value / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, sweep, _) => CustomPaint(
                painter: _RingPainter(sweep: sweep, color: meter.color),
                child: Center(
                  child: Text(
                    initial,
                    style: EverloreTheme.serifDisplay(
                      size: 17,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 52,
            child: Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EverloreTheme.ui(
                size: 10,
                color: EverloreTheme.ash,
                spacing: 0.2,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// A thin track ring with a coloured sweep of [sweep] (0–1), plus the avatar
/// fill behind the initial.
class _RingPainter extends CustomPainter {
  final double sweep;
  final Color color;

  _RingPainter({required this.sweep, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Avatar disc.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()..color = EverloreTheme.void3,
    );

    // Full track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = EverloreTheme.void4,
    );

    // Coloured sweep, starting at 12 o'clock, clockwise.
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            colors: [color.withValues(alpha: 0.55), color],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.sweep != sweep || old.color != color;
}
