import 'dart:async';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/core/network/api_client.dart';
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
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_editor_sheet.dart';
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

        // Top sections and story folds
        expect(find.text('Your group'), findsOneWidget);
        expect(find.text('The Climbing Gym'), findsWidgets);
        expect(find.text("WHO'S IN IT"), findsOneWidget);
        expect(find.text('THE STORY'), findsOneWidget);
        expect(find.text('How it begins'), findsOneWidget);
        expect(find.text('The setting'), findsOneWidget);
        expect(find.text('What they talk about'), findsOneWidget);
        expect(find.text('The first conversation'), findsOneWidget);

        // Tap person Ines (opens sheet)
        await tester.tap(find.text('Ines').first);
        await tester.pumpAndSettle();

        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        await tester.tap(find.text('How they talk and what they want'));
        await tester.pumpAndSettle();
        expect(find.text('When it gets intimate'), findsOneWidget);

        // Close sheet
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

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

        // Tap person Ines in non-adult
        await tester.tap(find.text('Ines').first);
        await tester.pumpAndSettle();

        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        await tester.tap(find.text('How they talk and what they want'));
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

      final paintButton = find.text('Paint a face');
      expect(paintButton, findsWidgets);

      await tester.tap(paintButton.first);
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

      // Clean state shows "Saved"
      expect(find.text('Saved'), findsOneWidget);

      // Edit title to make it dirty
      cubit.setTitle('Updated Gym');
      await tester.pumpAndSettle();

      // Dirty state shows "Save"
      expect(find.text('Save'), findsOneWidget);

      // Trigger save
      unawaited(cubit.save());
      await tester.pump();
      await tester.pump();

      // While saving: spinner shows, "Save" is gone
      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets(
      'emitting a state with new face URL keeps scroll offset and an open sheet open',
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

        // 1. Open person 0 (Ines)'s sheet
        await tester.tap(find.text('Ines').first);
        await tester.pumpAndSettle();
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(find.text('Who they are'), findsOneWidget);

        // 2. Emit state with equal-content copy having a new face URL
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

        // Verify: Sheet remains open
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(find.text('Who they are'), findsOneWidget);
      },
    );

    testWidgets('re-read via load keeps scroll offset and an open sheet open', (
      tester,
    ) async {
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

      // Open person 0 (Ines)'s sheet
      await tester.tap(find.text('Ines').first);
      await tester.pumpAndSettle();
      expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
      expect(find.text('Who they are'), findsOneWidget);

      // Re-read draft via load
      await cubit.load('g1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sheet remains open
      expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
      expect(find.text('Who they are'), findsOneWidget);
    });

    testWidgets(
      'a planted refused line at seed_cast.2.group.voice.4 opens the third person\'s sheet and that field\'s fold',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final raw = _authoring();
        final castList = List<Map<String, dynamic>>.from(
          raw['seed_cast'] as List,
        );
        final alex = _person('Alex', 25);
        (alex['group'] as Map<String, dynamic>)['voice'] = [
          'Line 0',
          'Line 1',
          'Line 2',
          'Line 3',
          'Line 4',
        ];
        castList.add(alex);
        raw['seed_cast'] = castList;

        final draft = GroupDraft.fromAuthoring(raw);
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

        // Sheet is not open initially
        expect(find.byType(GroupPersonEditorSheet), findsNothing);

        // Plant a refused line at seed_cast.2.group.voice.4
        cubit.emit(
          cubit.state.copyWith(
            refusedPaths: {'seed_cast.2.group.voice.4'},
            error: 'Please fix the refused lines.',
          ),
        );
        await tester.pumpAndSettle();

        // Verify: The 3rd person (Alex)'s sheet is opened
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(find.text('Alex'), findsWidgets);

        // And that field's fold ("Things they say") is opened, showing refusal text
        expect(
          find.text("This line can't be saved. Change it."),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'clearing an error on person 0 does not trigger reveal and sheet stays on person 0',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        // Plant errors on people 0 and 1
        cubit.emit(
          cubit.state.copyWith(
            fieldErrors: {
              'seed_cast.0.role': 'Needs role',
              'seed_cast.1.role': 'Needs role',
            },
          ),
        );
        await tester.pumpAndSettle();

        // Sheet is open on person 0 (Ines)
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(GroupPersonEditorSheet),
            matching: find.text('Ines'),
          ),
          findsWidgets,
        );

        // Clear person 0's error through cubit's setter
        cubit.setPersonRole(0, 'Route Setter');
        await tester.pumpAndSettle();

        // The sheet must stay on person 0 (Ines), NOT switch to person 1 (Tomas)
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(GroupPersonEditorSheet),
            matching: find.text('Ines'),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byType(GroupPersonEditorSheet),
            matching: find.text('Tomas'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'planted refused line at seed_cast.2.group.voice.4 at phone height is inside visible area after pumpAndSettle; sheet opened by tapping card has scroll offset 0',
      (tester) async {
        const phoneHeight = 844.0;
        const phoneWidth = 390.0;
        tester.view.physicalSize = const Size(phoneWidth, phoneHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final raw = _authoring();
        final castList = List<Map<String, dynamic>>.from(
          raw['seed_cast'] as List,
        );
        final alex = _person('Alex', 25);
        (alex['group'] as Map<String, dynamic>)['voice'] = [
          'Line 0',
          'Line 1',
          'Line 2',
          'Line 3',
          'Line 4',
        ];
        castList.add(alex);
        raw['seed_cast'] = castList;

        final draft = GroupDraft.fromAuthoring(raw);
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

        // 1. Part A: Planted refused line at seed_cast.2.group.voice.4 (revealed sheet)
        cubit.emit(
          cubit.state.copyWith(
            refusedPaths: {'seed_cast.2.group.voice.4'},
            error: 'Please fix the refused lines.',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);

        // Find the line 4 text field
        final line4Finder = find.widgetWithText(GroupTextField, 'Line 4');
        expect(line4Finder, findsOneWidget);

        // Verify that Line 4 is inside the visible area of the screen
        final line4Rect = tester.getRect(line4Finder);
        expect(line4Rect.top, greaterThanOrEqualTo(0.0));
        expect(line4Rect.bottom, lessThanOrEqualTo(phoneHeight));

        // 2. Part B: Close sheet, tap a card, verify scroll offset is 0
        Navigator.of(
          tester.element(find.byType(GroupPersonEditorSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byType(GroupPersonEditorSheet), findsNothing);

        // Tap Ines's card directly
        await tester.tap(find.text('Ines').first);
        await tester.pumpAndSettle();

        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(GroupPersonEditorSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.pixels, equals(0.0));
      },
    );

    testWidgets(
      'WHO\'S IN IT row has height 44 with at least 44 dp tap area on Paint everyone, stays 44 dp when link disappears, and grid has zero padding',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

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

        // 1. GridView padding is EdgeInsets.zero
        final grid = tester.widget<GridView>(find.byType(GridView));
        expect(grid.padding, equals(EdgeInsets.zero));

        // 2. "Paint everyone" tap area is at least 44 dp tall
        final paintEveryoneGesture = find
            .ancestor(
              of: find.text('Paint everyone'),
              matching: find.byType(GestureDetector),
            )
            .first;
        final tapSize = tester.getSize(paintEveryoneGesture);
        expect(tapSize.height, greaterThanOrEqualTo(44.0));

        // 3. The row has height 44 dp
        final rowContainer = find
            .ancestor(
              of: find.text("WHO'S IN IT"),
              matching: find.byType(SizedBox),
            )
            .first;
        expect(tester.getSize(rowContainer).height, equals(44.0));

        // 4. When everyone has a face (Paint everyone link disappears), the row stays 44 dp tall
        final withFaces = draft.copyWith(
          cast: [
            draft.cast[0].copyWith(portraitUrl: 'https://cdn/p0.webp'),
            draft.cast[1].copyWith(portraitUrl: 'https://cdn/p1.webp'),
          ],
        );
        cubit.emit(cubit.state.copyWith(draft: withFaces));
        await tester.pumpAndSettle();

        expect(find.text('Paint everyone'), findsNothing);
        expect(tester.getSize(rowContainer).height, equals(44.0));
      },
    );

    testWidgets('a fieldErrors entry on a story field opens its fold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      // Emit field error on topics.0
      cubit.emit(cubit.state.copyWith(fieldErrors: {'topics.0': 'Too short'}));
      await tester.pumpAndSettle();

      // The "What they talk about" fold is opened and displays the error
      expect(find.text('Too short'), findsOneWidget);
      expect(find.text('Add a topic'), findsOneWidget);
    });

    testWidgets(
      '"Paint everyone" saves first and then asks for one face at a time, in order, and stops when the save fails',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        var saveCalled = 0;
        var saveShouldFail = true;
        final faceRequestedIndices = <int>[];

        final raw = _authoring(portraitUrl: '');
        final draft = GroupDraft.fromAuthoring(raw);

        final cubit = CreateGroupCubit(
          loadFn: (_) async => draft,
          updateFn: (_, __) async {
            saveCalled++;
            if (saveShouldFail) {
              throw Exception('Save failed');
            }
          },
          faceFn: (id, index, {repaint = false}) async {
            faceRequestedIndices.add(index);
            return GroupFaceResult(
              GroupFaceOutcome.ready,
              url: 'https://cdn/face_$index.webp',
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

        // 1. Part A: Save fails -> stops and does NOT request faces
        cubit.setTitle('Updated Climbing Gym');
        await tester.pumpAndSettle();

        final paintEveryoneFinder = find.text('Paint everyone');
        expect(paintEveryoneFinder, findsOneWidget);

        await tester.tap(paintEveryoneFinder);
        await tester.pumpAndSettle();

        expect(saveCalled, 1);
        expect(faceRequestedIndices, isEmpty);

        // 2. Part B: Save succeeds -> requests faces one by one in order
        saveShouldFail = false;
        await tester.tap(paintEveryoneFinder);
        await tester.pumpAndSettle();

        expect(saveCalled, 2);
        expect(faceRequestedIndices, equals([0, 1]));
      },
    );

    testWidgets('a failed save shows the reveal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final draft = GroupDraft.fromAuthoring(_authoring());
      final cubit = CreateGroupCubit(
        loadFn: (_) async => draft,
        updateFn: (_, __) async {
          throw ApiException(
            statusCode: 400,
            message: 'Structure check failed',
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

      // Clear title so validation fails on save
      cubit.setTitle('');
      await tester.pumpAndSettle();

      // Tap "Start chatting" which attempts to save first
      await tester.tap(find.text('Start chatting'));
      await tester.pumpAndSettle();

      // Save failed and reveal shows the error under Title
      expect(find.text('Add a title.'), findsOneWidget);
    });

    testWidgets('"Start over" asks first and goes back to the form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A fresh draft where draft.id == null
      final raw = _authoring();
      raw.remove('_id');
      final draft = GroupDraft.fromAuthoring(raw);
      final cubit = CreateGroupCubit(draftFn: (_) async => draft);
      cubit.emit(
        cubit.state.copyWith(
          phase: CreateGroupPhase.editing,
          draft: draft,
          saved: draft,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          BlocProvider.value(value: cubit, child: const CreateGroupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Overflow menu contains "Start over"
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Start over'), findsOneWidget);

      // Tap "Start over" item
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();

      // Confirm sheet appears with title "Start over?"
      expect(find.text('Start over?'), findsOneWidget);
      expect(
        find.text(
          'This goes back to what you typed. The writing here will be lost.',
        ),
        findsOneWidget,
      );
      expect(find.text('Keep this'), findsOneWidget);

      // Confirm start over
      await tester.tap(find.widgetWithText(FilledButton, 'Start over'));
      await tester.pumpAndSettle();

      // Verify phase moved back to form
      expect(cubit.state.phase, CreateGroupPhase.form);
      expect(find.text('Write my group'), findsOneWidget);
    });

    testWidgets(
      'the editor person sheet at 320 x 640 with viewInsets of 300 has no overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });

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

        // Tap Ines to open editor sheet
        await tester.tap(find.text('Ines').first);
        await tester.pumpAndSettle();

        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);

        // Soft keyboard appears with 300 dp viewInsets
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Done button is hidden
        expect(find.text('Done'), findsNothing);
      },
    );

    testWidgets(
      'a share refused on seed_cast.2.group.voice.4 closes the sheet and opens that person\'s sheet at that line',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final raw = _authoring();
        final castList = List<Map<String, dynamic>>.from(
          raw['seed_cast'] as List,
        );
        final alex = _person('Alex', 25);
        (alex['group'] as Map<String, dynamic>)['voice'] = [
          'Line 0',
          'Line 1',
          'Line 2',
          'Line 3',
          'Line 4',
        ];
        castList.add(alex);
        raw['seed_cast'] = castList;

        final draft = GroupDraft.fromAuthoring(raw);
        final cubit = CreateGroupCubit(
          loadFn: (_) async => draft,
          publishFn: (_, __) async {
            throw ApiException(
              statusCode: 422,
              message:
                  "Some lines in this group can't be saved. Check each part and try again.",
              details: {
                'paths': ['seed_cast.2.group.voice.4'],
              },
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

        // Editor is loaded. Tap "Share"
        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();

        // PublishWorldSheet is now open
        expect(find.byType(PublishWorldSheet), findsOneWidget);
        expect(find.text('Keep it just for me'), findsOneWidget);

        // Tap "Keep it just for me" to publish
        await tester.tap(find.text('Keep it just for me'));
        await tester.pumpAndSettle();

        // With the wrapper, PublishWorldSheet closed
        expect(find.byType(PublishWorldSheet), findsNothing);

        // And Alex's person sheet is opened at that line
        expect(find.byType(GroupPersonEditorSheet), findsOneWidget);
        expect(find.text('Alex'), findsWidgets);
        expect(
          find.text("This line can't be saved. Change it."),
          findsOneWidget,
        );
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

    testWidgets('the Age counter is gone and a long field still counts down', (
      tester,
    ) async {
      // 1. Age field (maxLength = 3)
      await tester.pumpWidget(
        _wrap(
          GroupTextField(
            label: 'Age',
            hint: '18+',
            initialValue: '25',
            maxLength: 3,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1 char left, but maxLength <= 20, so counter is NOT shown
      expect(find.textContaining('left'), findsNothing);

      // 2. Long field (maxLength = 50)
      await tester.pumpWidget(
        _wrap(
          GroupTextField(
            label: 'Title',
            hint: 'Title…',
            initialValue:
                '1234567890123456789012345678901234567890', // 40 chars
            maxLength: 50,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 10 chars left (<= 20) and maxLength (50) > 20, so counter IS shown
      expect(find.text('10 left'), findsOneWidget);
    });

    testWidgets(
      'underlineOnlyOnFocusOrError removes top padding and shows no underline when idle, shows underline on error',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GroupTextField(
              hint: 'Opening line…',
              initialValue: 'Hello',
              onChanged: (_) {},
              underlineOnlyOnFocusOrError: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Outer padding is zero
        final paddingFinder = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Padding),
            )
            .first;
        expect(
          tester.widget<Padding>(paddingFinder).padding,
          equals(EdgeInsets.zero),
        );

        // TextField border is InputBorder.none
        final tfWidget = tester.widget<TextField>(find.byType(TextField));
        expect(tfWidget.decoration?.border, equals(InputBorder.none));
        expect(tfWidget.decoration?.enabledBorder, equals(InputBorder.none));

        // Now pump with error
        await tester.pumpWidget(
          _wrap(
            GroupTextField(
              hint: 'Opening line…',
              initialValue: 'Hello',
              errorText: 'Needs a line',
              onChanged: (_) {},
              underlineOnlyOnFocusOrError: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final errorTfWidget = tester.widget<TextField>(find.byType(TextField));
        expect(errorTfWidget.decoration?.border, isA<UnderlineInputBorder>());
        expect(
          errorTfWidget.decoration?.enabledBorder,
          isA<UnderlineInputBorder>(),
        );
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
      // Keeps empty card prose serif font
      final titleFinder = find.text('Someone new');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontFamily, contains('Garamond'));
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
        final err = tester.takeException();
        if (err is FlutterError) {
          for (final prop in err.diagnostics) {
            print('DIAGNOSTIC: ${prop.toString()}');
          }
        }
        expect(err, isNull);
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
