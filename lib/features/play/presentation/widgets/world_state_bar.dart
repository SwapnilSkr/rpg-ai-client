import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/motion.dart';

class WorldStateBar extends StatelessWidget {
  final Map<String, num> worldState;
  final bool expanded;
  final VoidCallback onToggle;

  /// Stat changes from the latest completed turn — drives the floating
  /// delta chips and bar pulses. Null/empty when nothing moved.
  final Map<String, num>? deltas;

  const WorldStateBar({
    super.key,
    required this.worldState,
    this.expanded = false,
    required this.onToggle,
    this.deltas,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: 0.45),
        border: const Border(
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
                      child: Row(
                        children: [
                          _MiniStatRow(worldState: worldState),
                          const SizedBox(width: 8),
                          if (deltas != null && deltas!.isNotEmpty)
                            Expanded(
                              child: _CollapsedDeltaTicker(deltas: deltas!),
                            ),
                        ],
                      ),
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
                      delta: deltas?[e.key],
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

/// Inline summary of the latest turn's stat movement, shown collapsed —
/// the "+5 Renown" beat the player feels without opening the panel.
class _CollapsedDeltaTicker extends StatelessWidget {
  final Map<String, num> deltas;
  const _CollapsedDeltaTicker({required this.deltas});

  @override
  Widget build(BuildContext context) {
    final entries = deltas.entries.take(2).toList();
    final text = entries
        .map((e) =>
            '${e.value > 0 ? '+' : ''}${e.value.round()} ${_label(e.key)}')
        .join('  ');
    final positive = entries.first.value > 0;

    final ticker = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: positive ? EverloreTheme.verdant : EverloreTheme.crimson,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
    if (reducedMotion(context)) return ticker;
    return ticker
        .animate(key: ValueKey(text))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic)
        .then(delay: 3200.ms)
        .fadeOut(duration: 600.ms);
  }

  String _label(String key) {
    final pretty = key.replaceAll('_', ' ');
    return pretty.isEmpty
        ? pretty
        : '${pretty[0].toUpperCase()}${pretty.substring(1)}';
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
      mainAxisSize: MainAxisSize.min,
      children: entries.map((e) {
        final pct = (e.value / 100).clamp(0.0, 1.0).toDouble();
        final color = _statColor(pct);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)
              ],
            ),
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

/// Full RPG-style stat bar shown when expanded. The fill eases to its new
/// value and a floating delta chip drifts up when this turn moved the stat.
class _RPGStatBar extends StatelessWidget {
  final String label;
  final double value;
  final num? delta;

  const _RPGStatBar({required this.label, required this.value, this.delta});

  @override
  Widget build(BuildContext context) {
    // Assume max 100 unless value > 100
    final max = value > 100 ? value : 100.0;

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (value / max).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, pct, _) {
              final color = _statColor(pct);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: EverloreTheme.void4,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
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
                  if (delta != null && delta != 0)
                    Positioned(
                      right: 0,
                      top: -14,
                      child: _FloatingDelta(delta: delta!, statLabel: label),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final color = _statColor((v / max).clamp(0.0, 1.0));
              return Text(
                '${v.round()}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
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

/// The "+5" chip that rises off a stat bar and fades — the felt reward beat.
class _FloatingDelta extends StatelessWidget {
  final num delta;
  final String statLabel;

  const _FloatingDelta({required this.delta, required this.statLabel});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final color = positive ? EverloreTheme.verdant : EverloreTheme.crimson;
    final chip = Text(
      '${positive ? '+' : ''}${delta.round()}',
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
    if (reducedMotion(context)) return chip;
    return chip
        .animate(key: ValueKey('$statLabel$delta'))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.8, end: -0.6, duration: 1400.ms, curve: Curves.easeOutCubic)
        .then(delay: 400.ms)
        .fadeOut(duration: 500.ms);
  }
}
