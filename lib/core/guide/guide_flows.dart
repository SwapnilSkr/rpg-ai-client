import 'guide_beat.dart';
import 'guide_ids.dart';

/// Every guide arc in the app, declared as data.
///
/// Copy stays in Everlore's register (DESIGN_PHILOSOPHY §1): the Chronicler
/// explains the world, never the interface. No "tap", no "button", no "screen".
///
/// Arcs are deliberately short and staggered. Five surfaces each opening a
/// four-step carousel is what makes an app feel like a help system; one arrival
/// line plus a couple of pointed beats, arriving when the surface is first
/// touched, does not.
abstract final class GuideFlows {
  /// Fired once on the first Explore visit — the "where am I" beat.
  static const arrival = GuideFlow(
    id: 'arrival',
    label: 'First Threshold',
    route: '/discover',
    beats: [
      GuideBeat.card(
        title: 'The Chronicler',
        body:
            'Welcome, storyteller. Everlore keeps a living record of every '
            'world you enter — what you say, who you meet, and what it costs '
            'them. I will point out a few things as you go, and step aside '
            'whenever you wish.',
      ),
      GuideBeat(
        anchor: GuideIds.discoverTabs,
        title: 'Worlds and Souls',
        body:
            'Realms are places to live in. Characters are souls to meet. '
            'Either one will open a story around you.',
      ),
      GuideBeat(
        anchor: GuideIds.discoverCard,
        title: 'Crossing Over',
        body:
            'Open any of these and the world begins where you stand. Nothing '
            'here is a rehearsal — the first thing you say becomes canon.',
      ),
      // There was a fourth beat here, pointing at the search icon. It went,
      // and the arc is better for it. This is the first thing a new player
      // ever sees, before they have done anything at all, and a magnifying
      // glass is the one control on the surface that needs no introduction —
      // so it was pure length on the beat where length costs the most.
    ],
  );

  /// The threshold itself. Opening a world is the one step between browsing
  /// and playing, and it was the only step on that path with no guidance at
  /// all — the arrival arc says "open any of these", and then the surface it
  /// opens says nothing.
  static const worldDetail = GuideFlow(
    id: 'world_detail',
    label: 'The Threshold',
    route: '/templates',
    beats: [
      GuideBeat(
        anchor: GuideIds.worldInvitation,
        title: 'What Waits Here',
        body:
            'How this world begins, and who tells it — a narrator holding the '
            'whole realm, or one soul at the centre of it.',
        requiresAnchor: true,
      ),
      GuideBeat(
        anchor: GuideIds.worldEnter,
        title: 'Crossing the Threshold',
        body:
            'Step through and the world makes a story that is yours alone. You '
            'may keep more than one here, and none of them touch each other.',
      ),
    ],
  );

  /// The essentials, at the first told turn. Four beats, nothing more — this
  /// arc stands between the player and their story.
  static const playFirst = GuideFlow(
    id: 'play.first',
    label: 'First Words',
    route: '/play',
    beats: [
      GuideBeat(
        anchor: GuideIds.playNarrative,
        fallbackAnchor: GuideIds.playNarrativeArea,
        title: 'The Narrator',
        body:
            'This is the world speaking. Every passage is written for you '
            'alone — and once written, it is remembered.',
      ),
      GuideBeat(
        anchor: GuideIds.playChoices,
        title: 'Offered Paths',
        body:
            'Ways the moment might turn. Choosing one sets it in your hand — '
            'reshape the wording before you commit, or discard it entirely.',
        requiresAnchor: true,
      ),
      GuideBeat(
        anchor: GuideIds.playComposer,
        title: 'Your Own Words',
        body:
            'You are never bound to what is offered. Speak plainly, and the '
            'world answers in kind.',
      ),
      GuideBeat(
        anchor: GuideIds.playNarrationMarker,
        title: 'Speak, or Act',
        body:
            'Wrap a line in asterisks and it becomes deed rather than speech — '
            '*you reach for the blade* instead of saying that you do.',
      ),
    ],
  );

