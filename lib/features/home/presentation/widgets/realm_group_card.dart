import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/layout/responsive.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/app_icons.dart';
import '../../../../shared/models/world_instance.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_sheet.dart';
import '../../domain/realm_group.dart';
import '../../../../shared/text_format.dart';

/// A realm-level overview for the home feed. Stories deliberately live on the
/// dedicated playthrough screen so a realm with a long history does not turn
/// this feed into an expanding list inside a list.
class RealmGroupCard extends StatelessWidget {
  final RealmGroup group;
  final ValueChanged<WorldInstance> onContinue;
  final VoidCallback onViewStories;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;

  const RealmGroupCard({
    super.key,
    required this.group,
    required this.onContinue,
    required this.onViewStories,
    this.onDelete,
    this.onArchive,
  });

  bool get _walks => group.isInteractiveWorld;

  @override
  Widget build(BuildContext context) {
    final template = group.template ?? group.latest.template;
    final imageUrl = template?['image_url'] as String? ?? '';
    final description = template?['description'] as String? ?? '';
    final isSentient = template?['is_sentient'] as bool? ?? false;
    final accent = isSentient ? EverloreTheme.aetherBright : EverloreTheme.gold;
    final latest = group.latest;
    final scene = _sceneLabel(latest.currentScene.tag);
    final last = latest.meta.lastActiveAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: EverloreTheme.void2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.44),
              blurRadius: 14,
              offset: const Offset(2, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onContinue(latest),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showActions(context);
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.56),
                            BlendMode.darken,
                          ),
                          child: EverloreNetworkImage(
                            imageUrl: imageUrl,
                            memCacheWidth: 1080,
                            errorWidget: const SizedBox.shrink(),
                            semanticLabel: group.title,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                                  ? Icons.psychology_alt_rounded
                                  : Icons.auto_stories_rounded,
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
                                  _walks
                                      ? 'Walkable World'
                                      : isSentient
                                      ? 'Sentient World'
                                      : 'Game Master World',
                                  style: EverloreTheme.ui(
                                    size: 11,
                                    color: accent,
                                  ),
                                ),
                                if (description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    maxLines: 1,
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
                        ],
                      ),
                    ),
                  ],
                ),
                Container(height: 1, color: EverloreTheme.white10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      EvIcon(AppIcons.event, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scene,
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
                                countLabel(latest.meta.totalEvents, 'event'),
                                countLabel(
                                  latest.meta.totalMemories,
                                  'echo',
                                  plural: 'echoes',
                                ),
                                if (last != null) _relative(last),
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EverloreTheme.ui(
                                size: 11,
                                color: EverloreTheme.ash,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!EvLayout.of(context).isCompact)
                        Text(
                          'Continue',
                          style: EverloreTheme.ui(
                            size: 12,
                            color: accent,
                            weight: FontWeight.w700,
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final latest = group.latest;
    showEverloreSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabHandle(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(
                      size: 16,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _ActionTile(
                icon: AppIcons.continueStory,
                label: _walks ? 'Continue this walk' : 'Continue this story',
                subtitle: _walks
                    ? 'Pick up where you left the map'
                    : 'Pick up where you left off',
                onTap: () {
                  Navigator.pop(ctx);
                  onContinue(latest);
                },
              ),
              if (group.hasMultipleStories)
                _ActionTile(
                  iconWidget: Icon(
                    Icons.layers_outlined,
                    color: EverloreTheme.parchment,
                    size: 22,
                  ),
                  label: _walks ? 'View all walks' : 'View all stories',
                  subtitle: countLabel(
                    group.storyCount,
                    _walks ? 'walk' : 'story',
                    plural: _walks ? 'walks' : 'stories',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onViewStories();
                  },
                )
              else ...[
                if (onArchive != null)
                  _ActionTile(
                    icon: AppIcons.seal,
                    label: _walks ? 'Seal this walk' : 'Seal this story',
                    subtitle: _walks
                        ? 'Hide it from your active walks'
                        : 'Hide it from your active realms',
                    onTap: () {
                      Navigator.pop(ctx);
                      onArchive!();
                    },
                  ),
                if (onDelete != null)
                  _ActionTile(
                    icon: AppIcons.destroy,
                    label: _walks ? 'Destroy this walk' : 'Destroy this story',
                    subtitle: 'Erase it and all its echoes forever',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text(
          _walks ? 'Destroy this walk?' : 'Destroy this story?',
          style: const TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: Text(
          _walks
              ? 'This will permanently erase this walk and everything that happened in it.'
              : 'This will permanently erase this story and everything that happened in it.',
          style: const TextStyle(
            color: EverloreTheme.ash,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep it',
              style: TextStyle(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text(
              'Destroy forever',
              style: TextStyle(color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }

  /// The scene tag is an internal word, so this card headed a playthrough
  /// with "Dialogue". Same fix as the Chronicle's almanac.
  String _sceneLabel(String tag) => tag.trim().isEmpty
      ? (_walks ? 'Continue the walk' : 'Continue the story')
      : sceneMomentLabel(tag, '');

  String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'now';
  }
}

class _ActionTile extends StatelessWidget {
  final String? icon;
  final Widget? iconWidget;
  final String label;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? EverloreTheme.crimson
        : EverloreTheme.parchment;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive
              ? EverloreTheme.crimson.withValues(alpha: 0.1)
              : EverloreTheme.void3,
        ),
        child: iconWidget ??
            Opacity(
              opacity: isDestructive ? 0.82 : 1,
              child: EvIcon(icon!, size: 22),
            ),
      ),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: EverloreTheme.ash, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}
