import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_routes.dart';
import 'app/theme/nexus_theme.dart';
import 'app/layout/responsive.dart';
import 'shared/widgets/dismiss_keyboard.dart';
import 'core/network/ws_manager.dart';
import 'core/auth/auth_service.dart';
import 'core/guide/guide_controller.dart';
import 'core/guide/widgets/guide_host.dart';
import 'core/guest/keep_story_host.dart';
import 'core/telemetry/route_name.dart';
import 'core/push/push_service.dart';
import 'core/reminders/reminder_service.dart';
import 'core/telemetry/telemetry.dart';
import 'core/notifications/notification_opener.dart';
import 'features/group_chat/state/chats_cubit.dart';
import 'features/notifications/state/notifications_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Started first and awaited just before runApp: its disk and device reads
  // overlap the startup work below instead of adding to the first frame, and
  // the error handlers still exist before the app runs. It never throws: a
  // failure just leaves telemetry off for the run.
  final telemetryReady = Telemetry.instance.init();
  // Same shape: never throws, and a cold-start tap on a reminder is held until
  // the router has left the splash screen.
  final remindersReady = ReminderService.instance.init();
  // Draw behind the status and navigation bars, explicitly and on every
  // Android version. From Android 15 the system does this anyway for apps
  // targeting SDK 35+, so declaring it is what makes the layout the same
  // everywhere instead of changing under the app at API 35. This is the
  // Flutter counterpart of Android's `enableEdgeToEdge()`.
  //
  // Deliberately no SystemUiOverlayStyle here: its colour fields route to
  // Window.setStatusBarColor/setNavigationBarColor, which Android 15
  // deprecated and Play flags.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  try {
    await dotenv.load();
  } catch (_) {}
  // Before anything can reach the auth screen. Firebase reads its config from
  // the platform files (google-services.json / GoogleService-Info.plist) that
  // the build embeds, so there is nothing to pass here.
  //
  // A failure is not fatal: phone sign-in and an already-restored session both
  // work without Firebase, and killing the app on launch would lock out every
  // signed-in player over a subsystem only the Google button needs. The auth
  // screen finds out on its own and hides that button.
  try {
    await Firebase.initializeApp();
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('[firebase] init failed, Google sign-in unavailable: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
  // After Firebase, which it needs. Same shape as reminders: never throws, a
  // cold-start tap on a message is held until the router has left the splash,
  // and registering the device runs in the background.
  final pushReady = PushService.instance.init();
  // Warm the device-cached guide record before the first frame so an arc can
  // never flash in a beat late; the account's copy folds in at splash.
  await guide.init();
  // Debug-only way to see an uncaught error arrive in the console:
  // `--dart-define=TELEMETRY_TEST_ERROR=true`. Folds away in release.
  if (kDebugMode && const bool.fromEnvironment('TELEMETRY_TEST_ERROR')) {
    Future<void>.delayed(const Duration(seconds: 8), () {
      throw StateError('Telemetry test error');
    });
  }
  await telemetryReady;
  await remindersReady;
  await pushReady;
  // Cinzel and EB Garamond ship in assets/google_fonts. With fetching off, a
  // weight someone forgot to bundle fails loudly in debug instead of quietly
  // downloading (and, offline, falling back to a system font on every title).
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final name in const ['Cinzel', 'EBGaramond']) {
      final text = await rootBundle.loadString(
        'assets/google_fonts/$name-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([name], text);
    }
  });
  runApp(const EverloreApp());
}

class EverloreApp extends StatefulWidget {
  const EverloreApp({super.key});

  @override
  State<EverloreApp> createState() => _EverloreAppState();
}

class _EverloreAppState extends State<EverloreApp> {
  StreamSubscription<void>? _accountDeletedSub;
  StreamSubscription<void>? _signedOutSub;

  /// One chats list for the whole app, above the Navigator: the room, the
  /// thread and the preview are pushed outside the tab shell and still mark
  /// and refresh it. Nothing is fetched until the shell first builds.
  final ChatsCubit _chats = ChatsCubit();