  /// The rest of the play surface, held back until the player has settled in.
  static const playTools = GuideFlow(
    id: 'play.tools',
    label: 'The Storyteller’s Tools',
    route: '/play',
    beats: [
      GuideBeat(
        anchor: GuideIds.playWorldActions,
        title: 'Bending the Tale',
        body:
            'Let the moment unfold on its own, skip ahead through quiet hours, '
            'travel elsewhere, or correct who someone truly is to you.',
      ),
      GuideBeat(
        anchor: GuideIds.playBondRail,
        title: 'Those Who Stand With You',
        body:
            'The souls present in this scene, and how near they hold you. '
            'Open one to speak with them apart from the story.',
        requiresAnchor: true,
      ),
      GuideBeat(
        anchor: GuideIds.playWorldState,
        title: 'The State of Things',
        body:
            'What this world measures in you. It shifts as you act, and the '
            'story reads it before it answers.',
        requiresAnchor: true,
      ),
      GuideBeat(
        anchor: GuideIds.playRealm,
        title: 'The Realm',
        body:
            'The world\u2019s own name opens its records — everything this story '
            'has gathered about its people, places, and days.',
      ),
      GuideBeat(
        anchor: GuideIds.playMenu,
        title: 'The Telling',
        body:
            'And behind this mark, the voice the story is told in. Change it '
            'mid-scene and the next passage obeys.',
      ),
    ],
  );

  /// Runs when the player first opens their realm — the story's own menu.
  static const realm = GuideFlow(
    id: 'realm',
    label: 'The Realm',
    route: '/realm',
    beats: [
      GuideBeat(
        anchor: GuideIds.realmTomes,
        title: 'The Tomes',
        body:
            'Four records, all kept without you asking: the story so far, every '
            'turn in order, the people and where they stand with you, and the '
            'ground you have covered.',
      ),
      GuideBeat(
        anchor: GuideIds.realmPlaythrough,
        title: 'How It Is Told',
        body:
            'The voice this particular story speaks in — whose eyes you see '
            'through, how long each passage runs, and the mode it plays by.',
      ),
      GuideBeat(
        anchor: GuideIds.realmManage,
        title: 'Beginning Again',
        body:
            'A reset returns you to the opening line while the world itself '
            'survives. Deleting ends the playthrough for good.',
        requiresAnchor: true,
      ),
    ],
  );

  /// Runs the first time Scene Settings is opened — an explicit act of
  /// curiosity, so every knob gets named, one short line each.
  static const sceneSettings = GuideFlow(
    id: 'scene_settings',
    label: 'Scene Settings',
    beats: [
      GuideBeat(
        anchor: GuideIds.settingsNarration,
        anchorEnd: GuideIds.settingsNarrationControl,
        title: 'Whose Eyes',
        body:
            'Told as "I", or told about you from without. Change it and the '
            'next passage obeys.',
      ),
      GuideBeat(
        anchor: GuideIds.settingsMode,
        anchorEnd: GuideIds.settingsModeControl,
        title: 'The Mode',
        body: 'What kind of story this is, and how freely it plays.',
      ),
      GuideBeat(
        anchor: GuideIds.settingsVoice,
        anchorEnd: GuideIds.settingsVoiceControl,
        title: 'The Voice',
        body:
            'The hand the narrator writes with — spare and hard-boiled, lush '
            'and romantic, or something else entirely.',
      ),
      GuideBeat(
        anchor: GuideIds.settingsTone,
        anchorEnd: GuideIds.settingsToneControl,
        title: 'The Temper',
        body: 'How dark, how warm, how cruel the telling is willing to be.',
      ),
      GuideBeat(
        anchor: GuideIds.settingsPersona,
        anchorEnd: GuideIds.settingsPersonaControl,
        title: 'Your Mask',
        body:
            'Which of your personas walks into this story — a name, a history, '
            'a way of being.',
        requiresAnchor: true,
      ),
      GuideBeat(
        anchor: GuideIds.settingsLength,
        anchorEnd: GuideIds.settingsLengthControl,
        title: 'The Measure',
        body: 'How much prose each turn returns. Shorter turns move faster.',
      ),
    ],
  );

  /// Held until the story has a memory worth showing (see `GuideTriggers`).
  static const chronicle = GuideFlow(
    id: 'chronicle',
    label: 'The Chronicle',
    route: '/chronicle',
    beats: [
      GuideBeat(
        anchor: GuideIds.chronicleOverview,
        title: 'Where You Stand',
        body:
            'The story so far, drawn together — recent turns, open threads, '
            'and the shape of the moment you are in.',
      ),
      GuideBeat(
        anchor: GuideIds.chronicleStory,
        title: 'The Telling',
        body: 'Every turn in order, from the first line to the last.',
      ),
      GuideBeat(
        anchor: GuideIds.chroniclePeople,
        title: 'People',
        body:
            'Everyone the story has met, where they stand with you, and the '
            'promises and debts still hanging between you.',
      ),
      GuideBeat(
        anchor: GuideIds.chronicleWorld,
        title: 'World',
        body:
            'The places you have walked and the days you have spent. The world '
            'keeps its own calendar, and it moves whether or not you do.',
      ),
      GuideBeat(
        anchor: GuideIds.chronicleArchive,
        title: 'The Archive',
        body:
            'Every echo the world has kept — the raw memory behind everything '
            'else here.',
      ),
    ],
  );

