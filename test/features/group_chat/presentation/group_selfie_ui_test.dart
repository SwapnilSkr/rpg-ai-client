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
import 'package:everlore/features/group_chat/presentation/widgets/group_selfie_frame.dart';
import 'package:everlore/features/media/presentation/media_viewer_sheet.dart';
import 'package:everlore/features/moderation/presentation/report_sheet.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _hostList(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

typedef HttpHandler = Future<http.Response> Function(http.Request request);

void main() {
  GroupSelfieFrame.animatePending = false;
  final List<MethodCall> platformCalls = [];
  HttpHandler? currentHandler;

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
      return null;
    });

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
  });

  const member = GroupMember(id: 'char-1', name: 'Lyra', role: 'mage');

  GroupLine makeLine({
    String? characterId = 'char-1',
    String? lineId = 'line-1',
    String? eventId = 'ev-1',
    bool isAction = false,
    GroupSelfie? selfie,
  }) {
    return GroupLine(
      key: 'key-1',
      characterId: characterId,
      name: 'Lyra',
      text: 'Greetings traveler',
      shownAt: DateTime.utc(2026, 11, 5, 12),
      lineId: lineId,
      eventId: eventId,
      isAction: isAction,
      selfie: selfie,
    );
  }

  group('Requirement 1: Menu item "Ask for a selfie"', () {
    testWidgets('shows on saved character line when line has no selfie',
        (tester) async {
      GroupLine? requestedLine;
      final line = makeLine();

      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (l) => requestedLine = l,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsOneWidget);

      await tester.tap(find.text('Ask for a selfie'));
      await tester.pumpAndSettle();

      expect(requestedLine, equals(line));
    });

    testWidgets('shows when selfie is failed', (tester) async {
      final line = makeLine(selfie: const GroupSelfie(status: SelfieStatus.failed));
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsOneWidget);
    });

    testWidgets('shows when selfie is unseen', (tester) async {
      final line = makeLine(selfie: const GroupSelfie(status: SelfieStatus.unseen));
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsOneWidget);
    });

    testWidgets('shows when selfie is resting and allowance has expired',
        (tester) async {
      final now = DateTime.utc(2026, 11, 5, 12, 0);
      final expired = DateTime.utc(2026, 11, 5, 11, 0);
      final line = makeLine(
        selfie: GroupSelfie(status: SelfieStatus.resting, resetsAt: expired),
      );

      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsOneWidget);
    });

    testWidgets('hides on player line', (tester) async {
      final line = makeLine(characterId: null); // player line has no characterId
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides on action line', (tester) async {
      final line = makeLine(isAction: true);
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when lineId is null', (tester) async {
      final line = makeLine(lineId: null);
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when eventId is null', (tester) async {
      final line = makeLine(eventId: null);
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when characterId is empty', (tester) async {
      final line = makeLine(characterId: '');
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when selfie is queued', (tester) async {
      final line = makeLine(selfie: const GroupSelfie(status: SelfieStatus.queued));
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when selfie is processing', (tester) async {
      final line = makeLine(selfie: const GroupSelfie(status: SelfieStatus.processing));
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when selfie is ready', (tester) async {
      final line = makeLine(
        selfie: const GroupSelfie(
          status: SelfieStatus.ready,
          mediaId: 'm1',
          url: 'https://img.test/pic.png',
        ),
      );
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when selfie is actively resting', (tester) async {
      final now = DateTime.utc(2026, 11, 5, 12, 0);
      final future = DateTime.utc(2026, 11, 5, 14, 0);
      final line = makeLine(
        selfie: GroupSelfie(status: SelfieStatus.resting, resetsAt: future),
      );
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: (_) {},
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });

    testWidgets('hides when rewind is in progress (onRequestSelfie == null)',
        (tester) async {
      final line = makeLine();
      await tester.pumpWidget(
        _host(
          GroupMessageBubble(
            line: line,
            member: member,
            onRequestSelfie: null, // disabled during rewind
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Greetings traveler'));
      await tester.pumpAndSettle();

      expect(find.text('Ask for a selfie'), findsNothing);
    });
  });

  group('Requirement 2: Frame states, words, dimensions, and interactions', () {
    testWidgets('frame has a fixed size in every state',
        (tester) async {
      final now = DateTime.utc(2026, 11, 5, 12, 0);
      final testSelfies = [
        const GroupSelfie(status: SelfieStatus.queued),
        const GroupSelfie(status: SelfieStatus.processing),
        const GroupSelfie(
          status: SelfieStatus.ready,
          mediaId: 'm1',
          url: 'https://img.test/p.png',
        ),
        const GroupSelfie(status: SelfieStatus.failed),
        const GroupSelfie(status: SelfieStatus.unseen),
        GroupSelfie(
          status: SelfieStatus.resting,
          resetsAt: DateTime.utc(2026, 11, 5, 13, 0),
        ),
        GroupSelfie(
          status: SelfieStatus.resting,
          resetsAt: DateTime.utc(2026, 11, 5, 11, 0),
        ),
      ];

      for (final selfie in testSelfies) {
        final line = makeLine(selfie: selfie);
        await tester.pumpWidget(
          _host(
            GroupSelfieFrame(
              line: line,
              member: member,
              now: now,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final size = tester.getSize(find.byType(GroupSelfieFrame));
        expect(size.width, 200.0,
            reason: 'Width must be 200 for ${selfie.status}');
        // Only a picture, or one on its way, holds the full height.
        final holdsPicture = selfie.isPending ||
            selfie.status == SelfieStatus.ready;
        expect(
            size.height,
            holdsPicture
                ? GroupSelfieFrame.frameHeight
                : GroupSelfieFrame.messageHeight,
            reason: 'Height for ${selfie.status}');
      }
    });

    testWidgets('failed and unseen display exact words, and tap calls requestSelfie',
        (tester) async {
      for (final status in [SelfieStatus.failed, SelfieStatus.unseen]) {
        var tapped = false;
        final line = makeLine(selfie: GroupSelfie(status: status));

        await tester.pumpWidget(
          _host(
            GroupSelfieFrame(
              line: line,
              member: member,
              onRequestSelfie: () => tapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("This picture didn't come through."), findsOneWidget);
        expect(find.text('Tap to try again'), findsOneWidget);

        await tester.tap(find.byType(GroupSelfieFrame));
        await tester.pumpAndSettle();

        expect(tapped, isTrue, reason: 'Tap should call callback for $status');
      }
    });

    testWidgets('resting and isRestingAt displays "More pictures at <time>" for same day',
        (tester) async {
      final now = DateTime(2026, 11, 5, 10, 0);
      final resetsAt = DateTime(2026, 11, 5, 14, 30);
      final line = makeLine(
        selfie: GroupSelfie(status: SelfieStatus.resting, resetsAt: resetsAt.toUtc()),
      );

      late String expectedTime;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              expectedTime =
                  TimeOfDay.fromDateTime(resetsAt).format(context);
              return GroupSelfieFrame(
                line: line,
                member: member,
                now: now,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('More pictures at $expectedTime'), findsOneWidget);
    });

    testWidgets('resting and isRestingAt displays "More pictures tomorrow at <time>" for next day',
        (tester) async {
      final now = DateTime(2026, 11, 5, 22, 0);
      final resetsAt = DateTime(2026, 11, 6, 2, 0); // tomorrow
      final line = makeLine(
        selfie: GroupSelfie(status: SelfieStatus.resting, resetsAt: resetsAt.toUtc()),
      );

      late String expectedTime;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              expectedTime =
                  TimeOfDay.fromDateTime(resetsAt).format(context);
              return GroupSelfieFrame(
                line: line,
                member: member,
                now: now,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('More pictures tomorrow at $expectedTime'), findsOneWidget);
    });

    testWidgets('resting and expired (or no time) displays "Tap for the picture" and tap calls callback',
        (tester) async {
      final now = DateTime(2026, 11, 5, 15, 0);
      final expired = DateTime(2026, 11, 5, 12, 0);
      final lineExpired = makeLine(
        selfie: GroupSelfie(status: SelfieStatus.resting, resetsAt: expired.toUtc()),
      );
      final lineNoTime = makeLine(
        selfie: const GroupSelfie(status: SelfieStatus.resting, resetsAt: null),
      );

      for (final line in [lineExpired, lineNoTime]) {
        var tapped = false;
        await tester.pumpWidget(
          _host(
            GroupSelfieFrame(
              line: line,
              member: member,
              now: now,
              onRequestSelfie: () => tapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tap for the picture'), findsOneWidget);

        await tester.tap(find.byType(GroupSelfieFrame));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      }
    });

    testWidgets('ready selfie: tap opens MediaViewerSheet', (tester) async {
      final line = makeLine(
        selfie: const GroupSelfie(
          status: SelfieStatus.ready,
          mediaId: 'media-42',
          url: 'https://img.test/lyra.png',
        ),
      );

      await tester.pumpWidget(
        _host(
          GroupSelfieFrame(
            line: line,
            member: member,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MediaViewerSheet), findsNothing);

      await tester.tap(find.byType(GroupSelfieFrame));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // route transition

      expect(find.byType(MediaViewerSheet), findsOneWidget);

      // Close viewer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MediaViewerSheet), findsNothing);
    });

    testWidgets('ready selfie: long press opens menu with Report item, and opens report sheet',
        (tester) async {
      final line = makeLine(
        selfie: const GroupSelfie(
          status: SelfieStatus.ready,
          mediaId: 'media-42',
          url: 'https://img.test/lyra.png',
        ),
      );

      await tester.pumpWidget(
        _host(
          GroupSelfieFrame(
            line: line,
            member: member,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.byType(GroupSelfieFrame));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Report'), findsOneWidget);

      await tester.tap(find.text('Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Report sheet opened
      expect(find.text('Lyra'), findsOneWidget);
    });
  });

  group('Requirement 3: showReportSelfieSheet in report_sheet.dart', () {
    testWidgets('submits group_selfie with targetId mediaId and no characterId or text',
        (tester) async {
      Map<String, dynamic>? submittedBody;

      currentHandler = (request) async {
        submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep-selfie-1'}),
          200,
        );
      };

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportSelfieSheet(
                  context,
                  mediaId: 'selfie-media-99',
                  speakerName: 'Jess',
                );
              },
              child: const Text('Open Report'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      expect(find.text('Jess'), findsOneWidget);

      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(submittedBody, isNotNull);
      expect(submittedBody!['target_type'], 'group_selfie');
      expect(submittedBody!['target_id'], 'selfie-media-99');
      expect(submittedBody!['reason'], 'harassment_or_hate');
      expect(submittedBody!.containsKey('character_id'), isFalse);
      expect(submittedBody!.containsKey('text'), isFalse);
    });
  });

  group('GroupMessageList integration', () {
    testWidgets('renders selfie frame under line and tapping retry calls callback',
        (tester) async {
      GroupLine? tappedLine;
      final line = makeLine(
        selfie: const GroupSelfie(status: SelfieStatus.failed),
      );

      await tester.pumpWidget(
        _hostList(
          GroupMessageList(
            lines: [line],
            memberMap: {'char-1': member},
            onRequestSelfie: (l) => tappedLine = l,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GroupSelfieFrame), findsOneWidget);
      expect(find.text("This picture didn't come through."), findsOneWidget);

      await tester.tap(find.text('Tap to try again'));
      await tester.pumpAndSettle();

      expect(tappedLine, equals(line));
    });

    testWidgets('passes null onRequestSelfie during rewind to hide retry tap',
        (tester) async {
      final line = makeLine(
        selfie: const GroupSelfie(status: SelfieStatus.failed),
      );

      await tester.pumpWidget(
        _hostList(
          GroupMessageList(
            lines: [line],
            memberMap: {'char-1': member},
            onRequestSelfie: null, // during rewind
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GroupSelfieFrame), findsOneWidget);

      // Tap does not crash or trigger anything
      await tester.tap(find.text('Tap to try again'));
      await tester.pumpAndSettle();
    });
  });
}
