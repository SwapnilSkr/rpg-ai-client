import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/group_chat/data/group_create_repository.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/screens/create_group_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_editor_view.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_editor_card.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _person(
  String name,
  int age, {
  String portraitUrl = '',
}) => {
  'name': name,
  'role': 'The regular.',
  'appearance': '$age, lean, short bleached hair.',
  'persona': 'Fiercely competitive and blunt.',
  'identity_kind': 'human',
  'aliases': <String>[],
  'portrait_url': portraitUrl,
  'portrait_thumb_url': portraitUrl.isNotEmpty ? '$portraitUrl-t' : '',
  'first_texts': ['Ready to get schooled again?', 'Chalk up.', 'Beat my time.'],
  'statuses': {
    'morning': 'Stretching.',
    'afternoon': 'Chalked up.',
    'evening': 'Crushed it. Drinks?',
    'night': 'Sleep.',
  },
  'group': {
    'age': age,
    'talkativeness': 0.8,
    'speech': 'Short, punchy sentences.',
    'wants': 'To push the player.',
    'start_bond': 'rival',
    'intimacy': 'When it is just us, I am not about the games.',
    'voice': ['You almost had that crux!', 'See you at O Beco.', 'Another?'],
  },
};

Map<String, dynamic> _authoring({bool adult = true, String portraitUrl = ''}) =>
    {
      '_id': 'g1',
      'kind': 'group',
      'title': 'The Climbing Gym',
      'description': 'Four regulars share a bouldering gym.',
      'is_nsfw_capable': adult,
      'is_published': false,
      'visibility': 'private',
      'review_status': 'none',
      'image_thumb_url': 'https://cdn/cover-t.webp',
      'seed_prompt': 'You arrive at the gym.',
      'global_lore': 'Lisbon climbing is small.',
      'topics': ['Routes.', 'Gossip.'],
      'opening_lines': [
        {'name': 'Ines', 'text': 'Seriously, Tomas?'},
        {'name': 'Tomas', 'text': 'Think before you fling yourself.'},
      ],
      'seed_cast': [
        _person('Ines', 27, portraitUrl: portraitUrl),
        _person('Tomas', 33, portraitUrl: portraitUrl),
      ],
    };

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreateGroupScreen', () {
    setUp(() {
      GroupEditorView.resetSavedState();
    });
    testWidgets('the form shows 2 person cards and "Write my group"', (
      tester,
    ) async {
      final cubit = CreateGroupCubit();
      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Person 2'), findsOneWidget);
      expect(find.text('Write my group'), findsOneWidget);
      expect(find.text('Explicit talk allowed'), findsOneWidget);
      expect(find.text('Everyone in the group is an adult.'), findsOneWidget);
    });

    testWidgets(
      'the editor shows every section for a fixture draft, and an intimacy field only when adult',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final adultDraft = GroupDraft.fromAuthoring(_authoring(adult: true));
        final adultCubit = CreateGroupCubit(loadFn: (_) async => adultDraft);

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: adultCubit,
              child: const CreateGroupScreen(templateId: 'g1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top sections
        expect(find.text('The Climbing Gym'), findsWidgets);
        expect(find.text('About this group'), findsOneWidget);
        expect(find.text('The setting'), findsOneWidget);
        expect(find.text('How the chat goes'), findsOneWidget);
        expect(find.text('Topics'), findsOneWidget);
        expect(find.text('Opening conversation'), findsOneWidget);
        expect(find.text('PEOPLE (2)'), findsOneWidget);

        // Expand person Ines
        await tester.tap(find.text('Ines').last);
        await tester.pumpAndSettle();

        expect(find.text('When it gets intimate'), findsOneWidget);

        // Now test non-adult draft
        final nonAdultDraft = GroupDraft.fromAuthoring(
          _authoring(adult: false),
        );
        final nonAdultCubit = CreateGroupCubit(
          loadFn: (_) async => nonAdultDraft,
        );

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: nonAdultCubit,
              child: const CreateGroupScreen(
                key: ValueKey('non_adult'),
                templateId: 'g1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand person Ines in non-adult
        await tester.tap(find.text('Ines').last);
        await tester.pumpAndSettle();

        expect(find.text('When it gets intimate'), findsNothing);
      },
    );

    testWidgets('a fieldErrors entry shows under its field', (tester) async {
      final draft = GroupDraft.fromAuthoring(_authoring());
      final cubit = CreateGroupCubit(loadFn: (_) async => draft);

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(
            value: cubit,
            child: const CreateGroupScreen(templateId: 'g1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear the title and save to trigger field error
      cubit.setTitle('');
      await cubit.save();
      await tester.pumpAndSettle();

      expect(find.text('Add a title.'), findsOneWidget);
    });

    testWidgets('"Paint a face" calls the face function', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var faceCalls = 0;
      final draft = GroupDraft.fromAuthoring(_authoring(portraitUrl: ''));
      final cubit = CreateGroupCubit(
        loadFn: (_) async => draft,
        faceFn: (id, index, {repaint = false}) async {
          faceCalls++;
          return const GroupFaceResult(
            GroupFaceOutcome.ready,
            url: 'https://cdn/ines.webp',
          );
        },
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(
            value: cubit,
            child: const CreateGroupScreen(templateId: 'g1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand person Ines
      await tester.tap(find.text('Ines').last);
      await tester.pumpAndSettle();

      // Find "Paint a face" button
      final paintButton = find.text('Paint a face');
      expect(paintButton, findsOneWidget);

      await tester.tap(paintButton);
      await tester.pumpAndSettle();

      expect(faceCalls, 1);
    });

    testWidgets('Save is disabled while saving', (tester) async {
      final completer = Completer<void>();
      final draft = GroupDraft.fromAuthoring(_authoring());
      final cubit = CreateGroupCubit(
        loadFn: (_) async => draft,
        updateFn: (_, __) => completer.future,
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(
            value: cubit,
            child: const CreateGroupScreen(templateId: 'g1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit title to make it dirty
      cubit.setTitle('Updated Gym');
      await tester.pumpAndSettle();

      // Trigger save
      unawaited(cubit.save());
      await tester.pump();
      await tester.pump();

      // While saving is true: Save button shows CircularProgressIndicator and onPressed is null
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
      expect(
        saveButtonFinder,
        findsNothing,
      ); // replaced by progress indicator child

      final filledButtons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      final savingButton = filledButtons.first;
      expect(savingButton.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'button foreground colors: enabled Save is dark foreground; disabled Save and disabled Chat are disabled foreground',
      (tester) async {
        final draft = GroupDraft.fromAuthoring(_authoring());
        final cubit = CreateGroupCubit(
          loadFn: (_) async => draft,
          updateFn: (_, __) async {},
        );

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: cubit,
              child: const CreateGroupScreen(templateId: 'g1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial loaded state: not dirty, so Save is disabled, Chat is enabled
        final saveFinder = find.widgetWithText(FilledButton, 'Save');
        final chatFinder = find.widgetWithText(FilledButton, 'Chat');
        expect(saveFinder, findsOneWidget);
        expect(chatFinder, findsOneWidget);

        Color? getTextColor(Finder buttonFinder) {
          final richText = tester.widget<RichText>(
            find.descendant(of: buttonFinder, matching: find.byType(RichText)),
          );
          return richText.text.style?.color;
        }

        // Disabled Save renders disabled foreground
        expect(
          getTextColor(saveFinder),
          EverloreTheme.ash.withValues(alpha: 0.5),
        );
        // Enabled Chat renders parchment foreground
        expect(getTextColor(chatFinder), EverloreTheme.parchment);

        // 2. Make dirty -> Save is enabled, Chat is disabled
        cubit.setTitle('Updated Gym');
        await tester.pumpAndSettle();

        // Enabled Save renders dark foreground (void0), NOT light parchment
        expect(getTextColor(saveFinder), EverloreTheme.void0);
        expect(getTextColor(saveFinder), isNot(EverloreTheme.parchment));

        // Disabled Chat renders disabled foreground
        expect(
          getTextColor(chatFinder),
          EverloreTheme.ash.withValues(alpha: 0.4),
        );
      },
    );

    testWidgets(
      'emitting a state with new face URL keeps scroll offset and expanded card expanded',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final raw = _authoring(portraitUrl: '');
        final draft = GroupDraft.fromAuthoring(raw);
        final cubit = CreateGroupCubit(
          loadFn: (_) async => draft,
          updateFn: (_, __) async {},
        );

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: cubit,
              child: const CreateGroupScreen(templateId: 'g1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down to make person cards visible
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();

        // 1. Expand person 0 (Ines)
        final card0 = find.byType(GroupPersonEditorCard).first;
        await tester.tap(
          find.descendant(of: card0, matching: find.byType(InkWell)).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('When it gets intimate'), findsOneWidget);

        // 2. Scroll down further so offset is non-zero
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final recordedOffset = scrollable.position.pixels;
        expect(recordedOffset, greaterThan(200));

        // 3. Emit state with equal-content copy having a new face URL
        final updatedDraft = draft.withPerson(
          0,
          draft.cast[0].copyWith(
            portraitUrl: 'https://cdn/ines-new.webp',
            portraitThumbUrl: 'https://cdn/ines-new-t.webp',
          ),
        );
        cubit.emit(
          cubit.state.copyWith(
            draft: updatedDraft,
            faces: {0: const GroupFace(GroupFaceStatus.ready)},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify: Card 0 remains expanded
        expect(find.text('When it gets intimate'), findsOneWidget);

        // Verify: Scroll offset did not jump or move
        expect(scrollable.position.pixels, equals(recordedOffset));
      },
    );

    testWidgets(
      're-read via load keeps scroll offset and expanded card expanded',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final raw = _authoring(portraitUrl: '');
        final draft = GroupDraft.fromAuthoring(raw);
        final cubit = CreateGroupCubit(
          loadFn: (_) async => draft,
          updateFn: (_, __) async {},
        );

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(
              value: cubit,
              child: const CreateGroupScreen(templateId: 'g1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down to make person cards visible
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();

        // Expand person 0 (Ines)
        final card0 = find.byType(GroupPersonEditorCard).first;
        await tester.tap(
          find.descendant(of: card0, matching: find.byType(InkWell)).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('When it gets intimate'), findsOneWidget);

        // Scroll down further
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        final scrollableBefore = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offsetBefore = scrollableBefore.position.pixels;
        expect(offsetBefore, greaterThan(200));

        // Re-read draft (unmounts and remounts GroupEditorView via phase: loading -> editing)
        await cubit.load('g1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Card 0 remains expanded
        expect(find.text('When it gets intimate'), findsOneWidget);

        // Scroll offset is preserved
        final scrollableAfter = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollableAfter.position.pixels, equals(offsetBefore));
      },
    );
  });

  group('PublishWorldSheet strings', () {
    const template = WorldTemplate(
      id: 'w1',
      creatorId: 'c1',
      title: 'The Valley',
      slug: 'the-valley',
      description: 'A quiet valley.',
    );

    testWidgets('the publish sheet with noun: "world" shows today\'s strings', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PublishWorldSheet(template: template, noun: 'world')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who can enter this world?'), findsOneWidget);
      expect(
        find.text('Ready to play now. Only you will see it.'),
        findsOneWidget,
      );
      expect(find.text('For every traveller'), findsOneWidget);
      expect(
        find.text(
          'We read every shared world first, usually within a day. You can play it while you wait.',
        ),
        findsOneWidget,
      );

      expect(find.text('Who can join this group?'), findsNothing);
      expect(find.text('For everyone'), findsNothing);
    });

    testWidgets('the publish sheet with noun: "group" shows group strings', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PublishWorldSheet(
            template: template,
            noun: 'group',
            allowPublic: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who can join this group?'), findsOneWidget);
      expect(
        find.text('Ready to chat now. Only you will see it.'),
        findsOneWidget,
      );
      expect(find.text('For everyone'), findsOneWidget);
      expect(
        find.text(
          'We read every shared group first, usually within a day. You can chat in it while you wait.',
        ),
        findsOneWidget,
      );
      expect(find.text('Every person needs a face first.'), findsOneWidget);
    });
  });
}
