import 'package:flutter/material.dart';
import '../../../../../shared/models/memory.dart';
import '../../../../../app/theme/nexus_theme.dart';

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MemoryCard({
    super.key,
    required this.memory,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(memory.type);
    final typeIcon = _typeIcon(memory.type);
    final typeLabel = _typeLabel(memory.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: typeColor.withValues(alpha: 0.1),
                    border: Border.all(
                        color: typeColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 10, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Importance stars
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < memory.importance ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 12,
                    color: i < memory.importance
                        ? EverloreTheme.gold
                        : EverloreTheme.white20,
                  ),
                ),

                const Spacer(),

                // Edit / Delete
                if (onEdit != null)
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: EverloreTheme.ash,
                    onTap: onEdit!,
                  ),
                if (onDelete != null)
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: EverloreTheme.crimson.withValues(alpha: 0.6),
                    onTap: onDelete!,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Memory text
            Text(
              memory.text,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 14,
                height: 1.6,
              ),
            ),

            if (memory.isArchived) ...[
              const SizedBox(height: 8),
              Text(
                'Faded — no longer active',
                style: TextStyle(
                  color: EverloreTheme.ash.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'relationship' => const Color(0xFFEC4899),
      'promise' => EverloreTheme.gold,
      'lore' => EverloreTheme.cyanBright,
      'observation' => EverloreTheme.violetBright,
      'emotion' => const Color(0xFFF97316),
      'secret' => EverloreTheme.crimson,
      _ => EverloreTheme.ash,
    };
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'relationship' => Icons.favorite_outline,
      'promise' => Icons.handshake_outlined,
      'lore' => Icons.auto_stories,
      'observation' => Icons.visibility_outlined,
      'emotion' => Icons.sentiment_satisfied_outlined,
      'secret' => Icons.lock_outline,
      _ => Icons.bookmark_outline,
    };
  }

  String _typeLabel(String type) {
    return switch (type) {
      'relationship' => 'Bond',
      'promise' => 'Oath',
      'lore' => 'Lore',
      'observation' => 'Sight',
      'emotion' => 'Feeling',
      'secret' => 'Secret',
      _ => type,
    };
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
