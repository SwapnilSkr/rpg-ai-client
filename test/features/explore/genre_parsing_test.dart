import 'package:everlore/shared/models/explore_genre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreGenre parsing & visibility', () {
    test('parses new nested shape from GET /templates/genres', () {
      final json = {
        'key': 'romance',
        'label': 'Romance',
        'worlds': 3,
        'characters': 30,
        'styles': {
          'dark_romance': {'worlds': 0, 'characters': 10},
          'flirty': {'worlds': 2, 'characters': 9},
        },
      };

      final genre = ExploreGenre.fromJson(json);
      expect(genre.key, 'romance');
      expect(genre.label, 'Romance');
      expect(genre.worlds, 3);
      expect(genre.characters, 30);
      expect(genre.total, 33);
      expect(genre.hasContent, isTrue);

      expect(genre.styles['dark_romance']?.worlds, 0);
      expect(genre.styles['dark_romance']?.characters, 10);
      expect(genre.styles['dark_romance']?.total, 10);

      expect(genre.styles['flirty']?.worlds, 2);
      expect(genre.styles['flirty']?.characters, 9);
      expect(genre.styles['flirty']?.total, 11);

      // Filtering available styles by kind
      expect(genre.availableStylesForKind('world'), {'flirty'});
      expect(genre.availableStylesForKind('character'), {'dark_romance', 'flirty'});
      expect(genre.availableStylesForKind(null), {'dark_romance', 'flirty'});
      expect(genre.availableStylesForKind('all'), {'dark_romance', 'flirty'});
    });

    test('accepts old bare-number shape and counts as available for both kinds', () {
      final json = {
        'key': 'romance',
        'label': 'Romance',
        'worlds': 3,
        'characters': 30,
        'styles': {'dark_romance': 10, 'flirty': 11},
      };

      final genre = ExploreGenre.fromJson(json);
      expect(genre.styles['dark_romance']?.worlds, 10);
      expect(genre.styles['dark_romance']?.characters, 10);
      expect(genre.styles['flirty']?.worlds, 11);
      expect(genre.styles['flirty']?.characters, 11);

      // Bare numbers must be available for both kinds during mixed rollout
      expect(genre.availableStylesForKind('world'), {'dark_romance', 'flirty'});
      expect(genre.availableStylesForKind('character'), {'dark_romance', 'flirty'});
    });

    test('handles missing or null fields gracefully', () {
      final genre = ExploreGenre.fromJson({'key': 'cozy', 'label': 'Cozy'});
      expect(genre.key, 'cozy');
      expect(genre.label, 'Cozy');
      expect(genre.worlds, 0);
      expect(genre.characters, 0);
      expect(genre.total, 0);
      expect(genre.hasContent, isFalse);
      expect(genre.styles, isEmpty);
      expect(genre.availableStylesForKind('world'), isEmpty);
    });

    test('zero-count genres have total 0 and hasContent false', () {
      final emptyGenre = ExploreGenre.fromJson({
        'key': 'horror',
        'label': 'Horror',
        'worlds': 0,
        'characters': 0,
        'styles': {},
      });

      final activeGenre = ExploreGenre.fromJson({
        'key': 'epic',
        'label': 'Epic',
        'worlds': 1,
        'characters': 0,
        'styles': {
          'epic_fantasy': {'worlds': 1, 'characters': 0},
        },
      });

      final characterOnlyGenre = ExploreGenre.fromJson({
        'key': 'modern',
        'label': 'Modern',
        'worlds': 0,
        'characters': 5,
        'styles': {
          'modern_casual': {'worlds': 0, 'characters': 5},
        },
      });

      expect(emptyGenre.hasContent, isFalse);
      expect(activeGenre.hasContent, isTrue);
      expect(characterOnlyGenre.hasContent, isTrue);

      final all = [emptyGenre, activeGenre, characterOnlyGenre];
      final visibleTabs = all.where((g) => g.hasContent).toList();

      expect(visibleTabs, [activeGenre, characterOnlyGenre]);
      expect(visibleTabs.map((g) => g.key), ['epic', 'modern']);
    });
  });
}
