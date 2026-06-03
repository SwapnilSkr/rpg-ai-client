/// Narrative VOICE / STYLE presets — mirrors the server registry in
/// everlore-server/src/utils/narrative-styles.ts. The `key` is what gets sent
/// to the backend; the label/blurb are for the picker UI. Keep keys in sync.
class NarrativeStyle {
  final String key;
  final String label;
  final String blurb;

  /// Genre family this style belongs to (see [kStyleFamilies]). `null` only for
  /// `default` (neutral — not a genre, excluded from interests).
  final String? familyKey;

  const NarrativeStyle(this.key, this.label, this.blurb, {this.familyKey});
}

/// A genre family — a SHARED grouping of narrative styles. Single source of
/// truth, consumed by three places:
///  • the interests onboarding picker (section headers),
///  • the discovery recommender (same-family = partial match),
///  • (future) Option-A voice accents (an accent must be family-compatible).
/// Mirror this grouping into narrative-styles.ts only when backend ranking
/// (discovery Phase 2) needs it.
class StyleFamily {
  final String key;
  final String label;
  const StyleFamily(this.key, this.label);
}

const StyleFamily famModern = StyleFamily('modern_everyday', 'Modern & Everyday');
const StyleFamily famEpic = StyleFamily('epic_adventure', 'Epic & Adventure');
const StyleFamily famDark = StyleFamily('atmospheric_dark', 'Atmospheric & Dark');
const StyleFamily famRomance = StyleFamily('romance_charged', 'Romance & Charged');
const StyleFamily famCozy = StyleFamily('cozy_playful', 'Cozy & Playful');

/// Ordered for display.
const List<StyleFamily> kStyleFamilies = [
  famModern,
  famEpic,
  famDark,
  famRomance,
  famCozy,
];

const List<NarrativeStyle> kNarrativeStyles = [
  NarrativeStyle('', 'Default', 'Neutral — let the world set its own voice.'),
  NarrativeStyle('modern_casual', 'Modern Casual',
      'Contemporary, conversational — how people actually talk.',
      familyKey: 'modern_everyday'),
  NarrativeStyle('anime', 'Anime / Expressive',
      'Lively, emotionally heightened, character-driven.',
      familyKey: 'cozy_playful'),
  NarrativeStyle('tsundere', 'Tsundere',
      'Hot-and-cold: prickly outside, secretly soft.',
      familyKey: 'romance_charged'),
  NarrativeStyle('romcom', 'Rom-Com', 'Warm, witty, flirty banter.',
      familyKey: 'modern_everyday'),
  NarrativeStyle('flirty', 'Flirty / Lustful',
      'Charged, sensual tension and desire.',
      familyKey: 'romance_charged'),
  NarrativeStyle('noir', 'Noir', 'Moody, terse, cynical — shadows and edges.',
      familyKey: 'atmospheric_dark'),
  NarrativeStyle('slice_of_life', 'Slice of Life',
      'Cozy, grounded, gentle everyday moments.',
      familyKey: 'modern_everyday'),
  NarrativeStyle('whimsical', 'Whimsical',
      'Playful, imaginative, lightly fantastical.',
      familyKey: 'cozy_playful'),
  NarrativeStyle('epic_fantasy', 'Epic Fantasy',
      'Grand, mythic, sweeping high-fantasy.',
      familyKey: 'epic_adventure'),
  NarrativeStyle('grimdark', 'Grimdark',
      'Bleak, brutal, morally grey and unflinching.',
      familyKey: 'atmospheric_dark'),
  NarrativeStyle('yandere', 'Yandere',
      'Sweetly obsessive — tender devotion with a dangerous edge.',
      familyKey: 'romance_charged'),
  NarrativeStyle('dark_romance', 'Dark Romance',
      'Dangerous, magnetic, morally grey — the love you shouldn\'t want.',
      familyKey: 'romance_charged'),
  NarrativeStyle('shonen', 'Shōnen / Battle',
      'Explosive battle-anime energy — guts, rivalry, never giving up.',
      familyKey: 'epic_adventure'),
  NarrativeStyle('cyberpunk', 'Cyberpunk',
      'Neon-soaked, high-tech low-life — rain on chrome and megacorps.',
      familyKey: 'atmospheric_dark'),
  NarrativeStyle('kdrama', 'K-Drama',
      'Tender slow-burn — aching longing and feelings too big to say.',
      familyKey: 'modern_everyday'),
  NarrativeStyle('cozy_comfort', 'Cozy Comfort',
      'Warm, gentle, safe — a soothing soft place to land.',
      familyKey: 'cozy_playful'),
  NarrativeStyle('dark_academia', 'Dark Academia',
      'Gothic and intellectual — candlelit libraries and old secrets.',
      familyKey: 'atmospheric_dark'),
  NarrativeStyle('regency', 'Regency Romance',
      'Courtly and swoony — ballrooms, wit, and longing behind manners.',
      familyKey: 'romance_charged'),
  NarrativeStyle('horror', 'Horror / Dread',
      'Eerie and creeping — wrongness in the ordinary, dread in the dark.',
      familyKey: 'atmospheric_dark'),
  NarrativeStyle('litrpg', 'LitRPG / System',
      'Gamified progression — stats, skills, levels, and quest prompts.',
      familyKey: 'epic_adventure'),
  NarrativeStyle('chaotic_comedy', 'Chaotic Comedy',
      'Unhinged, fast, absurd — gremlin energy that still moves the plot.',
      familyKey: 'cozy_playful'),
];

String narrativeStyleLabel(String key) {
  for (final s in kNarrativeStyles) {
    if (s.key == key) return s.label;
  }
  return 'Default';
}

/// The interest-eligible styles (everything with a family — i.e. excludes
/// `default`). This is the vocabulary the interests picker offers.
List<NarrativeStyle> get kInterestStyles =>
    kNarrativeStyles.where((s) => s.familyKey != null).toList();

/// Styles in a given family, in registry order.
List<NarrativeStyle> stylesInFamily(String familyKey) =>
    kNarrativeStyles.where((s) => s.familyKey == familyKey).toList();

/// The family key for a style key (null for default / unknown).
String? familyOfStyle(String styleKey) {
  for (final s in kNarrativeStyles) {
    if (s.key == styleKey) return s.familyKey;
  }
  return null;
}

/// Whether two style keys share a family — the recommender's "same-family =
/// partial match" signal, and (future) Option-A accent compatibility.
bool sameStyleFamily(String a, String b) {
  final fa = familyOfStyle(a);
  return fa != null && fa == familyOfStyle(b);
}
