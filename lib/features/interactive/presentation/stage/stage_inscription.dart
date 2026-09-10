import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// The matter of the fight, as a slim dark band under the far strip.
///
/// Putting this on parchment made two cream documents on one sand,
/// and the question sat on the opponent's standard.
class StageInscription extends StatelessWidget {
  const StageInscription({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StageMeasure.ground.withValues(
          alpha: StageMeasure.inscriptionFill,
        ),
        border: const Border(
          left: BorderSide(
            color: StageMeasure.brass,
            width: StageMeasure.inscriptionRule,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          StageMeasure.inscriptionPadX,
          StageMeasure.inscriptionPadY,
          StageMeasure.inscriptionPadX,
          StageMeasure.inscriptionPadY,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: EverloreTheme.aiText.copyWith(
            fontSize: 15,
            color: StageMeasure.parchment.withValues(alpha: 0.88),
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
