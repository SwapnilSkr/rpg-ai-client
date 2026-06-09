import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/world_instance.dart';

/// The story spine — landmarks the playthrough has crossed, rendered as a
/// vertical timeline (oldest first). Backed by the persisted `meta.milestones`
/// and grown live as new ones unlock. Tapping a landmark, or the footer, opens
/// the full Chronicle.
class StoryTimelineSheet extends StatelessWidget {
  final List<Milestone> milestones;
  final VoidCallback onOpenChronicle;

  const StoryTimelineSheet({
    super.key,
    required this.milestones,
    required this.onOpenChronicle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined,
                    size: 18, color: EverloreTheme.gold),
                const SizedBox(width: 8),
                Text(
                  'Story Timeline',
                  style: EverloreTheme.serifDisplay(
                    size: 18,
                    color: EverloreTheme.parchment,
                  ),
                ),
                const Spacer(),
                if (milestones.isNotEmpty)
                  Text(
                    '${milestones.length}',
                    style: EverloreTheme.ui(
                      size: 12,
                      weight: FontWeight.w700,
                      color: EverloreTheme.goldDim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'The landmarks your story has crossed.',
              style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.ash,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            if (milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No landmarks yet — vows, first kisses, victories and '
                  'betrayals will be sealed here as your story turns.',
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.ash,
                    height: 1.4,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: milestones.length,
                  itemBuilder: (_, i) => _MilestoneRow(
                    milestone: milestones[i],
                    isFirst: i == 0,
                    isLast: i == milestones.length - 1,
                    onTap: onOpenChronicle,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenChronicle,
                icon: const Icon(Icons.menu_book_outlined, size: 16),
                label: Text(
                  'Open full Chronicle',
                  style: EverloreTheme.ui(size: 13, color: EverloreTheme.gold),
                ),
                style: TextButton.styleFrom(foregroundColor: EverloreTheme.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Milestone milestone;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _MilestoneRow({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spine: connecting line + brass seal node.
            SizedBox(
              width: 26,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isFirst
                            ? Colors.transparent
                            : EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const Icon(Icons.workspace_premium,
                      size: 16, color: EverloreTheme.gold),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.label,
                      style: EverloreTheme.serifDisplay(
                        size: 15,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Turn ${milestone.sequence}',
                      style: EverloreTheme.ui(
                        size: 11,
                        color: EverloreTheme.ash,
                        spacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(Icons.chevron_right,
                  size: 16, color: EverloreTheme.goldDim),
            ),
          ],
        ),
      ),
    );
  }
}
