import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/settings_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        backgroundColor: EverloreTheme.void1,
        body: Center(child: child),
      ),
    );

void main() {
  group('SettingsGroup', () {
    testWidgets('dividers count = children − 1', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsGroup(
            children: [
              Text('Row 1'),
              Text('Row 2'),
              Text('Row 3'),
            ],
          ),
        ),
      );

      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(SettingsGroup),
          matching: find.byType(Column),
        ),
      );

      // 3 children + 2 dividers = 5 elements in the column
      expect(column.children.length, 5);

      final dividers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxHeight == 1 &&
            w.margin == const EdgeInsets.only(left: 56),
      );
      expect(dividers, findsNWidgets(2));
    });

    testWidgets('single child has 0 dividers', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsGroup(
            children: [
              Text('Only Row'),
            ],
          ),
        ),
      );

      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(SettingsGroup),
          matching: find.byType(Column),
        ),
      );
      expect(column.children.length, 1);

      final dividers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxHeight == 1 &&
            w.margin == const EdgeInsets.only(left: 56),
      );
      expect(dividers, findsNothing);
    });
  });

  group('SettingsSwitchRow', () {
    testWidgets('a tap on a switch row’s title calls onChanged(!value)', (
      tester,
    ) async {
      bool? nextVal;

      await tester.pumpWidget(
        _host(
          SettingsSwitchRow(
            icon: Icons.local_fire_department_outlined,
            title: 'Allow mature themes',
            subtitle: 'Needed before a world with mature themes will open.',
            value: false,
            onChanged: (v) => nextVal = v,
          ),
        ),
      );

      await tester.tap(find.text('Allow mature themes'));
      await tester.pump();

      expect(nextVal, isTrue);
    });

    testWidgets('a tap on an active switch row with value=true calls onChanged(false)', (
      tester,
    ) async {
      bool? nextVal;

      await tester.pumpWidget(
        _host(
          SettingsSwitchRow(
            icon: Icons.notifications_none_rounded,
            title: 'Story reminders',
            subtitle: 'A gentle nudge when a story is waiting.',
            value: true,
            onChanged: (v) => nextVal = v,
          ),
        ),
      );

      await tester.tap(find.text('Story reminders'));
      await tester.pump();

      expect(nextVal, isFalse);
    });

    testWidgets('a disabled (busy) row does not call onChanged', (
      tester,
    ) async {
      bool called = false;

      await tester.pumpWidget(
        _host(
          SettingsSwitchRow(
            icon: Icons.insights_outlined,
            title: 'Share usage and crash reports',
            subtitle:
                'Helps us find and fix problems. Never includes what you write.',
            value: false,
            busy: true,
            onChanged: (_) => called = true,
          ),
        ),
      );

      await tester.tap(find.text('Share usage and crash reports'));
      await tester.pump();

      expect(called, isFalse);

      final opacity = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0.5,
      );
      expect(opacity, findsOneWidget);
    });
  });

  group('SettingsNavRow', () {
    testWidgets('renders icon, label, detail and chevron by default', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        _host(
          SettingsNavRow(
            icon: Icons.public_rounded,
            label: 'Your worlds',
            detail: '3 active',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Your worlds'), findsOneWidget);
      expect(find.text('3 active'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.text('Your worlds'));
      expect(tapped, isTrue);
    });

    testWidgets('tone overrides color and hides chevron', (tester) async {
      await tester.pumpWidget(
        _host(
          const SettingsNavRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete account',
            tone: EverloreTheme.crimson,
          ),
        ),
      );

      expect(find.text('Delete account'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('SettingsSectionLabel', () {
    testWidgets('uppercases text and sets top margin according to isFirst', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              SettingsSectionLabel('story', isFirst: true),
              SettingsSectionLabel('privacy', isFirst: false),
            ],
          ),
        ),
      );

      expect(find.text('STORY'), findsOneWidget);
      expect(find.text('PRIVACY'), findsOneWidget);

      final padding1 = tester.widget<Padding>(
        find.ancestor(
          of: find.text('STORY'),
          matching: find.byType(Padding),
        ),
      );
      expect(padding1.padding, const EdgeInsets.fromLTRB(4, 8, 0, 10));

      final padding2 = tester.widget<Padding>(
        find.ancestor(
          of: find.text('PRIVACY'),
          matching: find.byType(Padding),
        ),
      );
      expect(padding2.padding, const EdgeInsets.fromLTRB(4, 28, 0, 10));
    });
  });
}
