/// Player-selected narration register for an individual story. It controls
/// wording and literary density only; world genre, canon, and Scene Mode remain
/// separate. Mirrors `everlore-server/src/utils/narration-tones.ts`.
class NarrationTone {
  final String key;
  final String label;
  final String blurb;

  const NarrationTone(this.key, this.label, this.blurb);
}

const String kDefaultNarrationTone = 'modern';

const List<NarrationTone> kNarrationTones = [
  NarrationTone(
    'modern',
    'Modern natural',
    'Contemporary, clear, and emotionally real.',
  ),
  NarrationTone(
    'cinematic',
    'Cinematic',
    'Visual, vivid, and controlled — like a great scene on screen.',
  ),
  NarrationTone(
    'literary',
    'Literary',
    'Evocative and polished, without purple prose.',
  ),
  NarrationTone('tense', 'Tense', 'Lean, sharp, and suspenseful.'),
  NarrationTone('warm', 'Warm', 'Human, intimate, and quietly tender.'),
  NarrationTone('wry', 'Wry', 'Dry, contemporary wit with a little bite.'),
  NarrationTone(
    'formal_period',
    'Formal & period',
    'Deliberate, elegant, and more ceremonious.',
  ),
];

String narrationToneLabel(String key) {
  for (final tone in kNarrationTones) {
    if (tone.key == key) return tone.label;
  }
  return kNarrationTones.first.label;
}
