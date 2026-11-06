import 'dart:async';

import 'package:everlore/core/guide/guide_anchor.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/guide/guide_flows.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:everlore/core/guide/widgets/guide_host.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_room_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_composer.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_reply_ideas.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';
import 'package:everlore/features/home/domain/realm_group.dart';
import 'package:everlore/features/home/presentation/home_screen.dart';
import 'package:everlore/features/home/state/home_cubit.dart';
import 'package:everlore/features/notifications/data/notifications_repository.dart';
import 'package:everlore/features/notifications/models/app_notification.dart';
import 'package:everlore/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:everlore/features/notifications/state/notifications_cubit.dart';
import 'package:everlore/features/notifications/state/notifications_state.dart';
import 'package:everlore/shared/models/world_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/group_chat/fakes.dart';

class _FakeHomeCubit extends HomeCubit {
  _FakeHomeCubit(HomeState initial) : super() {
    emit(initial);
  }
  void setState(HomeState next) => emit(next);

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> loadInstances({
    bool silent = false,
    bool forceRefresh = false,
    String? search,
  }) async {}
}

class _DummyNotificationsRepo implements NotificationsRepository {
  const _DummyNotificationsRepo();
  @override
  Future<NotificationsPage> page({String? before}) async =>
      const NotificationsPage(items: [], unread: 0, hasMore: false);
  @override
  Future<int> markIds(List<String> ids) async => 0;
  @override
  Future<int> markAll() async => 0;
  @override
  Future<int> markMedia(String mediaId) async => 0;
}

class _TestNotificationsCubit extends NotificationsCubit {
  _TestNotificationsCubit(NotificationsState initial)
    : super(
        repository: const _DummyNotificationsRepo(),
        frames: const Stream.empty(),
        connection: const Stream.empty(),
      ) {
    emit(initial);
  }
  void setState(NotificationsState next) => emit(next);
}

