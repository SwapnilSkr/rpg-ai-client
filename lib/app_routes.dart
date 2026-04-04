import 'package:go_router/go_router.dart';
import 'package:everlore/screens/splash_screen.dart';
import 'package:everlore/screens/welcome_screen.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/features/home/presentation/home_screen.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/chronicle/presentation/chronicle_screen.dart';
import 'package:everlore/features/templates/presentation/browse_screen.dart';
import 'package:everlore/features/templates/presentation/template_detail_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
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
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) => const AuthScreen(),
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
  ],
);