  /// Just-in-time: fires the first time People is actually opened, pointing at
  /// the split that is only visible from inside that tab.
  static const chroniclePeople = GuideFlow(
    id: 'chronicle.people',
    label: 'Bonds and Threads',
    route: '/chronicle',
    beats: [
      GuideBeat(
        anchor: GuideIds.chroniclePeopleToggle,
        title: 'Bonds and Threads',
        body:
            'Bonds are where people stand with you. Threads are what remains '
            'unsettled between you — a promise made, a debt unpaid, a question '
            'never answered.',
        requiresAnchor: true,
      ),
    ],
  );

  /// Same, for the Places / Almanac split under World.
  static const chronicleWorld = GuideFlow(
    id: 'chronicle.world',
    label: 'Places and Days',
    route: '/chronicle',
    beats: [
      GuideBeat(
        anchor: GuideIds.chronicleWorldToggle,
        title: 'Places and Days',
        body:
            'Places holds the ground you have covered. The almanac holds the '
            'time — seasons turn here even while you stand still.',
        requiresAnchor: true,
      ),
    ],
  );

  /// Fires the first time Ink is actually spent, when the cost is legible.
  /// Explained before it matters, it is forgotten before it matters.
  static const ink = GuideFlow(
    id: 'ink',
    label: 'Story Ink',
    beats: [
      GuideBeat.card(
        title: 'Story Ink',
        body:
            'Every turn the world tells costs a measure of Ink. A failed '
            'telling never costs you any. Your reserve refills with your '
            'membership — and you can see what remains at any time.',
      ),
    ],
  );

  static const home = GuideFlow(
    id: 'home',
    label: 'Your Stories',
    route: '/',
    beats: [
      GuideBeat(
        anchor: GuideIds.homeCard,
        title: 'Stories in Progress',
        body:
            'Every world you have entered waits here exactly as you left it — '
            'same hour, same company, same unfinished sentence.',
        requiresAnchor: true,
      ),
    ],
  );

  /// The same shelf before anything stands on it.
  ///
  /// Every arc but this one was written for an app with content in it, which
  /// is not the app anybody meets first. A player who has signed up and gone
  /// looking for their stories finds an empty shelf, and the arc that explains
  /// the shelf is waiting for a card that cannot exist until they have played.
  /// This is what that surface has to say on the day it is empty.
  static const homeEmpty = GuideFlow(
    id: 'home.empty',
    label: 'An Empty Shelf',
    route: '/',
    beats: [
      GuideBeat(
        anchor: GuideIds.homeEmpty,
        title: 'Nothing Yet',
        body:
            'Your stories will gather here — each one holding its own hour, '
            'its own company, its own unfinished sentence. You have not begun '
            'one. The shelves are through Explore.',
        requiresAnchor: true,
      ),
    ],
  );

  static const myWorlds = GuideFlow(
    id: 'my_worlds',
    label: 'The Forge',
    route: '/my-worlds',
    beats: [
      GuideBeat(
        anchor: GuideIds.navCreate,
        title: 'The Forge',
        body:
            'Build a world of your own — its rules, its cast, its temper. Keep '
            'it private, or set it loose for others to live in.',
      ),
    ],
  );

  static const personas = GuideFlow(
    id: 'personas',
    label: 'Masks',
    route: '/personas',
    beats: [
      GuideBeat(
        anchor: GuideIds.personasCreate,
        // The empty vault's central button and the header pill that replaces
        // it are the same affordance wearing two hats. Naming both means the
        // beat lights a real control whether or not the player already keeps
        // personas, instead of degrading to a card pointing at nothing.
        fallbackAnchor: GuideIds.personasAdd,
        title: 'Masks',
        body:
            'A persona is who you are when you cross over — a name, a history, '
            'a way of being. Keep several, and choose one per story.',
      ),
    ],
  );

  /// Registry for lookup, replay, and the settings list. Order is the order
  /// a player would meet them.
  static const all = <GuideFlow>[
    arrival,
    worldDetail,
    playFirst,
    playTools,
    realm,
    sceneSettings,
    chronicle,
    chroniclePeople,
    chronicleWorld,
    ink,
    home,
    homeEmpty,
    myWorlds,
    personas,
  ];

  static GuideFlow? byId(String id) {
    for (final flow in all) {
      if (flow.id == id) return flow;
    }
    return null;
  }
}