Future<void> _cleanGuide(WidgetTester tester) async {
  await guide.skip();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() async {
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  tearDown(() async {
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  group('Moment-fired arc: notifications', () {
    testWidgets('starts when bell shows unread mark and not before', (
      tester,
    ) async {
      final cubit = _TestNotificationsCubit(
        const NotificationsState(unread: 0),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: GuideHost(
            child: Scaffold(
              appBar: AppBar(actions: [NotificationsBellButton(cubit: cubit)]),
              body: const SizedBox(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // With unread == 0, notifications arc has not started
      expect(guide.activeFlow, isNull);

      // Now unread arrives
      cubit.setState(const NotificationsState(unread: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Starts once unread is true
      expect(guide.activeFlow?.id, equals(GuideFlows.notifications.id));
      expect(guide.activeFlow?.beats.first.title, 'Word From Elsewhere');

      await _cleanGuide(tester);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Moment-fired arc: group.ideas', () {
    testWidgets('starts when reply ideas are on screen and not before', (
      tester,
    ) async {
      final ideasNotifier = ValueNotifier<List<String>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: GuideHost(
            child: Scaffold(
              body: ValueListenableBuilder<List<String>>(
                valueListenable: ideasNotifier,
                builder: (context, ideas, _) {
                  return GroupReplyIdeas(ideas: ideas, onSendIdea: (_) {});
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // With no ideas, group.ideas does not start
      expect(guide.activeFlow, isNull);

      // Ideas arrive on screen
      ideasNotifier.value = ['Tell me more', 'I see'];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Starts once reply ideas are on screen
      expect(guide.activeFlow?.id, equals(GuideFlows.groupIdeas.id));
      expect(guide.activeFlow?.beats.first.title, 'A Word Ready');

      await _cleanGuide(tester);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Moment-fired arc: group.hold', () {
    testWidgets('starts once room shows third character line and not before', (
      tester,
    ) async {
      final clock = FakeClock();
      final gateway = FakeGateway();
      final repo = FakeRepository();
      final cubit = GroupChatCubit(
        instanceId: 'inst_1',
        gateway: gateway,
        repository: repo,
        clock: clock,
      );

      // Mark group.room as already seen so it does not auto-start ahead of group.hold
      await guide.hydrateFromAccount({
        GuideFlows.groupRoom.id: {
          'status': 'done',
          'version': GuideFlows.groupRoom.version,
          'step': 0,
          'at': DateTime.now().toIso8601String(),
        },
      });

      final chatsCubit = ChatsCubit(
        repository: FakeChatsRepository(),
        loadTemplates: () async => const [],
      );

      // Push initial frame with 2 character lines (not yet 3)
      gateway.pushLoaded(
        loadedFrame(
          id: 'inst_1',
          events: [
            eventRow(
              id: 'e1',
              sequence: 1,
              lines: [
                storedLine(
                  jess,
                  'Line 1 from Jess',
                  clock.now().subtract(const Duration(minutes: 2)),
                ),
                storedLine(
                  tom,
                  'Line 2 from Tom',
                  clock.now().subtract(const Duration(minutes: 1)),
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        BlocProvider<ChatsCubit>.value(
          value: chatsCubit,
          child: MaterialApp(
            home: GuideHost(
              child: GroupRoomScreen(instanceId: 'inst_1', cubit: cubit),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      // With only 2 character lines, group.hold does NOT start
      expect(guide.activeFlow, isNull);

      // 3rd character line arrives!
      gateway.pushLines({
        'type': 'group_lines',
        'instanceId': 'inst_1',
        'lines': [
          wireLine(
            jess,
            'Line 3 from Jess',
            clock.now().subtract(const Duration(seconds: 1)),
          ),
        ],
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      // Now 3 character lines: group.hold starts
      expect(guide.activeFlow?.id, equals(GuideFlows.groupHold.id));
      expect(guide.activeFlow?.beats.first.title, 'Keeping the Moment');

      await _cleanGuide(tester);
      await tester.pumpWidget(const SizedBox());
      cubit.close();
      chatsCubit.close();
    });
  });

  group('Moment-fired arc: nav.chats', () {
    testWidgets(
      'fires on Realms when holding at least 1 realm and playFirst finished',
      (tester) async {
        // Mark home and homeEmpty as done so HomeScreen's GuideOnEnter does not preempt nav.chats
        await guide.hydrateFromAccount({
          GuideFlows.home.id: {
            'status': 'done',
            'version': GuideFlows.home.version,
            'step': 0,
            'at': DateTime.now().toIso8601String(),
          },
          GuideFlows.homeEmpty.id: {
            'status': 'done',
            'version': GuideFlows.homeEmpty.version,
            'step': 0,
            'at': DateTime.now().toIso8601String(),
          },
        });

        final cubit = _FakeHomeCubit(
          const HomeState(isLoading: false, realms: []),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GuideHost(
              child: Scaffold(
                body: Column(
                  children: [
                    Expanded(child: HomeScreen(cubit: cubit)),
                    const GuideAnchor(
                      id: GuideIds.navChats,
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Text('Chats'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Condition 1: 0 realms -> does NOT fire
        expect(guide.activeFlow, isNull);

        // Give 1 realm, but playFirst not finished
        const realm1 = RealmGroup(
          templateId: 't1',
          template: {'title': 'Thornwall'},
          stories: [WorldInstance(id: 'w1', templateId: 't1', playerId: 'p1')],
          totalStoryCount: 1,
        );
        cubit.setState(const HomeState(isLoading: false, realms: [realm1]));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Condition 2: playFirst not finished -> does NOT fire
        expect(guide.activeFlow, isNull);

        // Mark playFirst as done in guide controller
        await guide.hydrateFromAccount({
          GuideFlows.playFirst.id: {
            'status': 'done',
            'version': GuideFlows.playFirst.version,
            'step': 0,
            'at': DateTime.now().toIso8601String(),
          },
        });

        // Condition met: 1 realm, playFirst finished, not guest first visit -> nav.chats fires!
        const realm2 = RealmGroup(
          templateId: 't2',
          template: {'title': 'Highwatch'},
          stories: [WorldInstance(id: 'w2', templateId: 't2', playerId: 'p1')],
          totalStoryCount: 2,
        );
        cubit.setState(
          const HomeState(isLoading: false, realms: [realm1, realm2]),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();

        expect(guide.activeFlow?.id, equals(GuideFlows.navChats.id));
        expect(guide.activeFlow?.beats.first.title, 'Rooms That Talk Back');

        debugPrint('STEP 7.1: skipping guide');
        await guide.skip();
        debugPrint('STEP 7.2: pumping 400ms');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        debugPrint('STEP 7.3: unmounting');
        await tester.pumpWidget(const SizedBox());
        debugPrint('STEP 7.4: closing cubit');
        cubit.close();
        debugPrint('STEP 8: done');
      },
    );
  });

  group('Layout integrity check at 360dp width with 1.3 text scale', () {
    // Layout checks: a first-visit arc would only leave its timer behind.
    setUp(() => guide.setOptOut(true));
    tearDown(() => guide.setOptOut(false));

    testWidgets('GroupComposer renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: GroupComposer(
                  onSend: (_, __) {},
                  onRetryFailed: (_) {},
                  onDiscardFailed: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('GroupRoomScreen header faces render without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final gateway = FakeGateway();
      final cubit = GroupChatCubit(
        instanceId: 'inst_layout',
        gateway: gateway,
        repository: FakeRepository(),
        clock: FakeClock(),
      );
      await cubit.start();

      final chatsCubit = ChatsCubit(
        repository: FakeChatsRepository(),
        loadTemplates: () async => const [],
      );

      gateway.pushLoaded({
        'type': 'instance_loaded',
        'data': {
          'instance': {
            'id': 'inst_layout',
            'seed_cast_snapshot': [
              {'name': 'Valerius Very Long Name'},
              {'name': 'Cassandra of Highwatch'},
              {'name': 'Theron Swiftblade'},
            ],
          },
          'template': {'title': 'The Iron Citadel'},
          'characters': [
            {
              '_id': 'm1',
              'canonical_name': 'Valerius Very Long Name',
              'role': 'Commander',
            },
            {
              '_id': 'm2',
              'canonical_name': 'Cassandra of Highwatch',
              'role': 'Arch-Mage',
            },
            {
              '_id': 'm3',
              'canonical_name': 'Theron Swiftblade',
              'role': 'Duelist',
            },
          ],
          'recentEvents': <Map<String, dynamic>>[],
          'eventWindow': {'hasOlder': false, 'total': 0},
        },
      });

      await tester.pumpWidget(
        BlocProvider<ChatsCubit>.value(
          value: chatsCubit,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: GroupRoomScreen(instanceId: 'inst_layout', cubit: cubit),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is GuideAnchor && w.id == GuideIds.groupRoomFaces,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      // Not awaited: closing waits on streams the fake clock never drains.
      unawaited(cubit.close());
      unawaited(chatsCubit.close());
    });
  });
}
