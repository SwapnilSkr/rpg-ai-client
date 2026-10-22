import 'package:everlore/features/templates/presentation/explore_filter_sheet.dart';
import 'package:everlore/shared/models/explore_genre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreFilterState', () {
    test('default state has no active filter', () {
      const state = ExploreFilterState();
      expect(state.isDefault, isTrue);
      expect(state.hasActiveFilter, isFalse);
      expect(state.kind, isNull);
      expect(state.styles, isEmpty);
      expect(state.sort, 'foryou');
      expect(state.buildSummary(), isEmpty);
    });

    test('setting kind marks active filter and formats summary', () {
      const worldState = ExploreFilterState(kind: 'world');
      expect(worldState.hasActiveFilter, isTrue);
      expect(worldState.buildSummary(), 'Worlds');

      const charState = ExploreFilterState(kind: 'character');
      expect(charState.hasActiveFilter, isTrue);
      expect(charState.buildSummary(), 'Characters');
    });

    test('hashCode is stable regardless of set iteration order (Object.hashAllUnordered)', () {
      const s1 = ExploreFilterState(
        kind: 'character',
        styles: {'dark_romance', 'flirty'},
        sort: 'new',
      );
      const s2 = ExploreFilterState(
        kind: 'character',
        styles: {'flirty', 'dark_romance'},
        sort: 'new',
      );

      expect(s1 == s2, isTrue);
      expect(s1.hashCode, equals(s2.hashCode),
          reason: 'Set iteration order must not produce different hashCodes');
    });

    test('summary line reads interest label when 1 picked, count when more (Requirement 4)', () {
      // 1 interest alone
      const singleInterest = ExploreFilterState(
        styles: {'noir'},
      );
      expect(singleInterest.buildSummary(), 'Noir');

      // 1 interest with kind
      const singleWithKind = ExploreFilterState(
        kind: 'world',
        styles: {'tsundere'},
      );
      expect(singleWithKind.buildSummary(), 'Worlds · Tsundere');

      // 1 interest with kind and sort
      const singleWithSort = ExploreFilterState(
        kind: 'world',
        styles: {'tsundere'},
        sort: 'new',
      );
      expect(singleWithSort.buildSummary(), 'Worlds · Tsundere · Newest');

      // Multiple interests: count is displayed
      const multipleInterests = ExploreFilterState(
        kind: 'character',
        styles: {'dark_romance', 'flirty'},
      );
      expect(multipleInterests.buildSummary(), 'Characters · 2 interests');

      const threeInterests = ExploreFilterState(
        kind: 'world',
        styles: {'epic_fantasy', 'shonen', 'litrpg'},
      );
      expect(threeInterests.buildSummary(), 'Worlds · 3 interests');
    });

    test('interests dropped on tab switch when not present in new tab', () {
      // Tab 1 (Romance) has styles: dark_romance, flirty
      // Player selected both
      const romanceFilter = ExploreFilterState(
        kind: 'character',
        styles: {'dark_romance', 'flirty'},
        sort: 'new',
      );

      // Switching to Tab 2 (Dark), which only has: noir, grimdark
      const darkAvailable = {'noir', 'grimdark'};

      final cleanedForDark = romanceFilter.cleanForAvailableStyles(darkAvailable);
      expect(cleanedForDark.kind, 'character');
      expect(cleanedForDark.sort, 'new');
      expect(cleanedForDark.styles, isEmpty, reason: 'Unavailable styles must be dropped quietly');

      // If switching to a tab that shares one style
      const partiallyOverlapping = {'flirty', 'slice_of_life'};
      final cleanedPartial = romanceFilter.cleanForAvailableStyles(partiallyOverlapping);
      expect(cleanedPartial.styles, {'flirty'});
    });

    test('cleanForAvailableStyleCounts filters by kind (Requirement 3)', () {
      const counts = {
        'dark_romance': GenreStyleCount(worlds: 0, characters: 10),
        'flirty': GenreStyleCount(worlds: 2, characters: 9),
      };

      const filter = ExploreFilterState(
        styles: {'dark_romance', 'flirty'},
      );

      // When Show is Worlds: dark_romance has worlds == 0 so it disappears
      final forWorlds = filter.cleanForAvailableStyleCounts(counts, kind: 'world');
      expect(forWorlds.styles, {'flirty'});

      // When Show is Characters: both have characters > 0
      final forChars = filter.cleanForAvailableStyleCounts(counts, kind: 'character');
      expect(forChars.styles, {'dark_romance', 'flirty'});

      // When Show is All: both have total > 0
      final forAll = filter.cleanForAvailableStyleCounts(counts, kind: null);
      expect(forAll.styles, {'dark_romance', 'flirty'});
    });

    test('per-tab state map isolates filters between tabs', () {
      final filtersByTab = <int, ExploreFilterState>{};

      // Tab 0 (For You)
      filtersByTab[0] = const ExploreFilterState(sort: 'new');

      // Tab 1 (Romance)
      filtersByTab[1] = const ExploreFilterState(
        kind: 'character',
        styles: {'dark_romance'},
      );

      expect(filtersByTab[0]?.sort, 'new');
      expect(filtersByTab[0]?.kind, isNull);
      expect(filtersByTab[0]?.styles, isEmpty);

      expect(filtersByTab[1]?.sort, 'foryou');
      expect(filtersByTab[1]?.kind, 'character');
      expect(filtersByTab[1]?.styles, {'dark_romance'});

      // Unvisited tab defaults to clean state
      final tab2Filter = filtersByTab[2] ?? const ExploreFilterState();
      expect(tab2Filter.isDefault, isTrue);
    });
  });
}
