import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/character_profile.dart';

/// Compact relationship ledger readout — the four meters that make a bond
/// inspectable and playable. Fills ease to their values; colors are stable
/// per meter so players learn the language (green trust, warm affection…).
class BondMeters extends StatelessWidget {
  final RelationshipMeters meters;
  final bool dense;

  const BondMeters({super.key, required this.meters, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int, Color)>[
      ('Trust', meters.trust, EverloreTheme.verdant),
      ('Affection', meters.affection, EverloreTheme.ember),
      if (meters.fear > 0) ('Fear', meters.fear, EverloreTheme.violetBright),
      if (meters.rivalry > 0) ('Rivalry', meters.rivalry, EverloreTheme.crimson),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value, color) in rows)
          Padding(
            padding: EdgeInsets.only(top: dense ? 4 : 6),
            child: Row(
              children: [
                SizedBox(
                  width: dense ? 58 : 70,
                  child: Text(
                    label,
                    style: EverloreTheme.ui(
                      size: dense ? 10 : 11,
                      color: EverloreTheme.ash,
                      spacing: 0.3,
                    ),
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (value / 100).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, pct, _) => Stack(
                      children: [
                        Container(
                          height: dense ? 4 : 5,
                          decoration: BoxDecoration(
                            color: EverloreTheme.void4,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: dense ? 4 : 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [color.withValues(alpha: 0.65), color],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: color,
                      fontSize: dense ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
