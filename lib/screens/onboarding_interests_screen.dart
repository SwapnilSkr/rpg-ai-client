import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/onboarding/interests_store.dart';
import '../shared/app_icons.dart';
import '../shared/narrative_styles.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../shared/widgets/neu.dart';

/// Post-signup "attune the realm to you" beat — the 4th beat of the
/// gate → threshold journey. Collects the player's genre taste (mapped to
/// `narrative_style` keys) which feeds genre-aware discovery (see memory:
/// interests_discovery.md). Skippable; ≥3 to continue. Choices persist locally
/// (Phase 1); Phase 2 mirrors them to the server.
class OnboardingInterestsScreen extends StatefulWidget {
  const OnboardingInterestsScreen({super.key});

  @override
  State<OnboardingInterestsScreen> createState() =>
      _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState extends State<OnboardingInterestsScreen> {
  static const int _minPick = 3;
  final Set<String> _selected = {};

  void _toggle(String key) {
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  /// Two-column grid: chips fill equal half-widths so the section reads as a
  /// tidy grid (no ragged vertical stacking). A lone trailing chip sits in the
  /// left column.
  Widget _chipGrid(List<NarrativeStyle> styles, String familyKey) {
    const gap = 10.0;
    final rows = <Widget>[];
    for (var i = 0; i < styles.length; i += 2) {
      final a = styles[i];
      final b = (i + 1 < styles.length) ? styles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < styles.length ? gap : 0),
          child: Row(
            children: [
              Expanded(child: _chipFor(a)),
              const SizedBox(width: gap),
              Expanded(child: b == null ? const SizedBox() : _chipFor(b)),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _chipFor(NarrativeStyle style) => _InterestChip(
    style: style,
    familyKey: style.familyKey ?? '',
    selected: _selected.contains(style.key),
    onTap: () => _toggle(style.key),
  );

  Future<void> _finish({required bool skipped}) async {
    if (!skipped) {
      final picks = _selected.toList();
      await InterestsStore.saveInterests(picks);
      // Best-effort: mirror to the server so discovery can rank across the whole
      // catalog (Phase 2). Never block leaving onboarding on this.
      try {
        await AuthService.updatePreferences({'interests': picks});
      } catch (_) {}
    }
    await InterestsStore.markOnboarded();
    if (!mounted) return;
    context.go('/discover'); // land on Discover, not the realms list
  }

  @override
  Widget build(BuildContext context) {
    final enough = _selected.length >= _minPick;
    final remaining = _minPick - _selected.length;

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: RealmBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              // Skip — quiet, top-right.
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                  child: TextButton(
                    onPressed: () => _finish(skipped: true),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        color: EverloreTheme.ash,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: ForgeMark(size: 60)),
                      const SizedBox(height: 18),
                      Text(
                        'Which worlds call to you?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: EverloreTheme.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose three or more. We\'ll summon the realms that '
                        'match your taste first.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ebGaramond(
                          color: EverloreTheme.ash,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final family in kStyleFamilies) ...[
                        _FamilyHeader(
                          label: family.label,
                          familyKey: family.key,
                        ),
                        const SizedBox(height: 12),
                        _chipGrid(stylesInFamily(family.key), family.key),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
              // Continue — gated on the minimum pick.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: NeuButton(
                  label: enough ? 'Enter Everlore' : 'Choose $remaining more',
                  icon: enough ? Icons.auto_awesome : null,
                  onTap: enough ? () => _finish(skipped: false) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: EverloreTheme.uiFamily,
            color: EverloreTheme.goldDim,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

/// Oval chip: a thumbnail disc (genre art, or a family-icon fallback) + label.
/// Selected = champagne-brass fill + gold rim (per DESIGN_PHILOSOPHY §2.3).
class _InterestChip extends StatelessWidget {
  final NarrativeStyle style;
  final String familyKey;
  final bool selected;
  final VoidCallback onTap;

  const _InterestChip({
    required this.style,
    required this.familyKey,
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
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
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
            _Thumb(styleKey: style.key, familyKey: familyKey),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: selected
                      ? EverloreTheme.parchment
                      : EverloreTheme.parchment.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 34px circular thumbnail: genre art if it exists, else a neumorphic disc with
/// the genre's family glyph (keeps chips premium for the ~9 genres without art).
class _Thumb extends StatelessWidget {
  final String styleKey;
  final String familyKey;
  const _Thumb({required this.styleKey, required this.familyKey});

  static const double _size = 34;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
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
