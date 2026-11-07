import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';

/// The four authored closeness chips:
/// "Just met", "Friend", "Has a crush on you", "Rival".
class GroupClosenessPicker extends StatelessWidget {
  final GroupCloseness selected;
  final ValueChanged<GroupCloseness> onSelected;
  final bool enabled;
  final String? label;

  const GroupClosenessPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.label,
  });

  static const _options = [
    (GroupCloseness.acquaintance, 'Just met'),
    (GroupCloseness.friend, 'Friend'),
    (GroupCloseness.unrequitedAttraction, 'Has a crush on you'),
    (GroupCloseness.rival, 'Rival'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              label!,
              style: EverloreTheme.ui(
                size: 13,
                color: enabled ? EverloreTheme.parchment : EverloreTheme.ash,
                weight: FontWeight.w600,
              ),
            ),
          )
        else
          const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (closeness, label) in _options) ...[
              _buildChip(closeness, label),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChip(GroupCloseness closeness, String label) {
    final isSelected = selected == closeness;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onSelected(closeness) : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? EverloreTheme.gold.withValues(alpha: 0.16)
                : EverloreTheme.void3.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? EverloreTheme.gold
                  : EverloreTheme.goldDim.withValues(alpha: 0.22),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: EverloreTheme.ui(
              size: 13,
              color: isSelected ? EverloreTheme.gold : EverloreTheme.parchment,
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
