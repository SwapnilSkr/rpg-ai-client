import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../data/interactive_world_repository.dart';
import '../domain/interactive_world.dart';
import 'travel_transition.dart';
import 'world_characters.dart';
import 'world_duel.dart';
import 'world_frame.dart';
import 'world_map_view.dart';

/// An interactive world — a terrain plate with placed markers, not a chat UI
/// with a decorative map.
///
/// Everything visible here is authored server data: which places exist, what
/// the player has heard of, what is sealed and why, and what can be done. The
/// client renders and predicts; it never decides.
///
/// The world is named by [worldKey] rather than baked in. The server has
/// always been world-agnostic — it reads whatever is in its data folder and
/// every route takes the key as a parameter — and this screen used to hold a
/// single world's key as a constant, so none of that could reach a player.
/// Worse, the callers had already begun building the path from real data while
/// the route still matched one literal segment: the first second world added
/// would have pushed a path nothing could route, and if it had routed, this
/// screen would have loaded the wrong world anyway.
class InteractiveWorldScreen extends StatefulWidget {
  const InteractiveWorldScreen({
    super.key,
    required this.worldKey,
    this.instanceId,
  });

  /// Which authored world to open, taken from the route.
  final String worldKey;

  /// A real play instance makes this screen server-backed. Without one it is
  /// the authoring preview: the published world, with no player state.
  final String? instanceId;

  @override
  State<InteractiveWorldScreen> createState() => _InteractiveWorldScreenState();
}

enum _View { map, scene }

class _InteractiveWorldScreenState extends State<InteractiveWorldScreen> {

  final _repository = const InteractiveWorldRepository();
  InteractiveWorld? _world;
  InteractiveWorldState _state = const InteractiveWorldState.empty();
  WorldProgression _progression = WorldProgression.empty;
  List<WorldPresence> _cast = const [];
  final Map<String, List<VisitLine>> _visit = {};
  final Set<String> _metHere = {};
  String? _addressingId;
  _View _view = _View.map;
  String? _selectedId;
  bool _loading = true;
  bool _acting = false;
  String? _error;
  String? _travellingTo;
  String _waitingLine = 'The land unfolds';

