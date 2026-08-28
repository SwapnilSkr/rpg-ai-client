import 'package:everlore/shared/widgets/story_prose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 14, height: 1.5);

// Explicit both ways so the renderer never falls back to `EverloreTheme.aiText`,
// which is a Google font and would try to fetch a typeface off the network.
const _narration = TextStyle(fontSize: 14, fontStyle: FontStyle.italic);
const _dialogue = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

List<InlineSpan> _spans(String text) =>
    storyProseSpans(text, narrationStyle: _narration, dialogueStyle: _dialogue);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 300, child: child)),
  ),
);

/// Every string the spans were built from, in order.
List<String> _texts(List<InlineSpan> spans) => [
  for (final s in spans)
    if (s is TextSpan) s.text ?? '',
];

void main() {
  group('storyProseSpans', () {
    test('action markers become italics rather than literal asterisks', () {
      final spans = _spans('*She turns away.*');
      expect(_texts(spans).join(), 'She turns away.');
      expect(_texts(spans).join(), isNot(contains('*')));
      expect((spans.single as TextSpan).style?.fontStyle, FontStyle.italic);
    });

    test('spoken lines are set apart from the narration around them', () {
      final spans = _spans('*He waits.* "You are late." *She sits.*');
      final spoken = spans
          .cast<TextSpan>()
          .where((s) => (s.text ?? '').contains('You are late'))
          .single;
      final narration = spans
          .cast<TextSpan>()
          .where((s) => (s.text ?? '').contains('He waits'))
          .single;
      // Asserting the routing rather than a slant: what matters is that the
      // spoken run is handed the caller's dialogue style and the prose around
      // it the narration style, whatever those two happen to look like.
      expect(spoken.style, _dialogue);
      expect(narration.style, _narration);
      expect(_texts(spans).join(), isNot(contains('*')));
    });

    test('a passage with no markers still renders', () {
      final spans = _spans('Nothing to mark up.');
      expect(_texts(spans).join(), 'Nothing to mark up.');
    });
  });

  group('ExpandableProse', () {
    testWidgets('prose that fits is shown whole, with nothing to dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ExpandableProse(
            text: 'Two lines at most.',
            style: _style,
            accent: Colors.amber,
            collapsedLines: 6,
          ),
        ),
      );
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('prose that overruns is cut, and opens on request', (
      tester,
    ) async {
      final long = List.filled(120, 'lore').join(' ');
      await tester.pumpWidget(
        _host(
          ExpandableProse(
            text: long,
            style: _style,
            accent: Colors.amber,
            collapsedLines: 6,
          ),
        ),
      );

      expect(find.text('Read more'), findsOneWidget);
      final collapsed = tester.getSize(find.byType(ExpandableProse)).height;

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ExpandableProse)).height,
        greaterThan(collapsed),
      );

      // Expanded, the control is now below a 600pt test viewport; tapping its
      // centre without this hits the scroll view instead and silently does
      // nothing.
      await tester.ensureVisible(find.text('Show less'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('the cut is measured on the styled spans, not the raw text', (
      tester,
    ) async {
      // A passage whose markers make it *shorter* than it reads: measuring the
      // raw string would count the asterisks, and a passage that only just
      // fits would be handed a control it does not need.
      await tester.pumpWidget(
        _host(
          ExpandableProse(
            spans: _spans('*A short beat.* "And a line."'),
            style: _style,
            accent: Colors.amber,
            collapsedLines: 6,
          ),
        ),
      );
      expect(find.text('Read more'), findsNothing);
      expect(find.textContaining('*'), findsNothing);
    });
  });
}
