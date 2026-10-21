import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/features/creator/presentation/create_character_screen.dart';
import 'package:everlore/features/creator/state/create_character_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. CreateCharacterState.hasUnsavedWork', () {
    test('is false when state is pristine/empty', () {
      const state = CreateCharacterState();
      expect(state.hasUnsavedWork, isFalse);
    });

    test('is true after typing a name', () {
      const state = CreateCharacterState(name: 'Mira');
      expect(state.hasUnsavedWork, isTrue);
    });

    test('is false when name contains only whitespace', () {
      const state = CreateCharacterState(name: '   ');
      expect(state.hasUnsavedWork, isFalse);
    });

    test('is true when any single content field is non-empty', () {
      expect(const CreateCharacterState(tagline: 'A wandering knight').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(persona: 'Brave, sharp, but secretive').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(greeting: 'Who walks in the dark?').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(backstory: 'Born beneath the iron crown').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(narrativeStyle: 'gritty').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(styleNotes: 'Speak tersely').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(imagePrompt: 'A hooded rogue with silver eyes').hasUnsavedWork, isTrue);
      expect(const CreateCharacterState(imageUrl: 'https://cdn.everlore.com/portraits/p1.png').hasUnsavedWork, isTrue);
    });

    test('is false while submitting even with full fields', () {
      const state = CreateCharacterState(
        name: 'Mira',
        tagline: 'A wandering knight',
        persona: 'Brave, sharp, but secretive',
        isSubmitting: true,
      );
      expect(state.hasUnsavedWork, isFalse);
    });

    test('is false once character has been created (instanceId is set)', () {
      const state = CreateCharacterState(
        name: 'Mira',
        tagline: 'A wandering knight',
        persona: 'Brave, sharp, but secretive',
        instanceId: 'inst_abc123',
      );
      expect(state.hasUnsavedWork, isFalse);
    });
  });

  group('2. Create Character Leave Guard & Dialog UI', () {
    Widget buildApp({required GoRouter router}) {
      return MaterialApp.router(
        routerConfig: router,
      );
    }

    testWidgets('back on step 0 with no unsaved work leaves immediately without dialog', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/create-character'),
                  child: const Text('Open Creator'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/create-character',
            builder: (context, state) => const CreateCharacterScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(buildApp(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Creator'));
      await tester.pumpAndSettle();
      expect(find.text('NEW CHARACTER'), findsOneWidget);

      // Tap header back arrow with empty fields
      final backArrowFinder = find.byIcon(Icons.arrow_back_ios_new);
      expect(backArrowFinder, findsOneWidget);
      await tester.tap(backArrowFinder);
      await tester.pumpAndSettle();

      // Leaves directly back to home, no dialog shown
      expect(find.text('Leave this character unfinished?'), findsNothing);
      expect(find.text('Open Creator'), findsOneWidget);
      expect(find.text('NEW CHARACTER'), findsNothing);
    });

    testWidgets('back on step 0 with a name shows the dialog; cancel stays; confirm leaves', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/create-character'),
                  child: const Text('Open Creator'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/create-character',
            builder: (context, state) => const CreateCharacterScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(buildApp(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Creator'));
      await tester.pumpAndSettle();
      expect(find.text('NEW CHARACTER'), findsOneWidget);

      // Type a character name into the Name field
      final nameField = find.widgetWithText(TextField, 'e.g. Mira, Captain Vale, Aria…');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Mira');
      await tester.pump();

      // Tap header back
      final backArrowFinder = find.byIcon(Icons.arrow_back_ios_new);
      await tester.tap(backArrowFinder);
      await tester.pumpAndSettle();

      // Dialog is shown with exact copy and actions
      expect(find.text('Leave this character unfinished?'), findsOneWidget);
      expect(
        find.text('Nothing you have written here has been saved yet. Leaving now discards it.'),
        findsOneWidget,
      );
      expect(find.text('Keep forging'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Cancel ("Keep forging") -> stays on character creation screen
      await tester.tap(find.text('Keep forging'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsNothing);
      expect(find.text('NEW CHARACTER'), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);

      // Tap header back again
      await tester.tap(backArrowFinder);
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsOneWidget);

      // Confirm ("Discard") -> leaves the screen
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsNothing);
      expect(find.text('Open Creator'), findsOneWidget);
      expect(find.text('NEW CHARACTER'), findsNothing);
    });

    testWidgets('system back gesture on step 0 with unsaved work shows dialog', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/create-character'),
                  child: const Text('Open Creator'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/create-character',
            builder: (context, state) => const CreateCharacterScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(buildApp(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Creator'));
      await tester.pumpAndSettle();

      // Enter a tagline
      final taglineField = find.widgetWithText(
        TextField,
        'A short line — who are they at a glance?',
      );
      await tester.enterText(taglineField, 'A lone scout');
      await tester.pump();

      // Trigger system back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Keep forging'));
      await tester.pumpAndSettle();
      expect(find.text('NEW CHARACTER'), findsOneWidget);

      // Trigger system back again and discard
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave this character unfinished?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open Creator'), findsOneWidget);
    });

    testWidgets('back on step 1 goes back one step without dialog', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push('/create-character'),
                  child: const Text('Open Creator'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/create-character',
            builder: (context, state) => const CreateCharacterScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(buildApp(router: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Creator'));
      await tester.pumpAndSettle();

      // Fill in required fields to advance to step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Mira, Captain Vale, Aria…'),
        'Mira',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'A short line — who are they at a glance?'),
        'A brave pathfinder',
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'How do they think, talk, and treat you? Their mood, quirks, and relationship to you.',
        ),
        'Loyal, sharp-witted, and quiet under pressure.',
      );
      await tester.pump();

      // Advance to step 1 (Voice & Story)
      final continueFinder = find.text('Continue');
      expect(continueFinder, findsOneWidget);
      await tester.tap(continueFinder);
      await tester.pumpAndSettle();

      expect(find.text('VOICE & STORY'), findsOneWidget);

      // Header back on step 1: must go back to step 0 without showing dialog
      final backArrowFinder = find.byIcon(Icons.arrow_back_ios_new);
      await tester.tap(backArrowFinder);
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsNothing);
      expect(find.text('WHO THEY ARE'), findsOneWidget);

      // Advance again to step 1
      await tester.tap(continueFinder);
      await tester.pumpAndSettle();
      expect(find.text('VOICE & STORY'), findsOneWidget);

      // System back on step 1: must go back to step 0 without showing dialog
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Leave this character unfinished?'), findsNothing);
      expect(find.text('WHO THEY ARE'), findsOneWidget);
    });

    test('dialog copy adheres to rules (no AI, vendor names, or mechanics words)', () {
      const title = 'Leave this character unfinished?';
      const body = 'Nothing you have written here has been saved yet. Leaving now discards it.';
      const keep = 'Keep forging';
      const discard = 'Discard';

      final combined = '$title $body $keep $discard'.toLowerCase();
      expect(combined.contains('ai'), isFalse);
      expect(combined.contains('model'), isFalse);
      expect(combined.contains('vendor'), isFalse);
      expect(combined.contains('stat'), isFalse);
      expect(combined.contains('flag'), isFalse);
      expect(combined.contains('disposition'), isFalse);
    });
  });
}
