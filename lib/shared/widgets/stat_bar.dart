import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

class StatBar extends StatelessWidget {
  final String label;
  final num value;
  final num max;
  final Color? color;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 100,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.0, 1.0).toDouble();
    final barColor = color ?? _colorForFraction(fraction);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: EverloreTheme.ash, fontSize: 12),
              ),
              Text(
                '${value.toInt()} / ${max.toInt()}',
                style: TextStyle(
                  color: barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        barColor.withValues(alpha: 0.7),
                        barColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: barColor.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForFraction(double fraction) {
    if (fraction >= 0.6) return EverloreTheme.verdant;
    if (fraction >= 0.3) return EverloreTheme.ember;
    return EverloreTheme.crimson;
  }
}