  bool get _isServerBacked => widget.instanceId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _waitingLine = 'The land unfolds';
    });
    try {
      final payload = _isServerBacked
          ? await _repository.loadInstance(
              worldKey: widget.worldKey,
              instanceId: widget.instanceId!,
            )
          : {'world': await _repository.loadWorld(widget.worldKey)};
      if (!mounted) return;
      _apply(payload);
      final world = _world;
      if (world != null) {
        // The map is shown the moment the words arrive. The plates then
        // fill in after, so a cold opening is an empty grid. Only the
        // land under the camera belongs on this wait — the rest of the
        // world would hold the gate for a minute.
        await awaitWorldFrame(
          context,
          urls: [
            for (final plateId in world.plateAssetIds) world.urlFor(plateId),
          ],
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The world could not be reached.';
      });
      debugPrint('interactive world load failed: $error');
    }
  }

  void _apply(Map<String, dynamic> payload) {
    final rawWorld = payload['world'];
    if (rawWorld is Map) {
      final world = InteractiveWorld.fromJson(
        Map<String, dynamic>.from(rawWorld),
      );
      if (world != null) _world = world;
    }
    final previousAt = _state.currentLocationId;
    final rawState = payload['state'];
    if (rawState is Map) {
      _state = InteractiveWorldState.fromJson(
        Map<String, dynamic>.from(rawState),
      );
    } else if (_world != null && _state.currentLocationId.isEmpty) {
      // Authoring preview: show the world as a new player would first meet it.
      final open = _world!.locations
          .where((l) => l.authoredVisibility == WorldVisibility.open)
          .toList();
      _state = InteractiveWorldState(
        currentLocationId: open.isEmpty ? '' : open.first.id,
        unlockedIds: open.map((l) => l.id).toSet(),
        revealedIds: _world!.locations
            .where((l) => l.authoredVisibility != WorldVisibility.rumoured)
            .map((l) => l.id)
            .toSet(),
        flags: const {},
      );
    }
    // A word can unseal a door or walk the player on. Keeping the last room's
    // exchange would put those sentences in a place that never heard them.
    if (previousAt.isNotEmpty && previousAt != _state.currentLocationId) {
      _visit.clear();
      _metHere.clear();
      _addressingId = null;
    }
    final rawProgression = payload['progression'];
    if (rawProgression is Map) {
      _progression = WorldProgression.fromJson(
        Map<String, dynamic>.from(rawProgression),
      );
    }
    final rawCast = payload['cast'];
    if (rawCast is List) {
      _cast = rawCast
          .whereType<Map>()
          .map((raw) => WorldPresence.fromJson(Map<String, dynamic>.from(raw)))
          .where((who) => who.id.isNotEmpty)
          .toList();
    }
    if (_addressingId != null &&
        !_cast.any((who) => who.id == _addressingId)) {
      _addressingId = null;
    }
    // Talk is not a side channel. The rest of the payload is applied the
    // same way a choice is; this only keeps the line they just answered.
    final rawSpoken = payload['spoken'];
    if (rawSpoken is Map) {
      final spoken = WorldSpoken.fromJson(Map<String, dynamic>.from(rawSpoken));
      if (spoken.characterId.isNotEmpty && spoken.line.isNotEmpty) {
        _visit.putIfAbsent(spoken.characterId, () => []).add(
          VisitLine(
            fromPlayer: false,
            text: spoken.line,
            portraitUrl: spoken.portraitUrl,
          ),
        );
      }
    }
    _selectedId ??= _state.currentLocationId;
  }

  WorldLocation? get _selected => _world?.byId(_selectedId ?? '');
  WorldLocation? get _here => _world?.byId(_state.currentLocationId);

  Future<bool> _act({
    required String type,
    String? locationId,
    String? choiceId,
    String? petitionId,
    String? resolutionId,
    String? characterId,
    String? said,
    bool alreadyActing = false,
  }) async {
    if (!_isServerBacked) {
      // The road was held for a walk this glimpse cannot take. Leaving
      // the lock set would freeze every later action on a preview.
      if (alreadyActing && mounted) setState(() => _acting = false);
      _notice('This glimpse has no memory of you. Enter from My Worlds to play.');
      return false;
    }
    // The road is already held while the destination is drawn. Dropping
    // the lock to call this would let a second tap start a second move;
    // treating the hold as a refusal would swallow the walk that waited.
    if (_acting && !alreadyActing) return false;
    if (!alreadyActing) setState(() => _acting = true);
    try {
      final payload = await _repository.act(
        worldKey: widget.worldKey,
        instanceId: widget.instanceId!,
        type: type,
        locationId: locationId,
        choiceId: choiceId,
        petitionId: petitionId,
        resolutionId: resolutionId,
        characterId: characterId,
        said: said,
      );
      if (!mounted) return false;
      // Read off the payload BEFORE it is applied, because applying it is what
      // moves the player on: by the time the room has changed, the fight that
      // changed it is no longer the turn we are holding.
      final fought = WorldDuel.tryFrom(payload['duel']);
      setState(() {
        _apply(payload);
        _acting = false;
      });
      if (fought != null) await _watch(fought);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _acting = false);
      // The server owns the refusal and its wording; surface it rather than
      // guessing a reason the fiction has not given.
      _notice(_reasonFrom(error));
      return false;
    }
  }

  /// The fight a choice was settled by.
  ///
  /// Watched AFTER the turn has been applied and never before: the Verdict is
  /// already law, so a player who backs out of the screen, kills the app or
  /// never sees a single exchange still lives in the duchy it decided. This
  /// only shows them what happened.
  Future<void> _watch(WorldDuel duel) async {
    final backdrop = _world?.urlFor(_world?.byId(duel.at)?.sceneAssetId);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => DuelStage(duel: duel, backdropUrl: backdrop),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  WorldPresence? get _addressing {
    final id = _addressingId;
    if (id == null) return null;
    for (final who in _cast) {
      if (who.id == id) return who;
    }
    return null;
  }

  void _address(WorldPresence who) {
    if (_acting) return;
    // first_met is the entrance, not a title. Putting it under their feet
    // every time the player walked in made a meeting into a caption.
    final meeting = who.firstMet;
    if (!_metHere.contains(who.id) && meeting != null) {
      final lines = _visit.putIfAbsent(who.id, () => []);
      if (lines.isEmpty) {
        lines.add(
          VisitLine(
            fromPlayer: false,
            text: meeting,
            portraitUrl: who.portraitUrl,
            meeting: true,
          ),
        );
      }
      _metHere.add(who.id);
    }
    setState(() => _addressingId = who.id);
  }

  Future<void> _speak(String characterId, String said) async {
    // Two talks in flight would interleave replies onto the same visit, and
    // the second would be a sentence the first had not finished answering.
    if (_acting) return;
    final text = said.trim();
    if (text.isEmpty || text.length > 500) return;
    if (!_cast.any((who) => who.id == characterId)) return;
    setState(() {
      _visit.putIfAbsent(characterId, () => []).add(
        VisitLine(fromPlayer: true, text: text),
      );
    });
    final reached = await _act(
      type: 'talk',
      characterId: characterId,
      said: text,
    );
    if (reached || !mounted) return;
    setState(() {
      final lines = _visit[characterId];
      if (lines != null &&
          lines.isNotEmpty &&
          lines.last.fromPlayer &&
          lines.last.text == text) {
        lines.removeLast();
      }
    });
  }

  String? _bearingFor(WorldPresence who) {
    final lines = _visit[who.id];
    if (lines == null) return who.portraitUrl;
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      // Meeting uses the face they stand with. Only a reply's bearing
      // may change what they are wearing.
      if (!line.fromPlayer && !line.meeting && line.portraitUrl != null) {
        return line.portraitUrl;
      }
    }
    return who.portraitUrl;
  }

  /// Why the world would not take that action.
  ///
  /// Only a refusal the server actually worded is reported as a refusal. When
  /// the request never got an answer — a dropped connection, a request that
  /// timed out — the player is told that instead, because the previous
  /// fallback claimed the road was closed to them and that is a lie the
  /// fiction never told: the road was open, the message never arrived. It sent
  /// a play-test hunting a locked choice that was not locked.
  String _reasonFrom(Object error) {
    final match = RegExp(
      r'"message"\s*:\s*"([^"]+)"',
    ).firstMatch(error.toString());
    return match?.group(1) ?? 'That did not reach the world. Try it again.';
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _travel(WorldLocation destination) async {
    if (_acting) return;
    setState(() => _acting = true);
    final world = _world;
    if (world != null) {
      // The walk eases the destination in. Starting it before that
      // painting can be drawn is arriving in a room that is not there.
      await awaitWorldFrame(
        context,
        urls: [world.urlFor(destination.sceneAssetId)],
      );
    }
    if (!mounted) return;
    setState(() => _travellingTo = destination.id);
    await _act(type: 'move', locationId: destination.id, alreadyActing: true);
    if (!mounted) return;
    final arrived = _state.currentLocationId == destination.id;
    if (arrived && destination.isEnterable) {
      setState(() {
        _travellingTo = null;
        _loading = true;
        _waitingLine = 'You cross the threshold';
      });
      await _awaitSceneFrame();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _view = _View.scene;
      });
    } else {
      setState(() => _travellingTo = null);
    }
  }

  /// The room is shown the moment they tap Enter. The painting and the
  /// people in it then fill in after, so they watch a dark frame become
  /// a place.
  Future<void> _enterScene() async {
    if (_acting || _loading) return;
    setState(() {
      _loading = true;
      _waitingLine = 'You cross the threshold';
    });
    await _awaitSceneFrame();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _view = _View.scene;
    });
  }

  /// Fifty-eight paintings is a minute of the sigil. Only the room they
  /// are walking into, and the faces already in it, can hold this curtain.
  Future<void> _awaitSceneFrame() async {
    final world = _world;
    final here = _here;
    if (world == null || here == null || !mounted) return;
    await awaitWorldFrame(
      context,
      urls: [world.urlFor(here.sceneAssetId)],
      cutouts: [for (final who in _cast) who.portraitUrl],
      cutoutMaxHeight: CharacterCutout.cacheHeightOf(context),
    );
  }

  bool get _inConversation => _view == _View.scene && _addressing != null;

  @override
  Widget build(BuildContext context) {
    final world = _world;
    final talking = !_loading && world != null && _inConversation;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0908),
      // The painting must not shrink when the field opens. Only the
      // parchment is padded for the keyboard.
      resizeToAvoidBottomInset: !talking,
      body: SafeArea(
        top: !talking,
        bottom: !talking,
        child: _loading
            ? Center(child: EverloreSessionLoader(message: _waitingLine))
            : world == null
            ? _Failure(message: _error ?? 'This world is not published yet.', onRetry: _load)
            : _view == _View.map
            ? _buildMap(world)
            : _buildScene(world),
      ),
    );
  }

  Widget _buildMap(InteractiveWorld world) {
    final selected = _selected;
    return Stack(
      fit: StackFit.expand,
      children: [
        WorldMapView(
          world: world,
          state: _state,
          selectedId: _selectedId,
          onSelect: (location) => setState(() => _selectedId = location.id),
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: EverloreTheme.parchment,
              ),
              Expanded(
                child: _Title(
                  subtitle: world.chapterTitle.toUpperCase(),
                  title: world.title,
                ),
              ),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SelectionCard(
              artUrl: world.urlFor(selected.sprite.assetIdFor(_state.flags)),
              location: selected,
              visibility: selected.visibilityFor(_state.flags),
              isHere: selected.id == _state.currentLocationId,
              busy: _acting,
              onTravel: () => _travel(selected),
              onEnter: () => unawaited(_enterScene()),
            ),
          ),
        if (_travellingTo != null)
          Positioned.fill(
            child: TravelTransition(
              backgroundUrl: world.urlFor(
                world.byId(_travellingTo!)?.sceneAssetId,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScene(InteractiveWorld world) {
    final location = _here;
    if (location == null || !location.isEnterable) {
      return _Failure(
        message: 'There is nothing to enter here.',
        onRetry: () => setState(() => _view = _View.map),
        label: 'Back to the map',
      );
    }
    final url = world.urlFor(location.sceneAssetId);
    final choices = world.choices
        .where((c) => c.availableAt(location.id, _state.flags))
        .toList();
    // A petition displaces the scene's own copy rather than sitting beside it.
    // Someone is standing in front of the player waiting to be answered, and
    // that is the whole of what this place is until it is answered.
    final petition = _progression.petitions
        .where((p) => p.at == location.id)
        .firstOrNull;
    final addressing = _addressing;
    final scene = Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          // The opening holds this same provider. A NetworkImage here
          // would paint from a shelf the gate never warmed, and the
          // player would still watch a dark room become a place.
          EverloreNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: const ColoredBox(color: Color(0xFF14100E)),
            errorWidget: const ColoredBox(color: Color(0xFF14100E)),
          )
        else
          const ColoredBox(color: Color(0xFF14100E)),
        if (addressing == null)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0xCC000000)],
              ),
            ),
          ),
        if (addressing == null)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _addressingId = null;
                    _view = _View.map;
                  }),
                  icon: const Icon(Icons.map_outlined),
                  color: EverloreTheme.parchment,
                  tooltip: 'World map',
                ),
                Expanded(
                  child: _Title(
                    subtitle: location.realm.toUpperCase(),
                    title: location.title,
                  ),
                ),
              ],
            ),
          ),
        // Stood in the painting, not stacked on the copy. A tall petition
        // used to shove them up the frame like a roster; the panel is
        // allowed to cover their feet the way dusk covers a room.
        if (addressing == null && _cast.isNotEmpty)
          Align(
            alignment: const Alignment(0, 0.22),
            child: SceneCast(
              people: _cast,
              enabled: !_acting,
              onAddress: _address,
            ),
          ),
        if (addressing != null)
          Positioned.fill(child: _buildConversation(addressing))
        else
          Align(
            alignment: Alignment.bottomCenter,
            child: petition != null
                ? _PetitionPanel(
                    petition: petition,
                    busy: _acting,
                    onRule: (resolutionId) => _act(
                      type: 'rule',
                      petitionId: petition.id,
                      resolutionId: resolutionId,
                    ),
                  )
                : _StoryPanel(
                    headline: location.sceneHeadline ?? location.title,
                    body: location.sceneBody ?? location.description,
                    choices: choices,
                    busy: _acting,
                    onChoose: (id) => _act(type: 'choose', choiceId: id),
                  ),
          ),
      ],
    );
    if (addressing == null) return scene;
    // Back from a meeting must return to the room, not the map. The
    // route pop would have thrown them out of a place they were still in.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _addressingId = null);
      },
      child: scene,
    );
  }

  Widget _buildConversation(WorldPresence who) {
    return ConversationPanel(
      person: who,
      bearingUrl: _bearingFor(who),
      lines: _visit[who.id] ?? const [],
      busy: _acting,
      onSpeak: (said) => unawaited(_speak(who.id, said)),
      onLeave: () => setState(() => _addressingId = null),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.artUrl,
    required this.location,
    required this.visibility,
    required this.isHere,
    required this.busy,
    required this.onTravel,
    required this.onEnter,
  });

  final String? artUrl;
  final WorldLocation location;
  final WorldVisibility visibility;
  final bool isHere;
  final bool busy;
  final VoidCallback onTravel;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final sealed = visibility == WorldVisibility.sealed;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xE6100C0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33C8A96A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The landmark's own art, shown here rather than pasted onto the
          // map. On a plate that already paints the city there is nowhere to
          // stand it; in the panel it is large, legible and composites against
          // nothing at all.
          if (artUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 116,
                width: double.infinity,
                child: ColoredBox(
                  color: const Color(0x33000000),
                  child: Image.network(
                    artUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            location.title,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // A sealed place says what it wants. A wall the player understands
            // is a goal; one they do not is a dead end.
            sealed
                ? (location.sealedReason ?? 'This place is closed to you.')
                : location.description,
            style: const TextStyle(color: Color(0xB3EFE3CC), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (isHere && location.isEnterable)
            _Action(label: 'Enter', busy: busy, onTap: onEnter)
          else if (!sealed)
            _Action(label: 'Travel here', busy: busy, onTap: onTravel)
          else
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: Color(0x80C8A96A)),
                SizedBox(width: 6),
                Text('Sealed', style: TextStyle(color: Color(0x80C8A96A), fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.busy, required this.onTap});
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onTap,
      child: busy
          ? const WorldStill(size: 16, color: EverloreTheme.void0)
          : Text(label),
    ),
  );
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({
    required this.headline,
    required this.body,
    required this.choices,
    required this.busy,
    required this.onChoose,
  });

  final String headline;
  final String body;
  final List<WorldChoice> choices;
  final bool busy;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: const Color(0xE60D0A09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x2EC8A96A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          style: const TextStyle(
            color: EverloreTheme.parchment,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(color: Color(0xB3EFE3CC), fontSize: 14, height: 1.45),
        ),
        if (choices.isNotEmpty) const SizedBox(height: 16),
        for (final choice in choices) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : () => onChoose(choice.id),
              child: Text(choice.label),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

/// A quarrel put in front of the player, and the ways of ending it.
///
/// Both parties are shown in full and neither is marked as the honest one,
/// because in most of these neither is lying. The rulings are given as labels
/// only — what each one costs is discovered by ruling it, which is what makes
/// this a judgement rather than a shop.
class _PetitionPanel extends StatelessWidget {
  const _PetitionPanel({
    required this.petition,
    required this.busy,
    required this.onRule,
  });

  final WorldPetition petition;
  final bool busy;
  final ValueChanged<String> onRule;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    // Three parties, their claims, any rulings quoted back and three ways to
    // answer will not fit a phone. The panel takes at most two thirds of the
    // screen and scrolls inside that, so the scene behind it stays visible and
    // the buttons are always reachable.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.66,
    ),
    decoration: BoxDecoration(
      color: const Color(0xF20D0A09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x5CC8A96A)),
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'BROUGHT BEFORE YOU',
            style: TextStyle(
              color: Color(0x99C8A96A),
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            petition.title,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final party in petition.parties) ...[
            Text(
              party.name,
              style: const TextStyle(
                color: Color(0xE6C8A96A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              party.claim,
              style: const TextStyle(
                color: Color(0xB3EFE3CC),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Your own words, brought back by someone who has read them.
          for (final principle in petition.cites) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: const Color(0x66C8A96A), width: 2),
                ),
                color: const Color(0x14C8A96A),
              ),
              child: Text(
                'They quote you: $principle',
                style: const TextStyle(
                  color: Color(0xCCEFE3CC),
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final resolution in petition.resolutions) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : () => onRule(resolution.id),
                child: Text(resolution.label, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title({required this.subtitle, required this.title});
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        subtitle,
        style: const TextStyle(
          color: Color(0x99C8A96A),
          fontSize: 10,
          letterSpacing: 1.6,
        ),
      ),
      Text(
        title,
        style: const TextStyle(
          color: EverloreTheme.parchment,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    required this.onRetry,
    this.label = 'Try again',
  });
  final String message;
  final VoidCallback onRetry;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xB3EFE3CC)),
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: Text(label)),
      ],
    ),
  );
}
