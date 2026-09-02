/// Player-facing text helpers.
///
/// Data written by creators (and by the world autofill) arrives as machine
/// tokens — `royal_palace`, `court_intrigue`. Rendering those raw shows the
/// player the shape of the database instead of the shape of the world.
library;

/// `royal_palace` → `Royal palace`. Leaves prose that is already written for
/// a reader untouched.
String humanizeTag(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[_\-]+'), ' ');
  if (cleaned.isEmpty) return '';
  final collapsed = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  // Something already capitalised and spaced is a human phrase; keep it.
  if (raw.trim() == collapsed && collapsed[0] == collapsed[0].toUpperCase()) {
    return collapsed;
  }
  return collapsed[0].toUpperCase() + collapsed.substring(1);
}

/// `3 → "3 echoes"`, `1 → "1 echo"`. Counts reach the player constantly —
/// realm cards, turn tallies, pending-decision nudges — and "1 echoes" reads
/// like a database row, not a story.
///
/// Pass [plural] for words English does not pluralise with a bare `s`
/// (`story` → `stories`).
String countLabel(int n, String singular, {String? plural}) {
  final word = n == 1 ? singular : (plural ?? '${singular}s');
  return '$n $word';
}

/// The narrator tags every turn with a scene mode — one of a small internal
/// set (`dialogue`, `combat`, `intimate`, …). The Chronicle's almanac and
/// location journal fall back to that tag whenever a turn has no milestone,
/// no travel and no clock reading, so a young story listed itself as
/// "Dialogue / Dialogue / Dialogue": how each turn was filed, not what
/// happened in it. Say it the way the world would instead.
const _sceneMoments = {
  'dialogue': 'Words exchanged',
  'combat': 'Blows exchanged',
  'romantic': 'A tender moment',
  'intimate': 'A private hour',
  'exploration': 'Ground covered',
  'existential': 'A hard reckoning',
  'cosmic': 'Something vast',
  'mundane': 'An ordinary hour',
};

/// Player-facing name for a turn that has nothing more specific to show.
String sceneMomentLabel(String? sceneTag, String type) {
  final raw = (sceneTag != null && sceneTag.isNotEmpty) ? sceneTag : type;
  if (raw.trim().isEmpty) return 'A moment';
  return _sceneMoments[raw.trim().toLowerCase()] ?? humanizeTag(raw);
}
