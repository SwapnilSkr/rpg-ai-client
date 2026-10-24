import 'package:everlore/core/telemetry/scrubber.dart';
import 'package:everlore/core/telemetry/stack_frames.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrubMessage', () {
    test('quoted text becomes a placeholder, all three quote styles', () {
      expect(
        scrubMessage('Unexpected "my secret line" and \'another one\' and `x y`'),
        "Unexpected '…' and '…' and '…'",
      );
    });

    test('emails, url queries, long digits and ids are reduced', () {
      final out = scrubMessage(
        'mail a.b@c.io failed at https://x.io/p?token=abc&q=1 '
        'code 1234567 id 66f0c0ffee66f0c0ffee66f0 ok 12345',
      );
      expect(out, contains('<email>'));
      expect(out, contains('https://x.io/p?…'));
      expect(out, contains('<n>'));
      expect(out, contains('<id>'));
      expect(out, contains('12345'));
      expect(out, isNot(contains('token=abc')));
      expect(out, isNot(contains('a.b@c.io')));
    });

    test('is cut to 300 characters', () {
      expect(scrubMessage('a' * 900).length, 300);
    });
  });

  group('routeTemplate', () {
    test('replaces ids, keeps words, drops the query', () {
      expect(
        routeTemplate('/instances/66f0c0ffee66f0c0ffee66f0/choices?x=1'),
        '/instances/:id/choices',
      );
      expect(routeTemplate('/users/42/events'), '/users/:id/events');
      expect(
        routeTemplate('/a/123e4567-e89b-42d3-a456-426614174000'),
        '/a/:id',
      );
      expect(routeTemplate('/billing/google/verify'), '/billing/google/verify');
      expect(routeTemplate('personas'), '/personas');
    });
  });

  group('parseFrames', () {
    test('keeps package and dart frames with symbol and line', () {
      final stack = StackTrace.fromString(
        '#0      PlayCubit._onFrame (package:everlore/features/play/state/play_cubit.dart:412:7)\n'
        '#1      _rootRun (dart:async/zone.dart:1399:13)\n'
        '#2      main (file:///Users/someone/app/main.dart:10:3)\n'
        'garbage line\n',
      );
      final frames = parseFrames(stack);
      expect(frames.length, 2);
      expect(frames.first.file, startsWith('package:everlore/'));
      expect(frames.first.symbol, 'PlayCubit._onFrame');
      expect(frames.first.line, 412);
      expect(frames.last.file, 'dart:async/zone.dart');
    });

    test('is capped at 30 and a null stack is empty', () {
      final lines = [
        for (var i = 0; i < 80; i++) '#$i  f$i (package:everlore/a.dart:$i:1)',
      ].join('\n');
      expect(parseFrames(StackTrace.fromString(lines)).length, 30);
      expect(parseFrames(null), isEmpty);
    });
  });
}
