import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import 'stage_tokens.dart';

/// A cream speech bubble with a tail that points at the speaker.
///
/// One or two short lines, never a paragraph. A bubble on every
/// exchange turns a Verdict into banter; this is only for a line
/// shouted mid-fight, where the author wrote one.
class StageBubble extends StatelessWidget {
  const StageBubble({super.key, required this.text, required this.toward});

  final String text;
  final StageSide toward;

  @override
  Widget build(BuildContext context) {
    final tailLeft = toward == StageSide.left;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: StageMeasure.bubbleMaxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: tailLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: StageMeasure.cream,
              borderRadius: BorderRadius.circular(StageMeasure.bubbleRadius),
              border: Border.all(
                color: StageMeasure.brassDeep.withValues(alpha: 0.5),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                text,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 16,
                  color: StageMeasure.ink,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(tailLeft ? 18 : -18, -1),
            child: CustomPaint(
              size: const Size(
                StageMeasure.bubbleTail,
                StageMeasure.bubbleTail,
              ),
              painter: _TailPainter(pointLeft: tailLeft),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.pointLeft});

  final bool pointLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointLeft) {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width * 0.35, 0)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.65, 0)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = StageMeasure.cream);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.pointLeft != pointLeft;
}
