import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everlore/core/network/api_client.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_message_bubble.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_message_list.dart';
import 'package:everlore/features/group_chat/presentation/widgets/member_avatar.dart';
import 'package:everlore/features/play/presentation/widgets/anchored_menu_popup.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: child),
);

typedef HttpHandler = Future<http.Response> Function(http.Request request);

void main() {
  final List<MethodCall> platformCalls = [];
  HttpHandler? currentHandler;
  Map<String, dynamic>? clipboardData;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://api.test');

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      if (call.method == 'Clipboard.setData') {
        clipboardData = call.arguments as Map<String, dynamic>?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return clipboardData;
      }
      return null;
    });

    // Ensure ApiClient._client is initialized with a delegating MockClient
    await http.runWithClient(() async {
      try {
        await ApiClient.get('/init_test_client');
      } catch (_) {}
    }, () => MockClient((request) async {
      if (currentHandler != null) {
        return currentHandler!(request);
      }
      return http.Response('{}', 200);
    }));
  });

  setUp(() {
    platformCalls.clear();
    currentHandler = null;
    clipboardData = null;
  });

  group('GroupMessageBubble - reporting lines', () {
    testWidgets('long press on a saved character line shows Copy and Report, and Report opens sheet with line', (tester) async {
      Map<String, dynamic>? sentBody;

      currentHandler = (request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep_123'}),
          200,
        );
      };

      final line = GroupLine(
        key: 'line-1',
        characterId: 'char-jess',
        name: 'Jess',
        text: 'Are we still meeting up later?',
        shownAt: DateTime.utc(2026, 11, 4, 12),
        eventId: 'event-456',
      );

      final member = const GroupMember(
        id: 'char-jess',
        name: 'Jess',
        role: 'Friend',
      );

      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Are we still meeting up later?'), findsOneWidget);

      // Long press on the character bubble
      await tester.longPress(find.text('Are we still meeting up later?'));
      await tester.pumpAndSettle();

      // Check light haptic feedback was triggered
      expect(
        platformCalls.any((call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.lightImpact'),
        isTrue,
      );

      // Check anchored menu opened showing Copy and Report
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);

      // Tap on Report
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      // Check report sheet opened with line and speaker name
      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('Jess'), findsNWidgets(2)); // bubble name + sheet header
      // Line text is quoted in the sheet (so present in bubble and sheet)
      expect(find.text('Are we still meeting up later?'), findsNWidgets(2));

      // Submit the report
      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      // Verify request body has target_type: group_line, event id, character_id, and text
      expect(sentBody, isNotNull);
      expect(sentBody!['target_type'], 'group_line');
      expect(sentBody!['target_id'], 'event-456');
      expect(sentBody!['character_id'], 'char-jess');
      expect(sentBody!['text'], 'Are we still meeting up later?');
      expect(sentBody!['reason'], 'harassment_or_hate');
    });

    testWidgets('Copy writes trimmed text to clipboard and shows notice', (tester) async {
      final line = GroupLine(
        key: 'line-copy',
        characterId: 'char-jess',
        name: 'Jess',
        text: '   See you at the gates.   ',
        shownAt: DateTime.utc(2026, 11, 4, 12),
        eventId: 'event-999',
      );

      await tester.pumpWidget(
        _host(GroupMessageBubble(line: line)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('   See you at the gates.   '));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Copied'), findsOneWidget);

      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clip?.text, 'See you at the gates.');
      expect(
        platformCalls.any((call) =>
            call.method == 'Clipboard.setData' &&
            call.arguments is Map &&
            (call.arguments as Map)['text'] == 'See you at the gates.'),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('long press on a player line shows Copy only', (tester) async {
      final playerLine = GroupLine(
        key: 'player-1',
        text: 'I am on my way now.',
        shownAt: DateTime.utc(2026, 11, 4, 12, 1),
        eventId: 'event-789',
        // characterId is null for player
      );

      await tester.pumpWidget(
        _host(GroupMessageBubble(line: playerLine)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('I am on my way now.'));
      await tester.pumpAndSettle();

      expect(
        platformCalls.any((call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.lightImpact'),
        isTrue,
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Report this message'), findsNothing);

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Copied'), findsOneWidget);

      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clip?.text, 'I am on my way now.');

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('long press on a sending player line shows Copy only', (tester) async {
      final sendingLine = GroupLine(
        key: 'player-sending',
        text: 'Hold the door!',
        shownAt: DateTime.utc(2026, 11, 4, 12, 1),
        status: GroupLineStatus.sending,
      );

      await tester.pumpWidget(
        _host(GroupMessageBubble(line: sendingLine)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Hold the door!'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Report this message'), findsNothing);

      await tester.tap(find.text('Copy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Copied'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('long press on an unsaved character line shows Copy only', (tester) async {
      final unsavedLine = GroupLine(
        key: 'unsaved-1',
        characterId: 'char-jess',
        name: 'Jess',
        text: 'This line is not yet saved to an event.',
        shownAt: DateTime.utc(2026, 11, 4, 12, 2),
        eventId: null, // unsaved
      );

      await tester.pumpWidget(
        _host(GroupMessageBubble(line: unsavedLine)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('This line is not yet saved to an event.'));
      await tester.pumpAndSettle();

      expect(
        platformCalls.any((call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.lightImpact'),
        isTrue,
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Report this message'), findsNothing);
    });

    testWidgets('long press on an action line shows Copy only', (tester) async {
      final actionLine = GroupLine(
        key: 'action-1',
        text: 'Sam poured a cup of tea.',
        shownAt: DateTime.utc(2026, 11, 4, 12, 3),
        eventId: 'event-111',
        isAction: true,
      );

      await tester.pumpWidget(
        _host(GroupMessageBubble(line: actionLine)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Sam poured a cup of tea.'));
      await tester.pumpAndSettle();

      expect(
        platformCalls.any((call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.lightImpact'),
        isTrue,
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Report this message'), findsNothing);
    });

    testWidgets('tap on avatar and name still works', (tester) async {
      int avatarTaps = 0;

      final line = GroupLine(
        key: 'line-tap',
        characterId: 'char-marco',
        name: 'Marco',
        text: 'Checking in.',
        shownAt: DateTime.utc(2026, 11, 4, 12, 4),
        eventId: 'event-222',
      );

      final member = const GroupMember(
        id: 'char-marco',
        name: 'Marco',
        role: 'Friend',
      );

      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onCharacterTap: () => avatarTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on character name
      await tester.tap(find.text('Marco'));
      await tester.pumpAndSettle();
      expect(avatarTaps, 1);

      // Tap on avatar (MemberAvatar)
      await tester.tap(find.byType(MemberAvatar));
      await tester.pumpAndSettle();
      expect(avatarTaps, 2);
    });

    testWidgets('menu does not sit below composerTop when room is limited', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final line = GroupLine(
        key: 'line-composer',
        text: 'Near the composer',
        shownAt: DateTime.utc(2026, 11, 4, 12),
      );

      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomCenter,
            child: GroupMessageBubble(
              line: line,
              composerTop: () => 900.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Near the composer'));
      await tester.pumpAndSettle();

      final menuFinder = find.byType(AnchoredMenuPopup);
      expect(menuFinder, findsOneWidget);
      final menuRect = tester.getRect(menuFinder);
      expect(menuRect.bottom, lessThanOrEqualTo(900.0));
    });
  });

  group('GroupMessageList - scrolling and reporting in list', () {
    testWidgets('long press inside GroupMessageList opens menu and Report opens report sheet with the line', (tester) async {
      final jess = const GroupMember(id: 'jess', name: 'Jess', role: 'Friend');
      final lines = [
        GroupLine(
          key: 'l-1',
          characterId: 'jess',
          name: 'Jess',
          text: 'First saved message in group',
          shownAt: DateTime.utc(2026, 11, 4, 10),
          eventId: 'ev-list-1',
        ),
        GroupLine(
          key: 'l-2',
          text: 'My reply as a player',
          shownAt: DateTime.utc(2026, 11, 4, 10, 1),
          eventId: 'ev-list-2',
        ),
      ];

      await tester.pumpWidget(
        _host(
          GroupMessageList(
            lines: lines,
            memberMap: {'jess': jess},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press character line
      await tester.longPress(find.text('First saved message in group'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);

      // Tap Report to open sheet
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('First saved message in group'), findsNWidgets(2));

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Report this message'), findsNothing);

      // Long press player line opens menu with Copy only
      await tester.longPress(find.text('My reply as a player'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('scrolling is not disturbed by long press detector', (tester) async {
      final member = const GroupMember(id: 'm1', name: 'Member', role: 'Role');
      final lines = List.generate(
        30,
        (i) => GroupLine(
          key: 'scroll-line-$i',
          characterId: 'm1',
          name: 'Member',
          text: 'Line item number $i with plenty of text to display',
          shownAt: DateTime.utc(2026, 11, 4, 10, i),
          eventId: 'ev-$i',
        ),
      );

      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 400,
            child: GroupMessageList(
              lines: lines,
              memberMap: {'m1': member},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line item number 29 with plenty of text to display'), findsOneWidget);

      // Scroll up
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Ensure earlier items become visible
      expect(find.byType(GroupMessageBubble), findsWidgets);
    });
  });
}
