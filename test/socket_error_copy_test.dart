import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what a socket error frame is allowed to say to the player', () {
    test('an authored failure speaks in its own words', () {
      expect(
        playerErrorMessage({
          'code': 'INSUFFICIENT_INK',
          'message': 'Not enough Story Ink',
        }, 'fallback'),
        'Not enough Story Ink',
      );
      expect(
        playerErrorMessage({
          'code': 'RATE_LIMITED',
          'message': 'Daily story safety limit reached (40 turns).',
        }, 'fallback'),
        'Daily story safety limit reached (40 turns).',
      );
    });

    test('an internal failure never reaches the player', () {
      // The case this exists for: the replay path rendered the server's
      // message straight into the story surface, so a dropped database
      // connection was shown to the player verbatim.
      expect(
        playerErrorMessage({
          'code': 'INTERNAL',
          'message': 'connect ECONNREFUSED 127.0.0.1:27017',
        }, 'Could not replay this response.'),
        'Could not replay this response.',
      );
      expect(
        isAuthoredSocketError({
          'code': 'INTERNAL',
          'message': "Cannot read properties of undefined (reading 'id')",
        }),
        isFalse,
      );
    });

    test('an unknown code is treated as internal, not as authored', () {
      // A code this build has never heard of is a server ahead of the app.
      // Showing its message would be trusting text this build cannot vouch
      // for, so it falls back.
      expect(
        playerErrorMessage({
          'code': 'SOME_FUTURE_CODE',
          'message': 'raw detail',
        }, 'fallback'),
        'fallback',
      );
    });

    test('a server predating coded errors still explains a spent reserve', () {
      // An app update and a server deploy do not land together. Against an
      // older server the only message that was ever safe to show is the one
      // about Ink, matched the way it always was.
      expect(
        playerErrorMessage({'message': 'Not enough Story Ink'}, 'fallback'),
        'Not enough Story Ink',
      );
      expect(
        playerErrorMessage({'message': 'ETIMEDOUT'}, 'fallback'),
        'fallback',
      );
    });

    test('a blocked line explains the theme so it can be rewritten', () {
      // The input guard refuses a turn with copy naming what to change. It
      // arrives as BAD_REQUEST and must reach the player verbatim — a generic
      // line would leave them guessing, which is the exact failure the guard
      // was built to avoid.
      expect(
        playerErrorMessage({
          'code': 'BAD_REQUEST',
          'message':
              'Everlore does not write sexual content between family members. '
              'Rewrite that line and the scene picks up where it left off.',
        }, 'The scene could not start. Please try again.'),
        startsWith('Everlore does not write sexual content'),
      );
    });

    test('a banned account is told so, not shown a generic retry', () {
      expect(
        playerErrorMessage({
          'code': 'ACCOUNT_BANNED',
          'message': 'This account is banned',
        }, 'fallback'),
        'This account is banned',
      );
    });

    test('only an unauthored failure is worth retrying verbatim', () {
      // The rule the error bar reads: authored failures already said what is
      // wrong and would fail identically on resend, so they drop the action
      // and hand the draft back instead. Internal ones keep retry.
      for (final code in const [
        'INSUFFICIENT_INK',
        'RATE_LIMITED',
        'BAD_REQUEST',
        'ACCOUNT_BANNED',
        'FORBIDDEN',
        'CONFLICT',
      ]) {
        expect(
          isAuthoredSocketError({'code': code, 'message': 'x'}),
          isTrue,
          reason: '$code should not offer retry',
        );
      }
      expect(isAuthoredSocketError({'code': 'INTERNAL', 'message': 'x'}), isFalse);
      expect(isAuthoredSocketError({'message': 'ETIMEDOUT'}), isFalse);
    });

    test('an empty or absent message falls back rather than showing blank', () {
      expect(playerErrorMessage({'code': 'RATE_LIMITED'}, 'fallback'), 'fallback');
      expect(playerErrorMessage({'code': 'INSUFFICIENT_INK', 'message': '  '}, 'fallback'), 'fallback');
      expect(playerErrorMessage(<String, dynamic>{}, 'fallback'), 'fallback');
    });
  });
}
