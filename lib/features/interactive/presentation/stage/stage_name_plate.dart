import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// The ornamented name ribbon.
///
/// Two placements, one widget: sitting under a figure's feet, or
/// overlapping the upper edge of a parchment panel on the speaker's
/// side. A second ribbon invented beside it is how a fight and a
/// conversation stopped naming people the same way.
class StageNamePlate extends StatelessWidget {
  const StageNamePlate({
    super.key,
    required this.name,
    this.seat = StagePlateSeat.feet,
  });

  final String name;
  final StagePlateSeat seat;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: StageMeasure.plateHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StageMeasure.ground.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(StageMeasure.plateRadius),
          border: const Border(
            top: BorderSide(color: StageMeasure.brass, width: 1.1),
            bottom: BorderSide(color: StageMeasure.brass, width: 1.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: seat == StagePlateSeat.panel ? 8 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StageMeasure.platePadX,
            vertical: 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Flourish(),
              const SizedBox(width: 10),
              Flexible(
                // A title may be authored longer than this world's names.
                // Losing its end makes the fighter anonymous; the ribbon may
                // yield type size, but never the words it was built to hold.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: EverloreTheme.serifDisplay(
                      size: 13,
                      color: StageMeasure.parchment,
                      weight: FontWeight.w600,
                      spacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const _Flourish(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small brass marks at each end, so the ribbon is a name-plate and not
/// a pill the interface invented.
class _Flourish extends StatelessWidget {
  const _Flourish();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(StageMeasure.flourish, StageMeasure.flourish),
      painter: const _FlourishPainter(),
    );
  }
}

class _FlourishPainter extends CustomPainter {
  const _FlourishPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StageMeasure.brass.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(size.width, cy)
      ..lineTo(cx, size.height)
      ..lineTo(0, cy)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(cx, cy),
      1.1,
      Paint()..color = StageMeasure.brass.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
