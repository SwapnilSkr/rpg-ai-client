import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/nexus_theme.dart';
import '../guide_beat.dart';
import '../guide_motion.dart';

/// The Chronicler's card — the guide's single voice.
///
/// Deliberately faceless. Everlore's narrator model has no avatar (see
/// DESIGN_PHILOSOPHY §3: the world does not have a face), so where other games
/// slide in a mascot portrait, this is a brass-sealed card in the narrator's
/// own typeface. Same material as `MilestoneToast`, so guidance and reward read
/// as the same voice.
class GuideSpeechCard extends StatelessWidget {
  final GuideBeat beat;
  final int step;
  final int total;
  final Color accent;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  /// Collapse the copy cross-fade to a plain cut. See `motion.dart`.
  final bool reduce;

  const GuideSpeechCard({
    this.reduce = false,
    super.key,
    required this.beat,
    required this.step,
    required this.total,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.accent = EverloreTheme.gold,
  });

  bool get _isLast => step >= total - 1;

  @override
  Widget build(BuildContext context) {
    // The card has to hold its shape from a 320pt phone to a tablet, and at
    // whatever system text size the player has chosen. Everything that would
    // otherwise overflow is measured here rather than assumed.
    final width = MediaQuery.sizeOf(context).width;
    final tight = width < 360;

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: tight
          ? const EdgeInsets.fromLTRB(16, 15, 16, 11)
          : const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          ...EverloreTheme.glow(accent, blur: 26, alpha: 0.12),
        ],
      ),
      // The chrome — border, glow, corner radius — stays put; only the words
      // change. The controls stay put too: cross-fading the whole card meant
      // the player watched Next disappear and come back on every beat, which
      // reads as a reload rather than a turn of the page, and left a fading
      // button briefly tappable underneath the new one.
      //
      // Staggered so the opening leads and the copy follows, and the height
      // glides rather than jumping when a short beat gives way to a long one.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No zero-duration variant of these: `AnimatedSize` completes inside
          // its own `performLayout` when handed one, re-dirties itself, and
          // trips an assertion. A player who asked for no animation gets the
          // plain column instead.
          if (reduce)
            _prose(context, tight)
          else
            AnimatedSize(
              duration: GuideMotion.resize,
              curve: GuideMotion.travelCurve,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: GuideMotion.swapIn,
                reverseDuration: GuideMotion.swapOut,
                switchInCurve: GuideMotion.enterCurve,
                switchOutCurve: GuideMotion.exitCurve,
                // Top-left rather than the default centring: two lines of
                // differing length centred inside a growing box is what makes
                // a plain switcher shudder.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    for (final child in previous)
                      Positioned(left: 0, right: 0, top: 0, child: child),
                    if (current != null) current,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.08,
                              1,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${beat.title}-$step-$total'),
                  child: _prose(context, tight),
                ),
              ),
            ),
          SizedBox(height: tight ? 12 : 16),
          _Footer(
            step: step,
            total: total,
            accent: accent,
            isLast: _isLast,
            onNext: onNext,
            onSkip: onSkip,
            onBack: onBack,
          ),
        ],
      ),
    );
  }

  /// Title and body — everything that belongs to this beat alone.
  Widget _prose(BuildContext context, bool tight) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: EverloreTheme.glow(accent, blur: 8, alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              beat.title.toUpperCase(),
              style: EverloreTheme.serifDisplay(
                size: tight ? 11.5 : 12.5,
                color: accent,
                weight: FontWeight.w600,
                spacing: 1.6,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: tight ? 8 : 10),
      Text(
        beat.body,
        style: GoogleFonts.ebGaramond(
          color: EverloreTheme.parchment.withValues(alpha: 0.94),
          fontSize: tight ? 15.5 : 16.5,
          height: 1.55,
          letterSpacing: 0.1,
        ),
      ),
    ],
  );
}

/// Progress and the three actions.
///
/// One row when they fit, dots lifted onto their own line when they do not.
/// The overflow is real rather than theoretical: a six-beat arc's dots plus
/// Back, Skip, and Next is about 240pt, which a 320pt phone clears by a hair
/// at normal text size and not at all once the player turns text up.
class _Footer extends StatelessWidget {
  final int step;
  final int total;
  final Color accent;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  const _Footer({
    required this.step,
    required this.total,
    required this.accent,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final dots = _StepDots(step: step, total: total, accent: accent);
    final actions = <Widget>[
      if (onBack != null)
        _GuideTextAction(
          label: 'Back',
          onTap: () {
            HapticFeedback.selectionClick();
            onBack!();
          },
        ),
      _GuideTextAction(
        label: 'Skip',
        onTap: () {
          HapticFeedback.selectionClick();
          onSkip();
        },
      ),
      _GuideNextButton(
        label: isLast ? 'Done' : 'Next',
        accent: accent,
        onTap: () {
          HapticFeedback.selectionClick();
          onNext();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = _actionsWidth(context) + _dotsWidth();
        // Measured, not estimated. A guessed threshold is wrong by a few
        // pixels at exactly the text sizes where being wrong overflows.
        if (constraints.maxWidth >= needed + 12) {
          return Row(
            children: [
              dots,
              const Spacer(),
              for (final action in actions) ...[
                if (action != actions.first) const SizedBox(width: 6),
                action,
              ],
            ],
          );
        }
        // Too narrow for one line: the dots step up, and the actions wrap
        // among themselves rather than running off the edge. A `Wrap` cannot
        // overflow, which matters at 200% text where even the three buttons
        // alone are wider than a small phone.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (total > 1) ...[dots, const SizedBox(height: 10)],
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  /// Exact width of the dot rail: each dot carries 5pt of trailing margin, and
  /// the current one is 16 wide rather than 5.
  double _dotsWidth() => total <= 1 ? 0 : (total - 1) * 5 + 16 + total * 5;

  /// Exact width of Back / Skip / Next, labels measured at the player's own
  /// text scale and the chrome around them added at its declared size.
  double _actionsWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double label(String text, FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: EverloreTheme.ui(size: 13, weight: weight),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      return painter.width;
    }

    // _GuideTextAction: 10pt of padding a side. _GuideNextButton: 18pt a side.
    // Plus a 6pt gap between each pair.
    var total = label('Skip', FontWeight.w500) + 20;
    total += label(isLast ? 'Done' : 'Next', FontWeight.w600) + 36 + 6;
    if (onBack != null) total += label('Back', FontWeight.w500) + 20 + 6;
    return total;
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  final int total;
  final Color accent;

  const _StepDots({
    required this.step,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // A single-beat arc has no progress worth drawing.
    if (total <= 1) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeInOutCubicEmphasized,
            margin: const EdgeInsets.only(right: 5),
            width: i == step ? 16 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == step
                  ? accent
                  : EverloreTheme.goldDim.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _GuideTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GuideTextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: EverloreTheme.ui(
          size: 13,
          color: EverloreTheme.ash,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _GuideNextButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _GuideNextButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.82)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: EverloreTheme.glow(accent, blur: 14, alpha: 0.28),
        ),
        child: Text(
          label,
          style: EverloreTheme.ui(
            size: 13,
            color: EverloreTheme.void0,
            weight: FontWeight.w600,
            spacing: 0.3,
          ),
        ),
      ),
    );
  }
}
