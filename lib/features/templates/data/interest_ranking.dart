import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/narrative_styles.dart';
import '../../../core/onboarding/interests_store.dart';

/// Re-orders discovery results by the player's interest taste — a **boost,
/// never a filter**: every world stays in the list, matches just float to the
/// top. An exact genre hit (`narrative_style` ∈ interests) outranks a same-
/// family hit, and within equal scores the source order is preserved (stable),
/// so the server's own ranking/recency still shows through.
///
/// Phase 1 (client-side) signal is interest-match only; popularity/recency
/// weighting lives in the Phase 2 backend aggregation where that data exists.
///
/// When the user is signed in, [orderTemplatesForFeed] returns the API list as-is:
/// `GET /templates` already boosts by `preferences.interests` (same family map).
/// Client re-ranking on top of that was redundant and diverged after logout when
/// local interests were cleared but the server still had picks.
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

/// Feed ordering for Discover / browse: trust the server when authenticated.
Future<List<WorldTemplate>> orderTemplatesForFeed(
  List<WorldTemplate> templates,
) async {
  if (await SecureStore.getToken() != null) return templates;
  final interests = await InterestsStore.getInterests();
  return rankByInterests(templates, interests);
}