  /// One notifications list for the whole app, for the same reason: the bell
  /// sits in two headers, and the screen and the banner share what it holds.
  final NotificationsCubit _notifications = NotificationsCubit(
    ensureConnected: NotificationsCubit.connectStored,
  );

  /// Lets the guide answer system back before the router does.
  ChildBackButtonDispatcher? _guideBack;

  @override
  void initState() {
    super.initState();
    // If the server reports this account was deleted (e.g. from another device),
    // drop the live session and bounce to auth instead of running on against a
    // dead account until the next request 401s.
    _accountDeletedSub = WsManager().onAccountDeleted.listen((_) async {
      await AuthService.logout();
      router.go('/auth');
    });
    // One account's chats must never show to the next.
    _signedOutSub = AuthService.onSignedOut.listen((_) {
      _chats.reset();
      _notifications.reset();
    });
    // A tap from a system message has no row in hand; a save that turns out
    // to be gone takes its rows with it.
    NotificationOpener.instance.onGone = _notifications.removeForSave;
    // Guide arcs are screen-scoped: leaving the surface ends the running arc
    // rather than trailing a tip onto the next one. Modal sheets do not change
    // location, so sheet-bound arcs (the Realm Menu) survive.
    router.routerDelegate.addListener(_onRouteChanged);
    // Seed it: the delegate only notifies on *changes*, so without this the
    // guide has no idea where the player is until they navigate once.
    _onRouteChanged();
    // System back clears a coachmark before it navigates.
    //
    // A child dispatcher rather than a second callback on the root: the root
    // holds exactly one callback — the Router's — and adding a second makes it
    // throw and fall through to the default, which is a silent no-op. Children
    // are asked first, and ours declines whenever the guide is not showing, so
    // an ordinary back press reaches the Router untouched.
    //
    // Deferred a frame because `takePriority` asserts the parent already has a
    // callback, and the `Router` registers its own during this widget's build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _guideBack = ChildBackButtonDispatcher(router.backButtonDispatcher)
        ..addCallback(guide.handleSystemBack)
        ..takePriority();
    });
  }

  void _onRouteChanged() {
    guide.onLocationChanged(_currentLocation());
    // The route's declared name, never the path with ids in it.
    final screen = routeNameOf(router.routerDelegate.currentConfiguration);
    if (screen != null) Telemetry.instance.screen(screen);
  }

  /// Where the player actually is, pushed routes included.
  ///
  /// `currentConfiguration.uri` answers with the *shell branch*. A route
  /// pushed on top of the tabs — play, chronicle, realm — leaves it reporting
  /// the tab underneath, so every arc declared on one of those routes decided
  /// it was on the wrong surface and declined to start. That is six of the
  /// twelve arcs, and the six that matter most.
  ///
  /// GoRouter wraps an imperative push in an `ImperativeRouteMatch` whose own
  /// `matches` carry the pushed location, so the honest answer is the last
  /// match's, falling back to the configuration for ordinary navigation.
  String _currentLocation() {
    final config = router.routerDelegate.currentConfiguration;
    final last = config.matches.isEmpty ? null : config.matches.last;
    if (last is ImperativeRouteMatch) return last.matches.uri.path;
    return config.uri.path;
  }

  @override
  void dispose() {
    _accountDeletedSub?.cancel();
    _signedOutSub?.cancel();
    _chats.close();
    NotificationOpener.instance.onGone = null;
    _notifications.close();
    _guideBack?.removeCallback(guide.handleSystemBack);
    router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Everlore',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.dark,
      routerConfig: router,
      // GuideHost sits above the Navigator so the Chronicler can point at
      // controls inside modal sheets and dialogs, not just plain routes.
      // Text scale is clamped before anything below it lays out, so a
      // player on 200% system text gets large type rather than a clipped one.
      builder: (context, child) => EvTextScaleGuard(
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ChatsCubit>.value(value: _chats),
            BlocProvider<NotificationsCubit>.value(value: _notifications),
          ],
          child: GuideHost(
            child: KeepStoryHost(
              child: DismissKeyboard(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
