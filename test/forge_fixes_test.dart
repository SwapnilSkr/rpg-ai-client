import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/features/creator/data/creator_repository.dart';
import 'package:everlore/features/creator/presentation/forge_world_screen.dart';
import 'package:everlore/features/creator/state/forge_world_cubit.dart';
import 'package:everlore/features/creator/state/my_worlds_cubit.dart';
import 'package:everlore/shared/models/world_template.dart';

void main() {
  group('1. Preset descriptions', () {
    test('every preset has a non-empty description in house voice', () {
      expect(ForgePresets.stats, isNotEmpty);
      expect(ForgePresets.stats.length, 6);

      final expected = {
        'health': 'How much harm you can take before you fall.',
        'mana': 'The magic you can still draw on.',
        'sanity': 'How firmly your mind holds together.',
        'honour': 'How others judge your word and deeds.',
        'gold': 'The coin you carry.',
        'strength': 'Your raw physical might.',
      };

      for (final preset in ForgePresets.stats) {
        expect(
          preset.description.trim(),
          isNotEmpty,
          reason: '${preset.key} must have a non-empty description',
        );
        expect(
          preset.description,
          equals(expected[preset.key]),
          reason:
              'preset ${preset.key} description must match house voice requirement',
        );

        // No mechanics words
        final lower = preset.description.toLowerCase();
        expect(lower.contains('stat'), isFalse);
        expect(lower.contains('value'), isFalse);
        expect(lower.contains('tracked'), isFalse);

        // Conversion to StatEntry preserves all fields
        final entry = preset.toEntry();
        expect(entry.name, preset.key);
        expect(entry.defaultValue, preset.defaultValue);
        expect(entry.min, preset.min);
        expect(entry.max, preset.max);
        expect(entry.description, preset.description);
      }
    });
  });

  group('2. StatEditorSheet description validation', () {
    testWidgets('save is disabled with empty description and enabled with text', (
      tester,
    ) async {
      StatEntry? saved;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatEditorSheet(onSave: (entry) => saved = entry),
          ),
        ),
      );

      // Verify label has required marker and no "Optional" hint
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Optional'), findsNothing);

      // Initial state: description is empty, so save button ("Add Force") is disabled
      final addButtonFinder = find.widgetWithText(ElevatedButton, 'Add Force');
      expect(addButtonFinder, findsOneWidget);
      ElevatedButton btn = tester.widget<ElevatedButton>(addButtonFinder);
      expect(
        btn.onPressed,
        isNull,
        reason: 'Save button must be disabled when description is empty',
      );

      // Type a name first
      final nameField = find.widgetWithText(
        TextField,
        'health, mana, honour...',
      );
      await tester.enterText(nameField, 'stamina');
      await tester.pump();

      btn = tester.widget<ElevatedButton>(addButtonFinder);
      expect(
        btn.onPressed,
        isNull,
        reason: 'Button must remain disabled while description is still empty',
      );

      // Enter description
      final descField = find.widgetWithText(
        TextField,
        'e.g. The life force of the adventurer',
      );
      await tester.enterText(
        descField,
        '  How long you can run without tiring.  ',
      );
      await tester.pump();

      btn = tester.widget<ElevatedButton>(addButtonFinder);
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Button must be enabled when description has text',
      );

      // Clear description -> button becomes disabled again
      await tester.enterText(descField, '   ');
      await tester.pump();

      btn = tester.widget<ElevatedButton>(addButtonFinder);
      expect(
        btn.onPressed,
        isNull,
        reason: 'Button must be disabled when description is only whitespace',
      );

      // Re-enter description
      await tester.enterText(
        descField,
        '  How long you can run without tiring.  ',
      );
      await tester.pump();

      btn = tester.widget<ElevatedButton>(addButtonFinder);
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Button must be re-enabled when description has text',
      );

      // Tap save
      await tester.tap(addButtonFinder);
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.name, 'stamina');
      expect(saved!.description, 'How long you can run without tiring.');
    });

    testWidgets(
      'editing existing stat disables Update Force when description is cleared',
      (tester) async {
        const initialStat = StatEntry(
          name: 'mana',
          defaultValue: 100,
          min: 0,
          max: 100,
          description: 'The magic you can still draw on.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatEditorSheet(existing: initialStat, onSave: (_) {}),
            ),
          ),
        );

        final updateButtonFinder = find.widgetWithText(
          ElevatedButton,
          'Update Force',
        );
        expect(updateButtonFinder, findsOneWidget);
        ElevatedButton btn = tester.widget<ElevatedButton>(updateButtonFinder);
        expect(
          btn.onPressed,
          isNotNull,
          reason: 'Update Force enabled initially with existing description',
        );

        // Clear description
        final descField = find.widgetWithText(
          TextField,
          'The magic you can still draw on.',
        );
        await tester.enterText(descField, '');
        await tester.pump();

        btn = tester.widget<ElevatedButton>(updateButtonFinder);
        expect(
          btn.onPressed,
          isNull,
          reason: 'Update Force must be disabled when description is cleared',
        );
      },
    );
  });

  group('3. Step 3 Continue gating and inline hint', () {
    test(
      'Continue is blocked on Vital Forces step when any stat has no description',
      () {
        final cubit = ForgeWorldCubit(
          initialState: const ForgeWorldState(
            title: 'The Ashen Vale',
            description: 'A grim valley forgotten by the stars.',
            seedPrompt: 'A wanderer seeks redemption across the ash.',
            globalLore: 'The ash fell ten centuries ago and never melted.',
            step: 3,
          ),
        );

        // No stats yet
        expect(cubit.state.step3Valid, isFalse);
        expect(cubit.state.canProceed, isFalse);

        // Add a stat with empty description
        cubit.addStat(
          const StatEntry(
            name: 'health',
            defaultValue: 100,
            min: 0,
            max: 100,
            description: '',
          ),
        );

        expect(cubit.state.step3Valid, isFalse);
        expect(cubit.state.canProceed, isFalse);

        // Attempting to advance does not move step
        cubit.nextStep();
        expect(cubit.state.step, 3);

        // Calling forge() directly is guarded against missing description
        cubit.forge();
        expect(cubit.state.error, 'Each Vital Force needs a description.');

        // Update stat with description
        cubit.updateStat(
          0,
          const StatEntry(
            name: 'health',
            defaultValue: 100,
            min: 0,
            max: 100,
            description: 'How much harm you can take before you fall.',
          ),
        );

        expect(cubit.state.step3Valid, isTrue);
        expect(cubit.state.canProceed, isTrue);

        // Advance step to step 4
        cubit.nextStep();
        expect(cubit.state.step, 4);
      },
    );

    testWidgets(
      'StatCard shows "Add a description" quiet inline hint when description is empty',
      (tester) async {
        final cubit = ForgeWorldCubit();
        addTearDown(cubit.close);

        // Card with empty description
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatCard(
                entry: const StatEntry(
                  name: 'health',
                  defaultValue: 100,
                  min: 0,
                  max: 100,
                  description: '',
                ),
                index: 0,
                cubit: cubit,
              ),
            ),
          ),
        );

        expect(find.text('Add a description'), findsOneWidget);

        // Card with non-empty description
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatCard(
                entry: const StatEntry(
                  name: 'health',
                  defaultValue: 100,
                  min: 0,
                  max: 100,
                  description: 'How much harm you can take before you fall.',
                ),
                index: 0,
                cubit: cubit,
              ),
            ),
          ),
        );

        expect(find.text('Add a description'), findsNothing);
        expect(
          find.text('How much harm you can take before you fall.'),
          findsOneWidget,
        );
      },
    );
  });

  group('4. MyWorldsCubit auto-refresh and loop prevention', () {
    test(
      'cubit reloads when repository signals change, preserving search',
      () async {
        int loadCount = 0;
        String? lastSearch;

        final cubit = MyWorldsCubit(
          fetchPage:
              ({int page = 1, int limit = 20, String search = ''}) async {
                loadCount++;
                lastSearch = search;
                return const CreatorWorldPage(worlds: [], total: 0, page: 1);
              },
        );
        addTearDown(cubit.close);

        // Initial load with search
        await cubit.load(search: 'dungeon');
        expect(loadCount, 1);
        expect(lastSearch, 'dungeon');

        // Repository signals change
        CreatorRepository.invalidate();
        await Future<void>.delayed(Duration.zero);

        expect(loadCount, 2);
        expect(
          lastSearch,
          'dungeon',
          reason: 'Reload must keep the active search string',
        );
      },
    );

    test('cubit does not loop on its own publish', () async {
      int fetchCount = 0;
      int publishCallCount = 0;

      final cubit = MyWorldsCubit(
        fetchPage: ({int page = 1, int limit = 20, String search = ''}) async {
          fetchCount++;
          return CreatorWorldPage(
            worlds: [
              WorldTemplate.fromJson({
                'id': 'world-1',
                'title': 'Kingdom of Dusk',
                'description': 'A fading realm.',
                'is_published': true,
              }),
            ],
            total: 1,
            page: 1,
          );
        },
        publishFn: (id, {visibility}) async {
          publishCallCount++;
          // Simulate real repository behavior where publish() calls invalidate()
          CreatorRepository.invalidate();
          return {'id': id, 'is_published': true};
        },
      );
      addTearDown(cubit.close);

      // Initial load
      await cubit.load();
      expect(fetchCount, 1);

      // Execute publish
      final success = await cubit.publish('world-1', visibility: 'public');
      expect(success, isTrue);
      expect(publishCallCount, 1);

      // Fetch count should be 2: initial load + intentional reload inside publish().
      // It must NOT be 3 or loop indefinitely from the invalidate() signal.
      expect(fetchCount, 2);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fetchCount, 2);
    });

    test('cubit does not loop on its own delete', () async {
      int fetchCount = 0;
      int deleteCallCount = 0;

      final cubit = MyWorldsCubit(
        fetchPage: ({int page = 1, int limit = 20, String search = ''}) async {
          fetchCount++;
          return CreatorWorldPage(
            worlds: [
              WorldTemplate.fromJson({
                'id': 'world-1',
                'title': 'Kingdom of Dusk',
                'description': 'A fading realm.',
                'is_published': false,
              }),
            ],
            total: 1,
            page: 1,
          );
        },
        deleteFn: (id) async {
          deleteCallCount++;
          // Simulate real repository behavior where delete() calls invalidate()
          CreatorRepository.invalidate();
        },
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(fetchCount, 1);
      expect(cubit.state.worlds.length, 1);

      final success = await cubit.delete('world-1');
      expect(success, isTrue);
      expect(deleteCallCount, 1);
      expect(cubit.state.worlds, isEmpty);

      // No second reload should have been triggered
      expect(fetchCount, 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fetchCount, 1);
    });

    test('cancels repository subscription on close()', () async {
      int fetchCount = 0;

      final cubit = MyWorldsCubit(
        fetchPage: ({int page = 1, int limit = 20, String search = ''}) async {
          fetchCount++;
          return const CreatorWorldPage(worlds: [], total: 0, page: 1);
        },
      );

      await cubit.load();
      expect(fetchCount, 1);

      await cubit.close();

      // Trigger change signal after cubit is closed
      CreatorRepository.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(
        fetchCount,
        1,
        reason: 'Closed cubit must not react to repository changes',
      );
    });
  });
}
