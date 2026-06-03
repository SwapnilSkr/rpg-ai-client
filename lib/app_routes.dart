import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/screens/splash_screen.dart';
import 'package:everlore/screens/welcome_screen.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/screens/onboarding_interests_screen.dart';
import 'package:everlore/screens/discover_screen.dart';
import 'package:everlore/features/home/presentation/home_screen.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/chronicle/presentation/chronicle_screen.dart';
import 'package:everlore/features/templates/presentation/browse_screen.dart';
import 'package:everlore/features/templates/presentation/template_detail_screen.dart';
import 'package:everlore/features/creator/presentation/my_worlds_screen.dart';
import 'package:everlore/features/creator/presentation/forge_world_route.dart';
import 'package:everlore/features/creator/presentation/create_character_screen.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_nav_bar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    // ── Full-screen, no nav bar (pre-app / gate→threshold) ──
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingInterestsScreen(),
    ),

    // ── Detail / secondary screens — pushed OVER the shell on the root
    // navigator, so they cover the nav bar and back/OS-back return correctly. ──
    GoRoute(
      path: '/templates',
      name: 'templates',
      builder: (context, state) => const BrowseTemplatesScreen(),
    ),
    GoRoute(
      path: '/templates/:templateId',
      name: 'template_detail',
      builder: (context, state) => TemplateDetailScreen(
        templateId: state.pathParameters['templateId']!,
      ),
    ),
    GoRoute(
      path: '/play/:instanceId',
      name: 'play',
      builder: (context, state) => PlayScreen(
        instanceId: state.pathParameters['instanceId']!,
      ),
    ),
    GoRoute(
      path: '/chronicle/:instanceId',
      name: 'chronicle',
      builder: (context, state) => ChronicleScreen(
        instanceId: state.pathParameters['instanceId']!,
      ),
    ),
    GoRoute(
      path: '/characters/new',
      name: 'create_character',
      builder: (context, state) => const CreateCharacterScreen(),
    ),
    GoRoute(
      path: '/my-worlds/forge',
      name: 'forge_world',
      builder: (context, state) => const ForgeWorldRoute(),
    ),
    GoRoute(
      path: '/my-worlds/:templateId/forge',
      name: 'edit_world',
      builder: (context, state) => ForgeWorldRoute(
        templateId: state.pathParameters['templateId'],
        existing: state.extra as WorldTemplate?,
      ),
    ),

    // ── The persistent shell: four branches, each with its own stack + state,
    // wrapped by the always-on EverloreNavBar. ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNavBar(shell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              name: 'discover',
              builder: (context, state) => const DiscoverScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-worlds',
              name: 'my_worlds',
              builder: (context, state) => const MyWorldsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const AuthScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
