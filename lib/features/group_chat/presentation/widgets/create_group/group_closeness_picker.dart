import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';

/// The four authored closeness tiles:
/// "Just met", "Friend", "Has a crush on you", "Rival".
/// Arranged in two rows of two expanded tiles, never a wrap.
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
    (
      GroupCloseness.acquaintance,
      'Just met',
      Icons.waving_hand_outlined,
      EverloreTheme.ash,
    ),
    (
      GroupCloseness.friend,
      'Friend',
      Icons.handshake_outlined,
      EverloreTheme.gold,
    ),
    (
      GroupCloseness.unrequitedAttraction,
      'Has a crush on you',
      Icons.favorite_border,
      EverloreTheme.rose,
    ),
    (GroupCloseness.rival, 'Rival', Icons.bolt_outlined, EverloreTheme.ember),
  ];

  /// Canonical tone for each closeness level across all views.
  static Color toneOf(GroupCloseness? bond, [Color? fallback]) {
    if (fallback != null) return fallback;
    switch (bond) {
      case GroupCloseness.acquaintance:
        return EverloreTheme.ash;
      case GroupCloseness.friend:
        return EverloreTheme.gold;
      case GroupCloseness.unrequitedAttraction:
        return EverloreTheme.rose;
      case GroupCloseness.rival:
        return EverloreTheme.ember;
      case null:
        return EverloreTheme.ash;
    }
  }

  /// Canonical player-facing label for each closeness level.
  static String labelOf(GroupCloseness? bond) {
    switch (bond) {
      case GroupCloseness.acquaintance:
        return 'Just met';
      case GroupCloseness.friend:
        return 'Friend';
      case GroupCloseness.unrequitedAttraction:
        return 'Has a crush on you';
      case GroupCloseness.rival:
        return 'Rival';
      case null:
        return 'Just met';
    }
  }

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
                size: 12,
                weight: FontWeight.w500,
                color: enabled
                    ? EverloreTheme.ash
                    : EverloreTheme.ash.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTile(_options[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildTile(_options[1])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTile(_options[2])),
            const SizedBox(width: 8),
            Expanded(child: _buildTile(_options[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildTile((GroupCloseness, String, IconData, Color) option) {
    final (closeness, labelText, icon, tone) = option;
    final isSelected = selected == closeness;

    return SizedBox(
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onSelected(closeness) : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? tone.withValues(alpha: 0.14)
                  : EverloreTheme.void3.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? tone
                    : EverloreTheme.goldDim.withValues(alpha: 0.22),
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? tone
                      : (enabled ? EverloreTheme.parchment : EverloreTheme.ash),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labelText,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(
                      size: 13,
                      color: isSelected
                          ? tone
                          : (enabled
                                ? EverloreTheme.parchment
                                : EverloreTheme.ash),
                      weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
