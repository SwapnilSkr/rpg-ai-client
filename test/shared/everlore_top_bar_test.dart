import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/billing/data/billing_repository.dart';
import 'package:everlore/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EverloreTopBar draws bell only when showNotifications is true', (
    tester,
  ) async {
    // 1. By default showNotifications is false: no bell rendered
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverloreTopBar(title: 'Test Bar'),
        ),
      ),
    );

    expect(find.byType(NotificationsBellButton), findsNothing);

    // 2. When showNotifications is true: bell is rendered
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EverloreTopBar(
            title: 'Test Bar',
            showNotifications: true,
          ),
        ),
      ),
    );

    expect(find.byType(NotificationsBellButton), findsOneWidget);
  });

  testWidgets(
    'EverloreTopBar layout order ends with search, bell, profile with 8dp gaps',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EverloreTopBar(
              title: 'Explore',
              subtitle: 'Find worlds and characters',
              showNotifications: true,
              actions: [
                EverloreTopBarIcon(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final searchFinder = find.byWidgetPredicate(
        (w) => w is EverloreTopBarIcon && w.icon == Icons.search_rounded,
      );
      final bellFinder = find.byType(NotificationsBellButton);
      final profileFinder = find.byWidgetPredicate(
        (w) => w is EverloreTopBarIcon && w.icon == Icons.person_outline_rounded,
      );

      expect(searchFinder, findsOneWidget);
      expect(bellFinder, findsOneWidget);
      expect(profileFinder, findsOneWidget);

      final searchRect = tester.getRect(searchFinder);
      final bellRect = tester.getRect(bellFinder);
      final profileRect = tester.getRect(profileFinder);

      // Verify horizontal order: search < bell < profile
      expect(searchRect.right, lessThan(bellRect.left));
      expect(bellRect.right, lessThan(profileRect.left));

      // Verify 8dp gap between search and bell
      expect(bellRect.left - searchRect.right, equals(8.0));

      // Verify 8dp gap between bell and profile
      expect(profileRect.left - bellRect.right, equals(8.0));

      // Verify sizes of the round controls are 40x40
      expect(searchRect.size, equals(const Size(40, 40)));
      expect(bellRect.size, equals(const Size(40, 40)));
      expect(profileRect.size, equals(const Size(40, 40)));
    },
  );

  testWidgets(
    'EverloreTopBar works at 360dp wide with text scale 1.3 without overflow',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: EverloreTopBar(
                title: 'Explore Worlds',
                subtitle: 'Find worlds and characters across the realm',
                showNotifications: true,
                actions: [
                  EverloreTopBarIcon(
                    icon: Icons.search_rounded,
                    tooltip: 'Search',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final overflowErrors = errors.where(
        (e) => e.toString().contains('overflowed'),
      );
      expect(overflowErrors, isEmpty);
    },
  );
}
