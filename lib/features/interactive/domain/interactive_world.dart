import 'package:flutter/foundation.dart';

/// How much of a place the player currently knows.
///
/// [rumoured] is the one that carries the open-world feeling: the place is not
/// drawn at all and its region sits under fog, so the map visibly grows during
/// play rather than being laid out on turn one.
enum WorldVisibility { open, sealed, rumoured }

WorldVisibility _visibility(String? raw) => switch (raw) {
  'open' => WorldVisibility.open,
  'sealed' => WorldVisibility.sealed,
  _ => WorldVisibility.rumoured,
};

@immutable
class WorldSpriteVariant {
  const WorldSpriteVariant({required this.flag, required this.assetId});
  final String flag;
  final String assetId;
}

/// Where a place's marker sits on the stitched terrain.
///
/// [x] and [y] are normalised against the whole MAP, never a single plate, so
/// re-stitching at a different resolution cannot move anything. This used to
/// carry a landmark sprite's size, aspect and rotation as well; the plate
/// paints its own places now, so only the anchor point still matters.
@immutable
class WorldSprite {
  const WorldSprite({
    required this.assetId,
    required this.x,
    required this.y,
    required this.scale,
    required this.anchorAtBase,
    required this.z,
    required this.variants,
  });

  final String assetId;
  final double x;
  final double y;
  final double scale;
  final bool anchorAtBase;
  final int z;
  final List<WorldSpriteVariant> variants;

  /// The art a place shows right now. State is server-owned; the renderer only
  /// picks the layer that matches it.
  String assetIdFor(Set<String> flags) {
    for (final variant in variants) {
      if (flags.contains(variant.flag)) return variant.assetId;
    }
    return assetId;
  }

  factory WorldSprite.fromJson(Map<String, dynamic> json) => WorldSprite(
    assetId: json['asset_id'] as String? ?? '',
    x: (json['x'] as num?)?.toDouble() ?? .5,
    y: (json['y'] as num?)?.toDouble() ?? .5,
    scale: (json['scale'] as num?)?.toDouble() ?? 1,
    anchorAtBase: json['anchor'] != 'center',
    z: (json['z'] as num?)?.toInt() ?? 0,
    variants: (json['variants'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (raw) => WorldSpriteVariant(
            flag: raw['flag'] as String? ?? '',
            assetId: raw['asset_id'] as String? ?? '',
          ),
        )
        .where((v) => v.flag.isNotEmpty && v.assetId.isNotEmpty)
        .toList(),
  );
}

@immutable
class WorldLocation {
  const WorldLocation({
    required this.id,
    required this.title,
    required this.description,
    required this.realm,
    required this.authoredVisibility,
    required this.drawnAsMarker,
    required this.sprite,
    required this.sceneAssetId,
    required this.sceneHeadline,
    required this.sceneBody,
    required this.routes,
    required this.unlockFlag,
    required this.sealedReason,
    required this.revealFlag,
  });

  final String id;
  final String title;
  final String description;
  final String realm;
  final WorldVisibility authoredVisibility;

  /// Pinned on the painting rather than redrawn on it. True where the plate is
  /// already built up, because a landmark sprite over painted architecture
  /// reads as a sticker at any position or size.
  final bool drawnAsMarker;
  final WorldSprite sprite;
  final String? sceneAssetId;
  final String? sceneHeadline;
  final String? sceneBody;
  final List<String> routes;
  final String? unlockFlag;
  final String? sealedReason;
  final String? revealFlag;

  /// A place with no scene is map presence only — named, owned, fought over,
  /// travelled past, but never entered. That is what keeps thirty locations
  /// inside twenty scene paintings.
  bool get isEnterable => sceneAssetId != null;

