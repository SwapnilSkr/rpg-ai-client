import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../domain/realm_group.dart';
import 'world_card.dart';

/// One world on "Your Realms" — may represent several stories in progress.
class RealmGroupCard extends StatelessWidget {
  final RealmGroup group;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const RealmGroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        WorldCard(
          instance: group.latest,
          onTap: onTap,
          onArchive: onArchive,
          onDelete: onDelete,
        ),
        if (group.hasMultipleStories)
          Positioned(
            top: 16,
            right: 28,
            child: _StoryCountBadge(count: group.storyCount),
          ),
      ],
    );
  }
}

class _StoryCountBadge extends StatelessWidget {
  final int count;
  const _StoryCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 story' : '$count stories';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [EverloreTheme.goldGlow, EverloreTheme.gold],
        ),
        border: Border.all(color: EverloreTheme.goldHot.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: EverloreTheme.gold.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: EverloreTheme.uiFamily,
          color: EverloreTheme.void0,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
