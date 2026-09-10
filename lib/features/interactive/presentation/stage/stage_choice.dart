import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// An authored action set into the world's dark brasswork.
///
/// Stock outlined buttons made every room feel like the same form. The words
/// remain supplied by the world; only their shared stage treatment lives here.
class StageChoice extends StatelessWidget {
  const StageChoice({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(StageMeasure.choiceRadius),
          splashColor: StageMeasure.brass.withValues(alpha: 0.10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  StageMeasure.ground.withValues(alpha: enabled ? 0.92 : 0.62),
                  StageMeasure.groundRaised.withValues(
                    alpha: enabled ? 0.86 : 0.56,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(StageMeasure.choiceRadius),
              border: Border.all(
                color: StageMeasure.brassDim.withValues(
                  alpha: enabled ? 0.55 : 0.24,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: StageMeasure.choiceMinHeight,
              ),
              child: Row(
                children: [
                  Container(
                    width: StageMeasure.choiceRule,
                    height: StageMeasure.choiceRuleHeight,
                    color: StageMeasure.brass.withValues(
                      alpha: enabled ? 0.85 : 0.32,
                    ),
                  ),
                  const SizedBox(width: StageMeasure.choicePadX),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StageMeasure.choicePadY,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.left,
                        style: EverloreTheme.aiText.copyWith(
                          color: StageMeasure.parchment.withValues(
                            alpha: enabled ? 0.94 : 0.48,
                          ),
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StageMeasure.choicePadX,
                    ),
                    child: busy
                        ? SizedBox.square(
                            dimension: StageMeasure.choiceGlyph,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: StageMeasure.brassDim,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            size: StageMeasure.choiceGlyph,
                            color: StageMeasure.brassDim.withValues(
                              alpha: enabled ? 0.9 : 0.35,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
