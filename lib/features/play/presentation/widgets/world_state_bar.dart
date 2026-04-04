import 'package:flutter/material.dart';
import '../../../../../app/theme/nexus_theme.dart';

class WorldStateBar extends StatelessWidget {
  final Map<String, num> worldState;
  final bool expanded;
  final VoidCallback onToggle;

  const WorldStateBar({
    super.key,
    required this.worldState,
    this.expanded = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
          bottom: BorderSide(color: EverloreTheme.white10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed summary / toggle header
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: EverloreTheme.goldDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'REALM STATUS',
                    style: TextStyle(
                      color: EverloreTheme.gold.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (!expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatRow(worldState: worldState),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: EverloreTheme.ash.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          // Expanded stats grid
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: worldState.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RPGStatBar(
                      label: _formatLabel(e.key),
                      value: e.value.toDouble(),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

/// Small inline dots shown in collapsed state
class _MiniStatRow extends StatelessWidget {
  final Map<String, num> worldState;
  const _MiniStatRow({required this.worldState});

  @override
  Widget build(BuildContext context) {
    final entries = worldState.entries.take(4).toList();
    return Row(
      children: entries.map((e) {
        final pct = (e.value / 100).clamp(0.0, 1.0).toDouble();
        final color = _statColor(pct);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4)
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _statColor(double pct) {
    if (pct >= 0.6) return EverloreTheme.verdant;
    if (pct >= 0.3) return EverloreTheme.ember;
    return EverloreTheme.crimson;
  }
}

/// Full RPG-style stat bar shown when expanded
class _RPGStatBar extends StatelessWidget {
  final String label;
  final double value;

  const _RPGStatBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Assume max 100 unless value > 100
    final max = value > 100 ? value : 100.0;
    final pct = (value / max).clamp(0.0, 1.0);
    final color = _statColor(pct);

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: EverloreTheme.ash,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              // Background track
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Filled portion
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.7),
                        color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _statColor(double pct) {
    if (pct >= 0.6) return EverloreTheme.verdant;
    if (pct >= 0.3) return EverloreTheme.ember;
    return EverloreTheme.crimson;
  }
}
