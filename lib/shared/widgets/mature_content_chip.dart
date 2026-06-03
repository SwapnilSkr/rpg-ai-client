import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

/// Pill label for NSFW-capable worlds and characters — pairs with genre chips
/// (champagne) using a rose–crimson mature palette, no separate asset icon.
enum MatureChipDensity { compact, standard }

class MatureContentChip extends StatelessWidget {
  final MatureChipDensity density;

  const MatureContentChip({
    super.key,
    this.density = MatureChipDensity.standard,
  });

  static const String label = 'Mature';

  @override
  Widget build(BuildContext context) {
    final compact = density == MatureChipDensity.compact;
    final fontSize = compact ? 9.5 : 10.5;
    final iconSize = compact ? 11.0 : 13.0;
    final hPad = compact ? 7.0 : 9.0;
    final vPad = compact ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EverloreTheme.crimson.withValues(alpha: 0.16),
            EverloreTheme.rose.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: EverloreTheme.crimson.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: EverloreTheme.rose.withValues(alpha: 0.10),
            blurRadius: compact ? 4 : 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: iconSize,
            color: compact
                ? EverloreTheme.rose.withValues(alpha: 0.95)
                : const Color(0xFFF472B6),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              color: compact
                  ? EverloreTheme.parchment.withValues(alpha: 0.92)
                  : const Color(0xFFF9A8D4),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? 0.2 : 0.35,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