  /// Mirrors the server's rule exactly so an optimistic frame never disagrees
  /// with the authoritative answer. The server still decides; this only avoids
  /// drawing a place the player has not heard of.
  WorldVisibility visibilityFor(Set<String> flags) {
    if (authoredVisibility == WorldVisibility.rumoured &&
        !(revealFlag != null && flags.contains(revealFlag))) {
      return WorldVisibility.rumoured;
    }
    if (unlockFlag != null && !flags.contains(unlockFlag)) {
      return WorldVisibility.sealed;
    }
    return WorldVisibility.open;
  }

  factory WorldLocation.fromJson(Map<String, dynamic> json) => WorldLocation(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    realm: json['realm'] as String? ?? '',
    drawnAsMarker: json['map_render'] == 'marker',
    authoredVisibility: _visibility(json['visibility'] as String?),
    sprite: WorldSprite.fromJson(
      Map<String, dynamic>.from(json['sprite'] as Map? ?? const {}),
    ),
    sceneAssetId: json['scene_asset_id'] as String?,
    sceneHeadline: json['scene_headline'] as String?,
    sceneBody: json['scene_body'] as String?,
    routes: (json['routes'] as List? ?? const []).whereType<String>().toList(),
    unlockFlag: json['unlock_flag'] as String?,
    sealedReason: json['sealed_reason'] as String?,
    revealFlag: json['reveal_flag'] as String?,
  );
}

/// An authored action. The client submits an id; the server decides what it
/// means. Nothing here can invent a flag.
@immutable
class WorldChoice {
  const WorldChoice({
    required this.id,
    required this.at,
    required this.label,
    required this.requires,
    required this.forbids,
  });

  final String id;
  final String at;
  final String label;

  /// Every flag that must be set. Authored as a bare string for the common
  /// single-gate case and as a list where a road needs more than one.
  final List<String> requires;

  /// Any flag that withdraws this choice. The endgame roads are exclusive —
  /// once the writ is in the Court's hands it cannot also be burned — and
  /// without this the player is offered a road the server will refuse.
  final List<String> forbids;

  bool availableAt(String locationId, Set<String> flags) =>
      at == locationId &&
      requires.every(flags.contains) &&
      !forbids.any(flags.contains);

  /// Accepts a string, a list, or nothing. The authored data uses whichever
  /// reads better at the site, so parsing has to take both rather than crash
  /// on the shape it did not expect.
  static List<String> _flags(Object? value) => switch (value) {
    String flag => [flag],
    List<Object?> list => list.whereType<String>().toList(),
    _ => const [],
  };

  factory WorldChoice.fromJson(Map<String, dynamic> json) => WorldChoice(
    id: json['id'] as String? ?? '',
    at: json['at'] as String? ?? '',
    label: json['label'] as String? ?? '',
    requires: _flags(json['requires']),
    forbids: _flags(json['forbids']),
  );
}

@immutable
class WorldRealm {
  const WorldRealm({
    required this.id,
    required this.title,
    required this.yFrom,
    required this.yTo,
  });
  final String id;
  final String title;
  final double yFrom;
  final double yTo;

  bool contains(double y) => y >= yFrom && y <= yTo;

  factory WorldRealm.fromJson(Map<String, dynamic> json) => WorldRealm(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    yFrom: (json['y_from'] as num?)?.toDouble() ?? 0,
    yTo: (json['y_to'] as num?)?.toDouble() ?? 1,
  );
}

/// The whole definition, with asset ids already resolved to CDN URLs.
@immutable
class InteractiveWorld {
  const InteractiveWorld({
    required this.key,
    required this.title,
    required this.chapterTitle,
    required this.plateAssetIds,
    required this.mapAspect,
    required this.fogAssetId,
    required this.sealedMarkerAssetId,
    required this.realms,
    required this.locations,
    required this.choices,
    required this.assetUrls,
    required this.assetAspects,
  });

  final String key;
  final String title;
  final String chapterTitle;

  /// In stack order, top to bottom.
  final List<String> plateAssetIds;
  final double mapAspect;
  final String? fogAssetId;
  final String? sealedMarkerAssetId;
  final List<WorldRealm> realms;
  final List<WorldLocation> locations;
  final List<WorldChoice> choices;
  final Map<String, String> assetUrls;

