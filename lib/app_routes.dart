import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/screens/splash_screen.dart';
import 'package:everlore/screens/welcome_screen.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/screens/onboarding_screen.dart';
import 'package:everlore/screens/discover_screen.dart';
import 'package:everlore/features/home/presentation/home_screen.dart';
import 'package:everlore/features/home/presentation/realm_playthroughs_screen.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';
import 'package:everlore/features/play/presentation/realm_screen.dart';
import 'package:everlore/features/chronicle/presentation/chronicle_screen.dart';
import 'package:everlore/features/templates/presentation/browse_screen.dart';
import 'package:everlore/features/templates/presentation/template_detail_screen.dart';
import 'package:everlore/features/creator/presentation/my_worlds_screen.dart';
import 'package:everlore/features/creator/presentation/forge_world_route.dart';
import 'package:everlore/features/creator/presentation/create_character_screen.dart';
import 'package:everlore/features/personas/presentation/personas_screen.dart';
import 'package:everlore/features/billing/presentation/billing_screen.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_nav_bar.dart';
import 'package:everlore/screens/settings_screen.dart';
import 'features/moderation/presentation/blocked_content_screen.dart';
import 'features/keepsakes/presentation/keepsakes_screen.dart';
import 'features/group_chat/presentation/screens/chats_screen.dart';
import 'features/group_chat/presentation/screens/create_group_screen.dart';
import 'features/group_chat/presentation/screens/group_preview_screen.dart';
import 'features/group_chat/presentation/screens/group_room_screen.dart';
import 'features/group_chat/presentation/screens/my_groups_screen.dart';
import 'features/group_chat/state/chats_cubit.dart';
import 'features/group_chat/state/create_group_cubit.dart';
import 'features/group_chat/state/my_groups_cubit.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/notifications/state/notifications_cubit.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// A context inside the root navigator's overlay, for notices and full-screen
/// viewers opened from code that has no screen of its own. Null before the
/// first frame.
BuildContext? get rootOverlayContext =>
    _rootNavigatorKey.currentState?.overlay?.context;

/// Reads the chats list and the notifications the first time the tab shell is built, which is after
/// sign-in; the cubit itself lives above the Navigator and starts empty.
class _RefreshChatsOnce extends StatefulWidget {
  final Widget child;
  const _RefreshChatsOnce({required this.child});

  @override
  State<_RefreshChatsOnce> createState() => _RefreshChatsOnceState();
}

class _RefreshChatsOnceState extends State<_RefreshChatsOnce> {
  @override
  void initState() {
    super.initState();
    context.read<ChatsCubit>().refresh();
    context.read<NotificationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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
      // `?from=story` is how a guest is sent here from a story that asked them
      // to sign in; they are returned to it afterwards.
      builder: (context, state) => AuthScreen(
        returnToStory: state.uri.queryParameters['from'] == 'story',
      ),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
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
      builder: (context, state) =>
          TemplateDetailScreen(templateId: state.pathParameters['templateId']!),
    ),
    GoRoute(
      path: '/realms/:templateId',
      name: 'realm_stories',
      builder: (context, state) => RealmPlaythroughsScreen(
        templateId: state.pathParameters['templateId']!,
      ),
    ),
    GoRoute(
      path: '/play/:instanceId',
      name: 'play',
      builder: (context, state) => PlayScreen(
        instanceId: state.pathParameters['instanceId']!,
        focusEventId: state.uri.queryParameters['event'],
        starter: state.uri.queryParameters['starter'] == '1',
      ),
    ),
    GoRoute(
      path: '/group-preview/:templateId',
      name: 'group_preview',
      builder: (context, state) => GroupPreviewScreen(
        templateId: state.pathParameters['templateId']!,
        template: state.extra as WorldTemplate?,
      ),
    ),
    GoRoute(
      path: '/group/:instanceId',
      name: 'group_chat',
      builder: (context, state) => GroupRoomScreen(
        instanceId: state.pathParameters['instanceId']!,
        title: state.extra is Map
            ? (state.extra as Map)['title'] as String?
            : null,
        initialMemberId: state.uri.queryParameters['member'],
      ),
    ),
    GoRoute(
      path: '/groups/new',
      name: 'create_group',
      builder: (context, state) => BlocProvider(
        create: (_) => CreateGroupCubit(),
        child: const CreateGroupScreen(),
      ),
    ),
    GoRoute(
      path: '/groups/:templateId/edit',
      name: 'edit_group',
      builder: (context, state) {
        final id = state.pathParameters['templateId']!;
        return BlocProvider(
          create: (_) => CreateGroupCubit()..load(id),
          child: CreateGroupScreen(templateId: id),
        );
      },
    ),
    GoRoute(
      path: '/groups/mine',
      name: 'my_groups',
      builder: (context, state) => BlocProvider(
        create: (_) => MyGroupsCubit()..load(),
        child: const MyGroupsScreen(),
      ),
    ),
    GoRoute(
      path: '/chronicle/:instanceId',
      name: 'chronicle',
      builder: (context, state) => ChronicleScreen(
        instanceId: state.pathParameters['instanceId']!,
        initialSection: state.uri.queryParameters['section'],
      ),
    ),
    GoRoute(
      path: '/realm/:instanceId',
      name: 'realm',
      builder: (context, state) => RealmScreen(
        instanceId: state.pathParameters['instanceId']!,
        args: state.extra as RealmScreenArgs?,
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
    GoRoute(
      path: '/my-worlds',
      name: 'my_worlds',
      builder: (context, state) => const MyWorldsScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/membership',
      name: 'membership',
      builder: (context, state) =>
          BillingScreen(source: state.uri.queryParameters['source']),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/blocked-content',
      name: 'blocked-content',
      builder: (context, state) => const BlockedContentScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/personas',
      name: 'personas',
      builder: (context, state) =>
          PersonasScreen(from: state.uri.queryParameters['from']),
    ),

    // ── The persistent shell: four primary branches, each with its own stack + state,
    // wrapped by the always-on EverloreNavBar. ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _RefreshChatsOnce(child: ScaffoldWithNavBar(shell: navigationShell)),
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
              path: '/chats',
              name: 'chats',
              builder: (context, state) => const ChatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/keepsakes',
              name: 'keepsakes',
              builder: (context, state) => const KeepsakesScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
