import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/motion.dart';
import '../guide_anchor.dart';
import '../guide_beat.dart';
import '../guide_controller.dart';
import '../guide_motion.dart';
import 'guide_cutout.dart';
import 'guide_pointer.dart';
import 'guide_speech_card.dart';

/// Mounts the guide above the whole app.
///
/// Installed from `MaterialApp.builder`, which puts this layer above the
/// Navigator — so the Chronicler can point at controls inside modal sheets and
/// dialogs (the Realm Menu, for one) rather than being buried under them.
///
/// Anchor rects are re-resolved every frame while a beat is showing, so the
/// opening tracks scrolling, the keyboard, and streaming layout shifts instead
/// of drifting off its target.
class GuideHost extends StatefulWidget {
  final Widget child;

  const GuideHost({super.key, required this.child});

  @override
  State<GuideHost> createState() => _GuideHostState();
}

class _GuideHostState extends State<GuideHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_onTick);
  GuideTarget? _target;

  /// The overlay's arrival, 0 to 1. Everything the guide draws is multiplied
  /// by it — the scrim, the opening's bloom, the card's rise, the halo — so an
  /// arc fades up as one object rather than three things switching on at once.
  ///
  /// It also runs backwards. Without it the last beat vanished the instant the
  /// player pressed Done, and a walkthrough that disappears between frames
  /// reads as a crash rather than an ending.
  late final AnimationController _stage = AnimationController(
    vsync: this,
    duration: GuideMotion.enter,
    reverseDuration: GuideMotion.exit,
  );

  /// An opening arriving where there was none.
  ///
  /// Separate from [_stage] because it happens *within* an arc: the beat
  /// before may have been an unanchored card, or its target may have been off
  /// screen, and in both cases there is no previous rect for the opening to
  /// travel from — so without this it simply appeared, at full size, between
  /// two frames. Runs again every time the spotlight returns from nothing.
  late final AnimationController _iris = AnimationController(
    vsync: this,
    duration: GuideMotion.enter,
    value: 1,
  );
  bool _hadTarget = false;

  /// The beat still being drawn while the overlay fades out, after the
  /// controller has already let go of it.
  GuideBeat? _leaving;
  int _leavingStep = 0;
  int _leavingTotal = 1;

  /// Which anchor the opening is currently on, and when it landed there.
  ///
  /// The opening tweens when it *moves to a different target* and tracks
  /// exactly when the target itself moves. Easing towards a rect that is
  /// already moving means the hole trails a quarter-second behind the control
  /// for as long as the player keeps scrolling, which reads as an opening
  /// stuck to the screen rather than to the thing it names.
  String? _anchor;
  Duration _anchorAt = Duration.zero;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    guide.addListener(_onGuideChanged);
    _stage.addListener(_onStage);
    _stage.addStatusListener(_onStageStatus);
    _iris.addListener(_onStage);
    _syncTicker();
    if (guide.currentBeat != null || guide.isAskingSkipAll) _stage.value = 1;
  }

  @override
  void dispose() {
    guide.removeListener(_onGuideChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stage.removeListener(_onStage);
    _stage.removeStatusListener(_onStageStatus);
    _stage.dispose();
    _iris.removeListener(_onStage);
    _iris.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Progress must not die with the process; spend the debounce on the way out.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      guide.onAppPaused();
    }
  }

  void _onGuideChanged() {
    if (!mounted) return;
    setState(() {
      _syncTicker();
      _syncStage();
    });
  }

  void _onStage() {
    if (mounted) setState(() {});
  }

  void _onStageStatus(AnimationStatus status) {
    // The fade-out has finished: let go of the beat it was still drawing.
    if (status == AnimationStatus.dismissed && _leaving != null) {
      setState(() {
        _leaving = null;
        _target = null;
      });
    }
  }

  /// Drive the arrival forwards when there is something to show and backwards
  /// when there is not, holding on to the departing beat until it has gone.
  void _syncStage() {
    final showing = guide.currentBeat != null || guide.isAskingSkipAll;
    if (showing) {
      _leaving = null;
      _stage.forward();
      return;
    }
    if (_stage.value == 0) return;
    // Snapshot what was on screen so the reverse has something to draw. The
    // controller has already cleared it by the time this runs.
    _leaving ??= _lastBeat;
    _stage.reverse();
  }

  GuideBeat? _lastBeat;

  void _syncTicker() {
    final beat = guide.currentBeat;
    if (beat != null) {
      _lastBeat = beat;
      // The delivered position, not the raw index: an arc that dropped a
      // beat for want of a target must not leave a gap in the rail.
      _leavingStep = guide.beatStep;
      _leavingTotal = guide.beatTotal;
    }
    final wants = beat != null && beat.anchors.isNotEmpty;
    if (wants && !_ticker.isActive) {
      _ticker.start();
    } else if (!wants && _ticker.isActive) {
      _ticker.stop();
    }
    if (!wants) {
      // The opening is still being painted through the fade-out, so the rect
      // it needs has to outlive the beat that asked for it.
      if (guide.currentBeat != null || _stage.value == 0) _target = null;
      _anchor = null;
      _settling = false;
      // So the next arc's first opening blooms rather than being switched on.
      _hadTarget = false;
    }
  }

  void _onTick(Duration elapsed) {
    final beat = guide.currentBeat;
    final registry = GuideAnchorRegistry.instance;
    final anchor = beat == null ? null : registry.firstResolvable(beat.anchors);
    var next = anchor == null ? null : registry.targetOf(anchor);

    // A spanning beat lights a heading and its control as one opening. The
    // pair has no shared outline, so the span drops back to a plain rounded
    // rectangle rather than borrowing the heading's corners.
    final end = beat?.anchorEnd;
    if (next != null && end != null) {
      // The tail is measured the same way as the head, so a span ends at the
      // control's own edge rather than at whatever padding wraps it.
      final tail = registry.targetOf(end);
      if (tail != null) {
        next = GuideTarget(
          rect: next.rect.expandToInclude(tail.rect),
          // A pair has no shared outline. Keeping the head's radius is closer
          // than a guessed default and never larger than what is drawn.
          radius: next.radius,
        );
      }
    }
    // A target the guide is *bringing* into view is not an absent one. Between
    // two Chronicle tabs the next tab is mounted but still scrolling in, so it
    // resolves to nothing for a few frames — and dropping the opening there
    // collapses the card into the floating band at the foot of the screen and
    // throws it back up when the tab lands. That drop and rebound is the flash
    // between beats. Holding the last opening keeps the card still until the
    // new target arrives.
    //
    // Only while the guide is doing the scrolling. Holding whenever the anchor
    // merely remains mounted would also hold it while the *reader* scrolls the
    // target away, which leaves the opening pinned over whatever content has
    // slid under it — the older bug, and the one the "scrolled most of the way
    // out" test exists to catch.
    if (next == null && _target != null && guide.isRevealing) next = _target;
    if (anchor != _anchor) {
      _anchor = anchor;
      _anchorAt = elapsed;
    }
    // An opening that was not there a frame ago has nothing to travel from, so
    // it grows open in place instead of being switched on.
    final has = next != null;
    if (has && !_hadTarget) _iris.forward(from: 0);
    _hadTarget = has;
    final settling = elapsed - _anchorAt < GuideMotion.settle;

    if (next != _target || settling != _settling) {
      setState(() {
        _target = next;
        _settling = settling;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The beat the controller is on, or — while the overlay is still fading
    // out — the one it has just left.
    final beat = guide.currentBeat ?? _leaving;
    // A player who has asked the platform to remove animation gets the end
    // states, not a faster version of them (`motion.dart`, and the same rule
    // the gamification flourishes follow). Collapsing here rather than
    // shortening the controllers keeps one code path for both.
    final reduce = reducedMotion(context);
    final progress = reduce
        ? (guide.currentBeat != null ? 1.0 : 0.0)
        : _stage.value;
    // The opening cannot be further along than the overlay carrying it.
    final opening = reduce ? progress : math.min(progress, _iris.value);
    final stack = Stack(
      // The app is a non-positioned child, so without this it would be handed
      // loose constraints and could shrink to its intrinsic size.
      fit: StackFit.expand,
      children: [
        widget.child,
        if (guide.isAskingSkipAll)
          Positioned.fill(
            child: _SkipEverythingPrompt(progress: reduce ? 1 : _stage.value),
          )
        // Mounted whenever there is a beat, or one still fading out. Gating on
        // `progress` alone would drop the very first frame of an arrival,
        // since a ticker's elapsed time starts at zero on its first frame.
        else if (beat != null && (guide.currentBeat != null || progress > 0))
          Positioned.fill(
            child: _GuideLayer(
              beat: beat,
              target: _target,
              settling: _settling,
              progress: progress,
              opening: opening,
              reduce: reduce,
              step: guide.currentBeat != null ? guide.beatStep : _leavingStep,
              total: guide.currentBeat != null
                  ? guide.beatTotal
                  : _leavingTotal,
            ),
          ),
      ],
    );
    return stack;
  }
}

class _GuideLayer extends StatelessWidget {
  final GuideBeat beat;
  final GuideTarget? target;

  /// True only for the moment after the opening changes target, which is the
  /// one time interpolating it helps.
  final bool settling;

  /// How far the overlay has arrived, 0 to 1. See `_GuideHostState._stage`.
  final double progress;

  /// How far the *opening* has arrived — never ahead of [progress], and reset
  /// whenever a spotlight appears where there was none.
  final double opening;

  /// The platform has asked for animation to be removed.
  final bool reduce;
  final int step;
  final int total;

  const _GuideLayer({
    required this.beat,
    required this.target,
    required this.settling,
    required this.progress,
    required this.opening,
    required this.reduce,
    required this.step,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    // What is actually free, rather than what the screen measures. A notch, a
    // punch-hole, and a home indicator all sit inside the screen rect; so does
    // the keyboard, which does not shrink `size` at all. The composer beats on
    // the play surface are anchored right where it opens, so a card laid out
    // against the raw height lands behind it.
    final insets = EdgeInsets.only(
      top: media.padding.top,
      bottom: math.max(media.padding.bottom, media.viewInsets.bottom),
    );
    // Every opening is clamped to that, rim and bloom included: an opening
    // nudged under the notch reads as a rendering fault, not a spotlight.
    final safe = Rect.fromLTRB(
      8,
      insets.top + 6,
      size.width - 8,
      size.height - insets.bottom - 6,
    );
    final spotlit = beat.style == GuideStyle.spotlight && target != null;
    final hole = spotlit
        ? guideHoleFor(
            target!,
            shape: beat.shape,
            gap: beat.inflate,
            bounds: safe,
          )
        : null;
    // The opening tracks a moving target frame for frame and only eases when
    // it changes target. Easing towards a rect that is itself still moving is
    // what made the Chronicle's tab strip lurch, and what left the spotlight
    // trailing behind the cards on Explore for as long as the list was moving.
    final still = reducedMotion(context) || guide.isRevealing || !settling;

    final card = GuideSpeechCard(
      reduce: reduce,
      beat: beat,
      step: step,
      total: total,
      onNext: guide.next,
      onSkip: guide.skip,
      onBack: step > 0 ? guide.back : null,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (beat.style == GuideStyle.spotlight)
            Positioned.fill(
              child: hole == null
                  // No resolvable target this frame — mid-scroll, mid-route,
                  // or simply absent. A plain scrim rides it out; a tween
                  // cannot, since it asserts on a null `end`.
                  ? GuideCutout(
                      hole: null,
                      progress: progress,
                      tapThrough: beat.tapThrough,
                      onTapOutside: guide.next,
                    )
                  // Tweening the opening between beats keeps the eye
                  // travelling with it instead of hunting for where it jumped.
                  // The whole rounded rect is interpolated, corners included,
                  // so a pill never squares off on its way to a circle.
                  // Extreme production: 620ms + easeInOutCubicEmphasized is a
                  // deliberate, calm travel - not lightning. Still collapses
                  // to 0 while the target itself scrolls so it never trails.
                  : TweenAnimationBuilder<RRect?>(
                      // Only `end` is set: the builder animates from the value
                      // it last held, which is the previous beat's opening.
                      // Setting `begin` too would pin both ends.
                      tween: _RRectTween(end: hole),
                      duration: still ? Duration.zero : GuideMotion.travel,
                      curve: GuideMotion.travelCurve,
                      // The bloom is applied on top of the travel rather than
                      // inside it, so the first opening of an arc grows open
                      // in place while a later one glides across the screen.
                      builder: (context, animated, _) => GuideCutout(
                        hole: guideBloomed(animated ?? hole, opening),
                        progress: progress,
                        tapThrough: beat.tapThrough,
                        onTapOutside: guide.next,
                      ),
                    ),
            )
          else
            // Ambient beats dim as well — the load-bearing bug was that
            // `GuideBeat.card` left the screen at full brightness, so the
            // speech card read as a stray popup rather than a guide step and
            // its coachmark was missed. A slightly lighter scrim (0.72 vs
            // 0.80) keeps it ambient while still pulling focus.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: guide.next,
                child: ColoredBox(
                  color: EverloreTheme.void0.withValues(alpha: 0.72 * progress),
                ),
              ),
            ),

          if (hole != null)
            Positioned.fromRect(
              rect: guideBloomed(hole, opening).outerRect.inflate(3),
              child: GuidePulse(
                progress: opening,
                borderRadius: guideRingRadius(hole, 3),
              ),
            ),

          _positionedCard(
            size: size,
            textScale: media.textScaler.scale(14) / 14,
            padding: insets,
            hole: hole,
            still: still,
            // The card arrives with the scrim rather than after it, lifted a
            // few points so it settles into place instead of blinking on.
            child: Opacity(
              opacity: Curves.easeOut.transform(progress.clamp(0.0, 1.0)),
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * GuideMotion.rise),
                child: card,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Places the card in the taller band of screen left free by the opening,
  /// bounded on every side so it can neither run off an edge nor overflow.
  ///
  /// Pinning only the near edge — the old approach — meant a three-line beat
  /// beside a low target simply overflowed the bottom of the screen. Giving
  /// the card a band and aligning it inside means the layout, not a guessed
  /// height threshold, decides whether it fits.
  ///
  /// Everything here is measured rather than assumed, because the range this
  /// has to survive is wide: a 320pt phone in landscape, a 1024pt tablet, a
  /// notch, a keyboard, and a player who has turned system text up to 200%.
  Widget _positionedCard({
    required Size size,
    required double textScale,
    required EdgeInsets padding,
    required RRect? hole,
    required bool still,
    required Widget child,
  }) {
    const gap = 14.0;
    // Small phones cannot spare 18pt a side; large ones look mean without it.
    final margin = size.width < 360 ? 12.0 : 18.0;
    final topEdge = padding.top + margin;
    final bottomEdge = padding.bottom + margin;
    final usable = math.max(0.0, size.height - topEdge - bottomEdge);

    /// Below this a band is too cramped to read from; float over the scrim.
    /// Proportional, because a flat 168 is a third of a landscape phone and a
    /// tenth of a tablet — and scaled by the player's text size, since the
    /// same three lines of prose need half again the room at 140%. Without
    /// the scale a large-text card was squeezed into a band it could not fit
    /// and the bottom of it was left inside the scroll view, out of sight.
    final minBand = math.min(168.0 * textScale, usable * 0.34 * textScale);

    // The card scrolls inside whatever room it is given, in every placement.
    // Between short screens, landscape, and large system text the card can
    // genuinely be taller than the space there is — and a coachmark that
    // overflows is worse than one that scrolls.
    Widget fitted(Alignment alignment) => Align(
      alignment: alignment,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: margin, vertical: 4),
        // Centred so the card's 460pt cap reads as a card on a tablet rather
        // than a slab pinned to the left.
        child: Center(child: child),
      ),
    );

    // Band placement is instant per beat - animating the Positioned's
    // top/bottom caused the SingleChildScrollView's constraints to tween
    // every frame, making the card's height shudder. Smoothness now comes
    // from the hole's 380ms travel + the prose cross-fade, not from the
    // band itself.
    // The band the card lives in moves when the opening does. Sliding it means
    // the card travels with the spotlight instead of teleporting across the
    // screen between beats — but only while the opening is easing, since
    // during a scroll the band is recomputed every frame and any duration at
    // all would leave the card lagging behind the target.
    final glide = still ? Duration.zero : GuideMotion.travel;

    Widget band({
      required double top,
      required double bottom,
      required Alignment alignment,
    }) => AnimatedPositioned(
      duration: glide,
      curve: GuideMotion.travelCurve,
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      child: fitted(alignment),
    );

    Widget floating() => band(
      top: topEdge,
      bottom: bottomEdge + (usable > 420 ? 24 : 8),
      alignment: Alignment.bottomCenter,
    );

    if (hole == null) return floating();

    final rect = hole.outerRect;
    final above = (rect.top - gap) - topEdge;
    final below = (size.height - bottomEdge) - (rect.bottom + gap);

    if (below < minBand && above < minBand) return floating();

    if (below >= above) {
      return band(
        top: rect.bottom + gap,
        bottom: bottomEdge,
        alignment: Alignment.topCenter,
      );
    }
    return band(
      top: topEdge,
      bottom: (size.height - rect.top) + gap,
      alignment: Alignment.bottomCenter,
    );
  }
}

/// Interpolates the whole opening — position, size, and every corner.
///
/// With no `begin` — the first opening of an arc — `RRect.lerp` scales the
/// rect's raw coordinates towards zero, which means the very first spotlight
/// of the walkthrough flew in diagonally from behind the status bar. Standing
/// still and letting the bloom do the work is the honest first frame.
class _RRectTween extends Tween<RRect?> {
  _RRectTween({super.end});

  @override
  RRect? lerp(double t) => begin == null ? end : RRect.lerp(begin, end, t);
}

/// The one-time courtesy after a player has waved two arcs off.
///
/// Asked at most once per account — being asked on every screen is exactly the
/// nagging this is meant to prevent.
class _SkipEverythingPrompt extends StatelessWidget {
  /// Shares the overlay's arrival so the question fades up like everything
  /// else the Chronicler does, rather than being thrown over the screen.
  final double progress;

  const _SkipEverythingPrompt({this.progress = 1});

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => guide.resolveSkipAll(silence: false),
              child: ColoredBox(
                color: EverloreTheme.void0.withValues(alpha: 0.72 * t),
              ),
            ),
          ),
          // Centred when it fits, scrollable when it does not. This is a
          // column of prose and two buttons, and a short screen at large text
          // size is where it would otherwise overflow — but a plain scroll
          // view would also stop it being centred in the common case, hence
          // the minimum height rather than a bare `Center`.
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 48),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * GuideMotion.rise),
                          child: _skipCard(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skipCard(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
    decoration: BoxDecoration(
      color: EverloreTheme.void2,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.5)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHALL I LEAVE YOU TO IT?',
          style: EverloreTheme.serifDisplay(
            size: 13,
            color: EverloreTheme.gold,
            spacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You seem to know your way. Silence me and I will say nothing more '
          'anywhere — not on your stories, not in the tomes. You may restore '
          'my voice from your profile at any time.',
          style: EverloreTheme.ui(
            size: 14,
            color: EverloreTheme.parchment.withValues(alpha: 0.86),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        // Wraps rather than overflows: two labelled actions at 200% system
        // text are wider than a small phone.
        //
        // The `Align` is load-bearing. This column is laid out
        // `crossAxisAlignment: start`, so the `Wrap` was handed loose
        // constraints, shrank to its two buttons, and sat against the left
        // edge — `WrapAlignment.end` had no spare width to align inside and
        // did nothing. Every beat card puts its actions on the right; the one
        // screen that asks the player a real question was the one that did not.
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            // Order and weight, both deliberate. This used to put "Stay
            // quiet" in the gold pill on the right — the position every beat
            // card uses for Next and Done, and the one a player taps without
            // reading. So the thumb's default answer was the irreversible
            // one: it sets `optOut`, which silences the play, chronicle and
            // realm arcs the player has not met yet, and nothing on the way
            // out said so. Waving off a few tips is ordinary impatience and
            // must not be able to end the walkthrough by muscle memory. The
            // reversible answer is now the emphasised one; silence is still
            // one tap away, it just has to be aimed at.
            children: [
              TextButton(
                onPressed: () => guide.resolveSkipAll(silence: true),
                child: Text(
                  'Stay quiet',
                  style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                ),
              ),
              GestureDetector(
                onTap: () => guide.resolveSkipAll(silence: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: EverloreTheme.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Keep them',
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.void0,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
