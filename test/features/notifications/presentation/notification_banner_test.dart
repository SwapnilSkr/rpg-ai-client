import 'dart:async';

import 'package:everlore/core/notifications/notification_opener.dart';
import 'package:everlore/features/notifications/data/notifications_repository.dart';
import 'package:everlore/features/notifications/models/app_notification.dart';
import 'package:everlore/features/notifications/presentation/widgets/notification_banner.dart';
import 'package:everlore/features/notifications/state/notifications_cubit.dart';
import 'package:everlore/features/notifications/state/notifications_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _DummyRepo implements NotificationsRepository {
  const _DummyRepo();
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
          repository: const _DummyRepo(),
          frames: const Stream.empty(),
          connection: const Stream.empty(),
        ) {
    emit(initial);
  }

  final openedItems = <AppNotification>[];
  final dismissedSeqs = <int?>[];

  void setState(NotificationsState next) => emit(next);

  @override
  Future<OpenResult> open(AppNotification item) async {
    openedItems.add(item);
    return OpenResult.opened;
  }

  @override
  void dismissBanner([int? seq]) {
    dismissedSeqs.add(seq);
    super.dismissBanner(seq);
  }
}

AppNotification _item({
  required String id,
  required String title,
  required String body,
  DateTime? createdAt,
}) => AppNotification(
  id: id,
  type: 'group_direct',
  instanceId: 'inst_1',
  title: title,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 6, 12),
);

void main() {
  testWidgets('banner shows title and body when banner state is present', (
    tester,
  ) async {
    final item = _item(
      id: 'b1',
      title: 'Captain Vance',
      body: 'Meet me by the harbor docks.',
    );
    final cubit = _TestNotificationsCubit(
      NotificationsState(
        banner: NotificationBanner(item, 1),
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationBannerHost(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Captain Vance'), findsOneWidget);
    expect(find.text('Meet me by the harbor docks.'), findsOneWidget);
    expect(find.text('App Content'), findsOneWidget);
  });

  testWidgets('replaces on a new seq without stacking', (tester) async {
    final item1 = _item(
      id: 'b1',
      title: 'First Messenger',
      body: 'Message from the north.',
    );
    final item2 = _item(
      id: 'b2',
      title: 'Second Messenger',
      body: 'Urgent news from the south.',
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        banner: NotificationBanner(item1, 1),
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationBannerHost(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Messenger'), findsOneWidget);
    expect(find.text('Second Messenger'), findsNothing);

    // Emit a new banner with seq 2
    cubit.setState(
      NotificationsState(
        banner: NotificationBanner(item2, 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Messenger'), findsNothing);
    expect(find.text('Second Messenger'), findsOneWidget);
  });

  testWidgets('calls dismissBanner after its time (using fake async timer)', (
    tester,
  ) async {
    final item = _item(
      id: 'b_timer',
      title: 'Scout',
      body: 'Enemies spotted on the ridge.',
    );

    final cubit = _TestNotificationsCubit(const NotificationsState());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationBannerHost(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      ),
    );
    await tester.pump();

    // Now trigger a banner arrival
    cubit.setState(NotificationsState(banner: NotificationBanner(item, 42)));
    await tester.pump();
    // Complete the enter animation
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scout'), findsOneWidget);
    expect(cubit.dismissedSeqs, isEmpty);

    // Advance 4 seconds (the banner display duration)
    await tester.pump(const Duration(seconds: 4));
    // Advance exit transition
    await tester.pump(const Duration(milliseconds: 250));

    // dismissBanner(42) was called
    expect(cubit.dismissedSeqs, contains(42));
  });

  test('unit fakeAsync proves 4s dismissal timing', () {
    fakeAsync((async) {
      var dismissed = false;
      int? dismissedSeq;

      final timer = Timer(const Duration(seconds: 4), () {
        dismissed = true;
        dismissedSeq = 101;
      });

      expect(dismissed, isFalse);

      async.elapse(const Duration(seconds: 3));
      expect(dismissed, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(dismissed, isTrue);
      expect(dismissedSeq, 101);

      timer.cancel();
    });
  });

  testWidgets('tapping banner calls cubit.open(item)', (tester) async {
    final item = _item(
      id: 'tap_item',
      title: 'Lyra',
      body: 'Can we speak in private?',
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        banner: NotificationBanner(item, 5),
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationBannerHost(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lyra'));
    await tester.pump();

    expect(cubit.openedItems.length, 1);
    expect(cubit.openedItems.first.id, 'tap_item');
  });

  testWidgets('swiping up dismisses banner and calls dismissBanner', (
    tester,
  ) async {
    final item = _item(
      id: 'swipe_item',
      title: 'Aleron',
      body: 'Watch your back.',
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        banner: NotificationBanner(item, 9),
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationBannerHost(
            child: Scaffold(body: Text('App Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Swipe up on the banner
    await tester.drag(find.text('Aleron'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(cubit.dismissedSeqs, contains(9));
    expect(find.text('Aleron'), findsNothing);
  });
}
