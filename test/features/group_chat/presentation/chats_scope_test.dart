import 'dart:async';

import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/screens/direct_thread_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_preview_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_room_screen.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';
import 'package:everlore/shared/models/world_instance.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes.dart';

GroupChatRow _row() => GroupChatRow.parse({
  'instance_id': instanceId,
  'template_id': 't1',
  'title': 'Guild',
  'members': [
    {'id': jess, 'name': 'Jess'},
  ],
  'last': {
    'from': 'member',
    'name': 'Jess',
    'text': 'hi',
    'at': DateTime.utc(2026, 11, 4, 11).toIso8601String(),
  },
})!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('a route pushed above the shell reads ChatsCubit and marks', (
    tester,
  ) async {
    final chats = ChatsCubit(
      repository: FakeChatsRepository([_row()]),
      loadTemplates: () async => const [],
      now: () => DateTime.utc(2026, 11, 4, 12),
    );
    addTearDown(chats.close);
    await chats.refresh();
    expect(chats.state.unreadCount, 1);

    final gateway = FakeGateway();
    final room = GroupChatCubit(
      instanceId: instanceId,
      gateway: gateway,
      repository: FakeRepository(),
      clock: FakeClock(),
    );
    addTearDown(room.close);
    await room.start();
    gateway.pushLoaded(loadedFrame());

    // The provider sits above the Navigator, as in main.dart's builder; the
    // room is pushed on the root navigator, outside any "shell".
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            BlocProvider<ChatsCubit>.value(value: chats, child: child!),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    GroupRoomScreen(instanceId: instanceId, cubit: room),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(chats.state.unreadCount, 0);
  });

  testWidgets('a thread opened from the list opens once and back lands there', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final room = GroupChatCubit(
      instanceId: instanceId,
      gateway: gateway,
      repository: FakeRepository(),
      clock: FakeClock(),
    );
    addTearDown(room.close);
    await room.start();

    final chats = ChatsCubit(
      repository: FakeChatsRepository([_row()]),
      loadTemplates: () async => const [],
    );
    addTearDown(chats.close);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/group/$instanceId?member=$jess'),
              child: const Text('chats'),
            ),
          ),
        ),
        GoRoute(
          path: '/group/:id',
          builder: (_, state) => GroupRoomScreen(
            instanceId: state.pathParameters['id']!,
            initialMemberId: state.uri.queryParameters['member'],
            cubit: room,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<ChatsCubit>.value(
        value: chats,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await chats.refresh();
    await tester.tap(find.text('chats'));
    await tester.pump();
    gateway.pushLoaded(loadedFrame());
    await tester.pumpAndSettle();

    expect(find.byType(DirectThreadScreen), findsOneWidget);

    // Further cubit changes must not push the thread again.
    gateway.pushLoaded(loadedFrame());
    await tester.pumpAndSettle();
    expect(find.byType(DirectThreadScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(DirectThreadScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DirectThreadScreen), findsNothing);
    expect(find.byType(GroupRoomScreen), findsNothing);
    expect(find.text('chats'), findsOneWidget);

    // Only the thread was read. The room underneath stays unread.
    final roomRow = chats.state.conversations.firstWhere((c) => !c.isDirect);
    expect(roomRow.unread, isTrue);
  });

  group('GroupPreviewScreen join', () {
    late List<WorldInstance> saves;
    var gate = Completer<WorldInstance>();
    var creates = 0;

    WorldInstance save(String id) =>
        WorldInstance(id: id, templateId: 't1', playerId: 'p');

    Future<void> pumpPreview(WidgetTester tester) async {
      // Made inside the test body, so its futures run on the test's clock.
      gate = Completer<WorldInstance>();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => GroupPreviewScreen(
              templateId: 't1',
              template: const WorldTemplate(
                id: 't1',
                creatorId: '',
                title: 'Guild',
                slug: 't1',
                description: 'A circle of friends.',
                kind: 'group',
                members: [TemplateMember(name: 'Jess')],
              ),
              loadSaves: () async => saves,
              createSave: (_) {
                creates++;
                return gate.future;
              },
            ),
          ),
          GoRoute(
            path: '/group/:id',
            builder: (_, state) =>
                Scaffold(body: Text('room ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider<ChatsCubit>(
          create: (_) => ChatsCubit(
            repository: FakeChatsRepository(),
            loadTemplates: () async => const [],
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    setUp(() {
      saves = [];
      creates = 0;
    });

    testWidgets('a second tap while joining, and after, makes one save', (
      tester,
    ) async {
      await pumpPreview(tester);
      expect(find.text('Join'), findsOneWidget);

      await tester.tap(find.text('Join'));
      await tester.pump();
      // The loader covers the button, but a double tap can still land
      // before it does: call the handler again while the create runs.
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!();
      await tester.pump();
      expect(creates, 1);

      gate.complete(save('new1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('room new1'), findsOneWidget);

      // Back on the preview, the button now opens the save.
      final router = GoRouter.of(tester.element(find.text('room new1')));
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('room new1'), findsOneWidget);
    });

    testWidgets('a save that already exists opens, with no create', (
      tester,
    ) async {
      saves = [save('old1')];
      await pumpPreview(tester);
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(creates, 0);
      expect(find.text('room old1'), findsOneWidget);
    });

    testWidgets('a failed create shows a notice and can be tried again', (
      tester,
    ) async {
      await pumpPreview(tester);
      await tester.tap(find.text('Join'));
      await tester.pump();
      gate.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Could not join that group.'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      // Flush the notice's timer.
      await tester.pump(const Duration(seconds: 10));
    });
  });

  test('a room frame names its group, and a frame without one keeps it', () async {
    final gateway = FakeGateway();
    final room = GroupChatCubit(
      instanceId: instanceId,
      gateway: gateway,
      repository: FakeRepository(),
      clock: FakeClock(),
    );
    addTearDown(room.close);
    await room.start();
    final frame = loadedFrame();
    (frame['data'] as Map)['template'] = {'title': 'Guild', 'image_url': 'https://cdn/cover.png'};
    gateway.pushLoaded(frame);
    await Future<void>.delayed(Duration.zero);
    expect(room.state.title, 'Guild');
    expect(room.state.imageUrl, 'https://cdn/cover.png');
    gateway.pushLoaded(loadedFrame());
    await Future<void>.delayed(Duration.zero);
    expect(room.state.title, 'Guild');
  });
}
