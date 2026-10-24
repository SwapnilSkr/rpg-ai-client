/// The closed list of things the app may report, and the shape of each one.
///
/// This mirrors `everlore-docs/phases/analytics.md` §3. The server validates
/// the same list and silently drops anything outside it, so a typo here would
/// never fail loudly in production — it would just be a hole in the data. The
/// app checks first: an invalid call asserts in debug (so it is found while
/// writing it) and is dropped in release.
///
/// There is no free-text type in this file on purpose. Every value is an enum,
/// a bounded number, a boolean, an id, or a short label from a server list.
library;

/// Route names are the screen vocabulary; the server only checks the shape.
final RegExp _slug = RegExp(r'^[a-z][a-z0-9_-]{1,39}$');
final RegExp _objectId = RegExp(r'^[0-9a-f]{24}$');
final RegExp _productId = RegExp(r'^[A-Za-z0-9._-]{1,80}$');

/// A genre label comes from the server's own list ("Slow-burn romance"), so it
/// is letters, digits and a little punctuation, never a sentence.
final RegExp _label = RegExp(r'^[A-Za-z0-9 &/_.\-]{1,40}$');

const int maxDurationMs = 6 * 60 * 60 * 1000;

class PropSpec {
  const PropSpec(this.accepts, {this.required = false});
  final bool Function(Object? value) accepts;
  final bool required;
}

PropSpec _oneOf(List<String> values, {bool required = false}) =>
    PropSpec((v) => v is String && values.contains(v), required: required);

PropSpec _slugProp({bool required = false}) =>
    PropSpec((v) => v is String && _slug.hasMatch(v), required: required);

PropSpec _worldId({bool required = false}) =>
    PropSpec((v) => v is String && _objectId.hasMatch(v), required: required);

PropSpec _boolProp() => const PropSpec(_isBool);

bool _isBool(Object? v) => v is bool;

PropSpec _intRange(int min, int max, {bool required = false}) => PropSpec(
  (v) => v is int && v >= min && v <= max,
  required: required,
);

/// The §3.1 sheet list. Confirm dialogs are not sheets: their outcome is an
/// action event.
const List<String> sheetValues = [
  'realm_menu',
  'protagonist',
  'filters',
  'paywall',
  'chat_menu',
  'timeline',
  'thoughts',
  'bond_actions',
  'world_actions',
  'travel',
  'relationships',
  'advance_time',
  'create_chooser',
  'world_options',
  'story_options',
  'keepsake_options',
  'report',
  'content_actions',
  'persona_editor',
  'interests_editor',
  'autofill',
  'publish',
  'story_intro',
];

/// First-run guide arc ids, as §3.1 lists them.
const List<String> guideArcValues = [
  'arrival',
  'chronicle',
  'explore_genres',
  'home',
  'ink',
  'keepsakes',
  'my_worlds',
  'personas',
  'realm',
  'scene_settings',
  'world_detail',
];

/// Where a paywall can be opened from.
const List<String> paywallSources = ['ink', 'media', 'profile', 'top_bar', 'story'];