  /// height / width of each published asset, measured by the asset pipeline.
  final Map<String, double> assetAspects;

  String? urlFor(String? assetId) =>
      assetId == null ? null : assetUrls[assetId];

  /// height / width of a published asset, or null when it is not published yet.
  /// Callers must handle null rather than substituting a square, because a
  /// square is a plausible wrong answer that renders without complaint.
  double? aspectFor(String? assetId) =>
      assetId == null ? null : assetAspects[assetId];

  WorldLocation? byId(String id) {
    for (final location in locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  static InteractiveWorld? fromJson(Map<String, dynamic> json) {
    final style = json['map_style'];
    if (style is! Map) return null;
    final mapStyle = Map<String, dynamic>.from(style);
    if (mapStyle['renderer'] != 'terrain_plate_scene_graph') return null;

    final urls = <String, String>{};
    final aspects = <String, double>{};
    for (final raw in (json['assets'] as List? ?? const []).whereType<Map>()) {
      final asset = Map<String, dynamic>.from(raw);
      final id = asset['id'];
      final url = asset['url'];
      // A null url is normal before art is published; the place still exists.
      if (id is String && url is String && url.isNotEmpty) urls[id] = url;
      // Measured on the published file by the asset pipeline. Without it the
      // layout has to assume a shape, and every wrong assumption here renders
      // silently rather than throwing.
      final w = (asset['width'] as num?)?.toDouble();
      final h = (asset['height'] as num?)?.toDouble();
      if (id is String && w != null && h != null && w > 0 && h > 0) {
        aspects[id] = h / w;
      }
    }

    final plates =
        (mapStyle['plates'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
          ..sort(
            (a, b) => ((a['order'] as num?) ?? 0).compareTo(
              (b['order'] as num?) ?? 0,
            ),
          );

    final aspect = Map<String, dynamic>.from(
      mapStyle['map_aspect'] as Map? ?? const {},
    );
    final width = (aspect['width'] as num?)?.toDouble() ?? 1;
    final height = (aspect['height'] as num?)?.toDouble() ?? 1;

    return InteractiveWorld(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      chapterTitle: json['chapter_title'] as String? ?? '',
      plateAssetIds: plates
          .map((p) => p['asset_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
      mapAspect: width <= 0 ? 1 : height / width,
      fogAssetId: mapStyle['fog_asset_id'] as String?,
      sealedMarkerAssetId: mapStyle['sealed_marker_asset_id'] as String?,
      realms: (json['realms'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => WorldRealm.fromJson(Map<String, dynamic>.from(raw)))
          .toList(),
      locations: (json['locations'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => WorldLocation.fromJson(Map<String, dynamic>.from(raw)))
          .toList(),
      choices: (json['choices'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => WorldChoice.fromJson(Map<String, dynamic>.from(raw)))
          .toList(),
      assetUrls: urls,
      assetAspects: aspects,
    );
  }
}

/// Server-owned player state. The client renders it and never derives it.
@immutable
class InteractiveWorldState {
  const InteractiveWorldState({
    required this.currentLocationId,
    required this.unlockedIds,
    required this.revealedIds,
    required this.flags,
  });

  const InteractiveWorldState.empty()
    : currentLocationId = '',
      unlockedIds = const {},
      revealedIds = const {},
      flags = const {};

  final String currentLocationId;
  final Set<String> unlockedIds;
  final Set<String> revealedIds;
  final Set<String> flags;

  factory InteractiveWorldState.fromJson(Map<String, dynamic> json) {
    final rawFlags = Map<String, dynamic>.from(
      json['flags'] as Map? ?? const {},
    );
    return InteractiveWorldState(
      currentLocationId: json['current_location_id'] as String? ?? '',
      unlockedIds: (json['unlocked_location_ids'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      revealedIds: (json['revealed_location_ids'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      flags: rawFlags.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toSet(),
    );
  }
}

/// A quarrel brought to the player to rule on, once the reign has begun.
///
/// The parties state their own cases and disagree; what is actually true is
/// deliberately not sent, and neither is what any ruling will cost. Both live
/// on the server. A petition the client could see through is not a judgement,
/// it is a menu with the answers printed on it.
@immutable
class WorldPetition {
  const WorldPetition({
    required this.id,
    required this.title,
    required this.at,
    required this.kind,
    required this.parties,
    required this.resolutions,
    required this.cites,
  });

  final String id;
  final String title;
  final String at;
  final String kind;
  final List<({String name, String claim})> parties;
  final List<({String id, String label})> resolutions;

  /// Rulings this petitioner has arrived already quoting. A principle set here
  /// or one route away travels, and the claim has been shaped to win under it.
  final List<String> cites;

  factory WorldPetition.fromJson(Map<String, dynamic> json) => WorldPetition(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    at: json['at'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    parties: (json['parties'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (p) => (
            name: p['name'] as String? ?? '',
            claim: p['claim'] as String? ?? '',
          ),
        )
        .toList(),
    resolutions: (json['resolutions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (r) => (id: r['id'] as String? ?? '', label: r['label'] as String? ?? ''),
        )
        .toList(),
    cites: (json['cites'] as List? ?? const [])
        .whereType<Map>()
        .map((c) => c['principle'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toList(),
  );
}

/// One ruling already handed down. The player's own record.
@immutable
class WorldLedgerEntry {
  const WorldLedgerEntry({
    required this.petitionId,
    required this.madeWhole,
    required this.madeToPay,
    required this.principle,
  });

  final String petitionId;
  final String madeWhole;
  final String madeToPay;
  final String principle;

  factory WorldLedgerEntry.fromJson(Map<String, dynamic> json) => WorldLedgerEntry(
    petitionId: json['petition_id'] as String? ?? '',
    madeWhole: json['made_whole'] as String? ?? '',
    madeToPay: json['made_to_pay'] as String? ?? '',
    principle: json['principle'] as String? ?? '',
  );
}

/// What the player has become: how factions read them, what they have earned,
/// where the story landed, and what is now being brought to them.
///
/// All of it is derived on the server from the choices and rulings already
/// recorded, so the client renders it and never accumulates it — a stale total
/// here would be a total nothing could correct.
@immutable
class WorldProgression {
  const WorldProgression({
    this.standing = const [],
    this.marks = const [],
    this.endingTitle,
    this.endingCost,
    this.reignDescription,
    this.petitions = const [],
    this.ledger = const [],
  });

  final List<({String id, String title, int value})> standing;
  final List<({String title, String description, bool earned})> marks;
  final String? endingTitle;
  final String? endingCost;
  final String? reignDescription;
  final List<WorldPetition> petitions;
  final List<WorldLedgerEntry> ledger;

  bool get hasEnded => endingTitle != null;

  static const empty = WorldProgression();

  factory WorldProgression.fromJson(Map<String, dynamic> json) {
    final ending = json['ending'] as Map?;
    return WorldProgression(
      standing: (json['standing'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (s) => (
              id: s['id'] as String? ?? '',
              title: s['title'] as String? ?? '',
              value: (s['value'] as num? ?? 0).toInt(),
            ),
          )
          .toList(),
      marks: (json['marks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (m) => (
              title: m['title'] as String? ?? '',
              description: m['description'] as String? ?? '',
              earned: m['earned'] == true,
            ),
          )
          .toList(),
      endingTitle: ending?['title'] as String?,
      endingCost: ending?['cost'] as String?,
      reignDescription: ending?['reign_description'] as String?,
      petitions: (json['petitions'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => WorldPetition.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      ledger: (json['ledger'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => WorldLedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Someone standing where the player is. The server has already filtered this
/// to the room; the client must not invent a second list from world data.
///
/// What they know, want or fear is deliberately absent. Showing a blank for
/// those would teach the player that the surface is incomplete, so the model
/// does not have the fields.
@immutable
class WorldPresence {
  const WorldPresence({
    required this.id,
    required this.name,
    required this.role,
    required this.faction,
    required this.portraitUrl,
    required this.met,
    required this.firstMet,
  });

  final String id;
  final String name;
  final String role;
  final String faction;
  final String? portraitUrl;
  final bool met;

  /// Authored entrance, present only while [met] is false. It is the meeting
  /// itself, not a caption to keep under their feet.
  final String? firstMet;

  factory WorldPresence.fromJson(Map<String, dynamic> json) => WorldPresence(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    faction: json['faction'] as String? ?? '',
    // An empty string is not a face; treating it as a URL flashes a failed
    // load and then a fallback, which reads as a broken painting.
    portraitUrl: switch (json['portrait_url']) {
      final String url when url.isNotEmpty => url,
      _ => null,
    },
    met: json['met'] == true,
    firstMet: switch (json['first_met']) {
      final String prose when prose.isNotEmpty => prose,
      _ => null,
    },
  );
}

/// The line that came back from a word spoken. Null on every other action.
///
/// [portraitUrl] is the bearing of this reply and may differ from the face
/// they wear while standing in the room. A missing line is still a reply —
/// the world does not mark a refusal as an error.
@immutable
class WorldSpoken {
  const WorldSpoken({
    required this.characterId,
    required this.name,
    required this.line,
    required this.portraitUrl,
  });

  final String characterId;
  final String name;
  final String line;
  final String? portraitUrl;

  factory WorldSpoken.fromJson(Map<String, dynamic> json) => WorldSpoken(
    characterId: json['character_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    line: json['line'] as String? ?? '',
    portraitUrl: switch (json['portrait_url']) {
      final String url when url.isNotEmpty => url,
      _ => null,
    },
  );
}

/// One side of a Verdict fought on the sand.
///
/// [characterId] is set only where the fighter is also someone the player can
/// meet and talk to, so the person on the sand and the person in the room are
/// known to be the same. [portraitUrl] may be null: the player has no painted
/// face, and neither does a champion hired for one afternoon.
@immutable
class WorldDuelFighter {
  const WorldDuelFighter({
    required this.side,
    required this.characterId,
    required this.name,
    required this.role,
    required this.isPlayer,
    required this.portraitUrl,
    required this.vigour,
  });

  final String side;
  final String? characterId;
  final String name;
  final String role;
  final bool isPlayer;
  final String? portraitUrl;

  /// What they can take before it is over. Never shown as a number.
  final int vigour;

  factory WorldDuelFighter.fromJson(Map<String, dynamic> json) =>
      WorldDuelFighter(
        side: json['side'] as String? ?? '',
        characterId: switch (json['character_id']) {
          final String id when id.isNotEmpty => id,
          _ => null,
        },
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        isPlayer: json['is_player'] == true,
        portraitUrl: switch (json['portrait_url']) {
          final String url when url.isNotEmpty => url,
          _ => null,
        },
        vigour: (json['vigour'] as num?)?.round() ?? 0,
      );
}

/// One exchange, already staged. The client renders it and decides nothing:
/// who acts, what it costs and where the bars stand afterwards all arrive
/// settled, because they are what the rest of the story is written against.
@immutable
class WorldDuelBeat {
  const WorldDuelBeat({
    required this.actor,
    required this.actorName,
    required this.action,
    required this.said,
    required this.toll,
    required this.portraitUrl,
    required this.challengerVigour,
    required this.defenderVigour,
    required this.decisive,
  });

  final String actor;
  final String actorName;
  final String action;

  /// Words spoken aloud mid-fight, where the author wrote any. Most exchanges
  /// are silent and a bubble on every one of them would be chatter.
  final String? said;
  final int toll;
  final String? portraitUrl;
  final int challengerVigour;
  final int defenderVigour;

  /// The exchange the Verdict turns on. Exactly one carries it.
  final bool decisive;

  factory WorldDuelBeat.fromJson(Map<String, dynamic> json) => WorldDuelBeat(
    actor: json['actor'] as String? ?? '',
    actorName: json['actor_name'] as String? ?? '',
    action: json['action'] as String? ?? '',
    said: switch (json['said']) {
      final String line when line.trim().isNotEmpty => line,
      _ => null,
    },
    toll: (json['toll'] as num?)?.round() ?? 0,
    portraitUrl: switch (json['portrait_url']) {
      final String url when url.isNotEmpty => url,
      _ => null,
    },
    challengerVigour: (json['challenger_vigour'] as num?)?.round() ?? 0,
    defenderVigour: (json['defender_vigour'] as num?)?.round() ?? 0,
    decisive: json['decisive'] == true,
  );
}

/// How the Verdict ended, and what it cost. Read out when the fight is over.
@immutable
class WorldDuelOutcome {
  const WorldDuelOutcome({
    required this.winner,
    required this.victorName,
    required this.fallenName,
    required this.verdict,
    required this.cost,
    required this.fatal,
  });

  final String winner;
  final String victorName;
  final String fallenName;
  final String verdict;
  final String cost;
  final bool fatal;

  factory WorldDuelOutcome.fromJson(Map<String, dynamic> json) =>
      WorldDuelOutcome(
        winner: json['winner'] as String? ?? '',
        victorName: json['victor_name'] as String? ?? '',
        fallenName: json['fallen_name'] as String? ?? '',
        verdict: json['verdict'] as String? ?? '',
        cost: json['cost'] as String? ?? '',
        fatal: json['fatal'] == true,
      );
}

/// A fight that makes law, arriving with the turn that called for it.
///
/// It is present only on the turn the fight happens, and it is a rendering of
/// something already decided — the world has already written down who won by
/// the time this is drawn. Nothing here may be recomputed, skipped forward or
/// resolved differently on the device.
@immutable
class WorldDuel {
  const WorldDuel({
    required this.id,
    required this.at,
    required this.question,
    required this.herald,
    required this.vigour,
    required this.challenger,
    required this.defender,
    required this.beats,
    required this.outcome,
  });

  final String id;
  final String at;

  /// The matter being settled, read to the tiers before the first blow.
  final String question;
  final String herald;
  final int vigour;
  final WorldDuelFighter challenger;
  final WorldDuelFighter defender;
  final List<WorldDuelBeat> beats;
  final WorldDuelOutcome outcome;

  WorldDuelFighter fighter(String side) =>
      side == 'challenger' ? challenger : defender;

  /// A fight with no exchanges is a title card, and a turn that carries a
  /// half-formed one is better rendered as the choice it already was.
  static WorldDuel? tryFrom(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final challenger = json['challenger'];
    final defender = json['defender'];
    final outcome = json['outcome'];
    if (challenger is! Map || defender is! Map || outcome is! Map) return null;
    final beats = (json['beats'] as List? ?? const [])
        .whereType<Map>()
        .map((beat) => WorldDuelBeat.fromJson(Map<String, dynamic>.from(beat)))
        .where((beat) => beat.action.trim().isNotEmpty)
        .toList();
    if (beats.isEmpty) return null;
    return WorldDuel(
      id: json['id'] as String? ?? '',
      at: json['at'] as String? ?? '',
      question: json['question'] as String? ?? '',
      herald: json['herald'] as String? ?? '',
      vigour: (json['vigour'] as num?)?.round() ?? 100,
      challenger: WorldDuelFighter.fromJson(
        Map<String, dynamic>.from(challenger),
      ),
      defender: WorldDuelFighter.fromJson(Map<String, dynamic>.from(defender)),
      beats: beats,
      outcome: WorldDuelOutcome.fromJson(Map<String, dynamic>.from(outcome)),
    );
  }
}
