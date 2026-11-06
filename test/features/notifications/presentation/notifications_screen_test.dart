import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/notifications/notification_opener.dart';
import 'package:everlore/features/notifications/data/notifications_repository.dart';
import 'package:everlore/features/notifications/models/app_notification.dart';
import 'package:everlore/features/notifications/presentation/notifications_screen.dart';
import 'package:everlore/features/notifications/state/notifications_cubit.dart';
import 'package:everlore/features/notifications/state/notifications_state.dart';
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

  int loadCalls = 0;
  int loadMoreCalls = 0;
  int markAllReadCalls = 0;
  final openedItems = <AppNotification>[];

  void setState(NotificationsState next) => emit(next);

  @override
  Future<void> load() async {
    loadCalls++;
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
  }

  @override
  Future<OpenResult> open(AppNotification item) async {
    openedItems.add(item);
    return OpenResult.opened;
  }
}

AppNotification _item({
  required String id,
  required String title,
  required String body,
  required DateTime createdAt,
  DateTime? readAt,
  String type = 'group_direct',
}) => AppNotification(
  id: id,
  type: type,
  instanceId: 'inst_1',
  title: title,
  body: body,
  createdAt: createdAt,
  readAt: readAt,
);

void main() {
  testWidgets('screen shows the empty line when there are no notifications', (
    tester,
  ) async {
    final cubit = _TestNotificationsCubit(
      const NotificationsState(hasLoaded: true, items: []),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nothing has happened while you were away.'),
      findsOneWidget,
    );
    // No icon, no button on the empty state
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('screen groups Today/Earlier and shows unread dot only on unread row', (
    tester,
  ) async {
    final now = DateTime.now();
    final todayItem = _item(
      id: 'today_1',
      title: 'Jessie',
      body: 'See you at the tavern.',
      createdAt: now.subtract(const Duration(minutes: 5)),
      readAt: null, // unread
    );

    final earlierItem = _item(
      id: 'earlier_1',
      title: 'Kael',
      body: 'The gates are closing.',
      createdAt: now.subtract(const Duration(days: 2)),
      readAt: now.subtract(const Duration(days: 1)), // read
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        hasLoaded: true,
        unread: 1,
        items: [todayItem, earlierItem],
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Section headers
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);

    // Items
    expect(find.text('Jessie'), findsOneWidget);
    expect(find.text('See you at the tavern.'), findsOneWidget);
    expect(find.text('Kael'), findsOneWidget);
    expect(find.text('The gates are closing.'), findsOneWidget);

    // Exactly one unread dot for the todayItem (earlierItem is read)
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == EverloreTheme.gold &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
      findsOneWidget,
    );
  });

  testWidgets('screen shows Mark all read only with unread and tapping it calls markAllRead', (
    tester,
  ) async {
    final now = DateTime.now();
    final item = _item(
      id: 'item_1',
      title: 'Rowan',
      body: 'A messenger has arrived.',
      createdAt: now,
      readAt: null,
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        hasLoaded: true,
        unread: 1,
        items: [item],
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(cubit.markAllReadCalls, 1);

    // Now update state to hasUnread == false
    cubit.setState(
      NotificationsState(
        hasLoaded: true,
        unread: 0,
        items: [item.asRead(now)],
      ),
    );
    await tester.pumpAndSettle();

    // 'Mark all read' is gone
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('tapping row calls cubit.open(item)', (tester) async {
    final now = DateTime.now();
    final item = _item(
      id: 'open_test_1',
      title: 'Tavern Keeper',
      body: 'Your drink is ready.',
      createdAt: now,
    );

    final cubit = _TestNotificationsCubit(
      NotificationsState(
        hasLoaded: true,
        unread: 1,
        items: [item],
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tavern Keeper'));
    await tester.pump();

    expect(cubit.openedItems.length, 1);
    expect(cubit.openedItems.first.id, 'open_test_1');
  });

  testWidgets('error state shows plain line and quiet Try again which calls load', (
    tester,
  ) async {
    final cubit = _TestNotificationsCubit(
      const NotificationsState(
        hasLoaded: false,
        hasError: true,
        items: [],
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load notifications.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    final before = cubit.loadCalls;
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(cubit.loadCalls, greaterThan(before));
  });
}
