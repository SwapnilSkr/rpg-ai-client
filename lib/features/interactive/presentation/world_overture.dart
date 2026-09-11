import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';

/// A tap-through of the duchy, painted from its own rooms, before anyone walks.
class WorldOvertureStage extends StatefulWidget {
  const WorldOvertureStage({
    super.key,
    required this.overture,
    required this.onFinished,
    this.onLeave,
  });

  final WorldOverture overture;
  final VoidCallback onFinished;
  final VoidCallback? onLeave;

  @override
  State<WorldOvertureStage> createState() => _WorldOvertureStageState();
}

class _WorldOvertureStageState extends State<WorldOvertureStage> {
  int _page = 0;

  WorldOvertureBeat get _beat =>
      widget.overture.beats[_page.clamp(0, widget.overture.beats.length - 1)];

  bool get _last => _page >= widget.overture.beats.length - 1;

  void _advance() {
    if (_last) {
      widget.onFinished();
      return;
    }
    setState(() => _page += 1);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.overture.beats.length;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 480),
          child: StageBackdrop(
            key: ValueKey(_beat.sceneUrl ?? _page),
            url: _beat.sceneUrl,
            veil: StageVeil.room,
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onLeave,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: EverloreTheme.parchment,
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        widget.overture.kicker.toUpperCase(),
                        style: EverloreTheme.caption.copyWith(
                          color: StageMeasure.brass,
                          letterSpacing: 1.5,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onFinished,
                      child: Text(
                        'SKIP',
                        style: EverloreTheme.caption.copyWith(
                          color: StageMeasure.brass,
                          letterSpacing: 1.6,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: IgnorePointer(child: SizedBox.expand())),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    StageMeasure.roomPanelFoot,
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_page),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    builder: (context, value, child) =>
                        Opacity(opacity: value, child: child),
                    child: StagePanel(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _beat.mark,
                            style: EverloreTheme.caption.copyWith(
                              color: StageMeasure.brassDeep,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _beat.title,
                            style: EverloreTheme.serifDisplay(
                              size: 22,
                              color: StageMeasure.ink,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _beat.body,
                            style: EverloreTheme.aiText.copyWith(
                              color: StageMeasure.inkMuted,
                              fontSize: 16,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              for (var i = 0; i < total; i++) ...[
                                Container(
                                  width: i == _page ? 18 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: StageMeasure.brassDeep.withValues(
                                      alpha: i == _page ? 0.95 : 0.28,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                if (i < total - 1) const SizedBox(width: 6),
                              ],
                              const Spacer(),
                              Text(
                                _last ? 'CHOOSE WHO WALKS' : 'CONTINUE',
                                style: EverloreTheme.caption.copyWith(
                                  color: StageMeasure.brassDeep,
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const StageAdvance(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
