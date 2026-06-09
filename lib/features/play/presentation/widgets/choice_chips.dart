import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/motion.dart';

/// Tap-to-play suggested moves rendered under the latest narrator turn.
///
/// Choices are sugar over a normal player turn: tapping one dispatches its
/// pre-formatted [Choice.send] (a *narrated action* or a spoken line) through
/// the same pipeline as typed input, so the ledger, memory extraction, and
/// rewind/replay all treat it identically. Free text always remains.
class ChoiceChips extends StatelessWidget {
  final List<Choice> choices;
  final bool enabled;
  final ValueChanged<String> onChoose;

  const ChoiceChips({
    super.key,
    required this.choices,
    required this.enabled,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    final reduce = reducedMotion(context);

    Widget chip(int i) {
      final choice = choices[i];
      final built = _ChoiceChip(
        label: choice.label,
        // A spoken line gets a chat-bubble glyph; an action keeps the spark, so
        // the player can read intent (say vs do) before tapping.
        icon: choice.kind == 'say'
            ? Icons.chat_bubble_outline_rounded
            : Icons.auto_awesome,
        enabled: enabled,
        onTap: () {
          HapticFeedback.lightImpact();
          onChoose(choice.send);
        },
      );
      if (reduce) return built;
      // Staggered bloom: the options materialize one after another once the
      // prose has finished streaming.
      return built
          .animate(delay: Duration(milliseconds: 80 * i))
          .fadeIn(duration: 250.ms, curve: Curves.easeOut)
          .slideY(begin: 0.35, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
          .scaleXY(begin: 0.96, end: 1, duration: 300.ms);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (var i = 0; i < choices.length; i++) chip(i)],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        splashColor: EverloreTheme.gold.withValues(alpha: 0.12),
        highlightColor: EverloreTheme.gold.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            color: EverloreTheme.void2.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? EverloreTheme.gold.withValues(alpha: 0.38)
                  : EverloreTheme.goldDim.withValues(alpha: 0.16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: enabled
                      ? EverloreTheme.gold.withValues(alpha: 0.8)
                      : EverloreTheme.ash.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    style: EverloreTheme.ui(
                      size: 13,
                      color: enabled
                          ? EverloreTheme.parchment
                          : EverloreTheme.ash.withValues(alpha: 0.5),
                      height: 1.25,
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
