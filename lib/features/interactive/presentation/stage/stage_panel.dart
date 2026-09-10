import 'package:flutter/material.dart';

import 'stage_tokens.dart';

/// The parchment document: warm aged paper, dark ink, brass edge, soft
/// grain, the drop shadow that lifts it off the painting.
///
/// Every block of read text on the sand and in a room goes in one of
/// these. Two parchments remembering different creams is how a Verdict
/// and a spoken line stopped being written on the same paper.
class StagePanel extends StatelessWidget {
  const StagePanel({
    super.key,
    required this.child,
    this.padding,
    this.expand = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Fill the incoming box. Without a tight child a DecoratedBox under
  /// a loose constraint paints nothing, silently.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: _PaperGrain()),
        Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                StageMeasure.panelPadX,
                StageMeasure.panelPadY,
                StageMeasure.panelPadX,
                StageMeasure.panelPadY,
              ),
          child: child,
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [StageMeasure.paper, StageMeasure.paperDeep],
        ),
        borderRadius: BorderRadius.circular(StageMeasure.panelRadius),
        border: Border.all(
          color: StageMeasure.brassDeep.withValues(alpha: 0.45),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: StageMeasure.panelShadowBlur,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: expand ? SizedBox.expand(child: body) : body,
    );
  }
}

class _PaperGrain extends StatelessWidget {
  const _PaperGrain();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StageMeasure.paperGrainLight,
              Color(0x00000000),
              StageMeasure.paperGrainDark,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
