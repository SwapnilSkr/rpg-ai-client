import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// A large number or short phrase that rises off a struck figure and fades.
///
/// Heavy and bright, with a dark outline so it reads on any painting.
/// The exchange the Verdict turns on is drawn wider and in the danger
/// colour — a number treated like any other blow would hide the one
/// that decided the matter.
class StageFloat extends StatelessWidget {
  const StageFloat({super.key, required this.text, this.alarming = false});

  final String text;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: StageMeasure.rise,
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: (1 - value).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -28 * value),
          child: child,
        ),
      ),
      child: alarming
          ? _Alarm(text: text)
          : Text(
              text,
              textAlign: TextAlign.center,
              style:
                  EverloreTheme.serifDisplay(
                    size: StageMeasure.floatSize,
                    color: StageMeasure.parchment,
                    weight: FontWeight.w700,
                  ).copyWith(
                    shadows: const [
                      Shadow(
                        color: StageMeasure.ground,
                        blurRadius: 2,
                        offset: Offset(-1.4, 0),
                      ),
                      Shadow(
                        color: StageMeasure.ground,
                        blurRadius: 2,
                        offset: Offset(1.4, 0),
                      ),
                      Shadow(
                        color: StageMeasure.ground,
                        blurRadius: 2,
                        offset: Offset(0, -1.4),
                      ),
                      Shadow(
                        color: StageMeasure.ground,
                        blurRadius: 2,
                        offset: Offset(0, 1.4),
                      ),
                      Shadow(
                        color: StageMeasure.ground,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
            ),
    );
  }
}

class _Alarm extends StatelessWidget {
  const _Alarm({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.72,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style:
            EverloreTheme.serifDisplay(
              size: StageMeasure.floatAlarm,
              color: StageMeasure.danger,
              weight: FontWeight.w700,
              spacing: 3.2,
            ).copyWith(
              shadows: const [
                Shadow(
                  color: StageMeasure.ground,
                  blurRadius: 2,
                  offset: Offset(-1.6, 0),
                ),
                Shadow(
                  color: StageMeasure.ground,
                  blurRadius: 2,
                  offset: Offset(1.6, 0),
                ),
                Shadow(
                  color: StageMeasure.ground,
                  blurRadius: 2,
                  offset: Offset(0, -1.6),
                ),
                Shadow(
                  color: StageMeasure.ground,
                  blurRadius: 2,
                  offset: Offset(0, 1.6),
                ),
                Shadow(
                  color: StageMeasure.ground,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
      ),
    );
  }
}
