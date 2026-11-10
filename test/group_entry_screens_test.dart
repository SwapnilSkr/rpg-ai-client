import 'dart:convert';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/storage/secure_storage.dart';
import 'package:everlore/features/creator/data/creator_repository.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/group_chat/presentation/screens/chats_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/my_groups_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_face_mosaic.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_cover_card.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/chats_read_marks.dart';
import 'package:everlore/features/group_chat/state/my_groups_cubit.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_empty_state.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'features/group_chat/fakes.dart';

class _NoOpReadMarks implements ChatsReadMarks {
  const _NoOpReadMarks();

  @override
  Future<Map<String, DateTime>> read() async => const {};

  @override
  Future<void> write(Map<String, DateTime> marks) async {}

  @override
  Future<void> clear() async {}
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await GuideController.instance.hydrateFromAccount(null, remoteOptOut: true);
  });

  group('Chats entry banner', () {
    testWidgets(
      'the banner two tap targets go to their two routes and are hidden without forge access',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. With forge access
        const forgeUser = User(
          id: 'u_forge',
          email: 'forge@test.com',
          username: 'forge',
          tier: 'premium',
          canForge: true,
        );
        await SecureStore.saveUserData(jsonEncode(forgeUser.toJson()));

        final chatsCubit = ChatsCubit(
          repository: FakeChatsRepository(),
          marks: const _NoOpReadMarks(),
          loadTemplates: () async => const [],
        );

        String? lastRoute;
        final router = GoRouter(
          initialLocation: '/chats',
          routes: [
            GoRoute(
              path: '/chats',
              builder: (context, state) => BlocProvider.value(
                value: chatsCubit,
                child: const ChatsScreen(),
              ),
            ),
            GoRoute(
              path: '/groups/new',
              builder: (context, state) {
                lastRoute = '/groups/new';
                return const Scaffold(body: Text('NEW_GROUP_SCREEN'));
              },
            ),
            GoRoute(
              path: '/groups/mine',
              builder: (context, state) {
                lastRoute = '/groups/mine';
                return const Scaffold(body: Text('MY_GROUPS_SCREEN'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(theme: EverloreTheme.dark, routerConfig: router),
        );
        await tester.pumpAndSettle();

        // Banner elements should be visible
        expect(find.text('Make your own group'), findsOneWidget);
        expect(find.text('Your people, your words.'), findsOneWidget);
        expect(find.text('Your groups'), findsOneWidget);

        // Tap "Make your own group" -> goes to /groups/new
        await tester.tap(find.text('Make your own group'));
        await tester.pumpAndSettle();
        expect(lastRoute, '/groups/new');
        expect(find.text('NEW_GROUP_SCREEN'), findsOneWidget);

        // Pop back to /chats
        router.pop();
        await tester.pumpAndSettle();

        // Tap "Your groups" -> goes to /groups/mine
        await tester.tap(find.text('Your groups'));
        await tester.pumpAndSettle();
        expect(lastRoute, '/groups/mine');
        expect(find.text('MY_GROUPS_SCREEN'), findsOneWidget);

        // 2. Without forge access: banner is hidden
        FlutterSecureStorage.setMockInitialValues({});
        const noForgeUser = User(
          id: 'u_noforge',
          email: 'noforge@test.com',
          username: 'noforge',
          tier: 'free',
          canForge: false,
        );
        await SecureStore.saveUserData(jsonEncode(noForgeUser.toJson()));

        final noForgeCubit = ChatsCubit(
          repository: FakeChatsRepository(),
          marks: const _NoOpReadMarks(),
          loadTemplates: () async => const [],
        );

        final routerNoForge = GoRouter(
          initialLocation: '/chats',
          routes: [
            GoRoute(
              path: '/chats',
              builder: (context, state) => BlocProvider.value(
                value: noForgeCubit,
                child: const ChatsScreen(),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            theme: EverloreTheme.dark,
            routerConfig: routerNoForge,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Make your own group'), findsNothing);
        expect(find.text('Your groups'), findsNothing);

        // Allow guide timer to complete
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });

  group('Your groups (MyGroupsScreen)', () {
    testWidgets(
      'shows empty state with no groups, mosaic for a group with no cover, and cover when there is one',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 1. Empty state with no groups
        final emptyCubit = MyGroupsCubit(
          fetchPage: ({page = 1, limit = 20}) async =>
              const CreatorWorldPage(worlds: [], total: 0, page: 1),
          changesNotifier: ValueNotifier(0),
        );
        await emptyCubit.load();

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: emptyCubit,
              child: const MyGroupsScreen(),
            ),
          ),
        );
        // EverloreEmptyState runs an infinite pulse animation, so pump without waiting to settle
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(EverloreEmptyState), findsOneWidget);
        expect(find.text("You haven't made a group yet."), findsOneWidget);
        expect(
          find.text('Write a few people and they start talking.'),
          findsOneWidget,
        );
        expect(find.text('Create a group'), findsOneWidget);

        // 2. Group with no cover renders GroupFaceMosaic
        const groupNoCover = WorldTemplate(
          id: 'g_no_cover',
          creatorId: 'c1',
          title: 'The Regulars',
          slug: 'the-regulars',
          description: 'A climbing squad.',
          kind: 'group',
          imageUrl: '',
          members: [
            TemplateMember(name: 'Ines', portraitUrl: 'https://cdn/ines.jpg'),
            TemplateMember(name: 'Tomas', portraitUrl: 'https://cdn/tomas.jpg'),
          ],
        );

        final noCoverCubit = MyGroupsCubit(
          fetchPage: ({page = 1, limit = 20}) async =>
              const CreatorWorldPage(worlds: [groupNoCover], total: 1, page: 1),
          changesNotifier: ValueNotifier(0),
        );
        await noCoverCubit.load();

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: noCoverCubit,
              child: const MyGroupsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(GroupCoverCard), findsOneWidget);
        expect(find.byType(GroupFaceMosaic), findsOneWidget);
        expect(find.text('The Regulars'), findsOneWidget);

        // 3. Group with cover renders EverloreNetworkImage cover
        const groupWithCover = WorldTemplate(
          id: 'g_with_cover',
          creatorId: 'c1',
          title: 'The Vault',
          slug: 'the-vault',
          description: 'A dark mystery.',
          kind: 'group',
          imageUrl: 'https://cdn/cover.webp',
          imageThumbUrl: 'https://cdn/cover-t.webp',
          members: [
            TemplateMember(name: 'Ines', portraitUrl: 'https://cdn/ines.jpg'),
          ],
        );

        final withCoverCubit = MyGroupsCubit(
          fetchPage: ({page = 1, limit = 20}) async => const CreatorWorldPage(
            worlds: [groupWithCover],
            total: 1,
            page: 1,
          ),
          changesNotifier: ValueNotifier(0),
        );
        await withCoverCubit.load();

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: withCoverCubit,
              child: const MyGroupsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(GroupCoverCard), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is EverloreNetworkImage &&
                (w.imageUrl == 'https://cdn/cover.webp' ||
                    w.imageUrl == 'https://cdn/cover-t.webp'),
          ),
          findsOneWidget,
        );
        expect(find.text('The Vault'), findsOneWidget);
        // Cover card has cover, so GroupFaceMosaic fallback is not rendered
        expect(find.byType(GroupFaceMosaic), findsNothing);
      },
    );
  });

  group('Share sheet button text', () {
    const groupTemplate = WorldTemplate(
      id: 'g1',
      creatorId: 'c1',
      title: 'Climbing Gym',
      slug: 'climbing-gym',
      description: 'A group.',
      kind: 'group',
    );

    const worldTemplate = WorldTemplate(
      id: 'w1',
      creatorId: 'c1',
      title: 'The Citadel',
      slug: 'the-citadel',
      description: 'A world.',
      kind: 'world',
    );

    testWidgets(
      'share button text for each of the two choices, and "Publish" for a world',
      (tester) async {
        // 1. Group with choiceButtonLabels: true
        await tester.pumpWidget(
          _wrap(
            const PublishWorldSheet(
              template: groupTemplate,
              noun: 'group',
              choiceButtonLabels: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially "Just for you" (private) is selected -> "Keep it just for me"
        expect(find.text('Keep it just for me'), findsOneWidget);
        expect(find.text('Share with everyone'), findsNothing);
        expect(find.text('Publish'), findsNothing);

        // Tap "For everyone" (public) -> "Share with everyone"
        await tester.tap(find.text('For everyone'));
        await tester.pumpAndSettle();

        expect(find.text('Share with everyone'), findsOneWidget);
        expect(find.text('Keep it just for me'), findsNothing);
        expect(find.text('Publish'), findsNothing);

        // Tap "Just for you" (private) -> "Keep it just for me"
        await tester.tap(find.text('Just for you'));
        await tester.pumpAndSettle();

        expect(find.text('Keep it just for me'), findsOneWidget);
        expect(find.text('Share with everyone'), findsNothing);
        expect(find.text('Publish'), findsNothing);

        // 2. World (noun: "world", default choiceButtonLabels: false) -> "Publish"
        await tester.pumpWidget(
          _wrap(
            const PublishWorldSheet(template: worldTemplate, noun: 'world'),
          ),
        );
        await tester.pumpAndSettle();

        // Private selected by default -> "Publish"
        expect(find.text('Publish'), findsOneWidget);
        expect(find.text('Keep it just for me'), findsNothing);
        expect(find.text('Share with everyone'), findsNothing);

        // Tap "For every traveller" -> still "Publish"
        await tester.tap(find.text('For every traveller'));
        await tester.pumpAndSettle();

        expect(find.text('Publish'), findsOneWidget);
        expect(find.text('Keep it just for me'), findsNothing);
        expect(find.text('Share with everyone'), findsNothing);
      },
    );
  });
}
