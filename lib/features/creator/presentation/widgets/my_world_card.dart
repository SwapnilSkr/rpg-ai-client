import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/app_icons.dart';
import '../../../../../shared/models/world_template.dart';
import '../../../../../shared/widgets/mature_content_chip.dart';
import '../../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/text_format.dart';
import 'world_status_chip.dart';

class MyWorldCard extends StatelessWidget {
  final WorldTemplate template;
  final bool isPublishing;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onTap;
  final Future<bool> Function()? onDelete;
  final VoidCallback? onMakePrivate;
  final VoidCallback? onShareWithAll;

  const MyWorldCard({
    super.key,
    required this.template,
    this.isPublishing = false,
    this.onEdit,
    this.onPublish,
    this.onTap,
    this.onDelete,
    this.onMakePrivate,
    this.onShareWithAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = !template.isPublished;
    final accent = template.isSentient
        ? EverloreTheme.violet
        : EverloreTheme.cyan;
    final isWorking = isPublishing;
    final statusColor = isPublishing
        ? EverloreTheme.gold
        : isDraft
        ? EverloreTheme.ember
        : EverloreTheme.verdant;

    return GestureDetector(
      onTap: isWorking ? null : (onTap ?? onEdit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // A dark smoked-glass surface preserves a hint of the cover
              // without allowing busy artwork to compete with the card copy.
              EverloreTheme.void1.withValues(alpha: 0.84),
              EverloreTheme.void2.withValues(alpha: 0.78),
            ],
          ),
          border: Border.all(
            color: isDraft
                ? EverloreTheme.ember.withValues(alpha: 0.3)
                : EverloreTheme.verdant.withValues(alpha: 0.3),
          ),
          // Forged 3D: deep bottom-right shadow + faint status-tinted top light.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(3, 5),
            ),
            BoxShadow(
              color: (isDraft ? EverloreTheme.ember : EverloreTheme.verdant)
                  .withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(-2, -3),
            ),
          ],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar thumbnail (generated image) or a type icon
                        Container(
                          width: 40,
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: template.imageUrl.isNotEmpty
                              ? ClipOval(
                                  child: EverloreNetworkImage(
                                    imageUrl: template.imageUrl,
                                    memCacheWidth: 160,
                                    semanticLabel: template.title,
                                  ),
                                )
                              : Icon(
                                  template.isSentient
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
                                template.title,
                                style: const TextStyle(
                                  color: EverloreTheme.parchment,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      template.isSentient
                                          ? 'Conscious Soul'
                                          : 'Game Master',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (template.isNsfwCapable)
                                    const MatureContentChip(
                                      density: MatureChipDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        WorldStatusChip(
                          template: template,
                          isWorking: isWorking,
                          showNote: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Description
                    Text(
                      template.description,
                      style: const TextStyle(
                        color: EverloreTheme.ash,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Stats + tags row
                    if (template.baseStatsTemplate.isNotEmpty ||
                        template.sceneTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (template.baseStatsTemplate.isNotEmpty)
                            _InfoChip(
                              icon: Icons.bar_chart,
                              label:
                                  countLabel(template.baseStatsTemplate.length, 'stat'),
                              color: EverloreTheme.ash,
                            ),
                          ...template.sceneTags
                              .take(3)
                              .map(
                                (tag) => _InfoChip(
                                  icon: Icons.label_outline,
                                  label: humanizeTag(tag),
                                  color: EverloreTheme.ash,
                                ),
                              ),
                          if (template.sceneTags.length > 3)
                            _InfoChip(
                              icon: Icons.more_horiz,
                              label: '+${template.sceneTags.length - 3}',
                              color: EverloreTheme.ash,
                            ),
                        ],
                      ),
                    ],
                    // Creation date
                    if (template.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Forged ${_timeAgo(template.createdAt!)}',
                        style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (isDraft) ...[
                      const SizedBox(height: 12),
                      const Divider(color: EverloreTheme.white10, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (onEdit != null)
                            _ActionButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: EverloreTheme.ash,
                              onTap: isWorking ? null : onEdit!,
                            ),
                          if (onDelete != null) ...[
                            const SizedBox(width: 16),
                            _ActionButton(
                              assetIcon: AppIcons.destroy,
                              label: 'Delete',
                              color: EverloreTheme.crimson,
                              onTap: isWorking
                                  ? null
                                  : () => _confirmDelete(context),
                            ),
                          ],
                          const Spacer(),
                          if (isWorking)
                            _ActionProgress(
                              label: 'Releasing…',
                              color: statusColor,
                            )
                          else if (onPublish != null)
                            _ActionButton(
                              assetIcon: AppIcons.publish,
                              label: 'Publish',
                              color: EverloreTheme.gold,
                              onTap: onPublish!,
                            ),
                        ],
                      ),
                    ] else if (onEdit != null ||
                        onTap != null ||
                        onDelete != null ||
                        onMakePrivate != null ||
                        onShareWithAll != null) ...[
                      const SizedBox(height: 12),
                      const Divider(color: EverloreTheme.white10, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (onEdit != null)
                            _ActionButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: EverloreTheme.ash,
                              onTap: isWorking ? null : onEdit!,
                            ),
                          const Spacer(),
                          if (onDelete != null)
                            _ActionButton(
                              assetIcon: AppIcons.destroy,
                              label: 'Delete',
                              color: EverloreTheme.crimson,
                              onTap: () => _confirmDelete(context),
                            ),
                          if (onDelete != null && onTap != null)
                            const SizedBox(width: 16),
                          if (onTap != null)
                            _ActionButton(
                              icon: Icons.visibility_outlined,
                              label: 'Preview',
                              color: EverloreTheme.verdant,
                              onTap: onTap!,
                            ),
                          if (onMakePrivate != null || onShareWithAll != null) ...[
                            const SizedBox(width: 6),
                            PopupMenuButton<String>(
                              tooltip: 'World options',
                              color: EverloreTheme.void2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                                ),
                              ),
                              icon: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: EverloreTheme.ash,
                              ),
                              onSelected: (action) {
                                if (action == 'make_private') {
                                  onMakePrivate?.call();
                                } else if (action == 'share_with_all') {
                                  onShareWithAll?.call();
                                }
                              },
                              itemBuilder: (context) => [
                                if (onMakePrivate != null)
                                  PopupMenuItem(
                                    value: 'make_private',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_outline,
                                          size: 16,
                                          color: EverloreTheme.ash,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Make it just for you',
                                          style: EverloreTheme.ui(
                                            size: 13,
                                            color: EverloreTheme.parchment,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (onShareWithAll != null)
                                  PopupMenuItem(
                                    value: 'share_with_all',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.public,
                                          size: 16,
                                          color: EverloreTheme.gold,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Share with every traveller',
                                          style: EverloreTheme.ui(
                                            size: 13,
                                            color: EverloreTheme.parchment,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final isDraft = !template.isPublished;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var isDestroying = false;
        String? deleteError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: EverloreTheme.void2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: EverloreTheme.crimson.withValues(alpha: 0.3),
              ),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: EverloreTheme.crimson,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isDraft ? 'Unforge This World?' : 'Destroy This World?',
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              deleteError ??
                  (isDraft
                      ? 'This draft will be permanently deleted. This action cannot be undone.'
                      : 'This will permanently delete your world and all adventurer realms created from it. This action cannot be undone.'),
              style: TextStyle(
                color: deleteError == null
                    ? EverloreTheme.ash
                    : EverloreTheme.crimson,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDestroying ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Keep World',
                  style: TextStyle(color: EverloreTheme.ash),
                ),
              ),
              TextButton(
                onPressed: isDestroying
                    ? null
                    : () async {
                        setDialogState(() => isDestroying = true);
                        final deleted = await onDelete?.call() ?? false;
                        if (!ctx.mounted) return;
                        if (deleted) {
                          Navigator.pop(ctx);
                        } else {
                          setDialogState(() {
                            isDestroying = false;
                            deleteError =
                                'The deletion could not be completed. This world is still here — try again.';
                          });
                        }
                      },
                child: isDestroying
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: EverloreTheme.crimson,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Destroying…',
                            style: TextStyle(color: EverloreTheme.crimson),
                          ),
                        ],
                      )
                    : const Text(
                        'Destroy Forever',
                        style: TextStyle(color: EverloreTheme.crimson),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: EverloreTheme.void4.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? assetIcon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    this.icon,
    this.assetIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onTap == null ? 0.42 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetIcon != null)
              EvIcon(assetIcon!, size: 16)
            else
              Icon(icon!, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionProgress extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionProgress({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
