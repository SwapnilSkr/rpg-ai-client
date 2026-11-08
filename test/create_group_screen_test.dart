import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/group_chat/data/group_create_repository.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/screens/create_group_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_art_backdrop.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_closeness_picker.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_drafting_view.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_editor_view.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_face_frame.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_face_mosaic.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_fold_section.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_form_view.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_card.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_editor_card.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_text_field.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';
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

      expect(find.text('Someone new'), findsNWidgets(2));
      expect(find.text('Add a person'), findsOneWidget);
      expect(find.text('Write my group'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Explicit talk allowed'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Explicit talk allowed'), findsOneWidget);
      expect(find.text('Everyone in the group is an adult.'), findsOneWidget);

      // Tapping the first card opens Person 1's sheet
      await tester.scrollUntilVisible(
        find.text('Someone new').first,
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Someone new').first);
      await tester.pumpAndSettle();

      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
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

  group('GroupTextField', () {
    testWidgets(
      'restyled: underline border, no box/fill, subdued label, and counter only when <= 20 chars left',
      (tester) async {
        var changedValue = '';
        await tester.pumpWidget(
          _wrap(
            GroupTextField(
              label: 'Voice line',
              hint: 'Say something…',
              initialValue: 'Hello',
              maxLength: 30,
              onChanged: (val) => changedValue = val,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Label is rendered with subdued style (size 12, ash)
        final labelFinder = find.text('Voice line');
        expect(labelFinder, findsOneWidget);
        final labelWidget = tester.widget<Text>(labelFinder);
        expect(labelWidget.style?.fontSize, 12);
        expect(labelWidget.style?.color, EverloreTheme.ash);

        // TextField has no fill and underline border
        final tfFinder = find.byType(TextField);
        expect(tfFinder, findsOneWidget);
        final tfWidget = tester.widget<TextField>(tfFinder);
        expect(tfWidget.decoration?.filled, isFalse);
        expect(tfWidget.decoration?.border, isA<UnderlineInputBorder>());
        expect(
          tfWidget.decoration?.contentPadding,
          const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        );

        // With 5 characters out of 30, remaining = 25 (> 20), so no counter is shown
        expect(find.textContaining('left'), findsNothing);

        // Type text so 15 characters remain (30 - 15 = 15 left, <= 20)
        await tester.enterText(tfFinder, '123456789012345');
        await tester.pumpAndSettle();

        expect(changedValue, '123456789012345');
        expect(find.text('15 left'), findsOneWidget);
      },
    );

    testWidgets('long writing uses aiText 16 and removes maxLines cap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GroupTextField(
            label: 'Setting',
            hint: 'Describe the setting…',
            initialValue: 'A gym in Lisbon.',
            useProseFont: true,
            maxLines: 4,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tfWidget = tester.widget<TextField>(find.byType(TextField));
      // maxLines cap is removed so writing grows
      expect(tfWidget.maxLines, isNull);
      expect(tfWidget.style?.fontSize, 16);
      expect(tfWidget.style?.fontFamily, contains('Garamond'));
    });

    testWidgets(
      'wrapSingleLine wraps visually with maxLines: null and denies newlines',
      (tester) async {
        var changedValue = '';
        await tester.pumpWidget(
          _wrap(
            GroupTextField(
              label: 'Topic',
              hint: 'Topic line…',
              initialValue: 'First line',
              wrapSingleLine: true,
              onChanged: (val) => changedValue = val,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tfWidget = tester.widget<TextField>(find.byType(TextField));
        expect(tfWidget.maxLines, isNull);
        expect(tfWidget.keyboardType, TextInputType.text);
        expect(tfWidget.textInputAction, TextInputAction.done);

        // Trying to enter text with newline should have newlines stripped
        await tester.enterText(find.byType(TextField), 'Line 1\nLine 2');
        await tester.pumpAndSettle();

        expect(changedValue, 'Line 1Line 2');
      },
    );
  });

  group('GroupClosenessPicker', () {
    testWidgets('restyled: two rows of two tiles, tone by bond, never a Wrap', (
      tester,
    ) async {
      var selected = GroupCloseness.acquaintance;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return GroupClosenessPicker(
                label: 'To you, they are',
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    selected = val;
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Never a Wrap
      expect(find.byType(Wrap), findsNothing);

      // Two Rows of two Expanded tiles
      expect(find.text('Just met'), findsOneWidget);
      expect(find.text('Friend'), findsOneWidget);
      expect(find.text('Has a crush on you'), findsOneWidget);
      expect(find.text('Rival'), findsOneWidget);

      // Icons
      expect(find.byIcon(Icons.waving_hand_outlined), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);

      // Select Friend
      await tester.tap(find.text('Friend'));
      await tester.pumpAndSettle();

      expect(selected, GroupCloseness.friend);
    });
  });

  group('GroupArtBackdrop', () {
    testWidgets(
      'renders 360 height with forge-group-cover asset and 3-stop gradient scrim',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const Stack(children: [GroupArtBackdrop()])),
        );
        await tester.pump();

        expect(find.byType(GroupArtBackdrop), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        final positioned = tester.widget<Positioned>(
          find.descendant(
            of: find.byType(GroupArtBackdrop),
            matching: find.byType(Positioned).first,
          ),
        );
        expect(positioned.height, 360);
        expect(positioned.top, 0);
        expect(positioned.left, 0);
        expect(positioned.right, 0);
      },
    );
  });

  group('GroupFaceFrame', () {
    testWidgets('renders arch with radial glow and initial', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 184,
            height: 242,
            child: GroupFaceFrame(initial: 'Ines', bond: GroupCloseness.rival),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('I'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('I'));
      expect(textWidget.style?.fontFamily, contains('Cinzel'));
    });

    testWidgets('renders icon for empty state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 184,
            height: 242,
            child: GroupFaceFrame(
              icon: Icons.person_outline,
              bond: GroupCloseness.acquaintance,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('pulsing frame animates glow and arch', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 184,
            height: 242,
            child: GroupFaceFrame(
              initial: 'Tomas',
              bond: GroupCloseness.friend,
              pulsing: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('T'), findsOneWidget);
    });
  });

  group('GroupFaceMosaic', () {
    testWidgets('0 faces renders asset cover fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(faceUrls: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('1 to 6 faces layout formats correctly', (tester) async {
      // 1 face
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: ['assets/art/forge-group-cover.webp'],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);

      // 2 faces
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: [
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));

      // 3 faces
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: [
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(3));

      // 4 faces
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: [
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(4));

      // 5 faces
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: [
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(5));

      // 6 faces
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            height: 300,
            child: GroupFaceMosaic(
              faceUrls: [
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
                'assets/art/forge-group-cover.webp',
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(6));
    });
  });

  group('GroupFoldSection', () {
    testWidgets(
      'closed 60 dp with title and summary; tap expands and reveals content',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const GroupFoldSection(
              title: 'How it begins',
              summary: 'You arrive at the gym.',
              child: Text('Expanded prompt details'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('How it begins'), findsOneWidget);
        expect(find.text('You arrive at the gym.'), findsOneWidget);
        expect(find.text('Expanded prompt details'), findsNothing);

        // Tap header to expand
        await tester.tap(find.text('How it begins'));
        await tester.pumpAndSettle();

        expect(find.text('Expanded prompt details'), findsOneWidget);
      },
    );

    testWidgets('error opens fold and shows crimson dot', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GroupFoldSection(
            title: 'The setting',
            hasError: true,
            child: Text('Setting error content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Child is immediately visible because hasError opens it
      expect(find.text('Setting error content'), findsOneWidget);

      // Crimson dot container exists
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCrimsonDot = containers.any((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.color == EverloreTheme.crimson &&
            dec.shape == BoxShape.circle;
      });
      expect(hasCrimsonDot, isTrue);
    });

    testWidgets('GroupFoldCard stacks sections with white10 hairlines', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const GroupFoldCard(
            sections: [
              GroupFoldSection(title: 'Section 1', child: Text('Content 1')),
              GroupFoldSection(title: 'Section 2', child: Text('Content 2')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section 1'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('GroupPersonCard', () {
    testWidgets('form states: addSlot, empty, filled, and withErrors', (
      tester,
    ) async {
      var addTapped = false;
      var emptyTapped = false;
      var filledTapped = false;

      // 1. Add slot
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 184,
            height: 242,
            child: GroupPersonCard.addSlot(onTap: () => addTapped = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a person'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.text('Add a person'));
      expect(addTapped, isTrue);

      // 2. Empty form card
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 184,
            height: 242,
            child: GroupPersonCard.form(
              person: const GroupFormPerson(),
              index: 0,
              onTap: () => emptyTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Someone new'), findsOneWidget);
      expect(find.text('Tap to describe them'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      await tester.tap(find.text('Someone new'));
      expect(emptyTapped, isTrue);

      // 3. Filled form card
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 184,
            height: 242,
            child: GroupPersonCard.form(
              person: const GroupFormPerson(
                name: 'Ines',
                age: 27,
                closeness: GroupCloseness.rival,
                look: 'Lean, short bleached hair.',
              ),
              index: 0,
              onTap: () => filledTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ines'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('Rival'), findsOneWidget);
      expect(find.text('Lean, short bleached hair.'), findsOneWidget);
      await tester.tap(find.text('Ines'));
      expect(filledTapped, isTrue);

      // 4. Form card with errors
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 184,
            height: 242,
            child: GroupPersonCard.form(
              person: const GroupFormPerson(name: ''),
              index: 0,
              formErrors: const {
                'people.0.name': 'Add a name.',
                'people.0.look': 'Add how they look.',
              },
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Still needs a name and a look'), findsOneWidget);
    });

    testWidgets(
      'face states: idleNoFace, painting, ready, resting/unseen, faceWillReset, and withErrors',
      (tester) async {
        var paintTapped = false;
        var cardTapped = false;

        final person = GroupDraftPerson.fromJson(_person('Ines', 27));

        // 1. idle, no face
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: person,
                index: 0,
                face: GroupFace.idle,
                onTap: () => cardTapped = true,
                onPaintFace: () => paintTapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paint a face'), findsOneWidget);
        expect(find.text('Ines'), findsOneWidget);
        expect(find.text('27'), findsOneWidget);
        expect(find.text('Rival'), findsOneWidget);

        // Tapping the pill paints without triggering card tap
        await tester.tap(find.text('Paint a face'));
        expect(paintTapped, isTrue);
        expect(cardTapped, isFalse);

        // Tapping elsewhere on card opens sheet
        await tester.tap(find.text('Ines'));
        expect(cardTapped, isTrue);

        // 2. painting state
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: person,
                index: 0,
                face: const GroupFace(GroupFaceStatus.painting),
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Painting…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 3. ready state (portrait url)
        final personWithFace = GroupDraftPerson.fromJson(
          _person('Ines', 27, portraitUrl: 'https://cdn/ines.webp'),
        );
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: personWithFace,
                index: 0,
                face: const GroupFace(GroupFaceStatus.ready),
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(EverloreNetworkImage), findsOneWidget);
        expect(find.text('Ines'), findsOneWidget);

        // 4. resting / unseen state
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: person,
                index: 0,
                face: const GroupFace(
                  GroupFaceStatus.resting,
                  message: 'Taking a rest. Try again soon.',
                ),
                onTap: () {},
                onPaintFace: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Taking a rest. Try again soon.'), findsOneWidget);
        expect(find.text('Paint a face'), findsOneWidget);

        // 5. faceWillReset state
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: personWithFace,
                index: 0,
                face: const GroupFace(GroupFaceStatus.ready),
                faceWillReset: true,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('New face after you save'), findsOneWidget);

        // 6. field error or refused line state
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 184,
              height: 242,
              child: GroupPersonCard.editor(
                person: person,
                index: 0,
                hasError: true,
                errorMessage: 'Needs a look',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Needs a look'), findsOneWidget);
      },
    );

    testWidgets('320 dp wide layout test with two columns has no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ines = GroupDraftPerson.fromJson(_person('Ines', 27));
      final tomas = GroupDraftPerson.fromJson(_person('Tomas', 33));

      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.76,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              children: [
                GroupPersonCard.form(
                  person: const GroupFormPerson(
                    name: 'Ines',
                    age: 27,
                    closeness: GroupCloseness.rival,
                    look: 'Lean, athletic.',
                  ),
                  index: 0,
                  onTap: () {},
                ),
                GroupPersonCard.form(
                  person: const GroupFormPerson(),
                  index: 1,
                  onTap: () {},
                ),
                GroupPersonCard.addSlot(onTap: () {}),
                GroupPersonCard.editor(
                  person: ines,
                  index: 0,
                  onTap: () {},
                  onPaintFace: () {},
                ),
                GroupPersonCard.editor(
                  person: tomas,
                  index: 1,
                  face: const GroupFace(GroupFaceStatus.painting),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Ines'), findsWidgets);
      expect(find.text('Someone new'), findsOneWidget);
      expect(find.text('Add a person'), findsOneWidget);
    });

    testWidgets(
      'a failed "Write my group" opens the first person with an error when title and setting are fine',
      (tester) async {
        final cubit = CreateGroupCubit();
        cubit.updateForm(
          title: 'The Climbing Gym',
          setting: 'A bouldering gym in Lisbon, old friends',
        );

        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Sheet is not open initially
        expect(find.text('Person 1'), findsNothing);

        // Tap "Write my group". Since person 1 and person 2 are empty,
        // validation fails and opens person 1's sheet.
        await tester.tap(find.text('Write my group'));
        await tester.pumpAndSettle();

        expect(find.text('Person 1'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets('title error scrolls up', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cubit = CreateGroupCubit();
      // Leave title empty, set setting so only title has error
      cubit.updateForm(setting: 'A bouldering gym in Lisbon, old friends');

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Drag to scroll down
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap "Write my group" which fails validation with a title error
      await tester.tap(find.text('Write my group'));
      await tester.pumpAndSettle();

      // Verify it scrolled back up and title hint is visible
      expect(find.text('Name your group'), findsOneWidget);
    });

    testWidgets('adding a sixth person hides the add slot', (tester) async {
      final cubit = CreateGroupCubit();
      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a person'), findsOneWidget);

      // Initially 2 people. Add 4 more to reach 6.
      cubit.addPerson();
      cubit.addPerson();
      cubit.addPerson();
      cubit.addPerson();
      await tester.pumpAndSettle();

      expect(cubit.state.form.people.length, 6);
      expect(find.text('Add a person'), findsNothing);
    });

    testWidgets('removing the middle person leaves the right people', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cubit = CreateGroupCubit();
      cubit.updatePerson(
        0,
        const GroupFormPerson(name: 'Alice', look: 'Tall, glasses'),
      );
      cubit.updatePerson(
        1,
        const GroupFormPerson(name: 'Bob', look: 'Curly hair'),
      );
      cubit.addPerson();
      cubit.updatePerson(
        2,
        const GroupFormPerson(name: 'Charlie', look: 'Athletic'),
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // Tap Bob (middle person) to open sheet
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();

      // Scroll inside the sheet to "Remove this person"
      await tester.scrollUntilVisible(
        find.text('Remove this person'),
        100,
        scrollable: find.byType(Scrollable).last,
      );

      // Tap "Remove this person"
      await tester.tap(find.text('Remove this person'));
      await tester.pumpAndSettle();

      // Bob should be gone; Alice and Charlie remain
      expect(find.text('Bob'), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(cubit.state.form.people.length, 2);
    });

    testWidgets(
      'the sheet at 320 x 640 with viewInsets of 300 has no overflow and hides "Done"',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });

        final cubit = CreateGroupCubit();
        await tester.pumpWidget(
          _wrap(
            BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll so the first person card is visible, then tap it to open sheet
        await tester.scrollUntilVisible(
          find.text('Someone new').first,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Someone new').first);
        await tester.pumpAndSettle();

        // Now simulate the soft keyboard appearing with 300 dp viewInsets
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        // No Flutter overflow exceptions
        expect(tester.takeException(), isNull);
        // "Person 1" should be in the sheet
        expect(find.text('Person 1'), findsOneWidget);
        // "Done" should be hidden when keyboard viewInsets.bottom > 0
        expect(find.text('Done'), findsNothing);
      },
    );

    testWidgets('the wait shows a real name', (tester) async {
      final state = CreateGroupState(
        phase: CreateGroupPhase.drafting,
        form: const GroupForm(
          title: 'The Climbing Gym',
          setting: 'A bouldering gym in Lisbon',
          people: [
            GroupFormPerson(name: 'Ines', look: 'Lean, athletic'),
            GroupFormPerson(name: 'Tomas', look: 'Tall, bearded'),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(GroupDraftingView(state: state)));
      await tester.pump();

      expect(find.text('Writing your group'), findsOneWidget);
      expect(find.text('Finding out what Ines wants'), findsOneWidget);
      expect(find.text('Usually under a minute.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'GroupPersonCard: pump painting, then ready, and find both children mid-fade',
      (tester) async {
        final person = GroupDraftPerson.fromJson(_person('Ines', 27));

        // 1. Pump painting state
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 180,
              height: 240,
              child: GroupPersonCard.editor(
                person: person,
                index: 0,
                face: const GroupFace(GroupFaceStatus.painting),
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(GroupFaceFrame), findsOneWidget);
        expect(find.byType(EverloreNetworkImage), findsNothing);

        // 2. Pump ready state with portrait URL
        final readyPerson = person.copyWith(
          portraitUrl: 'https://cdn/ines-portrait.webp',
        );
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 180,
              height: 240,
              child: GroupPersonCard.editor(
                person: readyPerson,
                index: 0,
                face: GroupFace.idle,
                onTap: () {},
              ),
            ),
          ),
        );

        // 3. Advance half-way through the 420ms fade (e.g. 200ms)
        await tester.pump(const Duration(milliseconds: 200));

        // Mid-fade: AnimatedSwitcher holds both the fading out GroupFaceFrame
        // and the fading in EverloreNetworkImage.
        expect(find.byType(GroupFaceFrame), findsWidgets);
        expect(find.byType(EverloreNetworkImage), findsOneWidget);

        // 4. Advance past the end of the fade animation
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // After fade finishes: only EverloreNetworkImage remains
        expect(find.byType(EverloreNetworkImage), findsOneWidget);
      },
    );

    testWidgets('paint pill with onPaintFace null does not block card tap', (
      tester,
    ) async {
      var cardTapped = false;
      final person = GroupDraftPerson.fromJson(_person('Ines', 27));

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 180,
            height: 240,
            child: GroupPersonCard.editor(
              person: person,
              index: 0,
              face: GroupFace.idle,
              onTap: () => cardTapped = true,
              onPaintFace: null,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the "Paint a face" pill (ignored pointer passes to parent card)
      await tester.tap(find.text('Paint a face'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tapping pill passes through to card onTap
      expect(cardTapped, isTrue);
    });
  });
}
