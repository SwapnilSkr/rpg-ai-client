/// Stable anchor ids shared by `GuideAnchor` call sites and `guide_flows.dart`.
///
/// Constants rather than raw strings so a renamed target breaks the build
/// instead of silently dropping a beat.
abstract final class GuideIds {
  // ── Play ──
  static const playRealm = 'play.realm';
  static const playMenu = 'play.menu';
  static const playWorldState = 'play.world_state';
  static const playBondRail = 'play.bond_rail';
  static const playNarrative = 'play.narrative';
  static const playNarrativeArea = 'play.narrative_area';
  static const playChoices = 'play.choices';
  static const playComposer = 'play.composer';
  static const playNarrationMarker = 'play.narration_marker';
  static const playWorldActions = 'play.world_actions';
  static const playSend = 'play.send';

  // ── Realm screen (the story's own menu) ──
  static const realmTomes = 'realm.tomes';
  static const realmPlaythrough = 'realm.playthrough';
  static const realmManage = 'realm.manage';

  // ── Scene settings sheet ──
  static const settingsNarration = 'settings.narration';
  static const settingsNarrationControl = 'settings.narration.control';
  static const settingsMode = 'settings.mode';
  static const settingsModeControl = 'settings.mode.control';
  static const settingsVoice = 'settings.voice';
  static const settingsVoiceControl = 'settings.voice.control';
  static const settingsTone = 'settings.tone';
  static const settingsToneControl = 'settings.tone.control';
  static const settingsPersona = 'settings.persona';
  static const settingsPersonaControl = 'settings.persona.control';
  static const settingsLength = 'settings.length';
  static const settingsLengthControl = 'settings.length.control';

  // ── Chronicle ──
  static const chronicleOverview = 'chronicle.overview';
  static const chronicleStory = 'chronicle.story';
  static const chroniclePeople = 'chronicle.people';
  static const chronicleWorld = 'chronicle.world';
  static const chronicleArchive = 'chronicle.archive';
  static const chroniclePeopleToggle = 'chronicle.people_toggle';
  static const chronicleWorldToggle = 'chronicle.world_toggle';

  // ── Discover ──
  static const discoverTabs = 'discover.tabs';
  static const discoverSearch = 'discover.search';
  static const discoverCard = 'discover.card';

  // ── Home / My Worlds / Personas ──
  static const homeCard = 'home.card';
  static const personasCreate = 'personas.create';

  // ── Shell ──
  static const navCreate = 'nav.create';
}
