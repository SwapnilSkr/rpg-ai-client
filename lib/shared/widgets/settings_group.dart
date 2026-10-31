import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';

/// Section header label above a [SettingsGroup].
///
/// Styled in dim gold uppercase, with an inset of 4 dp to align with the
/// card's inner content edge, 10 dp below to the card, and 28 dp above
/// (or 8 dp for the first section on a screen).
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(
    this.text, {
    super.key,
    this.isFirst = false,
  });

  final String text;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isFirst ? 8 : 28, 0, 10),
      child: Text(
        text.toUpperCase(),
        style: EverloreTheme.ui(
          size: 11.5,
          color: EverloreTheme.goldDim,
          weight: FontWeight.w700,
          spacing: 1.6,
        ),
      ),
    );
  }
}

/// A card-decorated container grouping settings rows.
///
/// Uses [EverloreTheme.cardDecoration] with anti-aliased clipping so ripples
/// respect the rounded corners. Separates consecutive rows with a 1 px divider
/// in [EverloreTheme.goldDim] at alpha 0.14, inset 56 dp from the left to align
/// with the row labels.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 56),
            color: EverloreTheme.goldDim.withValues(alpha: 0.14),
          ),
        );
      }
    }

    return Container(
      decoration: EverloreTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

/// A navigation row inside a [SettingsGroup].
///
/// 56 dp min height, 18 dp horizontal padding. Leading icon in 24 dp box with
/// 14 dp gap to the label. Trailing chevron is omitted when a destructive [tone]
/// is specified. Shows a 16 dp progress indicator instead of the icon when [busy].
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.detail,
    this.tone,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? detail;
  final Color? tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final iconColor = tone ?? EverloreTheme.gold.withValues(alpha: 0.9);
    final labelColor = tone ?? EverloreTheme.parchment;
    final showChevron = tone == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        splashColor: EverloreTheme.gold.withValues(alpha: 0.08),
        highlightColor: EverloreTheme.gold.withValues(alpha: 0.04),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor,
                            ),
                          )
                        : Icon(
                            icon,
                            size: 20,
                            color: iconColor,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: EverloreTheme.ui(
                      size: 15,
                      weight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    detail!,
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.ash,
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: EverloreTheme.ash.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch toggle row inside a [SettingsGroup].
///
/// Shares the 18 dp horizontal padding, 24 dp icon slot, and 14 dp gap with
/// [SettingsNavRow]. Uses brass tones on [Switch.adaptive], never red.
/// When [busy], the switch is disabled with 0.5 opacity while the subtitle
/// stays intact. The entire row is tappable to toggle.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final canToggle = !busy && onChanged != null;

    return Semantics(
      toggled: value,
      enabled: canToggle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canToggle ? () => onChanged!(!value) : null,
          splashColor: EverloreTheme.gold.withValues(alpha: 0.08),
          highlightColor: EverloreTheme.gold.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: EverloreTheme.gold.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: EverloreTheme.ui(
                            size: 15,
                            weight: FontWeight.w600,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 12.5,
                            color: EverloreTheme.ash,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Opacity(
                    opacity: busy ? 0.5 : 1.0,
                    child: Switch.adaptive(
                      value: value,
                      onChanged: canToggle ? onChanged : null,
                      activeThumbColor: EverloreTheme.goldHot,
                      activeTrackColor:
                          EverloreTheme.gold.withValues(alpha: 0.55),
                      inactiveThumbColor: EverloreTheme.ash,
                      inactiveTrackColor: EverloreTheme.void4,
                      trackOutlineColor: WidgetStateProperty.all(
                        EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return EverloreTheme.goldHot;
                        }
                        return EverloreTheme.ash;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return EverloreTheme.gold.withValues(alpha: 0.55);
                        }
                        return EverloreTheme.void4;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
