import 'package:flutter/material.dart';

import 'stage_tokens.dart';

/// The gently pulsing chevron that means tap to continue.
///
/// The fight does not run on its own, and a conversation does not turn
/// the page for someone looking away. The mark is the same on both so
/// a player is not taught two ways to go on.
class StageAdvance extends StatefulWidget {
  const StageAdvance({super.key});

  @override
  State<StageAdvance> createState() => _StageAdvanceState();
}

class _StageAdvanceState extends State<StageAdvance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: StageMeasure.pulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_pulse),
      child: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: StageMeasure.brassDeep,
        size: StageMeasure.advanceGlyph,
      ),
    );
  }
}
