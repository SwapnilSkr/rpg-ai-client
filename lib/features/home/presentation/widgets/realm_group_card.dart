import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/app_icons.dart';
import '../../../../shared/models/world_instance.dart';
import '../../domain/realm_group.dart';

/// One world on "Your Realms" — may represent several stories in progress.
class RealmGroupCard extends StatelessWidget {
  final RealmGroup group;
  final ValueChanged<WorldInstance> onStoryTap;
  final VoidCallback onViewStories;
  final ValueChanged<WorldInstance> onArchiveStory;
  final ValueChanged<WorldInstance> onDeleteStory;

  const RealmGroupCard({
    super.key,
    required this.group,
    required this.onStoryTap,
    required this.onViewStories,
    required this.onArchiveStory,
    required this.onDeleteStory,
  });

  @override
  Widget build(BuildContext context) {
    final template = group.template ?? group.latest.template;
    final imageUrl = template?['image_url'] as String? ?? '';
    final description = template?['description'] as String? ?? '';
    final isSentient = template?['is_sentient'] as bool? ?? false;
    final accent = isSentient ? EverloreTheme.aetherBright : EverloreTheme.gold;
    final visibleStories = group.stories.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 14,
              offset: const Offset(2, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: group.hasMultipleStories
                    ? onViewStories
                    : () => onStoryTap(group.latest),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.58),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    gradient: imageUrl.isEmpty
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF231A12), Color(0xFF0D0A07)],
                          )
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Icon(
                          isSentient
                              ? Icons.psychology_alt
                              : Icons.auto_stories,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.ui(
                                size: 17,
                                color: EverloreTheme.parchment,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                isSentient
                                    ? 'Sentient World'
                                    : 'Game Master World',
                                '${group.storyCount} ${group.storyCount == 1 ? 'story' : 'stories'}',
                              ].join(' • '),
                              style: EverloreTheme.ui(size: 11, color: accent),
                            ),
                            if (description.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: EverloreTheme.ui(
                                  size: 12,
                                  color: EverloreTheme.ash,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (group.hasMultipleStories)
                        Icon(
                          Icons.chevron_right,
                          color: EverloreTheme.ash.withValues(alpha: 0.7),
                        ),
                    ],
                  ),
                ),
              ),
              for (final story in visibleStories)
                _StoryRow(
                  instance: story,
                  accent: accent,
                  onTap: () => onStoryTap(story),
                  onArchive: () => onArchiveStory(story),
                  onDelete: () => onDeleteStory(story),
                ),
              if (group.stories.length > visibleStories.length)
                InkWell(
                  onTap: onViewStories,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      'View all ${group.storyCount} stories',
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.gold,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  final WorldInstance instance;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _StoryRow({
    required this.instance,
    required this.accent,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final last = instance.meta.lastActiveAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            EvIcon(AppIcons.event, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instance.currentScene.tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${instance.meta.totalEvents} events',
                      '${instance.meta.totalMemories} echoes',
                      if (last != null) _relative(last),
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Story options',
              onPressed: () => _showOptions(context),
              icon: const Icon(
                Icons.more_horiz,
                color: EverloreTheme.ash,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.archive_outlined,
                color: EverloreTheme.ash,
              ),
              title: const Text(
                'Archive story',
                style: TextStyle(color: EverloreTheme.parchment),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onArchive();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: EverloreTheme.crimson,
              ),
              title: const Text(
                'Delete story',
                style: TextStyle(color: EverloreTheme.crimson),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'now';
  }
}
