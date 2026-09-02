import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/shared/text_format.dart';

void main() {
  group('countLabel', () {
    test('a count of one takes the singular', () {
      // The realm card read "1 events • 1 echoes", which is the shape of a
      // database row rather than of a story.
      expect(countLabel(1, 'event'), '1 event');
      expect(countLabel(1, 'turn'), '1 turn');
      expect(countLabel(1, 'echo', plural: 'echoes'), '1 echo');
      expect(countLabel(1, 'story', plural: 'stories'), '1 story');
    });

    test('every other count takes the plural', () {
      expect(countLabel(0, 'event'), '0 events');
      expect(countLabel(3, 'event'), '3 events');
      expect(countLabel(0, 'echo', plural: 'echoes'), '0 echoes');
      expect(countLabel(12, 'story', plural: 'stories'), '12 stories');
    });

    test('an irregular plural is never guessed from the singular', () {
      expect(countLabel(2, 'echo'), isNot('2 echoes'));
      expect(countLabel(2, 'echo', plural: 'echoes'), '2 echoes');
    });
  });

  group('sceneMomentLabel', () {
    test('never shows the player an internal scene mode', () {
      // Every tag the narrator can emit. A young story listed itself as
      // "Dialogue / Dialogue / Dialogue" in the almanac and headed its
      // playthrough card the same way.
      const tags = [
        'dialogue',
        'combat',
        'romantic',
        'intimate',
        'exploration',
        'existential',
        'cosmic',
        'mundane',
      ];
      for (final tag in tags) {
        final label = sceneMomentLabel(tag, '');
        expect(
          label.toLowerCase().contains(tag),
          isFalse,
          reason: 'the tag "$tag" leaked into its own label: "$label"',
        );
        expect(label.trim(), isNotEmpty);
      }
    });

    test('falls back to the event type when there is no scene tag', () {
      expect(sceneMomentLabel(null, 'dialogue'), 'Words exchanged');
      expect(sceneMomentLabel('', 'combat'), 'Blows exchanged');
    });

    test('an unknown tag is at least humanised, never raw', () {
      expect(sceneMomentLabel('war_council', ''), 'War council');
    });

    test('nothing at all still names the moment', () {
      expect(sceneMomentLabel(null, ''), 'A moment');
      expect(sceneMomentLabel('   ', '  '), 'A moment');
    });
  });

  group('humanizeTag', () {
    test('machine tokens become prose', () {
      expect(humanizeTag('royal_palace'), 'Royal palace');
      expect(humanizeTag('court-intrigue'), 'Court intrigue');
    });

    test('text already written for a reader is left alone', () {
      expect(humanizeTag('The Ashen Gate'), 'The Ashen Gate');
    });
  });
}
