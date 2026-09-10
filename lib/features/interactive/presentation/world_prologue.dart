import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';

/// Authored opening beats for the bound lead, then the walk begins.
class WorldPrologueStage extends StatefulWidget {
  const WorldPrologueStage({
    super.key,
    required this.prologue,
    required this.onFinished,
  });

  final WorldPrologue prologue;
  final VoidCallback onFinished;

  @override
  State<WorldPrologueStage> createState() => _WorldPrologueStageState();
}

class _WorldPrologueStageState extends State<WorldPrologueStage> {
  int _page = 0;

  bool get _last => _page >= widget.prologue.beats.length - 1;

  void _advance() {
    if (_last) {
      widget.onFinished();
      return;
    }
    setState(() => _page += 1);
  }

  @override
  Widget build(BuildContext context) {
    final beat = widget.prologue.beats[_page.clamp(0, widget.prologue.beats.length - 1)];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: Stack(
        fit: StackFit.expand,
        children: [
          StageBackdrop(url: widget.prologue.sceneUrl, veil: StageVeil.room),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, StageMeasure.roomPanelFoot),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_page),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
                child: StagePanel(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.prologue.headline,
                        style: EverloreTheme.serifDisplay(
                          size: 18,
                          color: StageMeasure.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        beat,
                        style: EverloreTheme.aiText.copyWith(
                          color: StageMeasure.inkMuted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _last ? 'BEGIN' : 'CONTINUE',
                          style: EverloreTheme.caption.copyWith(
                            color: StageMeasure.brassDeep,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
