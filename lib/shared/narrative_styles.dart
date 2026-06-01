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
];

String narrativeStyleLabel(String key) {
  for (final s in kNarrativeStyles) {
    if (s.key == key) return s.label;
  }
  return 'Default';
}
