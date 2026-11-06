import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/notifications/data/notifications_repository.dart';
import 'package:everlore/features/notifications/models/app_notification.dart';
import 'package:everlore/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:everlore/features/notifications/state/notifications_cubit.dart';
import 'package:everlore/features/notifications/state/notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  void setState(NotificationsState next) => emit(next);
}

void main() {
  testWidgets('NotificationsBellButton renders bell and dot shows only with unread', (
    tester,
  ) async {
    final cubit = _TestNotificationsCubit(
      const NotificationsState(unread: 0),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<NotificationsCubit>.value(
            value: cubit,
            child: const NotificationsBellButton(),
          ),
        ),
      ),
    );

    // Bell icon is present
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

    // With 0 unread: no gold dot badge is rendered
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == EverloreTheme.gold &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
      findsNothing,
    );

    // Update state to have unread notifications
    cubit.setState(const NotificationsState(unread: 2));
    await tester.pumpAndSettle();

    // With unread > 0: gold dot badge is rendered
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

    // Update state back to 0 unread: dot disappears
    cubit.setState(const NotificationsState(unread: 0));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == EverloreTheme.gold &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
      findsNothing,
    );
  });

  testWidgets('tapping NotificationsBellButton navigates to /notifications', (
    tester,
  ) async {
    final cubit = _TestNotificationsCubit(
      const NotificationsState(unread: 1),
    );
    addTearDown(cubit.close);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: BlocProvider<NotificationsCubit>.value(
              value: cubit,
              child: const NotificationsBellButton(),
            ),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, _) => const Scaffold(
            body: Text('Notifications Destination'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );

    await tester.tap(find.byType(NotificationsBellButton));
    await tester.pumpAndSettle();

    expect(find.text('Notifications Destination'), findsOneWidget);
  });

  testWidgets(
    'NotificationsBellButton renders quiet bell gracefully without cubit in context',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationsBellButton(),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == EverloreTheme.gold &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNothing,
      );
    },
  );
}
