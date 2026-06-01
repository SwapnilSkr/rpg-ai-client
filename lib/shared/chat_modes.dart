/// CHAT MODES — the player's per-conversation lever for HOW THE CHAT FLOWS
/// (pacing, intent, escalation). Orthogonal to narrative voice, which is
/// creator-locked. Mirrors everlore-server/src/utils/chat-modes.ts — keep keys
/// in sync. `Ardent` is the mature on-ramp (server-side gated).
class ChatMode {
  final String key;
  final String label;
  final String blurb;
  const ChatMode(this.key, this.label, this.blurb);
}

const String kDefaultChatMode = 'free_play';

const List<ChatMode> kChatModes = [
  ChatMode('free_play', 'Free Play', 'Versatile — follows your lead.'),
  ChatMode('saga', 'Saga', 'Plot momentum — events, stakes, twists.'),
  ChatMode('slow_burn', 'Slow Burn', 'Closeness builds gradually.'),
  ChatMode('grounded', 'Grounded', 'Natural and present — understated.'),
  ChatMode('composed', 'Composed', 'Calm, measured, restrained.'),
  ChatMode('ardent', 'Ardent', 'Passionate and fast — heat rises quickly.'),
];

String chatModeLabel(String key) {
  for (final m in kChatModes) {
    if (m.key == key) return m.label;
  }
  return 'Free Play';
}

/// Reply length presets: (key, label). A conversation setting alongside mode.
const List<(String, String)> kMessageLengths = [
  ('short', 'Short'),
  ('medium', 'Medium'),
  ('long', 'Long'),
];

String messageLengthLabel(String key) {
  for (final m in kMessageLengths) {
    if (m.$1 == key) return m.$2;
  }
  return 'Medium';
}
