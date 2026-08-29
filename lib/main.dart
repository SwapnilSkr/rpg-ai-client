import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_routes.dart';
import 'app/theme/nexus_theme.dart';
import 'shared/widgets/dismiss_keyboard.dart';
import 'core/network/ws_manager.dart';
import 'core/auth/auth_service.dart';
import 'core/guide/guide_controller.dart';
import 'core/guide/widgets/guide_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  // Warm the device-cached guide record before the first frame so an arc can
  // never flash in a beat late; the account's copy folds in at splash.
  await guide.init();
  runApp(const EverloreApp());
}

class EverloreApp extends StatefulWidget {
  const EverloreApp({super.key});

  @override
  State<EverloreApp> createState() => _EverloreAppState();
}

class _EverloreAppState extends State<EverloreApp> {
  StreamSubscription<void>? _accountDeletedSub;

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

  void _onRouteChanged() => guide.onLocationChanged(_currentLocation());

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
      builder: (context, child) => GuideHost(
        child: DismissKeyboard(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
