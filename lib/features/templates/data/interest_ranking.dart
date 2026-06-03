import '../../../shared/models/world_template.dart';
import '../../../shared/narrative_styles.dart';

/// Re-orders discovery results by the player's interest taste — a **boost,
/// never a filter**: every world stays in the list, matches just float to the
/// top. An exact genre hit (`narrative_style` ∈ interests) outranks a same-
/// family hit, and within equal scores the source order is preserved (stable),
/// so the server's own ranking/recency still shows through.
///
/// Phase 1 (client-side) signal is interest-match only; popularity/recency
/// weighting lives in the Phase 2 backend aggregation where that data exists.
/// See memory: interests_discovery.md.
List<WorldTemplate> rankByInterests(
  List<WorldTemplate> templates,
  List<String> interests,
) {
  if (interests.isEmpty || templates.length < 2) return templates;
  final interestSet = interests.toSet();

  double matchScore(WorldTemplate t) {
    final style = t.narrativeStyle;
    if (style.isEmpty) return 0;
    if (interestSet.contains(style)) return 1.0; // exact genre hit
    for (final i in interestSet) {
      if (sameStyleFamily(style, i)) return 0.5; // same-family hit
    }
    return 0;
  }

  // Decorate with the original index so equal scores keep source order
  // (Dart's List.sort is not stable).
  final indexed = [
    for (var i = 0; i < templates.length; i++) (i, templates[i]),
  ];
  indexed.sort((a, b) {
    final byScore = matchScore(b.$2).compareTo(matchScore(a.$2));
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
