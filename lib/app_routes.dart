import 'package:go_router/go_router.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/screens/home_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const MyHomePage(title: 'Everlore'),
    ),
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) => const AuthScreen(title: 'Everlore'),
    ),
  ],
);
