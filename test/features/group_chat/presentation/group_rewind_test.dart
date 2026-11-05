import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_message_bubble.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_rewind.dart';
import 'package:everlore/features/group_chat/state/group_chat_state.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

GroupLine _line({
  String key = 'l',
  String? characterId = 'char-jess',
  String? eventId = 'ev',
  int? sequence = 3,
  bool action = false,
  GroupLineStatus status = GroupLineStatus.sent,
  String text = 'Hello there.',
}) => GroupLine(
  key: key,
  characterId: characterId,
  name: characterId == null ? '' : 'Jess',
  text: text,
  shownAt: DateTime.utc(2026, 11, 4, 12),
  eventId: eventId,
  sequence: sequence,
  isAction: action,
  status: status,
);

void main() {
  final List<MethodCall> platformCalls = [];
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
      if (key == 'assets/icons/app_icon.png') {
        // The loader draws the app icon; a 1x1 picture is enough.
        return ByteData.view(Uint8List.fromList(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        )).buffer);
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
  });

  setUp(() {
    platformCalls.clear();
    clipboardData = null;
  });

  Future<void> openMenu(
    WidgetTester tester,
    GroupLine line, {
    void Function(GroupLine)? onRewind,
  }) async {
    await tester.pumpWidget(
      _host(GroupMessageBubble(line: line, onRewindLine: onRewind)),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text(line.text));
    await tester.pumpAndSettle();
  }

  group('Rewind in the message menu', () {
    testWidgets('shows on a saved character, player and action line after the opening', (tester) async {
      final cases = {
        'character': _line(),
        'player': _line(characterId: null, text: 'I go.'),
        'action': _line(characterId: null, action: true, text: 'Waves.'),
      };
      for (final entry in cases.entries) {
        await openMenu(tester, entry.value, onRewind: (_) {});
        expect(find.text('Rewind to here'), findsOneWidget, reason: entry.key);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.byIcon(Icons.history_toggle_off), findsOneWidget);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('comes after Report and leaves Report as it was', (tester) async {
      await openMenu(tester, _line(), onRewind: (_) {});
      expect(find.text('Report'), findsOneWidget);
      final report = tester.getTopLeft(find.text('Report')).dy;
      final rewind = tester.getTopLeft(find.text('Rewind to here')).dy;
      expect(rewind, greaterThan(report));
    });

    testWidgets('is absent on the opening, an unsaved line, and while rewinding is not possible', (tester) async {
      await openMenu(tester, _line(sequence: 1), onRewind: (_) {});
      expect(find.text('Rewind to here'), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      await openMenu(
        tester,
        _line(characterId: null, eventId: null, sequence: null, status: GroupLineStatus.sending, text: 'Sending.'),
        onRewind: (_) {},
      );
      expect(find.text('Rewind to here'), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      // A line saved but not yet numbered.
      await openMenu(tester, _line(sequence: null), onRewind: (_) {});
      expect(find.text('Rewind to here'), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      // No callback: a turn is running or queued, or a rewind is in flight.
      await openMenu(tester, _line());
      expect(find.text('Rewind to here'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('asks first, with the agreed words; Cancel does nothing', (tester) async {
      GroupLine? rewound;
      await openMenu(tester, _line(), onRewind: (l) => rewound = l);
      await tester.tap(find.text('Rewind to here'));
      await tester.pumpAndSettle();

      expect(find.text('Rewind the chat?'), findsOneWidget);
      expect(
        find.text(
          'This turn and everything after it will be removed, including later '
          "messages in the group and in direct chats. This can't be undone.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Rewind the chat?'), findsNothing);
      expect(rewound, isNull);
    });

    testWidgets('Rewind in the dialog rewinds to that line', (tester) async {
      GroupLine? rewound;
      await openMenu(tester, _line(sequence: 6), onRewind: (l) => rewound = l);
      await tester.tap(find.text('Rewind to here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rewind'));
      await tester.pumpAndSettle();
      expect(rewound?.sequence, 6);
    });
  });

  group('canRewindGroup', () {
    test('only when nothing is being written, waiting or rewinding', () {
      const idle = GroupChatState(instanceId: 'i');
      expect(canRewindGroup(idle), isTrue);
      expect(canRewindGroup(idle.copyWith(turnInFlight: true)), isFalse);
      expect(canRewindGroup(idle.copyWith(queuedSends: 1)), isFalse);
      expect(canRewindGroup(idle.copyWith(rewinding: true)), isFalse);
    });
  });

  group('GroupRewindVeil', () {
    testWidgets('blocks taps while a rewind runs and is gone otherwise', (tester) async {
      var taps = 0;
      Widget host(bool active) => _host(
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
            ),
            GroupRewindVeil(active: active),
          ],
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
      await tester.pumpWidget(host(true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
      expect(find.text('REWINDING THE CHAT'), findsOneWidget);
    });
  });
}
