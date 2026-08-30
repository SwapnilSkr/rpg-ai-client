import 'dart:async';
import 'dart:io';

import 'package:everlore/core/errors/user_message.dart';
import 'package:everlore/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('what a thrown object is allowed to say to the player', () {
    test('a refusal the server wrote for a player is shown in its own words', () {
      expect(
        userFacingError(
          ApiException(
            statusCode: 400,
            message:
                'Everlore does not write sexual content between family members.',
          ),
          fallback: 'fallback',
        ),
        startsWith('Everlore does not write sexual content'),
      );
      expect(
        userFacingError(
          ApiException(statusCode: 402, message: 'Not enough Story Ink'),
          fallback: 'fallback',
        ),
        'Not enough Story Ink',
      );
    });

    test('a 5xx body never reaches the player', () {
      // The case this exists for: imageService raises
      // HttpError(502, 'Image generation failed: <provider message>'), so a 5xx
      // body can carry a vendor's words even though most 5xx is flattened to
      // "Internal server error" upstream.
      expect(
        userFacingError(
          ApiException(
            statusCode: 502,
            message: 'Image generation failed: upstream connect error',
          ),
          fallback: 'Could not create that image.',
        ),
        'Could not create that image.',
      );
      expect(
        userFacingError(
          ApiException(statusCode: 500, message: 'Internal server error'),
          fallback: 'fallback',
        ),
        'fallback',
      );
    });

    test('a lost connection is explained without naming hosts or routes', () {
      // The exact failure seen on a device with no DNS: the raw text was
      // "ClientException with SocketException: Failed host lookup:
      // 'api.everloreapp.com' ... uri=https://api.everloreapp.com/auth/otp/send"
      // rendered into the sign-in screen.
      final raw = http.ClientException(
        "Failed host lookup: 'api.everloreapp.com'",
        Uri.parse('https://api.everloreapp.com/auth/otp/send'),
      );
      final shown = userFacingError(raw, fallback: 'fallback');
      expect(shown, connectivityMessage);
      expect(shown, isNot(contains('everloreapp.com')));
      expect(shown, isNot(contains('auth/otp')));

      expect(
        userFacingError(
          const SocketException('Connection refused'),
          fallback: 'fallback',
        ),
        connectivityMessage,
      );
      expect(
        userFacingError(TimeoutException('too slow'), fallback: 'fallback'),
        connectivityMessage,
      );
    });

    test('a body that was not JSON falls back rather than being quoted', () {
      // A gateway error page decodes to a FormatException whose message is the
      // offending text. Showing it hands the player someone else's HTML.
      expect(
        userFacingError(
          const FormatException(
            'Unexpected character',
            '<html>502 Bad Gateway',
          ),
          fallback: 'Could not send the code.',
        ),
        'Could not send the code.',
      );
    });

    test('a bug in the app is not narrated to the player', () {
      expect(
        userFacingError(
          TypeError(),
          fallback: 'Could not save that name. Please try again.',
        ),
        'Could not save that name. Please try again.',
      );
      expect(
        userFacingError(
          Exception('Null check operator used on a null value'),
          fallback: 'fallback',
        ),
        'fallback',
      );
    });

    test('an empty or placeholder server message falls back', () {
      // "Unknown error" is the client's own default when the body had no error
      // field. It is no more useful than the fallback, and the fallback at
      // least names the action that failed.
      expect(
        userFacingError(
          ApiException(statusCode: 400, message: 'Unknown error'),
          fallback: 'Could not send the code.',
        ),
        'Could not send the code.',
      );
      expect(
        userFacingError(
          ApiException(statusCode: 400, message: '   '),
          fallback: 'fallback',
        ),
        'fallback',
      );
      expect(userFacingError(null, fallback: 'fallback'), 'fallback');
    });

    test('connectivity is distinguished from the server saying no', () {
      expect(isConnectivityError(const SocketException('x')), isTrue);
      expect(
        isConnectivityError(ApiException(statusCode: 400, message: 'x')),
        isFalse,
      );
    });
  });
}
