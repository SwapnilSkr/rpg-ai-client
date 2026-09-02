import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/app_icons.dart';
import '../../../../shared/models/world_instance.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../domain/realm_group.dart';
import '../../../../shared/text_format.dart';
import '../../../../app/layout/responsive.dart';

/// A realm-level overview for the home feed. Stories deliberately live on the
/// dedicated playthrough screen so a realm with a long history does not turn
/// this feed into an expanding list inside a list.
class RealmGroupCard extends StatelessWidget {
  final RealmGroup group;
  final ValueChanged<WorldInstance> onContinue;
  final VoidCallback onViewStories;

  const RealmGroupCard({
    super.key,
    required this.group,
    required this.onContinue,
    required this.onViewStories,
  });

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
                  InkWell(
                    onTap: () => onContinue(latest),
                    child: Padding(
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
                                  isSentient
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
                  ),
                ],
              ),
              Container(height: 1, color: EverloreTheme.white10),
              InkWell(
                onTap: () => onContinue(latest),
                child: Padding(
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
                                countLabel(latest.meta.totalMemories, 'echo', plural: 'echoes'),
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
                      // On the narrowest phones the word costs about a third
                      // of the line the scene and its tally have to share.
                      // The chevron already says "continue", so spend the
                      // width on the story instead.
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
              ),
              if (group.hasMultipleStories)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onViewStories,
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_outlined,
                                color: accent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                countLabel(group.storyCount, 'story', plural: 'stories'),
                                style: EverloreTheme.ui(
                                  size: 11,
                                  color: accent,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  /// The scene tag is an internal word, so this card headed a playthrough
  /// with "Dialogue". Same fix as the Chronicle's almanac.
  String _sceneLabel(String tag) =>
      tag.trim().isEmpty ? 'Continue the story' : sceneMomentLabel(tag, '');

  String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'now';
  }
}
