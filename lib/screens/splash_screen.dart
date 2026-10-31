import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/auth/auth_service.dart';
import '../core/guest/guest_session.dart';
import '../core/guide/guide_controller.dart';
import '../core/onboarding/interests_store.dart';
import '../app/theme/nexus_theme.dart';
import '../shared/app_icons.dart';

/// Everlore splash: "Step through".
///
/// Frame 0 is exactly what Android 12+'s system splash is showing (the
/// painting in a 160 px circle on the launch ground), so the hand-off from the
/// OS is invisible. The circle then opens into the full painting, holds while
/// the sign-in decision finishes, and the player walks into the doorway's light.
///
/// The sign-in decision runs at the same time as the animation. The exit only
/// starts once BOTH the opening and the decision are done.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.decideRoute});

  /// Replaces the sign-in decision in tests. Returns the location to go to.
  @visibleForTesting
  final Future<String?> Function()? decideRoute;

  /// Widget tests cannot decode images under fake time, so they switch the
  /// wait for the painting off.
  @visibleForTesting
  static bool waitForPainting = true;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Android draws the adaptive icon at 240 dp and masks a 160 dp circle; that
/// circle is the painting. Anything else here would jump on hand-off.
const double _kSystemSplashCircle = 160;

const Duration _kOpen = Duration(milliseconds: 900);
const Duration _kMinHold = Duration(milliseconds: 250);
const Duration _kWalk = Duration(milliseconds: 900);
const Duration _kOut = Duration(milliseconds: 450);
const Duration _kReducedHold = Duration(milliseconds: 400);

/// Hides everything outside the painting's circle by laying the ground colour
/// over it: transparent out to `(1 - feather) * R`, ground from R outwards.
/// A circle (not a rounded square) because the painting's own edges are
/// mid-brown stone, not ground, and a square hole shows up as a lighter square
/// on the dark ground. At frame 0 the feather is a hair, so the edge is the
/// same antialiased circle Android's system splash draws.
@visibleForTesting
class SplashPaintingMask extends CustomPainter {
  /// Side of the painting's square; the circle's radius is half of it.
  final double side;

