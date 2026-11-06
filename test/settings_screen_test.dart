import 'package:everlore/core/auth/group_notifications.dart';
import 'package:everlore/core/reminders/reminder_service.dart';
import 'package:everlore/screens/reminder_switch_row.dart';
import 'package:everlore/screens/settings_screen.dart';
import 'package:everlore/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:everlore/shared/widgets/settings_group.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReminders extends ReminderService {
  _FakeReminders(this.result);

  final ReminderToggleResult result;
  bool on = false;

  /// Whether the system lets reminders fire; defaults to allowing them.
  bool systemAllows = true;
  final calls = <bool>[];

  @override
  bool get enabled => on;

  @override
  Future<bool> isActive() async => on && systemAllows;

  @override
  Future<ReminderToggleResult> setEnabled(bool value) async {
    calls.add(value);
    if (result == ReminderToggleResult.on) on = true;
    if (result == ReminderToggleResult.off) on = false;
    return result;
  }
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ReminderSwitchRow', () {
    testWidgets('turns on when the service says on', (tester) async {
      final fake = _FakeReminders(ReminderToggleResult.on);
      await tester.pumpWidget(_host(ReminderSwitchRow(service: fake)));
      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(fake.calls, [true]);
      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isTrue);
    });

    testWidgets('stays off and explains when the system must allow it', (
      tester,
    ) async {
      final fake = _FakeReminders(ReminderToggleResult.needsSystemSettings);
      await tester.pumpWidget(_host(ReminderSwitchRow(service: fake)));

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isFalse);
      expect(
        find.text('Allow notifications for Everlore, then turn this on.'),
        findsOneWidget,
      );
      // Let the notice retire its timers.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('re-reads the service when the app resumes', (tester) async {
      final fake = _FakeReminders(ReminderToggleResult.off);
      await tester.pumpWidget(_host(ReminderSwitchRow(service: fake)));
      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isFalse);

      fake.on = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isTrue);

      // The player revokes the permission in the system settings and returns.
      fake.systemAllows = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isFalse);
    });

    testWidgets('draws off when enabled but the system denies', (
      tester,
    ) async {
      final fake = _FakeReminders(ReminderToggleResult.off)
        ..on = true
        ..systemAllows = false;
      await tester.pumpWidget(_host(ReminderSwitchRow(service: fake)));
      // First frame shows the stored flag; the real answer follows.
      await tester.pump();
      await tester.pump();

      expect(fake.enabled, isTrue);
      expect(tester.widget<SettingsSwitchRow>(find.byType(SettingsSwitchRow)).value,
          isFalse);
    });
  });

  group('SettingsScreen sections', () {
    const signedIn = User(
      id: 'u1',
      email: 'a@b.c',
      username: 'a',
      tier: 'free',
    );
    const guest = User(
      id: 'g1',
      email: '',
      username: 'g',
      tier: 'free',
      guest: true,
    );

    testWidgets('a signed-in user gets Account with Delete account', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            user: signedIn,
            reminders: _FakeReminders(ReminderToggleResult.off),
          ),
        ),
      );
      await tester.pump();
      for (final label in ['STORY', 'REMINDERS', 'PRIVACY']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('a guest gets no Account section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            user: guest,
            reminders: _FakeReminders(ReminderToggleResult.off),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Allow mature themes'), findsOneWidget);
      expect(find.text('Story reminders'), findsOneWidget);
      expect(find.text('Blocked content'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
    });
  });

  group('Messages from your stories', () {
    const signedIn = User(id: 'u1', email: 'a@b.c', username: 'a', tier: 'free');
    const guest = User(id: 'g1', email: '', username: 'g', tier: 'free', guest: true);

    Widget host(User user, GroupNotificationsPref pref, {bool allowed = true}) =>
        MaterialApp(
          home: SettingsScreen(
            user: user,
            reminders: _FakeReminders(ReminderToggleResult.off),
            messages: pref,
            systemAllowsMessages: () async => allowed,
          ),
        );

    bool switchOn(WidgetTester tester) => tester
        .widget<SettingsSwitchRow>(
          find.ancestor(
            of: find.text('Messages from your stories'),
            matching: find.byType(SettingsSwitchRow),
          ),
        )
        .value;

    Future<void> tapSwitch(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Messages from your stories'),
            matching: find.byType(SettingsSwitchRow),
          ),
          matching: find.byType(Switch),
        ),
      );
    }

    testWidgets('is hidden for a guest', (tester) async {
      await tester.pumpWidget(
        host(guest, GroupNotificationsPref(fetchAccount: () async => {}, store: (_) async {})),
      );
      await tester.pump();
      expect(find.text('Messages from your stories'), findsNothing);
    });

    testWidgets('reads absent as on', (tester) async {
      await tester.pumpWidget(
        host(signedIn, GroupNotificationsPref(fetchAccount: () async => {'preferences': {}}, store: (_) async {})),
      );
      await tester.pump();
      expect(switchOn(tester), isTrue);
    });

    testWidgets('reads an explicit false as off', (tester) async {
      await tester.pumpWidget(
        host(signedIn, GroupNotificationsPref(
          fetchAccount: () async => {'preferences': {'group_notifications': false}},
          store: (_) async {},
        )),
      );
      await tester.pumpAndSettle();
      expect(switchOn(tester), isFalse);
    });

    testWidgets('writes false, then true', (tester) async {
      final written = <bool>[];
      await tester.pumpWidget(
        host(signedIn, GroupNotificationsPref(
          fetchAccount: () async => {'preferences': {}},
          store: (v) async => written.add(v),
        )),
      );
      await tester.pump();
      await tapSwitch(tester);
      await tester.pumpAndSettle();
      expect(written, [false]);
      expect(switchOn(tester), isFalse);

      await tapSwitch(tester);
      await tester.pumpAndSettle();
      expect(written, [false, true]);
      expect(switchOn(tester), isTrue);
    });

    testWidgets('rolls back with a plain notice when the write fails', (tester) async {
      await tester.pumpWidget(
        host(signedIn, GroupNotificationsPref(
          fetchAccount: () async => {'preferences': {}},
          store: (_) async => throw Exception('offline'),
        )),
      );
      await tester.pump();
      await tapSwitch(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(switchOn(tester), isTrue);
      expect(find.text('Could not update that preference. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('stays as stored and shows the hint when the phone has it off', (tester) async {
      final written = <bool>[];
      await tester.pumpWidget(
        host(
          signedIn,
          GroupNotificationsPref(
            fetchAccount: () async => {'preferences': {'group_notifications': false}},
            store: (v) async => written.add(v),
          ),
          allowed: false,
        ),
      );
      await tester.pumpAndSettle();
      await tapSwitch(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(written, [true]);
      expect(switchOn(tester), isTrue);
      expect(find.text('Allow notifications for Everlore, then turn this on.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
