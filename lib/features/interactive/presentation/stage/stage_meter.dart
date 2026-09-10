import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_avatar.dart';
import 'stage_tokens.dart';

/// A combatant's status strip.
///
/// The bar is the only thing on the sand that could contradict the
/// words, so it is fed the standing the exchange already left — a
/// total this widget added up itself could drift a hit out of step
/// and leave the loser standing while the Herald reads that they fell.
/// Nothing is written inside the bar: it is drawn, not counted.
class StageMeter extends StatelessWidget {
  const StageMeter({
    super.key,
    required this.name,
    required this.role,
    required this.portraitUrl,
    required this.vigour,
    required this.of,
    required this.seat,
  });

  final String name;
  final String role;
  final String? portraitUrl;
  final int vigour;
  final int of;
  final StageMeterSeat seat;

  /// Height of the strip including the safe inset it sits against, so
  /// a name-plate or a skip can stand just above it without guessing.
  static double extentOf(BuildContext context, {required bool top}) {
    final pad = MediaQuery.paddingOf(context);
    return (top ? pad.top : pad.bottom) + StageMeasure.meterExtent;
  }

  @override
  Widget build(BuildContext context) {
    final far = seat == StageMeterSeat.far;
    final left = of <= 0 ? 0.0 : (vigour / of).clamp(0.0, 1.0);
    final pad = MediaQuery.paddingOf(context);
    final medallion = StageAvatar(name: name, portraitUrl: portraitUrl);
    final readouts = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: far
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: far ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              name,
              maxLines: 1,
              style: EverloreTheme.caption.copyWith(
                color: StageMeasure.parchment,
                letterSpacing: 0.8,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: far ? TextAlign.right : TextAlign.left,
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.parchment.withValues(alpha: 0.68),
              letterSpacing: 0.5,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );

    // Safe inset lives outside the mirrored body. Putting pad.top inside
    // one strip and not the other is how the far bar became a hairline
    // against the screen edge while the near bar sat inset.
    return ColoredBox(
      color: StageMeasure.ground.withValues(alpha: 0.78),
      child: Padding(
        padding: EdgeInsets.only(
          top: far ? pad.top : 0,
          bottom: far ? 0 : pad.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            StageMeasure.meterPad,
            StageMeasure.meterInner,
            StageMeasure.meterPad,
            StageMeasure.meterInner,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: far
                    ? BorderSide.none
                    : BorderSide(
                        color: StageMeasure.brassDeep.withValues(alpha: 0.45),
                      ),
                bottom: far
                    ? BorderSide(
                        color: StageMeasure.brassDeep.withValues(alpha: 0.45),
                      )
                    : BorderSide.none,
              ),
            ),
            child: SizedBox(
              height: StageMeasure.meterBody,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: far
                          ? [readouts, const SizedBox(width: 10), medallion]
                          : [medallion, const SizedBox(width: 10), readouts],
                    ),
                  ),
                  const SizedBox(height: StageMeasure.meterBarGap),
                  _Bar(left: left, fromRight: far),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.left, required this.fromRight});

  final double left;
  final bool fromRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StageMeasure.meterBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(
            color: StageMeasure.brassDeep.withValues(alpha: 0.7),
          ),
        ),
        child: Align(
          alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: left, end: left),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              // The expanded child is load-bearing: a ColoredBox with
              // nothing in it collapses to nothing under a loose
              // constraint and paints no bar at all, silently.
              child: ColoredBox(
                color: value > 0.5
                    ? StageMeasure.brass
                    : value > 0.25
                    ? StageMeasure.ember
                    : StageMeasure.danger,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
