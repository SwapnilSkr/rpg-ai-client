import 'package:everlore/features/templates/data/template_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TemplateRepository query-string building & cache key', () {
    test('default parameters build standard page and limit query', () {
      final path = TemplateRepository.buildPublishedPath(page: 1, limit: 20);
      expect(path, '/templates?page=1&limit=20');
    });

    test('search query is properly URL encoded', () {
      final path = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        search: 'sword & magic = epic?',
      );
      expect(path, contains('page=1'));
      expect(path, contains('limit=20'));
      // Properly encoded query parameters
      final uri = Uri.parse(path);
      expect(uri.queryParameters['search'], 'sword & magic = epic?');
      expect(path, isNot(contains(' '))); // no raw spaces
    });

    test('genre, kind, styles, and sort are all included in path', () {
      final path = TemplateRepository.buildPublishedPath(
        page: 2,
        limit: 15,
        genre: 'romance',
        kind: 'character',
        styles: ['dark_romance', 'flirty'],
        sort: 'new',
      );

      final uri = Uri.parse(path);
      expect(uri.queryParameters['page'], '2');
      expect(uri.queryParameters['limit'], '15');
      expect(uri.queryParameters['genre'], 'romance');
      expect(uri.queryParameters['kind'], 'character');
      expect(uri.queryParameters['styles'], 'dark_romance,flirty');
      expect(uri.queryParameters['sort'], 'new');
    });

    test('styles are sorted alphabetically before joining so cache keys are stable (Requirement 2)', () {
      final path1 = TemplateRepository.buildPublishedPath(
        styles: ['flirty', 'dark_romance', 'anime'],
      );
      final path2 = TemplateRepository.buildPublishedPath(
        styles: ['dark_romance', 'anime', 'flirty'],
      );
      final pathFromSet = TemplateRepository.buildPublishedPath(
        styles: {'anime', 'flirty', 'dark_romance'},
      );

      expect(path1, path2);
      expect(path1, pathFromSet);
      expect(path1, contains('styles=anime%2Cdark_romance%2Cflirty'));
    });

    test('empty or null parameters are omitted from query string', () {
      final path = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        search: '',
        genre: null,
        kind: '',
        styles: [],
        sort: null,
      );
      expect(path, '/templates?page=1&limit=20');
    });

    test('cache key differs when any parameter changes', () {
      final base = TemplateRepository.buildPublishedPath(page: 1, limit: 20);
      final withGenre = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        genre: 'dark',
      );
      final withKind = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        kind: 'world',
      );
      final withStyles = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        styles: ['grimdark'],
      );
      final withSort = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        sort: 'new',
      );
      final withSearch = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        search: 'vampire',
      );

      final keys = {base, withGenre, withKind, withStyles, withSort, withSearch};
      expect(keys.length, 6, reason: 'Every parameter variation produces a unique cache key');
    });

    test('cached entry can be retrieved by exact path key', () {
      final path = TemplateRepository.buildPublishedPath(
        page: 1,
        limit: 20,
        genre: 'epic',
      );
      expect(TemplateRepository.isPathCached(path), isFalse);

      final dummyResult = {'templates': [], 'total': 0};
      TemplateRepository.setCached(path, dummyResult);

      expect(TemplateRepository.isPathCached(path), isTrue);
      expect(TemplateRepository.getCached(path), dummyResult);

      TemplateRepository.invalidate();
      expect(TemplateRepository.isPathCached(path), isFalse);
    });
  });
}
