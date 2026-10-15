import 'package:everlore/features/billing/data/billing_repository.dart';
import 'package:everlore/features/play/presentation/widgets/the_ink_rests_dialog.dart';
import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingWallet.fromJson unlimited ink parsing', () {
    test('parses unlimited_ink: true as unlimitedInk = true', () {
      final wallet = BillingWallet.fromJson({
        'tier': 'free',
        'balance': 0,
        'unlimited_ink': true,
        'profile': {
          'monthly_ink': 0,
          'daily_story_safety_cap': 40,
        },
      });
      expect(wallet.unlimitedInk, isTrue);
    });

    test('parses unlimited_ink: false as unlimitedInk = false', () {
      final wallet = BillingWallet.fromJson({
        'tier': 'free',
        'balance': 100,
        'unlimited_ink': false,
        'profile': {
          'monthly_ink': 100,
          'daily_story_safety_cap': 40,
        },
      });
      expect(wallet.unlimitedInk, isFalse);
    });

    test('defaults unlimitedInk = false when unlimited_ink is omitted', () {
      final wallet = BillingWallet.fromJson({
        'tier': 'creator',
        'balance': 500,
        'profile': {
          'monthly_ink': 500,
          'daily_story_safety_cap': 100,
        },
      });
      expect(wallet.unlimitedInk, isFalse);
    });
  });

  group('EverloreInkBalanceChip widget tests', () {
    testWidgets('renders infinity icon and semantics label when unlimitedInk', (
      tester,
    ) async {
      const wallet = BillingWallet(
        tier: 'free',
        balance: 0,
        monthlyInk: 0,
        dailyStorySafetyCap: 40,
        purchasesEnabled: false,
        simulationEnabled: false,
        unlimitedInk: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EverloreInkBalanceChip(previewWallet: wallet),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
      expect(find.bySemanticsLabel('Unlimited Story Ink'), findsOneWidget);
    });

    testWidgets('renders compact number and semantics label when not unlimited', (
      tester,
    ) async {
      const wallet = BillingWallet(
        tier: 'free',
        balance: 150,
        monthlyInk: 100,
        dailyStorySafetyCap: 40,
        purchasesEnabled: true,
        simulationEnabled: false,
        unlimitedInk: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EverloreInkBalanceChip(previewWallet: wallet),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.all_inclusive), findsNothing);
      expect(find.text('150'), findsOneWidget);
      expect(find.bySemanticsLabel('150 Story Ink'), findsOneWidget);
    });
  });

  group('TheInkRestsDialog widget tests', () {
    testWidgets('renders copy, local time line and fires callback', (
      tester,
    ) async {
      bool backPressed = false;
      // Use fixed local timestamp
      final now = DateTime(2026, 10, 15, 14, 30);
      final isoString = now.toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: TheInkRestsDialog(
            resetsAt: isoString,
            onBackToWorlds: () {
              backPressed = true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('The Ink Rests'), findsOneWidget);
      expect(
        find.text(
          "Your story has run long today, and the quill needs a moment. Everything you've written is kept exactly where you left it.",
        ),
        findsOneWidget,
      );

      // Verify the formatted time line appears
      expect(find.textContaining('Your tale continues at'), findsOneWidget);

      // Tap Back to my worlds button
      await tester.tap(find.text('Back to my worlds'));
      expect(backPressed, isTrue);
    });

    testWidgets('omits time line when resetsAt is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TheInkRestsDialog(
            resetsAt: null,
            onBackToWorlds: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('The Ink Rests'), findsOneWidget);
      expect(find.textContaining('Your tale continues at'), findsNothing);
    });

    testWidgets('omits time line when resetsAt is empty or unparseable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TheInkRestsDialog(
            resetsAt: 'not-a-valid-timestamp',
            onBackToWorlds: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('The Ink Rests'), findsOneWidget);
      expect(find.textContaining('Your tale continues at'), findsNothing);
    });
  });
}
