import 'package:everlore/core/guide/guide_flows.dart';
import 'package:everlore/core/guide/guide_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guide flows', () {
    test('flow ids are unique', () {
      final ids = GuideFlows.all.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the Chronicler explains the world, never the interface', () {
      final banned = RegExp(r'\b(tap|taps|tapping|button|screen|click)\b',
          caseSensitive: false);
      for (final flow in GuideFlows.all) {
        for (final beat in flow.beats) {
          expect(banned.hasMatch('${beat.title} ${beat.body}'), isFalse,
              reason: '${flow.id}: "${beat.body}"');
        }
      }
    });

    test('changed arcs are versioned so they run again once', () {
      expect(GuideFlows.spokenLine.version, 2);
      expect(GuideFlows.playMedia.version, 2);
      expect(GuideFlows.playMedia.beats.single.title, 'Picture and Film');
    });

    test('Keepsakes has its own arc, pointing at its shelves', () {
      expect(GuideFlows.all, contains(GuideFlows.keepsakes));
      expect(GuideFlows.keepsakes.route, '/keepsakes');
      expect(GuideFlows.keepsakes.anchorIds, contains(GuideIds.keepsakesFilters));
    });

    test('the tools arc names the turn menu on the newest passage', () {
      final unwriting =
          GuideFlows.playTools.beats.where((b) => b.title == 'Unwriting');
      expect(unwriting, hasLength(1));
      expect(unwriting.single.anchors, contains(GuideIds.playNarrative));
    });

    test('no beat promises a conversation apart from the story', () {
      for (final flow in GuideFlows.all) {
        for (final beat in flow.beats) {
          expect(beat.body.contains('apart from the story'), isFalse,
              reason: flow.id);
        }
      }
    });
  });
}
