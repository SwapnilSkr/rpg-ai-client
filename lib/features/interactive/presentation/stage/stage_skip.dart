import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// A round translucent control with a skip glyph and its word beneath it.
///
/// Reading the fight is optional; the outcome is not. The control lands
/// the player on the Verdict rather than closing the screen, so nobody
/// leaves the sand without being told what was decided on it.
class StageSkip extends StatelessWidget {
  const StageSkip({super.key, required this.label, required this.onSkip});

  final String label;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSkip,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: StageMeasure.skipColumn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: StageMeasure.skipSize,
                height: StageMeasure.skipSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StageMeasure.ground.withValues(alpha: 0.55),
                    border: Border.all(
                      color: StageMeasure.brassDim.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    color: StageMeasure.parchment,
                    size: StageMeasure.skipGlyph,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: EverloreTheme.caption.copyWith(
                  color: StageMeasure.parchment.withValues(alpha: 0.82),
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
