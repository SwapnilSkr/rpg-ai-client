import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:everlore/core/network/api_client.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/shared/widgets/neu.dart';

ApiException _fail(int status, String code, String copy, {int? retryAfter}) =>
    ApiException(
      statusCode: status,
      message: copy,
      code: code,
      retryAfter: retryAfter,
    );

ApiException _parsed(int status, String body) {
  try {
    ApiClient.parseResponse(http.Response(body, status));
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('expected an ApiException');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
  });

  group('ApiException from a failure body', () {
    test('carries code and retryAfter', () {
      final e = _parsed(
        429,
        '{"error":"Too many tries.","code":"verify_limited","retryAfter":540}',
      );
      expect(e.statusCode, 429);
      expect(e.message, 'Too many tries.');
      expect(e.code, 'verify_limited');
      expect(e.retryAfter, 540);
    });

    test('stays fine without them', () {
      final e = _parsed(400, '{"error":"Nope"}');
      expect(e.message, 'Nope');
      expect(e.code, isNull);
      expect(e.retryAfter, isNull);
      final text = _parsed(502, '<html>bad gateway</html>');
      expect(text.code, isNull);
      expect(ApiException(statusCode: 1, message: 'm').retryAfter, isNull);
    });
  });

  group('sign-in recovery', () {
    late GlobalKey<AuthScreenState> key;
    late int sends;
    late List<String> verified;
    late List<Object> verifyScript;
    late Object? sendFailure;

    Future<void> pump(WidgetTester tester) async {
      key = GlobalKey<AuthScreenState>();
      sends = 0;
      verified = [];
      verifyScript = [];
      sendFailure = null;
      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(
            path: '/auth',
            builder: (context, state) => AuthScreen(
              key: key,
              sendCode: (phone) async {
                sends++;
                final f = sendFailure;
                if (f != null) throw f;
                return true;
              },
              // Every scripted outcome is a failure: building a signed-in User
              // would drag in routing, and the count of posts is the point.
              verifyCode: ({required phone, required code}) async {
                verified.add(code);
                throw verifyScript.removeAt(0);
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> sendFirstCode(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '5551234567');
      await tester.tap(find.widgetWithText(NeuButton, 'Send the Code'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final c in [
      ('code_locked', 429, 'Too many tries. Send a new code.'),
      ('code_expired', 410, 'That code has expired. Send a new code.'),
    ]) {
      testWidgets('${c.$1}: copy, no resubmit, one-tap new code', (
        tester,
      ) async {
        await pump(tester);
        verifyScript = [
          _fail(c.$2, c.$1, c.$3),
          _fail(400, 'code_invalid', "That code isn't right."),
        ];
        await sendFirstCode(tester);
        expect(sends, 1);

        final auth = key.currentState!;
        auth.otpController.text = '123456'; // auto-submits once
        await tester.pump(const Duration(milliseconds: 400));
        expect(verified, ['123456']);
        expect(find.text(c.$3), findsOneWidget);

        // Verify is replaced by the new-code action.
        expect(find.widgetWithText(NeuButton, 'Enter the Realm'), findsNothing);
        expect(find.widgetWithText(NeuButton, 'Send new code'), findsOneWidget);

        // The spent code is never posted again, however the field is edited.
        await auth.handleVerifyCode();
        auth.otpController.text = '12345';
        auth.otpController.text = '654321';
        await tester.pump(const Duration(milliseconds: 400));
        await auth.handleVerifyCode();
        expect(verified, ['123456']);

        await tester.tap(find.widgetWithText(NeuButton, 'Send new code'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(sends, 2);
        expect(auth.otpController.text, isEmpty);
        expect(
          find.widgetWithText(NeuButton, 'Enter the Realm'),
          findsOneWidget,
        );
        expect(find.textContaining('Resend code in 0:30'), findsOneWidget);

        // A new code verifies again (here: a plain wrong-code reply).
        auth.otpController.text = '222333';
        await tester.pump(const Duration(milliseconds: 400));
        expect(verified, ['123456', '222333']);
        expect(find.text("That code isn't right."), findsOneWidget);
        expect(find.widgetWithText(NeuButton, 'Send new code'), findsNothing);

        await tester.pump(const Duration(seconds: 31));
      });
    }

    testWidgets('send_limited holds the send button for retryAfter', (
      tester,
    ) async {
      await pump(tester);
      sendFailure = _fail(
        429,
        'send_limited',
        "You've asked for a lot of codes. Wait 10 minutes, then try again.",
        retryAfter: 90,
      );
      await sendFirstCode(tester);

      expect(find.textContaining('Wait 10 minutes'), findsOneWidget);
      final held = find.widgetWithText(NeuButton, 'Try again in 1:30');
      expect(held, findsOneWidget);
      expect(tester.widget<NeuButton>(held).onTap, isNull);

      await tester.pump(const Duration(seconds: 91));
      expect(find.widgetWithText(NeuButton, 'Send the Code'), findsOneWidget);
    });

    testWidgets('verify_limited without retryAfter waits 10 minutes', (
      tester,
    ) async {
      await pump(tester);
      verifyScript = [
        _fail(429, 'verify_limited', 'Too many tries. Wait a few minutes.'),
      ];
      await sendFirstCode(tester);
      key.currentState!.otpController.text = '123456';
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Too many tries. Wait a few minutes.'), findsOneWidget);
      expect(find.textContaining('Resend code in 10:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 601));
    });
  });
}
