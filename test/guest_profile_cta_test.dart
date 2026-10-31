// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/storage/secure_storage.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:everlore/shared/widgets/neu.dart';
import 'package:everlore/shared/widgets/settings_group.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildTestApp({
  required GoRouter router,
  Size size = const Size(390, 844),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      disableAnimations: true,
    ),
    child: MaterialApp.router(
      theme: EverloreTheme.dark,
      routerConfig: router,
    ),
  );
}

Future<void> _pumpIt(WidgetTester tester, [int count = 3]) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _setTallViewport(WidgetTester tester, [double height = 1400]) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(800, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
    await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
  });

  group('Guest profile CTA (/profile)', () {
    const guestUser = User(
      id: 'guest-1',
      email: '',
      username: 'Traveler',
      tier: 'free',
      guest: true,
      preferences: UserPreferences(),
    );

    const signedInUser = User(
      id: 'user-1',
      email: 'traveler@everlore.com',
      username: 'traveler',
      tier: 'free',
      guest: false,
      preferences: UserPreferences(),
    );

    testWidgets('guest sees "Keep your story" CTA card, "Sign in" NeuButton, and no phone field', (tester) async {
      _setTallViewport(tester);
      await SecureStore.saveUserData(jsonEncode(guestUser.toJson()));

      String? pushedRoute;
      final testRouter = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AuthScreen(),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) {
              pushedRoute = '/auth';
              return const Scaffold(body: Text('Auth Screen'));
            },
          ),
          GoRoute(
            path: '/my-worlds',
            builder: (context, state) => const Scaffold(body: Text('My Worlds')),
          ),
          GoRoute(
            path: '/membership',
            builder: (context, state) => const Scaffold(body: Text('Membership')),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Scaffold(body: Text('Settings')),
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(router: testRouter));
      await _pumpIt(tester, 5);

      expect(find.byType(AuthScreen), findsOneWidget);

      // The guest CTA card is visible
      expect(find.text('Keep your story'), findsOneWidget);
      expect(
        find.text("Sign in to save everything you've done and play on any device."),
        findsOneWidget,
      );

      // Full-width primary NeuButton "Sign in"
      final signInButtonFinder = find.widgetWithText(NeuButton, 'Sign in');
      expect(signInButtonFinder, findsOneWidget);
      final neuButton = tester.widget<NeuButton>(signInButtonFinder);
      expect(neuButton.primary, isTrue);

      // No phone field / text field on guest profile
      expect(find.byType(TextField), findsNothing);

      // No sign out button for guest
      expect(find.text('Sign out'), findsNothing);

      // Tapping "Sign in" pushes /auth
      await tester.tap(signInButtonFinder);
      await _pumpIt(tester, 3);
      expect(pushedRoute, equals('/auth'));
    });

    testWidgets('signed-in user sees "Sign out" and no "Keep your story" CTA', (tester) async {
      _setTallViewport(tester);
      await SecureStore.saveUserData(jsonEncode(signedInUser.toJson()));

      final testRouter = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AuthScreen(),
          ),
          GoRoute(
            path: '/my-worlds',
            builder: (context, state) => const Scaffold(body: Text('My Worlds')),
          ),
          GoRoute(
            path: '/membership',
            builder: (context, state) => const Scaffold(body: Text('Membership')),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Scaffold(body: Text('Settings')),
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(router: testRouter));
      await _pumpIt(tester, 5);

      expect(find.byType(AuthScreen), findsOneWidget);

      // Sign out text button is visible
      expect(find.text('Sign out'), findsOneWidget);

      // No guest CTA
      expect(find.text('Keep your story'), findsNothing);
      expect(find.widgetWithText(NeuButton, 'Sign in'), findsNothing);
    });
  });

  group('SettingsNavRow busy state', () {
    testWidgets('busy: false renders icon and accepts taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: Scaffold(
            body: SettingsGroup(
              children: [
                SettingsNavRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete account',
                  tone: EverloreTheme.crimson,
                  busy: false,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Delete account'), findsOneWidget);

      await tester.tap(find.text('Delete account'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('busy: true renders 16dp progress indicator and ignores taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: Scaffold(
            body: SettingsGroup(
              children: [
                SettingsNavRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Deleting your account…',
                  tone: EverloreTheme.crimson,
                  busy: true,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Icon replaced by CircularProgressIndicator
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      final spinnerFinder = find.byType(CircularProgressIndicator);
      expect(spinnerFinder, findsOneWidget);

      final spinnerWidget = tester.widget<CircularProgressIndicator>(spinnerFinder);
      expect(spinnerWidget.strokeWidth, equals(2.0));
      expect(spinnerWidget.color, equals(EverloreTheme.crimson));

      // Container size is 16x16
      final indicatorSize = tester.getSize(spinnerFinder);
      expect(indicatorSize.width, equals(16.0));
      expect(indicatorSize.height, equals(16.0));

      expect(find.text('Deleting your account…'), findsOneWidget);

      // Row is not tappable while busy
      await tester.tap(find.text('Deleting your account…'));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });
}
