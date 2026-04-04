import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/models/world_template.dart';

class MyWorldCard extends StatelessWidget {
  final WorldTemplate template;
  final bool isPublishing;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onTap;

  const MyWorldCard({
    super.key,
    required this.template,
    this.isPublishing = false,
    this.onEdit,
    this.onPublish,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = !template.isPublished;
    final accent = template.isSentient ? EverloreTheme.violet : EverloreTheme.cyan;

    return GestureDetector(
      onTap: onTap ?? onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EverloreTheme.void2,
              EverloreTheme.void1.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: isDraft
                ? EverloreTheme.ember.withValues(alpha: 0.3)
                : EverloreTheme.verdant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top stripe
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: isDraft
                      ? [EverloreTheme.ember.withValues(alpha: 0.6), EverloreTheme.ember.withValues(alpha: 0.2)]
                      : [EverloreTheme.verdant.withValues(alpha: 0.6), EverloreTheme.verdant.withValues(alpha: 0.2)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          template.isSentient ? Icons.psychology_alt : Icons.auto_stories,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    template.isSentient ? 'Conscious Soul' : 'Game Master',
                                    style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (template.isNsfwCapable)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: EverloreTheme.crimson.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text('18+', style: TextStyle(color: EverloreTheme.crimson, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDraft
                              ? EverloreTheme.ember.withValues(alpha: 0.12)
                              : EverloreTheme.verdant.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDraft
                                ? EverloreTheme.ember.withValues(alpha: 0.4)
                                : EverloreTheme.verdant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDraft ? Icons.edit_note : Icons.public,
                              size: 11,
                              color: isDraft ? EverloreTheme.ember : EverloreTheme.verdant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDraft ? 'DRAFT' : 'LIVE',
                              style: TextStyle(
                                color: isDraft ? EverloreTheme.ember : EverloreTheme.verdant,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Description
                  Text(
                    template.description,
                    style: const TextStyle(color: EverloreTheme.ash, fontSize: 13, height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Stats + tags row
                  if (template.baseStatsTemplate.isNotEmpty || template.sceneTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (template.baseStatsTemplate.isNotEmpty)
                          _InfoChip(
                            icon: Icons.bar_chart,
                            label: '${template.baseStatsTemplate.length} stats',
                            color: EverloreTheme.ash,
                          ),
                        ...template.sceneTags.take(3).map((tag) => _InfoChip(
                              icon: Icons.label_outline,
                              label: tag,
                              color: EverloreTheme.ash,
                            )),
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
                      style: const TextStyle(color: EverloreTheme.ash, fontSize: 11),
                    ),
                  ],
                  // Action buttons (drafts only)
                  if (isDraft) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF252548), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Edit
                        if (onEdit != null)
                          _ActionButton(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            color: EverloreTheme.ash,
                            onTap: onEdit!,
                          ),
                        const Spacer(),
                        // Publish
                        if (onPublish != null)
                          isPublishing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: EverloreTheme.gold),
                                )
                              : _ActionButton(
                                  icon: Icons.public,
                                  label: 'Release to Realm',
                                  color: EverloreTheme.gold,
                                  onTap: onPublish!,
                                ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: EverloreTheme.void4.withValues(alpha: 0.5),
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
