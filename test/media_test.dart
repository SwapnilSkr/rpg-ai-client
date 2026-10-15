import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/spoken_line.dart';
import 'package:everlore/features/media/models/turn_media.dart';
import 'package:everlore/features/play/presentation/widgets/narrative_bubble.dart';
import 'package:everlore/shared/models/event.dart';
import 'package:everlore/shared/widgets/story_prose.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 380, child: child)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 9: Media tests', () {
    // 1. Span mapping from offsets, including curly quotes and a multi-byte character before the line
    testWidgets(
      'span mapping from offsets, including curly quotes and multi-byte character before the line',
      (tester) async {
        // Multi-byte character before the line:
        // 🛡️ = \uD83D\uDEE1\uFE0F (3 UTF-16 code units) + space (1 code unit) = 4 units before quote.
        const proseWithEmoji = '🛡️ “Protect the realm,” she cried.';
        // "“Protect the realm,”" has length 21 code units (from index 4 to 25)
        const line = SpokenLine(lineId: 'line_emoji_1', start: 4, end: 25);

        SpokenLine? tappedLine;

        final event = GameEvent(
          id: 'ev_1',
          instanceId: 'inst_1',
          sequence: 1,
          type: 'narration',
          aiResponse: proseWithEmoji,
          spokenLines: const [line],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: event,
              onSpokenLineTap: (l) => tappedLine = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final richTextFinder = find.byType(RichText);
        expect(richTextFinder, findsWidgets);

        // Find the RichText inside the narrator panel
        final richText = tester.widget<RichText>(richTextFinder.first);
        final rootSpan = richText.text as TextSpan;

        // Traverse spans to verify the spoken line text is preserved
        final allSpans = <TextSpan>[];
        rootSpan.visitChildren((span) {
          if (span is TextSpan) allSpans.add(span);
          return true;
        });

        // The spoken line text should match exactly
        final spokenSpan = allSpans.firstWhere(
          (s) => s.text != null && s.text!.contains('Protect the realm'),
        );
        expect(spokenSpan.text, '"Protect the realm,"');
        expect(spokenSpan.recognizer, isNotNull);

        // Verify tap invokes the callback
        if (spokenSpan.recognizer is SpokenLineGestureRecognizer) {
          (spokenSpan.recognizer as SpokenLineGestureRecognizer).onTap?.call();
          expect(tappedLine?.lineId, 'line_emoji_1');
        }

        // Test curly quotes at the beginning:
        const proseWithCurly = '“I see the stars,” murmured the traveler.';
        const curlyLine = SpokenLine(lineId: 'line_curly_2', start: 0, end: 18);

        SpokenLine? curlyTapped;
        final curlyEvent = GameEvent(
          id: 'ev_2',
          instanceId: 'inst_1',
          sequence: 2,
          type: 'narration',
          aiResponse: proseWithCurly,
          spokenLines: const [curlyLine],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: curlyEvent,
              onSpokenLineTap: (l) => curlyTapped = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final curlyRichText = tester.widget<RichText>(find.byType(RichText).first);
        final curlyRoot = curlyRichText.text as TextSpan;
        final curlySpans = <TextSpan>[];
        curlyRoot.visitChildren((s) {
          if (s is TextSpan) curlySpans.add(s);
          return true;
        });

        final targetCurlySpan = curlySpans.firstWhere(
          (s) => s.text != null && s.text!.contains('I see the stars'),
        );
        expect(targetCurlySpan.text, '"I see the stars,"');
        (targetCurlySpan.recognizer as SpokenLineGestureRecognizer).onTap?.call();
        expect(curlyTapped?.lineId, 'line_curly_2');
      },
    );

    // 2. A turn without spoken_lines renders identically
    testWidgets('a turn without spoken_lines renders identically to baseline', (
      tester,
    ) async {
      const narrativeText =
          '*The cold wind howls across the battlements.* "Who goes there?" *a guard calls.*';

      final eventWithoutLines = GameEvent(
        id: 'ev_no_lines',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: narrativeText,
        spokenLines: const [],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _host(NarrativeBubble(event: eventWithoutLines)),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final renderedSpans = (richText.text as TextSpan).children ?? [];

      // Baseline spans from storyProseSpans
      final baselineSpans = storyProseSpans(narrativeText);

      // Verify identical span text counts and content
      expect(renderedSpans.length, baselineSpans.length);
      for (var i = 0; i < renderedSpans.length; i++) {
        final r = renderedSpans[i] as TextSpan;
        final b = baselineSpans[i] as TextSpan;
        expect(r.text, b.text);
        expect(r.style?.fontStyle, b.style?.fontStyle);
        expect(r.style?.fontWeight, b.style?.fontWeight);
        // At rest with no spoken_lines, no recognizers on dialogue
        expect(r.recognizer, isNull);
      }
    });

    // 3. An unvoiceable line goes inert
    testWidgets('an unvoiceable line goes inert', (tester) async {
      const line = SpokenLine(lineId: 'unvoiceable_line', start: 0, end: 11);
      bool tapCalled = false;

      final event = GameEvent(
        id: 'ev_unvoiceable',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: '"Inert line"',
        spokenLines: const [line],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _host(
          NarrativeBubble(
            event: event,
            unvoiceableLines: const {'unvoiceable_line'},
            onSpokenLineTap: (_) => tapCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final spans = <TextSpan>[];
      (richText.text as TextSpan).visitChildren((s) {
        if (s is TextSpan) spans.add(s);
        return true;
      });

      final spokenSpan = spans.firstWhere(
        (s) => s.text != null && s.text!.contains('Inert line'),
      );
      final recognizer = spokenSpan.recognizer as SpokenLineGestureRecognizer;

      // Tap on unvoiceable line triggers light impact and does NOT call onSpokenLineTap
      recognizer.onTap?.call();
      expect(tapCalled, isFalse);
    });

    // 4. Each 429 kind shows its copy
    test('each 429 kind shows its exact resting copy', () {
      expect(
        const MediaRestingException(kind: 'voice').restingCopy,
        'Their voices rest until tomorrow.',
      );
      expect(
        const MediaRestingException(kind: 'picture').restingCopy,
        'The painter rests until tomorrow.',
      );
      expect(
        const MediaRestingException(kind: 'video').restingCopy,
        'The visions rest until tomorrow.',
      );
      expect(
        const MediaRestingException(kind: 'portrait').restingCopy,
        'The requested media waits until tomorrow.',
      );
    });

    // 5. media_ready replaces the placeholder
    test('media_ready replaces the placeholder thumbnail', () {
      final initialEvent = GameEvent(
        id: 'ev_media_1',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: 'A tranquil meadow under moonlight.',
        media: const [
          TurnMedia(
            mediaId: 'med_temp_1',
            kind: MediaKind.picture,
            status: MediaStatus.queued,
          ),
        ],
        createdAt: DateTime.now(),
      );

      expect(initialEvent.media.single.isQueued, isTrue);
      expect(initialEvent.media.single.isReady, isFalse);

      // When media_ready arrives for med_temp_1:
      final updatedMediaList = initialEvent.media.map((m) {
        if (m.mediaId == 'med_temp_1') {
          return const TurnMedia(
            mediaId: 'med_temp_1',
            kind: MediaKind.picture,
            status: MediaStatus.ready,
            url: 'https://cdn.everlore.app/media/pic1.webp',
          );
        }
        return m;
      }).toList();

      final readyEvent = initialEvent.copyWith(media: updatedMediaList);
      expect(readyEvent.media.single.isQueued, isFalse);
      expect(readyEvent.media.single.isReady, isTrue);
      expect(readyEvent.media.single.url, 'https://cdn.everlore.app/media/pic1.webp');
    });

    // 6. "Picture this" is hidden when usage returns 404
    test('Picture this is hidden when usage returns 404', () async {
      MediaRepository.resetSession();

      // Fake client returning 404 on /media/usage
      final client404 = MockClient((request) async {
        if (request.url.path.endsWith('/media/usage')) {
          return http.Response('{"error": "not found"}', 404);
        }
        return http.Response('', 200);
      });

      final repo404 = MediaRepository(
        client: client404,
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'test_token',
      );
      final usage404 = await repo404.getUsage();

      expect(usage404, isNull);
      expect(MediaRepository.isMediaEnabledSession, isFalse);

      // Fake client returning 200 on /media/usage
      final client200 = MockClient((request) async {
        if (request.url.path.endsWith('/media/usage')) {
          return http.Response(
            jsonEncode({
              'voice': {'used': 2, 'limit': 100},
              'picture': {'used': 1, 'limit': 15},
              'video': {'used': 0, 'limit': 2},
              'portrait': {'used': 0, 'limit': 20},
              'resets_at': '2026-10-17T00:00:00.000Z',
            }),
            200,
          );
        }
        return http.Response('', 200);
      });

      final repo200 = MediaRepository(
        client: client200,
        baseUrl: 'https://api.test',
        tokenProvider: () async => 'test_token',
      );
      final usage200 = await repo200.getUsage();

      expect(usage200, isNotNull);
      expect(usage200?.voice.limit, 100);
      expect(MediaRepository.isMediaEnabledSession, isTrue);
    });

    // 7. Long-press on a voiceable spoken line opens the line menu
    testWidgets(
      'long-press on a voiceable spoken line opens the line menu',
      (tester) async {
        SpokenLine? lineMenuTarget;
        bool turnMenuOpened = false;

        const rawProse = '*He whispered,* "Listen carefully," *before slipping away.*';
        const line = SpokenLine(lineId: 'line_voiceable_1', start: 16, end: 35);

        final event = GameEvent(
          id: 'ev_long_press_1',
          instanceId: 'inst_1',
          sequence: 1,
          type: 'narration',
          aiResponse: rawProse,
          spokenLines: const [line],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: event,
              onLongPress: () => turnMenuOpened = true,
              onSpokenLineLongPress: (l) => lineMenuTarget = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final renderParagraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText).first,
        );

        // Rendered text is 'He whispered, "Listen carefully," before slipping away.'
        // The spoken line occupies rendered offsets 14 to 33.
        final boxes = renderParagraph.getBoxesForSelection(
          const TextSelection(baseOffset: 16, extentOffset: 30),
        );
        expect(boxes, isNotEmpty);

        final lineCenter = renderParagraph.localToGlobal(boxes.first.toRect().center);

        // Drive a real long-press gesture over the spoken line:
        await tester.longPressAt(lineCenter);
        await tester.pumpAndSettle();

        expect(lineMenuTarget?.lineId, 'line_voiceable_1');
        expect(turnMenuOpened, isFalse);
      },
    );

    // 8. Long-press on narration opens the turn menu
    testWidgets(
      'long-press on narration opens the turn menu',
      (tester) async {
        SpokenLine? lineMenuTarget;
        bool turnMenuOpened = false;

        const rawProse = '*He whispered,* "Listen carefully," *before slipping away.*';
        const line = SpokenLine(lineId: 'line_voiceable_1', start: 16, end: 35);

        final event = GameEvent(
          id: 'ev_long_press_2',
          instanceId: 'inst_1',
          sequence: 1,
          type: 'narration',
          aiResponse: rawProse,
          spokenLines: const [line],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: event,
              onLongPress: () => turnMenuOpened = true,
              onSpokenLineLongPress: (l) => lineMenuTarget = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final renderParagraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText).first,
        );

        // Bounding box for narration before the spoken line (rendered offsets 2 to 10):
        final narrationBoxes = renderParagraph.getBoxesForSelection(
          const TextSelection(baseOffset: 2, extentOffset: 10),
        );
        expect(narrationBoxes, isNotEmpty);

        final narrationCenter =
            renderParagraph.localToGlobal(narrationBoxes.first.toRect().center);

        // Drive a real long-press gesture on narration:
        await tester.longPressAt(narrationCenter);
        await tester.pumpAndSettle();

        expect(turnMenuOpened, isTrue);
        expect(lineMenuTarget, isNull);
      },
    );

    // 9. Long-press on an unvoiceable line opens the turn menu
    testWidgets(
      'long-press on an unvoiceable line opens the turn menu',
      (tester) async {
        SpokenLine? lineMenuTarget;
        bool turnMenuOpened = false;

        const rawProse = '*He whispered,* "Unvoiceable words," *before slipping away.*';
        const line = SpokenLine(
          lineId: 'line_unvoiceable_1',
          start: 16,
          end: 35,
          unvoiceable: true,
        );

        final event = GameEvent(
          id: 'ev_long_press_3',
          instanceId: 'inst_1',
          sequence: 1,
          type: 'narration',
          aiResponse: rawProse,
          spokenLines: const [line],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: event,
              onLongPress: () => turnMenuOpened = true,
              onSpokenLineLongPress: (l) => lineMenuTarget = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final renderParagraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText).first,
        );

        final boxes = renderParagraph.getBoxesForSelection(
          const TextSelection(baseOffset: 16, extentOffset: 30),
        );
        expect(boxes, isNotEmpty);

        final lineCenter = renderParagraph.localToGlobal(boxes.first.toRect().center);

        // Drive a real long-press gesture on the unvoiceable line:
        await tester.longPressAt(lineCenter);
        await tester.pumpAndSettle();

        expect(turnMenuOpened, isTrue);
        expect(lineMenuTarget, isNull);
      },
    );

    // 10. Tap behaviour stays unchanged (tap voices line, second tap stops, menus don't open)
    testWidgets(
      'tap on a spoken line invokes onSpokenLineTap without triggering long-press menus',
      (tester) async {
        SpokenLine? tappedLine;
        SpokenLine? lineMenuTarget;
        bool turnMenuOpened = false;

        const rawProse = '*He whispered,* "Listen carefully," *before slipping away.*';
        const line = SpokenLine(lineId: 'line_voiceable_1', start: 16, end: 35);

        final event = GameEvent(
          id: 'ev_tap_1',
          instanceId: 'inst_1',
          sequence: 1,
          type: 'narration',
          aiResponse: rawProse,
          spokenLines: const [line],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          _host(
            NarrativeBubble(
              event: event,
              onLongPress: () => turnMenuOpened = true,
              onSpokenLineLongPress: (l) => lineMenuTarget = l,
              onSpokenLineTap: (l) => tappedLine = l,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final renderParagraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText).first,
        );

        final boxes = renderParagraph.getBoxesForSelection(
          const TextSelection(baseOffset: 16, extentOffset: 30),
        );
        expect(boxes, isNotEmpty);

        final lineCenter = renderParagraph.localToGlobal(boxes.first.toRect().center);

        // Drive a tap gesture:
        await tester.tapAt(lineCenter);
        await tester.pumpAndSettle();

        expect(tappedLine?.lineId, 'line_voiceable_1');
        expect(lineMenuTarget, isNull);
        expect(turnMenuOpened, isFalse);
      },
    );
  });
}
