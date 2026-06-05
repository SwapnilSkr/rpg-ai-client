import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/onboarding/interests_store.dart';
import '../shared/models/user.dart';
import '../shared/widgets/keyboard_aware_scroll.dart';
import '../shared/widgets/player_avatar.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../shared/widgets/neu.dart';
import 'onboarding_interests_step.dart';

/// Post-auth onboarding — name → gender → interests, then Discover.
///
/// One question per step (DESIGN_PHILOSOPHY §2.9). Smooth fade+slide between
/// beats, shared [RealmBackdrop], neumorphic chrome throughout.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 3;
  static const _transitionMs = 320;

  int _step = 0;
  int _slideDir = 1;
  bool _bootstrapping = true;

  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  PlayerGender? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = await AuthService.getCachedUser();
    final start = await InterestsStore.resolveStartStep(user: user);
    if (!mounted) return;
    if (start > 0 && (user?.preferences.playerName.isNotEmpty ?? false)) {
      _nameCtrl.text = user!.preferences.playerName;
      _gender = user.preferences.gender;
    }
    setState(() {
      _step = start;
      _bootstrapping = false;
    });
    if (start == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  void _goToStep(int next) {
    setState(() {
      _slideDir = next > _step ? 1 : -1;
      _step = next;
    });
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) return;
    setState(() => _saving = true);
    try {
      await AuthService.updatePreferences({'player_name': name});
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    _goToStep(1);
  }

  Future<void> _saveGender(PlayerGender? picked) async {
    setState(() {
      _gender = picked;
      _saving = true;
    });
    try {
      if (picked != null) {
        await AuthService.updatePreferences({
          'gender': playerGenderToJson(picked),
        });
      }
      await InterestsStore.markGenderStepDone();
    } catch (_) {
      await InterestsStore.markGenderStepDone();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _goToStep(2);
  }

  Future<void> _finishInterests({required bool skipped}) async {
    if (!skipped) {
      // Interests step handles its own persistence.
      return;
    }
    await InterestsStore.markOnboarded();
    if (!mounted) return;
    context.go('/discover');
  }

  void _onInterestsComplete() {
    if (!mounted) return;
    context.go('/discover');
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        backgroundColor: EverloreTheme.void0,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: EverloreTheme.gold,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      resizeToAvoidBottomInset: false,
      body: RealmBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _OnboardingProgress(step: _step, total: _stepCount),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: _transitionMs),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: Offset(0.06 * _slideDir, 0),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: switch (_step) {
                    0 => _NameStep(
                        key: const ValueKey('name'),
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        saving: _saving,
                        onContinue: _saveName,
                      ),
                    1 => _GenderStep(
                        key: const ValueKey('gender'),
                        selected: _gender,
                        saving: _saving,
                        onSelect: (g) => setState(() => _gender = g),
                        onContinue: () => _saveGender(_gender),
                        onSkip: () => _saveGender(null),
                      ),
                    _ => OnboardingInterestsStep(
                        key: const ValueKey('interests'),
                        onComplete: _onInterestsComplete,
                        onSkip: () => _finishInterests(skipped: true),
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;
  const _OnboardingProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == step;
          final done = i < step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: done || active
                  ? EverloreTheme.gold.withValues(alpha: active ? 0.95 : 0.55)
                  : EverloreTheme.void4,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: EverloreTheme.gold.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class _NameStep extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final VoidCallback onContinue;

  const _NameStep({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.saving,
    required this.onContinue,
  });

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ready = widget.controller.text.trim().length >= 2;
    return Column(
      children: [
        Expanded(
          child: KeyboardAwareScroll(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ForgeMark(size: 68)),
                const SizedBox(height: 28),
                Text(
                  'What shall we call you?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: EverloreTheme.gold,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your name travels with you across every realm.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ebGaramond(
                    color: EverloreTheme.ash,
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                KeyboardAwareInputGroup(
                  focusNode: widget.focusNode,
                  child: NeuField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    hintText: 'Your name',
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
          child: NeuButton(
            label: widget.saving ? 'Saving…' : 'Continue',
            loading: widget.saving,
            onTap: ready && !widget.saving ? widget.onContinue : null,
          ),
        ),
      ],
    );
  }
}

class _GenderStep extends StatelessWidget {
  final PlayerGender? selected;
  final bool saving;
  final ValueChanged<PlayerGender> onSelect;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _GenderStep({
    super.key,
    required this.selected,
    required this.saving,
    required this.onSelect,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
            child: TextButton(
              onPressed: saving ? null : onSkip,
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
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ForgeMark(size: 60)),
                const SizedBox(height: 18),
                Text(
                  'How do you see yourself?',
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
                  'We\'ll forge your portrait. You can skip — we\'ll choose a '
                  'timeless hero look for you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ebGaramond(
                    color: EverloreTheme.ash,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _GenderOption(
                  label: 'Male',
                  gender: PlayerGender.male,
                  selected: selected == PlayerGender.male,
                  onTap: saving ? null : () => onSelect(PlayerGender.male),
                ),
                const SizedBox(height: 12),
                _GenderOption(
                  label: 'Female',
                  gender: PlayerGender.female,
                  selected: selected == PlayerGender.female,
                  onTap: saving ? null : () => onSelect(PlayerGender.female),
                ),
                const SizedBox(height: 12),
                _GenderOption(
                  label: 'Non-binary',
                  gender: PlayerGender.nonBinary,
                  selected: selected == PlayerGender.nonBinary,
                  onTap: saving ? null : () => onSelect(PlayerGender.nonBinary),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
          child: NeuButton(
            label: saving ? 'Saving…' : 'Continue',
            loading: saving,
            onTap: selected != null && !saving ? onContinue : null,
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final PlayerGender gender;
  final bool selected;
  final VoidCallback? onTap;

  const _GenderOption({
    required this.label,
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    EverloreTheme.gold.withValues(alpha: 0.22),
                    EverloreTheme.gold.withValues(alpha: 0.08),
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
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(2, 4),
            ),
            if (selected)
              BoxShadow(
                color: EverloreTheme.gold.withValues(alpha: 0.16),
                blurRadius: 14,
              ),
          ],
        ),
        child: Row(
          children: [
            PlayerAvatar(gender: gender, size: 52, showRim: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: selected
                      ? EverloreTheme.parchment
                      : EverloreTheme.parchment.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: EverloreTheme.gold, size: 22),
          ],
        ),
      ),
    );
  }
}
