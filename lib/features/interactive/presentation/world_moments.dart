import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';

/// After the lead's own death: take the hinge again, or walk as someone else.
class WorldDeathSheet extends StatelessWidget {
  const WorldDeathSheet({
    super.key,
    required this.death,
    required this.busy,
    required this.onRestore,
    required this.onRebind,
    required this.onLeave,
  });

  final WorldDeath death;
  final bool busy;
  final ValueChanged<String> onRestore;
  final ValueChanged<WorldLeadCard> onRebind;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0908)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onLeave,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: EverloreTheme.parchment,
                    tooltip: 'Leave',
                  ),
                ),
                Text(
                  'A HINGE',
                  style: EverloreTheme.caption.copyWith(
                    color: StageMeasure.brass,
                    letterSpacing: 1.6,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  death.title,
                  style: EverloreTheme.serifDisplay(
                    size: 24,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  death.body,
                  style: EverloreTheme.aiText.copyWith(
                    color: EverloreTheme.parchment.withValues(alpha: 0.8),
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                if (death.restoreId != null)
                  StageChoice(
                    label: death.restoreTitle == null
                        ? 'Take the fight again'
                        : 'Replay · ${death.restoreTitle}',
                    busy: busy,
                    onPressed: busy ? null : () => onRestore(death.restoreId!),
                  ),
                if (death.restoreId != null) const SizedBox(height: 10),
                if (death.rebind.isNotEmpty) ...[
                  Text(
                    'Or walk this same world as someone still standing.',
                    style: EverloreTheme.caption.copyWith(
                      color: StageMeasure.brass,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: death.rebind.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final lead = death.rebind[index];
                        return StageChoice(
                          label: 'Walk as ${lead.name}',
                          busy: busy,
                          onPressed: busy ? null : () => onRebind(lead),
                        );
                      },
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The road behind this save. Restoring a step undoes everything after it.
class WorldMomentsSheet extends StatelessWidget {
  const WorldMomentsSheet({
    super.key,
    required this.moments,
    required this.busy,
    required this.onRestore,
    required this.onClose,
  });

  final List<WorldMoment> moments;
  final bool busy;
  final ValueChanged<String> onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final road = moments.reversed.toList();
    return Material(
      color: const Color(0xF20A0908),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'THE ROAD BEHIND YOU',
                      style: EverloreTheme.caption.copyWith(
                        color: StageMeasure.brass,
                        letterSpacing: 1.6,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: EverloreTheme.parchment,
                    tooltip: 'Close',
                  ),
                ],
              ),
              Text(
                'Take any step again. What came after is undone — flags, talks, and what the world remembers. Strength you earned in the yards stays.',
                style: EverloreTheme.aiText.copyWith(
                  color: EverloreTheme.parchment.withValues(alpha: 0.78),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: road.isEmpty
                    ? Text(
                        'The road is still ahead of you. Walk, speak, or take a marked choice, and the step will be waiting here.',
                        style: EverloreTheme.aiText.copyWith(
                          color: EverloreTheme.parchment.withValues(alpha: 0.55),
                          fontSize: 15,
                        ),
                      )
                    : ListView.separated(
                        itemCount: road.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _MomentCard(
                            moment: road[index],
                            latest: index == 0,
                            busy: busy,
                            onRestore: onRestore,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.latest,
    required this.busy,
    required this.onRestore,
  });

  final WorldMoment moment;
  final bool latest;
  final bool busy;
  final ValueChanged<String> onRestore;

  ({String label, Color color}) get _mark {
    if (moment.fatal) {
      return (label: 'FATAL', color: StageMeasure.danger);
    }
    return switch (moment.kind) {
      'hinge' => (label: 'HINGE', color: StageMeasure.brass),
      'travel' => (label: 'ROAD', color: StageMeasure.brassDim),
      'talk' => (label: 'WORD', color: StageMeasure.brassDim),
      'rule' => (label: 'RULING', color: StageMeasure.brass),
      _ => (label: 'DEED', color: StageMeasure.brassDim),
    };
  }

  @override
  Widget build(BuildContext context) {
    final mark = _mark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6100C0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mark.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                latest ? '${mark.label} · LAST STEP' : mark.label,
                style: EverloreTheme.caption.copyWith(
                  color: mark.color,
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
              if (moment.place.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    moment.place.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: EverloreTheme.caption.copyWith(
                      color: EverloreTheme.parchment.withValues(alpha: 0.45),
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            moment.title,
            style: EverloreTheme.serifDisplay(
              size: 17,
              color: EverloreTheme.parchment,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            moment.hint,
            style: EverloreTheme.aiText.copyWith(
              color: EverloreTheme.parchment.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          StageChoice(
            label: 'Return to this step',
            busy: busy,
            onPressed: busy ? null : () => onRestore(moment.id),
          ),
        ],
      ),
    );
  }
}
