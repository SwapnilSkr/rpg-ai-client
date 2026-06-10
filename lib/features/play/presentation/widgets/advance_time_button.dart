import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../app/theme/nexus_theme.dart';

/// The "let the days pass" control — Everlore's age-up button.
///
/// Tap (or long-press) opens a single sheet: the first option is a quiet
/// continue beat, the rest are calendar-tick time-skips. One discoverable
/// gesture so players never have to guess that time travel exists.
class AdvanceTimeButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onContinue;
  final ValueChanged<String> onAdvance;

  const AdvanceTimeButton({
    super.key,
    required this.enabled,
    required this.onContinue,
    required this.onAdvance,
  });

  static const _spans = [
    (key: 'hours', label: 'Hours slip by', icon: Icons.wb_twilight),
    (key: 'day', label: 'A day passes', icon: Icons.wb_sunny_outlined),
    (key: 'days', label: 'Days drift past', icon: Icons.calendar_today_outlined),
    (key: 'season', label: 'A season turns', icon: Icons.ac_unit),
  ];

  void _showTimeSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LET TIME PASS',
                style: EverloreTheme.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  color: EverloreTheme.gold.withValues(alpha: 0.8),
                  spacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The world lives on while you are silent.',
                style: EverloreTheme.ui(
                  size: 12,
                  color: EverloreTheme.ash,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              // A quiet continue beat — the common case, kept at the top so it
              // stays one quick gesture even though the sheet now owns the tap.
              _TimeSpanTile(
                    icon: Icons.play_arrow_rounded,
                    label: 'A quiet moment passes',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      HapticFeedback.lightImpact();
                      onContinue();
                    },
                  )
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  color: EverloreTheme.gold.withValues(alpha: 0.12),
                ),
              ),
              for (var i = 0; i < _spans.length; i++)
                _TimeSpanTile(
                      icon: _spans[i].icon,
                      label: _spans[i].label,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        HapticFeedback.mediumImpact();
                        onAdvance(_spans[i].key);
                      },
                    )
                    .animate(delay: Duration(milliseconds: 50 * (i + 1)))
                    .fadeIn(duration: 200.ms)
                    .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Let time pass',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? () => _showTimeSheet(context) : null,
            onLongPress: enabled ? () => _showTimeSheet(context) : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.void3,
                border: Border.all(
                  color: enabled
                      ? EverloreTheme.gold.withValues(alpha: 0.4)
                      : EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.hourglass_bottom_rounded,
                size: 19,
                color: enabled
                    ? EverloreTheme.gold.withValues(alpha: 0.9)
                    : EverloreTheme.ash.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSpanTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TimeSpanTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: EverloreTheme.gold.withValues(alpha: 0.75)),
            const SizedBox(width: 14),
            Text(
              label,
              style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
            ),
          ],
        ),
      ),
    );
  }
}
