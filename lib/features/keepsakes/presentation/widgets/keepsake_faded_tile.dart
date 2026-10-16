import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';

/// Rendered when a piece's file fails to load (§3.5):
/// A muted parchment tile with a faint crest and "This keepsake has faded",
/// at the exact 9:16 aspect ratio, never black or empty.
class KeepsakeFadedTile extends StatelessWidget {
  final double? width;
  final double? height;

  const KeepsakeFadedTile({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1E1A17), // muted warm parchment/stone
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.18),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF26211C),
              Color(0xFF181513),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: EverloreTheme.goldDim.withValues(alpha: 0.25),
                    ),
                    color: EverloreTheme.void3.withValues(alpha: 0.5),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This keepsake has faded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: EverloreTheme.aiText.fontFamily,
                    fontStyle: FontStyle.italic,
                    color: EverloreTheme.ash.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
