import 'package:flutter/material.dart';
import '../../../../../shared/models/world_instance.dart';
import '../../../../../app/theme/nexus_theme.dart';

// Gradient palettes for realm cards — pick by hash of instanceId
const List<List<Color>> _realmGradients = [
  [Color(0xFF1A0A2E), Color(0xFF0D1A3E)], // Arcane Violet → Deep Navy
  [Color(0xFF1A1500), Color(0xFF0E1A10)], // Dark Amber → Forest Dark
  [Color(0xFF0A1A1A), Color(0xFF0A0E2A)], // Teal Void → Midnight
  [Color(0xFF1A0D0D), Color(0xFF1A0A22)], // Crimson Dark → Violet
  [Color(0xFF0A120A), Color(0xFF121A0A)], // Verdant Dark → Moss
];

const List<Color> _accentColors = [
  EverloreTheme.violet,
  EverloreTheme.gold,
  EverloreTheme.cyanBright,
  Color(0xFFEC4899), // rose
  Color(0xFF34D399), // emerald
];

class WorldCard extends StatelessWidget {
  final WorldInstance instance;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const WorldCard({
    super.key,
    required this.instance,
    required this.onTap,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = instance.template?['title'] as String? ?? 'Untitled Realm';
    final description = instance.template?['description'] as String? ?? '';
    final isSentient = instance.template?['is_sentient'] as bool? ?? false;
    final sceneTag = instance.currentScene.tag;

    final colorIdx = instance.id.hashCode.abs() % _realmGradients.length;
    final gradColors = _realmGradients[colorIdx];
    final accentColor = _accentColors[colorIdx];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradColors,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              splashColor: accentColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + title + archive
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // World type icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            isSentient
                                ? Icons.psychology_alt
                                : Icons.auto_stories,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: EverloreTheme.parchment,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSentient
                                    ? 'Sentient World'
                                    : 'Game Master World',
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onArchive != null || onDelete != null)
                          GestureDetector(
                            onTap: () => _showOptions(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: EverloreTheme.white10,
                              ),
                              child: const Icon(
                                Icons.more_horiz,
                                color: EverloreTheme.ash,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Divider
                    Container(
                      height: 1,
                      color: accentColor.withValues(alpha: 0.1),
                    ),

                    const SizedBox(height: 14),

                    // Stats row
                    Row(
                      children: [
                        _Stat(
                          icon: Icons.chat_bubble_outline,
                          label: '${instance.meta.totalEvents}',
                          tooltip: 'Events',
                          color: accentColor,
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          icon: Icons.bookmark_outline,
                          label: '${instance.meta.totalMemories}',
                          tooltip: 'Echoes',
                          color: accentColor,
                        ),
                        const SizedBox(width: 12),
                        _SceneTag(tag: sceneTag, color: accentColor),
                        const Spacer(),
                        _TimeAgo(
                          dateTime: instance.meta.lastActiveAt,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (onArchive != null)
                _OptionTile(
                  icon: Icons.archive_outlined,
                  label: 'Seal Realm (Archive)',
                  subtitle:
                      'Preserve your story but hide it from active realms',
                  onTap: () {
                    Navigator.pop(ctx);
                    onArchive!();
                  },
                ),
              if (onDelete != null)
                _OptionTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Destroy Realm (Delete)',
                  subtitle: 'Permanently erase this realm and all its echoes',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EverloreTheme.crimson.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: EverloreTheme.crimson, size: 24),
            SizedBox(width: 10),
            Text(
              'Destroy This Realm?',
              style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your realm and all its history, memories, and echoes. This action cannot be undone.',
          style: TextStyle(color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep Realm',
              style: TextStyle(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text(
              'Destroy Forever',
              style: TextStyle(color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
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
        child: Icon(icon, color: color, size: 20),
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

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: EverloreTheme.ash, fontSize: 12),
        ),
      ],
    );
  }
}

class _SceneTag extends StatelessWidget {
  final String tag;
  final Color color;

  const _SceneTag({required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TimeAgo extends StatelessWidget {
  final DateTime? dateTime;
  final Color color;

  const _TimeAgo({this.dateTime, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(dateTime),
      style: TextStyle(
        color: EverloreTheme.ash.withValues(alpha: 0.6),
        fontSize: 11,
      ),
    );
  }

  String _format(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