  /// Fraction of the radius over which the edge fades to the ground.
  final double feather;
  final Color ground;
  const SplashPaintingMask({
    required this.side,
    required this.feather,
    required this.ground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = side / 2;
    final clear = ground.withValues(alpha: 0);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        size.center(Offset.zero),
        r,
        [clear, clear, ground, ground],
        [0, 1 - feather, 1, 1],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(SplashPaintingMask old) =>
      old.side != side || old.feather != feather || old.ground != ground;
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: _kOpen,
  );
  // One half of the doorway light's breath; reversing makes a 1.8 s period.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _kMinHold,
  );
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: _kWalk,
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: _kOut,
  );

  late final Future<String?> _route;
  bool _started = false;
  bool _deferred = false;
  Timer? _safety;

  @override
  void initState() {
    super.initState();
    _route = _resolveRoute();
    // Android's system splash stays up until Flutter's first frame. Hold that
    // frame until the painting is decoded, or the circle blinks to near-black
    // and back while it loads.
    final binding = WidgetsBinding.instance;
    if (SplashScreen.waitForPainting && !binding.firstFrameRasterized) {
      _deferred = true;
      binding.deferFirstFrame();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!_deferred) {
      _run(reduced: reduced);
      return;
    }
    _paintingReady().then((_) {
      _allowFirstFrame();
      if (mounted) _run(reduced: reduced);
    });
  }

  /// Completes when the painting has decoded, failed, or a second has passed:
  /// a failed decode must never freeze the app on the system splash.
  Future<void> _paintingReady() {
    final done = Completer<void>();
    final stream = const AssetImage(
      AppIcons.threshold,
    ).resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    void finish() {
      if (done.isCompleted) return;
      _safety?.cancel();
      stream.removeListener(listener);
      done.complete();
    }

    listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    _safety = Timer(const Duration(seconds: 1), finish);
    return done.future;
  }

  void _allowFirstFrame() {
    if (!_deferred) return;
    _deferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  /// The decision must always end in a location: an exception here used to be
  /// swallowed by an unawaited future and left the splash on screen for good.
  Future<String?> _resolveRoute() async {
    try {
      return await (widget.decideRoute ?? _decideRoute)();
    } catch (_) {
      return '/welcome';
    }
  }

  /// The sign-in decision. Returns the location, or null if the screen went away.
  Future<String?> _decideRoute() async {
    var user = await AuthService.getCachedUser();
    if (!mounted) return null;
    if (user != null && user.guest) {
      // A guest is signed in like anyone else: the server confirms the stored
      // token, and only a rejected one is answered with a resume.
      user = await GuestSession.instance.resume();
      if (!mounted) return null;
    }
    if (user == null) return '/welcome';
    // Fold the account's guide record into the device cache before any
    // surface can trigger an arc.
    await guide.hydrateFromAccount(
      user.preferences.guideProgress,
      remoteOptOut: user.preferences.guideOptOut,
    );
    if (!mounted) return null;
    const debugPlay = String.fromEnvironment('DEBUG_OPEN_PLAY');
    if (kDebugMode && debugPlay.isNotEmpty) return '/play/$debugPlay';
    // Discover unless this account still needs interests onboarding.
    final onboarded = await InterestsStore.hasCompletedOnboarding(user: user);
    if (!mounted) return null;
    return onboarded ? '/discover' : '/onboarding';
  }

  /// Open, hold until the decision is in, walk in, fade out, go. Every await
  /// is on a controller of this State, so a disposed screen simply never
  /// resumes; the `mounted` checks cover the decision future.
  Future<void> _run({required bool reduced}) async {
    if (reduced) {
      _open.value = 1;
      _hold.duration = _kReducedHold;
      await Future.wait<void>([_route, _hold.forward()]);
    } else {
      await _open.forward();
      if (!mounted) return;
      _breath.repeat(reverse: true);
      await Future.wait<void>([_route, _hold.forward()]);
      if (!mounted) return;
      _breath.stop();
      await _walk.forward();
      if (!mounted) return;
      await _out.forward();
    }
    if (!mounted) return;
    final route = await _route;
    if (route != null && mounted) context.go(route);
  }

  @override
  void dispose() {
    _safety?.cancel();
    _allowFirstFrame();
    _open.dispose();
    _breath.dispose();
    _hold.dispose();
    _walk.dispose();
    _out.dispose();
    super.dispose();
  }

  static const _nameFade = Interval(350 / 900, 1.0);
  static const _textLeave = Interval(0, 250 / 900);
  static const _lightIn = Interval(0.35, 1.0, curve: Curves.easeIn);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: Listenable.merge([_open, _breath, _walk, _out]),
            builder: (context, _) {
              final openT = Curves.easeInOutCubic.transform(_open.value);
              final side = lerpDouble(_kSystemSplashCircle, w, openT)!;
              // A hair at frame 0 keeps the edge antialiased like the OS circle.
              final feather = 0.006 + (0.22 - 0.006) * openT;
              final scale =
                  1 + 2.4 * Curves.easeInCubic.transform(_walk.value);
              final textA =
                  _nameFade.transform(_open.value) *
                  (1 - _textLeave.transform(_walk.value));
              final glowA =
                  (0.15 + 0.30 * Curves.easeInOut.transform(_breath.value)) *
                  openT;
              final dim = Curves.easeOut.transform(_out.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: SizedBox(
                            key: const Key('splash-painting'),
                            width: side,
                            height: side,
                            child: Image.asset(
                              AppIcons.threshold,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: SplashPaintingMask(
                            side: side,
                            feather: feather,
                            ground: EverloreTheme.void1,
                          ),
                        ),
                        // A soft warm glow over the door opening (centre of the
                        // painting): 25% of the width wide, 55% tall.
                        Center(
                          child: Opacity(
                            opacity: glowA.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scaleX: 0.25 / 0.55,
                              child: Container(
                                width: side * 0.55,
                                height: side * 0.55,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xFFFBEEC9),
                                      Color(0x00FBEEC9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The name block hangs under where the opened painting ends.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: h / 2 + w / 2 + 28,
                    child: Opacity(
                      opacity: textA.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - textA) * 6),
                        child: const _NameBlock(),
                      ),
                    ),
                  ),
                  // The door's light; on the way out its colours dim to the
                  // ground, so it reads as the light going down, not a cut.
                  Opacity(
                    opacity: _lightIn.transform(_walk.value),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.5,
                          colors: [
                            for (final c in const [
                              Color(0xFFFBEEC9),
                              Color(0xFFE9C983),
                              Color(0xFFB08D4C),
                            ])
                              Color.lerp(c, EverloreTheme.void1, dim)!,
                            EverloreTheme.void1,
                          ],
                          stops: const [0.0, 0.5, 0.85, 1.0],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock();

  @override
  Widget build(BuildContext context) {
    const spacing = 20 * 0.32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trailing letter-spacing would push the name off-centre; pad it back.
        Padding(
          padding: const EdgeInsets.only(left: spacing),
          child: Text(
            'EVERLORE',
            style: GoogleFonts.cinzel(
              color: EverloreTheme.gold,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: spacing,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step into a story that remembers you',
          style: GoogleFonts.ebGaramond(
            color: EverloreTheme.ash,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
