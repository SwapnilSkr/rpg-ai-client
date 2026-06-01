/// Narrative VOICE / STYLE presets — mirrors the server registry in
/// everlore-server/src/utils/narrative-styles.ts. The `key` is what gets sent
/// to the backend; the label/blurb are for the picker UI. Keep keys in sync.
class NarrativeStyle {
  final String key;
  final String label;
  final String blurb;
  const NarrativeStyle(this.key, this.label, this.blurb);
}

const List<NarrativeStyle> kNarrativeStyles = [
  NarrativeStyle('', 'Default', 'Neutral — let the world set its own voice.'),
  NarrativeStyle('modern_casual', 'Modern Casual',
      'Contemporary, conversational — how people actually talk.'),
  NarrativeStyle('anime', 'Anime / Expressive',
      'Lively, emotionally heightened, character-driven.'),
  NarrativeStyle('tsundere', 'Tsundere',
      'Hot-and-cold: prickly outside, secretly soft.'),
  NarrativeStyle('romcom', 'Rom-Com', 'Warm, witty, flirty banter.'),
  NarrativeStyle('flirty', 'Flirty / Lustful',
      'Charged, sensual tension and desire.'),
  NarrativeStyle('noir', 'Noir', 'Moody, terse, cynical — shadows and edges.'),
  NarrativeStyle('slice_of_life', 'Slice of Life',
      'Cozy, grounded, gentle everyday moments.'),
  NarrativeStyle('whimsical', 'Whimsical',
      'Playful, imaginative, lightly fantastical.'),
  NarrativeStyle('epic_fantasy', 'Epic Fantasy',
      'Grand, mythic, sweeping high-fantasy.'),
  NarrativeStyle('grimdark', 'Grimdark',
      'Bleak, brutal, morally grey and unflinching.'),
  NarrativeStyle('yandere', 'Yandere',
      'Sweetly obsessive — tender devotion with a dangerous edge.'),
  NarrativeStyle('dark_romance', 'Dark Romance',
      'Dangerous, magnetic, morally grey — the love you shouldn\'t want.'),
  NarrativeStyle('shonen', 'Shōnen / Battle',
      'Explosive battle-anime energy — guts, rivalry, never giving up.'),
  NarrativeStyle('cyberpunk', 'Cyberpunk',
      'Neon-soaked, high-tech low-life — rain on chrome and megacorps.'),
  NarrativeStyle('kdrama', 'K-Drama',
      'Tender slow-burn — aching longing and feelings too big to say.'),
  NarrativeStyle('cozy_comfort', 'Cozy Comfort',
      'Warm, gentle, safe — a soothing soft place to land.'),
  NarrativeStyle('dark_academia', 'Dark Academia',
      'Gothic and intellectual — candlelit libraries and old secrets.'),
  NarrativeStyle('regency', 'Regency Romance',
      'Courtly and swoony — ballrooms, wit, and longing behind manners.'),
  NarrativeStyle('horror', 'Horror / Dread',
      'Eerie and creeping — wrongness in the ordinary, dread in the dark.'),
  NarrativeStyle('litrpg', 'LitRPG / System',
      'Gamified progression — stats, skills, levels, and quest prompts.'),
  NarrativeStyle('chaotic_comedy', 'Chaotic Comedy',
      'Unhinged, fast, absurd — gremlin energy that still moves the plot.'),
];

String narrativeStyleLabel(String key) {
  for (final s in kNarrativeStyles) {
    if (s.key == key) return s.label;
  }
  return 'Default';
}
