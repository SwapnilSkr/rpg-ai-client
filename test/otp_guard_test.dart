import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/screens/auth_screen.dart';
import 'package:everlore/shared/widgets/neu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
  });

  group('OTP Guard (Enter the Realm button & length check)', () {
    testWidgets('button is disabled at 0 and 5 digits, enabled at exactly 6 digits', (
      tester,
    ) async {
      final phoneController = TextEditingController(text: '5551234567');
      final otpController = TextEditingController();
      int verifyCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PhoneTab(
                phoneController: phoneController,
                otpController: otpController,
                isLoading: false,
                codeSent: true,
                dialCode: kDefaultDialCode,
                onDialCodeChanged: (_) {},
                onSendCode: () async {},
                onVerifyCode: () async {
                  verifyCalls++;
                },
                onEditPhone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(NeuButton, 'Enter the Realm');
      expect(buttonFinder, findsOneWidget);

      // 1. Initial: 0 digits -> button disabled, tapping does not invoke onVerifyCode
      NeuButton btn = tester.widget<NeuButton>(buttonFinder);
      expect(
        btn.onTap,
        isNull,
        reason: 'Enter the Realm button must be disabled when OTP is empty (0 digits)',
      );
      await tester.tap(buttonFinder, warnIfMissed: false);
      expect(verifyCalls, 0);

      // 2. 5 digits -> button remains disabled
      otpController.text = '12345';
      await tester.pump();

      btn = tester.widget<NeuButton>(buttonFinder);
      expect(
        btn.onTap,
        isNull,
        reason: 'Enter the Realm button must be disabled at 5 digits',
      );
      await tester.tap(buttonFinder, warnIfMissed: false);
      expect(verifyCalls, 0);

      // 3. Exactly 6 digits -> OtpField auto-submits, button becomes enabled, tapping also calls verify
      otpController.text = '123456';
      await tester.pump();

      expect(verifyCalls, 1, reason: 'OtpField auto-submits on the 6th digit');

      btn = tester.widget<NeuButton>(buttonFinder);
      expect(
        btn.onTap,
        isNotNull,
        reason: 'Enter the Realm button must be enabled when OTP holds exactly 6 digits',
      );
      await tester.tap(buttonFinder);
      expect(verifyCalls, 2, reason: 'Tapping enabled button triggers onVerifyCode');

      // 4. Back down to 5 digits -> button becomes disabled again
      otpController.text = '12345';
      await tester.pump();

      btn = tester.widget<NeuButton>(buttonFinder);
      expect(
        btn.onTap,
        isNull,
        reason: 'Enter the Realm button must return to disabled if code drops below 6 digits',
      );

      phoneController.dispose();
      otpController.dispose();
    });

    testWidgets('handleVerifyCode returns early without attempting verify when code is < 6 digits', (
      tester,
    ) async {
      final authKey = GlobalKey<AuthScreenState>();

      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(
            path: '/auth',
            builder: (context, state) => AuthScreen(key: authKey),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final authState = authKey.currentState!;

      // 0 digits: handleVerifyCode must return early doing nothing
      authState.otpController.text = '';
      await authState.handleVerifyCode();
      expect(
        authState.isPhoneLoading,
        isFalse,
        reason: 'handleVerifyCode must do nothing if code length is 0',
      );

      // 5 digits: handleVerifyCode must return early doing nothing
      authState.otpController.text = '12345';
      await authState.handleVerifyCode();
      expect(
        authState.isPhoneLoading,
        isFalse,
        reason: 'handleVerifyCode must do nothing if code length is 5',
      );
    });
  });
}
