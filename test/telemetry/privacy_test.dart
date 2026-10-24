import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Strings a player could have typed or had on screen. None may ever leave.
const planted = [
  'I draw my sword and whisper to Lady Morwenna',
  'Morwenna the Pale',
  'My Hero Aldric',
  'dreamer@example.com',
  '+919876543210',
  'The Hollow Crown of Ash',
  'slow-burn dragons',
  'secret_choice_text_xyz',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session of realistic actions sends none of the planted text', () async {
    final rig = Rig(token: 'jwt');
    await rig.start();

    // Screens, the way the router reports them.
    for (final s in ['welcome', 'auth', 'onboarding', 'discover', 'template_detail', 'play']) {
      rig.telemetry.screen(s);
      rig.clock.advance(const Duration(seconds: 4));
    }
    // Actions the app records, with only what the contract allows.
    rig.telemetry
      ..track('sign_in_started', {'method': 'phone'})
      ..track('sign_in_completed', {'method': 'phone'})
      ..track('onboarding_completed', {'interests_count': 3})
      ..track('persona_created')
      ..track('world_viewed', {'world_id': '66f0c0ffee66f0c0ffee66f0'})
      ..track('world_started', {'world_id': '66f0c0ffee66f0c0ffee66f0', 'kind': 'gm'})
      ..track('turn_sent', {'input': 'typed'})
      ..track('turn_failed', {'reason': 'server'})
      ..track('media_requested', {'kind': 'picture'})
      ..track('explore_filtered', {'genre': 'Romance'});

    // Errors whose own text is full of the player's words.
    rig.telemetry.recordHandled(
      FormatException(
        'Unexpected character in "${planted[0]}" for ${planted[1]} ${planted[2]} '
        '${planted[3]} ${planted[4]} ${planted[5]} ${planted[6]} ${planted[7]}',
      ),
      httpStatus: 400,
      httpRoute: '/instances/:id/choices',
    );
    // Uncaught errors keep their message, reduced to its shape: quoted text,
    // emails and digit runs go. (Unquoted prose in an exception message is
    // outside what the contract's scrubber can know; our own code does not
    // throw player text unquoted.)
    rig.telemetry.recordPlatformError(
      StateError('Bad state: "${planted[0]}" / ${planted[3]} / ${planted[4]}'),
      StackTrace.empty,
    );
    rig.telemetry.recordFlutterError(
      FlutterErrorDetails(
        exception: Exception("rendering '${planted[1]}' `${planted[2]}`"),
      ),
    );

    await rig.telemetry.settle();
    await rig.telemetry.flush(ignoreBackoff: true);

    final everything = rig.transport.bodies.join('\n');
    expect(everything, isNotEmpty);
    final decoded = jsonDecode(everything.split('\n').first);
    expect(decoded, isA<Map>());
    for (final text in planted) {
      expect(everything, isNot(contains(text)), reason: 'leaked: $text');
    }
    // The password-ish things the contract forbids are not even field names.
    for (final key in ['email', 'phone', 'title', 'text', 'prompt']) {
      expect(everything.contains('"$key":'), isFalse, reason: 'field $key');
    }
  });
}