final Map<String, Map<String, PropSpec>> telemetryEvents = {
  'first_open': {},
  'session_start': {
    'launch': _oneOf(['cold', 'resume']),
  },
  'screen_view': {
    'screen': _slugProp(required: true),
    'duration_ms': _intRange(0, maxDurationMs, required: true),
    'partial': _boolProp(),
    'from': _slugProp(),
  },
  'sign_in_started': {
    'method': _oneOf(['google', 'phone']),
  },
  'sign_in_completed': {
    'method': _oneOf(['google', 'phone']),
    'new_account': _boolProp(),
  },
  'sign_in_failed': {
    'method': _oneOf(['google', 'phone']),
    'reason': _oneOf(['cancelled', 'network', 'rejected', 'unknown']),
  },
  'onboarding_completed': {'interests_count': _intRange(0, 200)},
  'persona_created': {},
  'world_viewed': {'world_id': _worldId(required: true)},
  'world_started': {
    'world_id': _worldId(required: true),
    'kind': _oneOf(['gm', 'sentient', 'character']),
  },
  'story_opened': {'world_id': _worldId()},
  'turn_sent': {
    'input': _oneOf(['typed', 'choice', 'choice_edited', 'continue']),
  },
  'turn_failed': {
    'reason': _oneOf(['network', 'ink', 'server', 'rest']),
  },
  'sheet_opened': {
    'sheet': _oneOf(sheetValues),
  },
  'explore_filtered': {
    'genre': PropSpec((v) => v is String && _label.hasMatch(v)),
  },
  'paywall_shown': {
    'source': _oneOf(paywallSources),
  },
  'purchase_started': {
    'product': PropSpec((v) => v is String && _productId.hasMatch(v)),
  },
  'purchase_completed': {
    'product': PropSpec((v) => v is String && _productId.hasMatch(v)),
  },
  'media_requested': {
    'kind': _oneOf(['picture', 'voice', 'film', 'portrait']),
  },
  'world_published': {
    'visibility': _oneOf(['private', 'public']),
  },
  'story_action': {
    'action': _oneOf([
      'retry',
      'rewind',
      'edit_reply',
      'replay_reply',
      'pick_variant',
      'reset',
      'delete',
      'travel',
      'relationship_set',
      'time_advanced',
      'protagonist_set',
      'protagonist_reused',
      'protagonist_skipped',
      'character_edited',
      'character_tracked',
      'relation_resolved',
      'milestone_cleared',
      'history_loaded',
      'voice_played',
    ], required: true),
  },
  'story_settings_changed': {
    'setting': _oneOf([
      'pov',
      'mode',
      'length',
      'voice',
      'tone',
      'focus',
      'persona',
    ], required: true),
  },
  'chronicle_tab': {
    'tab': _oneOf([
      'recap',
      'timeline',
      'memories',
      'calendar',
      'places',
      'bonds',
      'threads',
    ], required: true),
  },
  'chronicle_action': {
    'action': _oneOf([
      'memory_edited',
      'memory_deleted',
      'event_edited',
      'timeline_switched',
    ], required: true),
  },
  'keepsakes_action': {
    'action': _oneOf([
      'filtered',
      'mode_changed',
      'opened',
      'removed',
    ], required: true),
    'filter': _oneOf(['all', 'pictures', 'films', 'faces']),
    'mode': _oneOf(['feed', 'grid']),
  },
  'library_action': {
    'action': _oneOf([
      'story_deleted',
      'world_deleted',
      'world_forge_opened',
      'character_creation_opened',
    ], required: true),
    'mode': _oneOf(['new', 'edit']),
  },
  'creator_action': {
    'action': _oneOf([
      'autofill_used',
      'character_created',
      'world_saved',
    ], required: true),
  },
  'report_submitted': {
    'target': _oneOf([
      'world',
      'message',
      'character',
      'keepsake',
      'other',
    ], required: true),
  },
  'account_action': {
    'action': _oneOf([
      'signed_out',
      'account_deleted',
      'interests_updated',
    ], required: true),
    'count': _intRange(0, 200),
  },
  'guide_arc': {
    'arc': _oneOf(guideArcValues, required: true),
    'outcome': _oneOf(['completed', 'skipped'], required: true),
  },
  'review_prompt_shown': {},
  'analytics_opted_out': {},
};

/// Why [name]/[props] would not be accepted, or null when they would be.
///
/// Unknown keys are an error here even though the server would merely drop
/// them: on this side an unknown key is always a typo.
String? validateEvent(String name, Map<String, Object?> props) {
  final spec = telemetryEvents[name];
  if (spec == null) return 'unknown event "$name"';
  for (final entry in props.entries) {
    final prop = spec[entry.key];
    if (prop == null) return '"$name" has no prop "${entry.key}"';
    if (!prop.accepts(entry.value)) {
      return '"$name" prop "${entry.key}" has an invalid value';
    }
  }
  for (final entry in spec.entries) {
    if (entry.value.required && !props.containsKey(entry.key)) {
      return '"$name" needs prop "${entry.key}"';
    }
  }
  return null;
}

bool isScreenName(String name) => _slug.hasMatch(name);

/// Whether [id] has the shape of a world id. Call sites check this instead of
/// letting an odd id (a draft, a fixture) assert in debug.
bool isWorldId(String? id) => id != null && _objectId.hasMatch(id);

/// Whether [label] is a plausible genre label from the server's list.
bool isGenreLabel(String? label) => label != null && _label.hasMatch(label);
