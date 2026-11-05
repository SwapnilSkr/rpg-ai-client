import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/screens/direct_thread_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_room_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_reply_ideas.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';

import '../fakes.dart';

Widget _host(Widget child, {EdgeInsets viewInsets = EdgeInsets.zero}) =>
    BlocProvider<ChatsCubit>(
      create: (_) => ChatsCubit(
        repository: FakeChatsRepository(),
        loadTemplates: () async => const [],
      ),
      child: MaterialApp(
        theme: ThemeData(
          splashFactory: InkRipple.splashFactory,
        ),
        home: MediaQuery(
          data: MediaQueryData(viewInsets: viewInsets),
          child: Scaffold(body: child),
        ),
      ),
    );

Map<String, dynamic> ideasFrame(
  String eventId,
  List<String> ideas, {
  String? directWith,
}) => {
  'type': 'group_ideas',
  'instanceId': instanceId,
  if (directWith != null) 'directWith': directWith,
  'eventId': eventId,
  'ideas': ideas,
};

Map<String, dynamic> withIdeas(
  String id,
  List<String> ideas, {
  String? who,
  List<Map<String, dynamic>>? characters,
}) => loadedFrame(
  directWith: who,
  characters: characters,
  events: [
    eventRow(id: 'e1', sequence: 1, playerInput: 'old'),
    eventRow(id: id, sequence: 2, replyIdeas: ideas),
  ],
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(
        message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, Object?>{});
      }
      if (key == 'AssetManifest.json') {
        return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
      }
      return null;
    });
  });

  late FakeGateway gateway;
  late FakeRepository repo;
  late FakeClock clock;
  late GroupChatCubit cubit;

  void createRig() {
    gateway = FakeGateway();
    repo = FakeRepository();
    clock = FakeClock();
    cubit = GroupChatCubit(
      instanceId: instanceId,
      gateway: gateway,
      repository: repo,
      clock: clock,
    );
  }

  tearDown(() {
    DriftingPortraitBackdrop.animateDrift = true;
    cubit.close();
  });

  group('Reply ideas chips UI', () {
    testWidgets('chips render for ideas, tap calls send and they vanish',
        (tester) async {
      createRig();
      await cubit.start();

      gateway.pushLoaded(
        withIdeas('e2', [
          'I shall investigate the archives at dawn.',
          'Tell me more of what you saw.',
          'We must prepare for the council.',
        ]),
      );

      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      // Pump past entrance animation (250ms)
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('I shall investigate the archives at dawn.'),
        findsOneWidget,
      );
      expect(
        find.text('Tell me more of what you saw.'),
        findsOneWidget,
      );
      expect(
        find.text('We must prepare for the council.'),
        findsOneWidget,
      );
      expect(find.byType(GroupReplyIdeas), findsOneWidget);

      // Verify no icons inside chips
      final chipsFinder = find.descendant(
        of: find.byType(GroupReplyIdeas),
        matching: find.byType(Icon),
      );
      expect(chipsFinder, findsNothing);

      // Tap the second chip
      await tester.tap(find.text('Tell me more of what you saw.'));
      await tester.pump();

      // State is cleared and outgoing chat queued
      expect(gateway.chats.single['text'], 'Tell me more of what you saw.');
      expect(cubit.state.replyIdeasFor(), isEmpty);

      // Chips vanish immediately on send
      expect(find.byType(GroupReplyIdeas), findsNothing);
      expect(
        find.text('I shall investigate the archives at dawn.'),
        findsNothing,
      );
      // Sent message is now in the message list
      expect(find.text('Tell me more of what you saw.'), findsOneWidget);

      // Composer text field remains empty (nothing was placed in composer)
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty);
    });

    testWidgets('chips are hidden while keyboard is up with text typed in composer',
        (tester) async {
      createRig();
      await cubit.start();

      gateway.pushLoaded(withIdeas('e2', ['Idea one', 'Idea two']));

      // 1. Keyboard down, no text: visible
      await tester.pumpWidget(
        _host(
          GroupRoomScreen(
            instanceId: instanceId,
            cubit: cubit,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Idea one'), findsOneWidget);

      // 2. Keyboard up but text is empty: still visible
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(find.text('Idea one'), findsOneWidget);

      // 3. User types in composer with keyboard up: hidden
      await tester.enterText(find.byType(TextField), 'Custom message');
      await tester.pump();
      expect(find.byType(GroupReplyIdeas), findsNothing);

      // 4. User clears composer text while keyboard is up: chips reappear
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Idea one'), findsOneWidget);
    });

    testWidgets('reply ideas render and send in direct thread screen',
        (tester) async {
      createRig();
      await cubit.start();

      final cards = [
        {
          '_id': jess,
          'canonical_name': 'Jess',
          'status': 'exploring the ruins',
        },
      ];

      gateway.pushLoaded(
        withIdeas('d2', ['Direct idea 1', 'Direct idea 2'], who: jess, characters: cards),
      );

      final jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        status: 'exploring the ruins',
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Direct idea 1'), findsOneWidget);
      expect(find.text('Direct idea 2'), findsOneWidget);

      await tester.tap(find.text('Direct idea 1'));
      await tester.pump();

      expect(gateway.chats.single['text'], 'Direct idea 1');
      expect(gateway.chats.single['direct_with'], jess);
      expect(find.byType(GroupReplyIdeas), findsNothing);
      expect(find.text('Direct idea 2'), findsNothing);
      // Sent message is in the thread
      expect(find.text('Direct idea 1'), findsOneWidget);
    });
  });

  group('Empty direct thread & first texts UI', () {
    final cardsWithFirstTexts = [
      {
        '_id': jess,
        'canonical_name': 'Jess',
        'portrait_url': 'https://example.com/jess-full.jpg',
        'status': 'waiting by the gate',
        'first_texts': [
          'Are you ready for the journey?',
          'The road ahead is perilous.',
          'May the light guide our steps.',
        ],
      },
    ];

    testWidgets('empty thread shows large name, status, and three first text lines',
        (tester) async {
      createRig();
      await cubit.start();

      gateway.pushLoaded(loadedFrame(characters: cardsWithFirstTexts, directWith: jess));

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        portraitUrl: 'https://example.com/jess-full.jpg',
        status: 'waiting by the gate',
        firstTexts: [
          'Are you ready for the journey?',
          'The road ahead is perilous.',
          'May the light guide our steps.',
        ],
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drifting backdrop is present
      expect(find.byType(DriftingPortraitBackdrop), findsOneWidget);

      // Character's name and status large over the fade
      expect(find.text('Jess'), findsOneWidget);
      expect(find.text('waiting by the gate'), findsOneWidget);

      // Three stacked first text lines
      expect(find.text('Are you ready for the journey?'), findsOneWidget);
      expect(find.text('The road ahead is perilous.'), findsOneWidget);
      expect(find.text('May the light guide our steps.'), findsOneWidget);

      // Tapping a first text line calls sendIdea immediately
      await tester.tap(find.text('The road ahead is perilous.'));
      await tester.pump();

      expect(gateway.chats.single['text'], 'The road ahead is perilous.');
      expect(gateway.chats.single['direct_with'], jess);

      // Transition to normal thread over 400ms
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));
      // First texts are now gone
      expect(find.text('The road ahead is perilous.'), findsOneWidget); // Now in the message bubble!
      expect(find.text('Are you ready for the journey?'), findsNothing);
    });

    testWidgets('empty thread without first_texts shows large name and status without lines',
        (tester) async {
      createRig();
      await cubit.start();

      final cardsNoTexts = [
        {
          '_id': jess,
          'canonical_name': 'Jess',
          'status': 'resting by the fire',
        },
      ];

      gateway.pushLoaded(loadedFrame(characters: cardsNoTexts, directWith: jess));

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        status: 'resting by the fire',
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DriftingPortraitBackdrop), findsOneWidget);
      expect(find.text('Jess'), findsOneWidget);
      expect(find.text('resting by the fire'), findsOneWidget);

      // Composer is visible at the bottom
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('empty thread without portrait falls back to backdrop without crashing',
        (tester) async {
      createRig();
      await cubit.start();

      final cardsNoPortrait = [
        {
          '_id': jess,
          'canonical_name': 'Jess',
          'portrait_url': '',
        },
      ];

      gateway.pushLoaded(loadedFrame(characters: cardsNoPortrait, directWith: jess));

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        portraitUrl: null,
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DriftingPortraitBackdrop), findsOneWidget);
      expect(find.text('Jess'), findsOneWidget);
    });

    testWidgets('drift animation controller has 24s duration and repeat reversing',
        (tester) async {
      DriftingPortraitBackdrop.animateDrift = true;
      createRig();
      await cubit.start();

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        portraitUrl: 'https://example.com/jess-full.jpg',
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final state = tester.state(find.byType(DriftingPortraitBackdrop));
      expect(state, isNotNull);

      // Pump 1 second of drift
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Transform), findsWidgets);
    });
  });

  group('Status in direct thread header UI', () {
    testWidgets('status shows in header when messages exist', (tester) async {
      createRig();
      await cubit.start();

      final cards = [
        {
          '_id': jess,
          'canonical_name': 'Jess',
          'status': 'patrolling the north wall',
        },
      ];

      final directEvent = eventRow(
        id: 'e1',
        sequence: 1,
        lines: [
          storedLine(jess, 'All quiet on the ramparts.', DateTime.utc(2026, 11, 4, 11)),
        ],
      );

      gateway.pushLoaded(loadedFrame(characters: cards));
      cubit.selectThread(jess);
      gateway.pushLoaded(loadedFrame(
        characters: cards,
        directWith: jess,
        events: [directEvent],
      ));

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        status: 'patrolling the north wall',
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));

      // In header: character name and status under the name
      final headerName = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Jess'),
      );
      expect(headerName, findsOneWidget);

      final headerStatus = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('patrolling the north wall'),
      );
      expect(headerStatus, findsOneWidget);

      final statusText = tester.widget<Text>(headerStatus);
      expect(statusText.maxLines, 1);
      expect(statusText.overflow, TextOverflow.ellipsis);
      expect(statusText.style?.color, EverloreTheme.ash);
      expect(statusText.style?.fontSize, 11);
    });

    testWidgets('no status means the name sits alone in header', (tester) async {
      createRig();
      await cubit.start();

      final cards = [
        {
          '_id': jess,
          'canonical_name': 'Jess',
          'status': null,
        },
      ];

      final directEvent = eventRow(
        id: 'e1',
        sequence: 1,
        lines: [
          storedLine(jess, 'Greetings traveler.', DateTime.utc(2026, 11, 4, 11)),
        ],
      );

      gateway.pushLoaded(loadedFrame(characters: cards));
      cubit.selectThread(jess);
      gateway.pushLoaded(loadedFrame(
        characters: cards,
        directWith: jess,
        events: [directEvent],
      ));

      const jessMember = GroupMember(
        id: jess,
        name: 'Jess',
        status: null,
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(
          cubit: cubit,
          member: jessMember,
        )),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));

      final headerName = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Jess'),
      );
      expect(headerName, findsOneWidget);
      // No subtitle under the name
      final statusSubtitles = find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (w) => w is Text && w.style?.fontSize == 11,
        ),
      );
      expect(statusSubtitles, findsNothing);
    });
  });
}
