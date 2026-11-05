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
import 'package:everlore/features/moderation/data/moderation_repository.dart';
import 'package:everlore/features/moderation/presentation/report_sheet.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: child),
);

typedef HttpHandler = Future<http.Response> Function(http.Request request);

void main() {
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
    currentHandler = null;
  });

  group('ModerationRepository.report', () {
    test('sends character_id and text when set for group_line', () async {
      Map<String, dynamic>? sentBody;
      String? sentPath;

      currentHandler = (request) async {
        sentPath = request.url.path;
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'reported': true,
            'report_id': 'rep_1',
            'duplicate': false,
          }),
          200,
        );
      };

      await ModerationRepository.report(
        targetType: 'group_line',
        targetId: 'ev_123',
        characterId: 'char_jess',
        text: 'Meet me at the pub tonight.',
        reason: ReportReason.harassment,
        details: 'Unwanted message',
      );

      expect(sentPath, '/moderation/reports');
      expect(sentBody, {
        'target_type': 'group_line',
        'target_id': 'ev_123',
        'reason': 'harassment_or_hate',
        'character_id': 'char_jess',
        'text': 'Meet me at the pub tonight.',
        'details': 'Unwanted message',
      });
    });

    test('omits character_id and text for world and user reports', () async {
      final List<Map<String, dynamic>> sentBodies = [];

      currentHandler = (request) async {
        sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep_2'}),
          200,
        );
      };

      await ModerationRepository.report(
        targetType: 'world',
        targetId: 'world_456',
        reason: ReportReason.spam,
      );
      await ModerationRepository.report(
        targetType: 'user',
        targetId: 'user_789',
        reason: ReportReason.violence,
      );

      expect(sentBodies.length, 2);
      expect(sentBodies[0], {
        'target_type': 'world',
        'target_id': 'world_456',
        'reason': 'spam_or_misleading',
      });
      expect(sentBodies[0].containsKey('character_id'), isFalse);
      expect(sentBodies[0].containsKey('text'), isFalse);

      expect(sentBodies[1], {
        'target_type': 'user',
        'target_id': 'user_789',
        'reason': 'violence_or_threats',
      });
      expect(sentBodies[1].containsKey('character_id'), isFalse);
      expect(sentBodies[1].containsKey('text'), isFalse);
    });

    test('omits character_id and text for chat_line reports even if passed', () async {
      Map<String, dynamic>? sentBody;

      currentHandler = (request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep_chat_1'}),
          200,
        );
      };

      await ModerationRepository.report(
        targetType: 'chat_line',
        targetId: 'ev_chat_123',
        characterId: 'char_ignored',
        text: 'text_ignored',
        reason: ReportReason.harassment,
        details: 'Chat turn problem',
      );

      expect(sentBody, {
        'target_type': 'chat_line',
        'target_id': 'ev_chat_123',
        'reason': 'harassment_or_hate',
        'details': 'Chat turn problem',
      });
      expect(sentBody!.containsKey('character_id'), isFalse);
      expect(sentBody!.containsKey('text'), isFalse);
    });
  });

  group('showReportChatTurnSheet', () {
    testWidgets('displays title, quotes the passage capped at 3 lines, with no speaker name, and same privacy wording', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportChatTurnSheet(
                  context,
                  eventId: 'ev_chat_100',
                  text: 'Turn passage line 1\nLine 2\nLine 3\nLine 4 is capped',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('Reports are private, and we read every one.'), findsOneWidget);
      expect(find.text('Turn passage line 1\nLine 2\nLine 3\nLine 4 is capped'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Turn passage line 1\nLine 2\nLine 3\nLine 4 is capped'));
      expect(textWidget.maxLines, 3);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      // Verify no speaker name is displayed
      expect(find.text('Someone'), findsNothing);
      expect(find.text('Jess'), findsNothing);
    });

    testWidgets('submitting sends request body with chat_line and event id, never character_id or text', (tester) async {
      Map<String, dynamic>? capturedBody;

      currentHandler = (request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep_chat_200'}),
          200,
        );
      };

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportChatTurnSheet(
                  context,
                  eventId: 'ev_chat_turn_1',
                  text: 'The dragon exhaled a cloud of silver mist.',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(capturedBody, isNotNull);
      expect(capturedBody!['target_type'], 'chat_line');
      expect(capturedBody!['target_id'], 'ev_chat_turn_1');
      expect(capturedBody!['reason'], 'harassment_or_hate');
      expect(capturedBody!.containsKey('character_id'), isFalse);
      expect(capturedBody!.containsKey('text'), isFalse);

      expect(find.text('Report this message'), findsNothing);
      expect(find.text('Report sent. Our team will review it.'), findsOneWidget);
    });

    testWidgets('error keeps sheet open with error message', (tester) async {
      currentHandler = (request) async {
        return http.Response(
          jsonEncode({'error': 'Report already filed for this turn'}),
          409,
        );
      };

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportChatTurnSheet(
                  context,
                  eventId: 'ev_chat_err',
                  text: 'Some turn text',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('Report already filed for this turn'), findsOneWidget);
    });
  });

  group('showReportLineSheet', () {
    testWidgets('displays title, speaker name, and quotes the line capped at 3 lines', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportLineSheet(
                  context,
                  eventId: 'ev_123',
                  characterId: 'char_jess',
                  text: 'Line 1\nLine 2\nLine 3\nLine 4 is capped',
                  speakerName: 'Jess',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('Jess'), findsOneWidget);
      expect(find.text('Line 1\nLine 2\nLine 3\nLine 4 is capped'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Line 1\nLine 2\nLine 3\nLine 4 is capped'));
      expect(textWidget.maxLines, 3);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('submitting sends request body with group_line, event id, character_id, and text', (tester) async {
      Map<String, dynamic>? capturedBody;

      currentHandler = (request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reported': true, 'report_id': 'rep_100'}),
          200,
        );
      };

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportLineSheet(
                  context,
                  eventId: 'ev_999',
                  characterId: 'char_sam',
                  text: 'This is the reported text line.',
                  speakerName: 'Sam',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Select a reason
      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      // Tap send report button
      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(capturedBody, isNotNull);
      expect(capturedBody!['target_type'], 'group_line');
      expect(capturedBody!['target_id'], 'ev_999');
      expect(capturedBody!['character_id'], 'char_sam');
      expect(capturedBody!['text'], 'This is the reported text line.');
      expect(capturedBody!['reason'], 'harassment_or_hate');

      // Sheet is dismissed on success and notice is shown
      expect(find.text('Report this message'), findsNothing);
      expect(find.text('Report sent. Our team will review it.'), findsOneWidget);
    });

    testWidgets('error keeps sheet open with error notice', (tester) async {
      currentHandler = (request) async {
        return http.Response(
          jsonEncode({'error': 'Report already filed for this line'}),
          409,
        );
      };

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showReportLineSheet(
                  context,
                  eventId: 'ev_fail',
                  characterId: 'char_jess',
                  text: 'Error test line',
                  speakerName: 'Jess',
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Harassment or hate'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      // Sheet remains visible with error message
      expect(find.text('Report this message'), findsOneWidget);
      expect(find.text('Report already filed for this line'), findsOneWidget);
    });
  });
}
