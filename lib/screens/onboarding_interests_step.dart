import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/onboarding/interests_store.dart';
import '../shared/widgets/interest_picker.dart';
import '../shared/widgets/neu.dart';

/// Interests beat — third step of post-auth onboarding (genre chip grid).
class OnboardingInterestsStep extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const OnboardingInterestsStep({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<OnboardingInterestsStep> createState() =>
      _OnboardingInterestsStepState();
}

class _OnboardingInterestsStepState extends State<OnboardingInterestsStep> {
  static const int _minPick = 3;
  final Set<String> _selected = {};

  void _toggle(String key) {
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  Future<void> _finish({required bool skipped}) async {
    if (!skipped) {
      final picks = _selected.toList();
      await InterestsStore.saveInterests(picks);
      try {
        await AuthService.updatePreferences({'interests': picks});
      } catch (_) {}
    }
    await InterestsStore.markOnboarded();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final enough = _selected.length >= _minPick;
    final remaining = _minPick - _selected.length;

    return Column(
      children: [
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
                  'match your taste first — you can change these any time '
                  'from your profile.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ebGaramond(
                    color: EverloreTheme.ash,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                InterestPickerGrid(selected: _selected, onToggle: _toggle),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: NeuButton(
            label: enough ? 'Enter Everlore' : 'Choose $remaining more',
            icon: enough ? Icons.auto_awesome : null,
            onTap: enough ? () => _finish(skipped: false) : null,
          ),
        ),
      ],
    );
  }
}
