import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/errors/user_message.dart';
import '../shared/widgets/age_confirm_dialog.dart';
import '../shared/widgets/neu.dart';

/// Fourth step of post-auth onboarding: mature themes choice.
///
/// Offers two equal-weight options: "Keep it gentle" and "Allow mature themes".
/// "Allow" prompts for an 18+ confirmation dialog; "Keep it gentle" sets nothing.
class OnboardingMatureStep extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingMatureStep({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingMatureStep> createState() => _OnboardingMatureStepState();
}

class _OnboardingMatureStepState extends State<OnboardingMatureStep> {
  bool _saving = false;
  String? _error;

  void _onKeepGentle() {
    if (_saving) return;
    widget.onComplete();
  }

  Future<void> _onAllowMature() async {
    if (_saving) return;
    final confirmed = await showAgeConfirmDialog(context);
    if (!confirmed) {
      // Cancel stays on the step.
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AuthService.updatePreferences({
        'nsfw_enabled': true,
        'age_confirmed': true,
      });
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingError(
          e,
          fallback: 'Could not update your preferences. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: ForgeMark(size: 60)),
                const SizedBox(height: 18),
                Text(
                  'Mature themes',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: EverloreTheme.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Some worlds can include romance, violence and mature themes. '
                  'You can change this any time in your profile.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ebGaramond(
                    color: EverloreTheme.ash,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                _MatureChoiceCard(
                  label: 'Keep it gentle',
                  onTap: _saving ? null : _onKeepGentle,
                ),
                const SizedBox(height: 14),
                _MatureChoiceCard(
                  label: 'Allow mature themes',
                  onTap: _saving ? null : _onAllowMature,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: EverloreTheme.ui(
                      color: EverloreTheme.crimson,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_saving) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EverloreTheme.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MatureChoiceCard extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _MatureChoiceCard({
    required this.label,
    required this.onTap,
  });

  @override
  State<_MatureChoiceCard> createState() => _MatureChoiceCardState();
}

class _MatureChoiceCardState extends State<_MatureChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [EverloreTheme.void2, EverloreTheme.void3]
                : [EverloreTheme.void3, EverloreTheme.void2],
          ),
          border: Border.all(
            color: _pressed
                ? EverloreTheme.gold
                : EverloreTheme.goldDim.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: _pressed ? 4 : 10,
              offset: _pressed ? const Offset(1, 2) : const Offset(2, 4),
            ),
          ],
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: EverloreTheme.uiFamily,
            color: EverloreTheme.parchment,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
