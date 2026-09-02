import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';
import '../app_icons.dart';
import '../narrative_styles.dart';

/// The genre-interest chip grid, shared by the onboarding interests beat and
/// the profile editor so both offer exactly the same vocabulary and look.
///
/// Labels wrap to two lines instead of being clipped — "Modern Casual" and
/// "Shōnen / Battle" used to render as "Modern Ca…" / "Shōnen / B…", which
/// hid what the player was actually choosing.
class InterestPickerGrid extends StatelessWidget {
  /// Currently picked style keys.
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const InterestPickerGrid({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    // Measured once here rather than per chip: a LayoutBuilder inside the
    // IntrinsicHeight below cannot report intrinsic dimensions and asserts.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Small phones leave a chip barely wider than its thumb; the chips
        // tighten their furniture there so long labels still fit two lines.
        final compact = (constraints.maxWidth - _gap) / 2 < 150;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final family in kStyleFamilies) ...[
              _FamilyHeader(label: family.label, familyKey: family.key),
              const SizedBox(height: 12),
              _grid(stylesInFamily(family.key), compact),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  Widget _grid(List<NarrativeStyle> styles, bool compact) {
    final rows = <Widget>[];
    for (var i = 0; i < styles.length; i += 2) {
      final a = styles[i];
      final b = (i + 1 < styles.length) ? styles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < styles.length ? _gap : 0),
          // Both chips in a pair share the taller one's height, so a
          // two-line label never leaves its neighbour looking stunted.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _chip(a, compact)),
                const SizedBox(width: _gap),
                Expanded(
                  child: b == null ? const SizedBox() : _chip(b, compact),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _chip(NarrativeStyle style, bool compact) => InterestChip(
    style: style,
    familyKey: style.familyKey ?? '',
    selected: selected.contains(style.key),
    compact: compact,
    onTap: () => onToggle(style.key),
  );
}

class _FamilyHeader extends StatelessWidget {
  final String label;
  final String familyKey;
  const _FamilyHeader({required this.label, required this.familyKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EvIcon(AppIcons.family(familyKey), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              color: EverloreTheme.goldDim,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class InterestChip extends StatelessWidget {
  final NarrativeStyle style;
  final String familyKey;
  final bool selected;

  /// Narrow layout (small phones): smaller thumb, tighter gaps, smaller label
  /// so long names like "Anime / Expressive" still fit in two lines.
  final bool compact;
  final VoidCallback onTap;

  const InterestChip({
    super.key,
    required this.style,
    required this.familyKey,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final thumbSize = compact ? 30.0 : 34.0;
    final gap = compact ? 8.0 : 10.0;
    final rightPad = compact ? 10.0 : 12.0;
    final fontSize = compact ? 12.5 : 14.0;
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(5, 5, rightPad, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      EverloreTheme.gold.withValues(alpha: 0.22),
                      EverloreTheme.gold.withValues(alpha: 0.10),
                    ]
                  : [EverloreTheme.void3, EverloreTheme.void2],
            ),
            border: Border.all(
              color: selected
                  ? EverloreTheme.gold.withValues(alpha: 0.85)
                  : EverloreTheme.goldDim.withValues(alpha: 0.22),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(2, 3),
              ),
              if (selected)
                BoxShadow(
                  color: EverloreTheme.gold.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              _Thumb(
                styleKey: style.key,
                familyKey: familyKey,
                size: thumbSize,
              ),
              SizedBox(width: gap),
              Expanded(
                child: Text(
                  style.label,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    height: 1.15,
                    color: selected
                        ? EverloreTheme.parchment
                        : EverloreTheme.parchment.withValues(alpha: 0.82),
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String styleKey;
  final String familyKey;
  final double size;
  const _Thumb({
    required this.styleKey,
    required this.familyKey,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/splash/$styleKey.webp',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [EverloreTheme.void3, EverloreTheme.void0],
        ),
      ),
      alignment: Alignment.center,
      child: EvIcon(AppIcons.family(familyKey), size: 20),
    );
  }
}
