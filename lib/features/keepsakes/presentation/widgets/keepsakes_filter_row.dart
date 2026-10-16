import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../models/keepsake_item.dart';

/// Segmented filter row with mode toggle (§3.2, §3.3):
/// All · Pictures · Films · Faces, and a feed/grid toggle at right.
class KeepsakesFilterRow extends StatelessWidget {
  final KeepsakesFilter selectedFilter;
  final KeepsakesViewMode viewMode;
  final ValueChanged<KeepsakesFilter> onFilterChanged;
  final ValueChanged<KeepsakesViewMode> onModeChanged;

  const KeepsakesFilterRow({
    super.key,
    required this.selectedFilter,
    required this.viewMode,
    required this.onFilterChanged,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFaces = selectedFilter == KeepsakesFilter.faces;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filter pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in KeepsakesFilter.values) ...[
                    _FilterChip(
                      label: filter.label,
                      selected: selectedFilter == filter,
                      onTap: () => onFilterChanged(filter),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // View mode toggle (Feed vs Grid) — disabled / hidden when Faces is selected
          if (!isFaces)
            Container(
              decoration: BoxDecoration(
                color: EverloreTheme.void2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    icon: Icons.view_agenda_outlined,
                    tooltip: 'Feed view',
                    active: viewMode == KeepsakesViewMode.feed,
                    onTap: () => onModeChanged(KeepsakesViewMode.feed),
                  ),
                  _ModeButton(
                    icon: Icons.grid_view_rounded,
                    tooltip: 'Grid view',
                    active: viewMode == KeepsakesViewMode.grid,
                    onTap: () => onModeChanged(KeepsakesViewMode.grid),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? EverloreTheme.gold.withValues(alpha: 0.16)
              : EverloreTheme.void2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? EverloreTheme.gold
                : EverloreTheme.goldDim.withValues(alpha: 0.22),
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: EverloreTheme.ui(
            size: 13,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? EverloreTheme.gold : EverloreTheme.ash,
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(
        icon,
        size: 18,
        color: active ? EverloreTheme.gold : EverloreTheme.ash,
      ),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
