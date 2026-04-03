import 'package:flutter/material.dart';

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
    final barColor = color ?? _colorForValue(fraction);

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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              Text(
                '${value.toInt()}/${max.toInt()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForValue(double fraction) {
    if (fraction > 0.7) return Colors.redAccent;
    if (fraction > 0.4) return Colors.amberAccent;
    return Colors.greenAccent;
  }
}
