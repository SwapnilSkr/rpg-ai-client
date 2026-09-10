import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_empty_state.dart';
import '../../../shared/widgets/everlore_notice.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../data/interactive_world_repository.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';
import 'travel_transition.dart';
import 'world_characters.dart';
import 'world_duel.dart';
import 'world_frame.dart';
import 'world_identity.dart';
import 'world_map_view.dart';
import 'world_moments.dart';
import 'world_prologue.dart';

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
  List<WorldLeadCard> _playable = const [];
  WorldLeadCard? _lead;
  WorldPrologue? _prologue;
  WorldDeath? _death;
  List<WorldMoment> _moments = const [];
  List<WorldDrill> _drillsHere = const [];
  List<WorldContest> _contests = const [];
  bool _showMoments = false;
  bool _needsIdentity = false;
  String? _sceneHeadline;
  String? _sceneBody;
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
        revealedIds: {
          if (open.isNotEmpty) open.first.id,
          if (open.isNotEmpty)
            ...open.first.routes.where((id) {
              final neighbour = _world!.byId(id);
              return neighbour != null &&
                  neighbour.authoredVisibility != WorldVisibility.rumoured;
            }),
        },
        flags: const {},
        // A preview has no server state. Mirror only the authored first step so
        // it still illustrates the graph without implying arbitrary travel.
        travelLocationIds: open.isEmpty
            ? const {}
            : open.first.routes
                  .where(
                    (id) =>
                        _world!.byId(id)?.authoredVisibility ==
                        WorldVisibility.open,
                  )
                  .toSet(),
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
    if (_addressingId != null && !_cast.any((who) => who.id == _addressingId)) {
      _addressingId = null;
    }
    // Talk is not a side channel. The rest of the payload is applied the
    // same way a choice is; this only keeps the line they just answered.
    final rawSpoken = payload['spoken'];
    if (rawSpoken is Map) {
      final spoken = WorldSpoken.fromJson(Map<String, dynamic>.from(rawSpoken));
      if (spoken.characterId.isNotEmpty && spoken.line.isNotEmpty) {
        _visit
            .putIfAbsent(spoken.characterId, () => [])
            .add(
              VisitLine(
                fromPlayer: false,
                text: spoken.line,
                portraitUrl: spoken.portraitUrl,
              ),
            );
      }
    }
    _selectedId ??= _state.currentLocationId;
    _needsIdentity = payload['needs_identity'] == true;
    _playable = (payload['playable'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => WorldLeadCard.fromJson(Map<String, dynamic>.from(raw)))
        .where((lead) => lead.characterId.isNotEmpty)
        .toList();
    final rawLead = payload['lead'];
    _lead = rawLead is Map
        ? WorldLeadCard.fromJson(Map<String, dynamic>.from(rawLead))
        : null;
    _prologue = WorldPrologue.tryFrom(payload['prologue']);
    _death = WorldDeath.tryFrom(payload['death']);
    _moments = (payload['moments'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => WorldMoment.fromJson(Map<String, dynamic>.from(raw)))
        .where((moment) => moment.id.isNotEmpty)
        .toList();
    _drillsHere = (payload['drills'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => WorldDrill.fromJson(Map<String, dynamic>.from(raw)))
        .where((drill) => drill.id.isNotEmpty)
        .toList();
    _contests = (payload['contests'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => WorldContest.fromJson(Map<String, dynamic>.from(raw)))
        .where((contest) => contest.choiceId.isNotEmpty)
        .toList();
    final rawScene = payload['scene'];
    if (rawScene is Map) {
      _sceneHeadline = rawScene['headline'] as String?;
      _sceneBody = rawScene['body'] as String?;
    }
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
    String? checkpointId,
    String? drillId,
    bool alreadyActing = false,
  }) async {
    if (!_isServerBacked) {
      // The road was held for a walk this glimpse cannot take. Leaving
      // the lock set would freeze every later action on a preview.
      if (alreadyActing && mounted) setState(() => _acting = false);
      _notice(
        'This glimpse has no memory of you. Come as one already walking these lands.',
      );
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
        checkpointId: checkpointId,
        drillId: drillId,
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
      final reason = _reasonFrom(error);
      _notice(
        reason,
        // A refusal the world worded is the fiction speaking. Only a
        // message that never arrived is an error.
        tone: reason == _unreachable ? NoticeTone.error : NoticeTone.info,
      );
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
      _visit
          .putIfAbsent(characterId, () => [])
          .add(VisitLine(fromPlayer: true, text: text));
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
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"')
        .firstMatch(error.toString());
    return match?.group(1) ?? _unreachable;
  }

  static const _unreachable = 'That did not reach the world. Try it again.';

  Future<void> _restore(String checkpointId) async {
    final reached = await _act(type: 'restore', checkpointId: checkpointId);
    if (!reached || !mounted) return;
    setState(() {
      _showMoments = false;
      _view = _View.map;
      _visit.clear();
      _metHere.clear();
      _addressingId = null;
    });
  }

  Future<void> _rebind(WorldLeadCard lead) async {
    final reached = await _act(type: 'rebind', characterId: lead.characterId);
    if (!reached || !mounted) return;
    setState(() {
      _showMoments = false;
      _view = _View.map;
      _visit.clear();
      _metHere.clear();
      _addressingId = null;
    });
  }

  void _notice(String message, {NoticeTone tone = NoticeTone.info}) {
    if (!mounted) return;
    showEverloreNotice(context, message, tone: tone);
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
    // The room stands inside the safe area. Warming against the raw
    // frame stocks a shelf the cut-out will not paint from.
    final media = MediaQuery.of(context);
    final size = Size(
      media.size.width - media.padding.left - media.padding.right,
      media.size.height - media.padding.top - media.padding.bottom,
    );
    final petitionHere = _progression.petitions.any((p) => p.at == here.id);
    final reserved = StageMeasure.roomReservedHeight(
      screenHeight: size.height,
      petition: petitionHere,
    );
    await awaitWorldFrame(
      context,
      urls: [world.urlFor(here.sceneAssetId)],
      cutouts: [for (final who in _cast) who.portraitUrl],
      cutoutMaxHeight: StageMeasure.figureCacheHeight(
        context,
        slotHeight: StageMeasure.roomSlotHeight(
          screenHeight: size.height,
          reservedPanelHeight: reserved,
        ),
      ),
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
            ? _Failure(
                title: 'The way is closed',
                message: _error ?? 'The way in is not open.',
                onRetry: _load,
              )
            : _needsIdentity
            ? WorldIdentitySheet(
                leads: _playable,
                busy: _acting,
                onLeave: () => Navigator.of(context).maybePop(),
                onChoose: (lead) => unawaited(
                  _act(type: 'bind', characterId: lead.characterId),
                ),
              )
            : _death != null
            ? WorldDeathSheet(
                death: _death!,
                busy: _acting,
                onLeave: () => Navigator.of(context).maybePop(),
                onRestore: _restore,
                onRebind: _rebind,
              )
            : _prologue != null
            ? WorldPrologueStage(
                prologue: _prologue!,
                onFinished: () => unawaited(_act(type: 'begin')),
              )
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
                tooltip: 'Back',
              ),
              Expanded(
                child: _Title(
                  subtitle: world.chapterTitle.toUpperCase(),
                  title: world.title,
                ),
              ),
              _HingesButton(
                count: _moments.length,
                onPressed: () => setState(() => _showMoments = true),
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
              canTravel: _state.travelLocationIds.contains(selected.id),
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
        if (_showMoments)
          Positioned.fill(
            child: WorldMomentsSheet(
              moments: _moments,
              busy: _acting,
              onRestore: _restore,
              onClose: () => setState(() => _showMoments = false),
            ),
          ),
      ],
    );
  }

  Widget _buildScene(InteractiveWorld world) {
    final location = _here;
    if (location == null || !location.isEnterable) {
      return _Failure(
        title: 'No door stands open',
        message: 'There is nothing to enter here.',
        onRetry: () => setState(() => _view = _View.map),
        label: 'Back to the map',
        icon: Icons.map_outlined,
      );
    }
    final url = world.urlFor(location.sceneAssetId);
    final choices = world.choices
        .where(
          (c) => c.availableAt(
            location.id,
            _state.flags,
            taken: _state.takenChoiceIds,
            leadId: _state.protagonistId,
          ),
        )
        .toList();
    // A petition displaces the scene's own copy rather than sitting beside it.
    // Someone is standing in front of the player waiting to be answered, and
    // that is the whole of what this place is until it is answered.
    final petition = _progression.petitions
        .where((p) => p.at == location.id)
        .firstOrNull;
    final addressing = _addressing;
    final reserved = StageMeasure.roomReservedHeight(
      screenHeight: MediaQuery.sizeOf(context).height,
      petition: petition != null,
    );
    final sceneCopy = location.sceneCopy(
      flags: _state.flags,
      leadId: _state.protagonistId,
    );
    final choosing = addressing == null && petition == null && choices.isNotEmpty;
    final scene = Stack(
      fit: StackFit.expand,
      children: [
        // The conversation paints its own backdrop. Drawing it here as
        // well would stack two veils and swallow the figure meant to
        // stand in the room.
        if (addressing == null) StageBackdrop(url: url, veil: StageVeil.room),
        // Choice is your body only. Talk is the person you addressed.
        // An idle room may still show who is standing here.
        if (addressing == null && choosing)
          Positioned.fill(
            child: _ChoiceFigure(lead: _lead, reservedPanelHeight: reserved),
          )
        else if (addressing == null && _cast.isNotEmpty)
          Positioned.fill(
            child: _FadeIn(
              child: SceneCast(
                people: _cast,
                reservedPanelHeight: reserved,
                enabled: !_acting,
                onAddress: _address,
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
                _HingesButton(
                  count: _moments.length,
                  onPressed: () => setState(() => _showMoments = true),
                ),
              ],
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
                    headline:
                        _sceneHeadline ?? sceneCopy.headline,
                    body: _sceneBody ?? sceneCopy.body,
                    choices: choices,
                    drills: _drillsHere,
                    contests: _contests,
                    people: _cast,
                    traits: _state.traits,
                    standing: _progression.standing,
                    busy: _acting,
                    onChoose: (choice) {
                      if (!choice.traitsMet(_state.traits)) {
                        _notice(
                          choice.trainHint ??
                              'You have not the strength for that',
                        );
                        return;
                      }
                      _act(type: 'choose', choiceId: choice.id);
                    },
                    onTrain: (drill) =>
                        _act(type: 'train', drillId: drill.id),
                    onAddress: _address,
                  ),
          ),
        if (_showMoments)
          Positioned.fill(
            child: WorldMomentsSheet(
              moments: _moments,
              busy: _acting,
              onRestore: _restore,
              onClose: () => setState(() => _showMoments = false),
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
      backdropUrl: _world?.urlFor(_here?.sceneAssetId),
      lines: _visit[who.id] ?? const [],
      busy: _acting,
      playerPortraitUrl: _lead?.portraitUrl,
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
    required this.canTravel,
    required this.busy,
    required this.onTravel,
    required this.onEnter,
  });

  final String? artUrl;
  final WorldLocation location;
  final WorldVisibility visibility;
  final bool isHere;
  final bool canTravel;
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
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
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
          Text(location.title, style: EverloreTheme.cardTitle),
          const SizedBox(height: 6),
          Text(
            // A sealed place says what it wants. A wall the player understands
            // is a goal; one they do not is a dead end.
            sealed
                ? (location.sealedReason ?? 'This place is closed to you.')
                : location.description,
            style: EverloreTheme.aiText.copyWith(
              color: EverloreTheme.parchment.withValues(alpha: 0.7),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (isHere && location.isEnterable) ...[
            const SizedBox(height: 14),
            _Action(label: 'Enter', busy: busy, onTap: onEnter),
          ] else if (!sealed && canTravel) ...[
            const SizedBox(height: 14),
            _Action(label: 'Travel here', busy: busy, onTap: onTravel),
          ],
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
      style: FilledButton.styleFrom(
        backgroundColor: EverloreTheme.gold,
        foregroundColor: EverloreTheme.void0,
        disabledBackgroundColor: EverloreTheme.gold,
        disabledForegroundColor: EverloreTheme.void0,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const WorldStill(size: 16, color: EverloreTheme.void0),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: EverloreTheme.ui(
              size: 13,
              color: EverloreTheme.void0,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HingesButton extends StatelessWidget {
  const _HingesButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: count == 0 ? 'The road behind you' : 'The road behind you · $count',
      color: EverloreTheme.parchment,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: StageMeasure.brass,
        textColor: StageMeasure.ground,
        child: const Icon(Icons.history_rounded),
      ),
    );
  }
}

class _HingeChoice extends StatelessWidget {
  const _HingeChoice({
    required this.choice,
    required this.traits,
    required this.contest,
    required this.busy,
    required this.onChoose,
  });

  final WorldChoice choice;
  final WorldTraits? traits;
  final WorldContest? contest;
  final bool busy;
  final ValueChanged<WorldChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    final hinge = choice.critical;
    final short = !choice.traitsMet(traits);
    final weight = contest != null && !contest!.winnableNow;
    final hint = weight
        ? contest!.warning
        : short
        ? choice.trainHint
        : hinge?.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weight) ...[
          Text(
            contest!.fatal
                ? 'WEIGHT · YOU WILL FALL'
                : 'WEIGHT · YOU WILL LOSE',
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.danger,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (hinge != null) ...[
          Text(
            'HINGE · ${hinge.title.toUpperCase()}',
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.brassDeep,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          width: double.infinity,
          child: StageChoice(
            label: choice.label,
            busy: busy,
            onPressed: busy ? null : () => onChoose(choice),
          ),
        ),
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            style: EverloreTheme.aiText.copyWith(
              color: weight ? StageMeasure.danger : StageMeasure.inkMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({
    required this.headline,
    required this.body,
    required this.choices,
    required this.drills,
    required this.contests,
    required this.people,
    required this.traits,
    required this.standing,
    required this.busy,
    required this.onChoose,
    required this.onTrain,
    required this.onAddress,
  });

  final String headline;
  final String body;
  final List<WorldChoice> choices;
  final List<WorldDrill> drills;
  final List<WorldContest> contests;
  final List<WorldPresence> people;
  final WorldTraits? traits;
  final List<({String id, String title, int value})> standing;
  final bool busy;
  final ValueChanged<WorldChoice> onChoose;
  final ValueChanged<WorldDrill> onTrain;
  final ValueChanged<WorldPresence> onAddress;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, StageMeasure.roomPanelFoot),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * StageMeasure.roomPanelCeiling,
      ),
      child: _FadeIn(
        child: StagePanel(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (traits != null || standing.isNotEmpty) ...[
                  _WalkMeters(traits: traits, standing: standing),
                  const SizedBox(height: 12),
                ],
                Text(
                  headline,
                  style: EverloreTheme.serifDisplay(
                    size: 18,
                    color: StageMeasure.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: EverloreTheme.aiText.copyWith(
                    color: StageMeasure.inkMuted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                if (people.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final who in people) ...[
                    SizedBox(
                      width: double.infinity,
                      child: StageChoice(
                        label: who.disposition == null
                            ? 'Speak with ${who.name}'
                            : 'Speak with ${who.name}  ·  ${who.disposition}',
                        busy: busy,
                        onPressed: busy ? null : () => onAddress(who),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (drills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'WORK THE PLACE',
                    style: EverloreTheme.caption.copyWith(
                      color: StageMeasure.brassDeep,
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final drill in drills) ...[
                    SizedBox(
                      width: double.infinity,
                      child: StageChoice(
                        label: drill.label,
                        busy: busy,
                        onPressed: busy ? null : () => onTrain(drill),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (choices.isNotEmpty) const SizedBox(height: 8),
                for (final choice in choices) ...[
                  _HingeChoice(
                    choice: choice,
                    traits: traits,
                    contest: contests
                        .where((entry) => entry.choiceId == choice.id)
                        .firstOrNull,
                    busy: busy,
                    onChoose: onChoose,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ChoiceFigure extends StatelessWidget {
  const _ChoiceFigure({required this.lead, required this.reservedPanelHeight});

  final WorldLeadCard? lead;
  final double reservedPanelHeight;

  @override
  Widget build(BuildContext context) {
    final layout = StageRoomLayout.of(
      context,
      count: 1,
      reservedPanelHeight: reservedPanelHeight,
    );
    final rect = layout.figureAt(0);
    return _FadeIn(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            child: StageFigure(
              name: lead?.name ?? 'You',
              portraitUrl: lead?.portraitUrl,
              side: StageSide.left,
              rise: StageRise.speak,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkMeters extends StatelessWidget {
  const _WalkMeters({required this.traits, required this.standing});

  final WorldTraits? traits;
  final List<({String id, String title, int value})> standing;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (traits != null) 'Str ${traits!.strength}',
      if (traits != null) 'Cha ${traits!.charisma}',
      if (traits != null) 'Lead ${traits!.leadership}',
      if (traits != null) 'Lv ${traits!.level}',
      for (final track in standing.take(3)) '${track.title} ${track.value}',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final chip in chips)
          Text(
            chip.toUpperCase(),
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.brassDeep,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
      ],
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, StageMeasure.roomPanelFoot),
    // Three parties, their claims, any rulings quoted back and three ways to
    // answer will not fit a phone. The panel takes at most two thirds of the
    // screen and scrolls inside that, so the scene behind it stays visible and
    // the buttons are always reachable.
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * StageMeasure.roomPanelCeiling,
      ),
      child: StagePanel(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BROUGHT BEFORE YOU',
                style: EverloreTheme.sectionHeader.copyWith(
                  color: StageMeasure.brassDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                petition.title,
                style: EverloreTheme.serifDisplay(
                  size: 18,
                  color: StageMeasure.ink,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final party in petition.parties) ...[
                Text(
                  party.name,
                  style: EverloreTheme.ui(
                    size: 13,
                    color: StageMeasure.brassDeep,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  party.claim,
                  style: EverloreTheme.aiText.copyWith(
                    color: StageMeasure.inkMuted,
                    height: 1.45,
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
                      left: BorderSide(
                        color: StageMeasure.brassDeep.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    color: StageMeasure.brass.withValues(alpha: 0.10),
                  ),
                  child: Text(
                    'They quote you: $principle',
                    style: EverloreTheme.aiText.copyWith(
                      color: StageMeasure.inkMuted,
                      fontSize: 15,
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
                  child: StageChoice(
                    label: resolution.label,
                    busy: busy,
                    onPressed: busy ? null : () => onRule(resolution.id),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title({required this.subtitle, required this.title});
  final String subtitle;
  final String title;

  /// A northern plate can be bright sky directly behind the name. The
  /// shadow holds the letters without dimming the land; without it the
  /// title vanishes into the painting.
  static const _overPaint = [
    Shadow(color: Color(0xCC0A0807), blurRadius: 18, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EverloreTheme.sectionHeader.copyWith(shadows: _overPaint),
      ),
      // A long place name used to walk into the map control. Shrink the
      // words rather than lose them or cover the icon.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 1,
          style: EverloreTheme.serifDisplay(size: 19)
              .copyWith(shadows: _overPaint),
        ),
      ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.title,
    required this.message,
    required this.onRetry,
    this.label = 'Try again',
    this.icon = Icons.explore_off_outlined,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => EverloreEmptyState(
    icon: icon,
    title: title,
    message: message,
    actionLabel: label,
    onAction: onRetry,
    compact: true,
  );
}
