import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../data/interactive_world_repository.dart';
import '../domain/interactive_world.dart';
import 'travel_transition.dart';
import 'world_map_view.dart';

/// The Iron Verdict — a terrain plate with placed landmarks, not a chat UI with
/// a decorative map.
///
/// Everything visible here is authored server data: which places exist, what
/// the player has heard of, what is sealed and why, and what can be done. The
/// client renders and predicts; it never decides.
class IronVerdictWorldScreen extends StatefulWidget {
  const IronVerdictWorldScreen({super.key, this.instanceId});

  /// A real play instance makes this screen server-backed. Without one it is
  /// the authoring preview: the published world, with no player state.
  final String? instanceId;

  @override
  State<IronVerdictWorldScreen> createState() => _IronVerdictWorldScreenState();
}

enum _View { map, scene }

class _IronVerdictWorldScreenState extends State<IronVerdictWorldScreen> {
  static const _worldKey = 'iron-verdict';

  final _repository = const InteractiveWorldRepository();
  InteractiveWorld? _world;
  InteractiveWorldState _state = const InteractiveWorldState.empty();
  WorldProgression _progression = WorldProgression.empty;
  _View _view = _View.map;
  String? _selectedId;
  bool _loading = true;
  bool _acting = false;
  String? _error;
  String? _travellingTo;

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
    });
    try {
      final payload = _isServerBacked
          ? await _repository.loadInstance(
              worldKey: _worldKey,
              instanceId: widget.instanceId!,
            )
          : {'world': await _repository.loadWorld(_worldKey)};
      if (!mounted) return;
      _apply(payload);
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
    final rawProgression = payload['progression'];
    if (rawProgression is Map) {
      _progression = WorldProgression.fromJson(
        Map<String, dynamic>.from(rawProgression),
      );
    }
    _selectedId ??= _state.currentLocationId;
  }

  WorldLocation? get _selected => _world?.byId(_selectedId ?? '');
  WorldLocation? get _here => _world?.byId(_state.currentLocationId);

  Future<void> _act({
    required String type,
    String? locationId,
    String? choiceId,
    String? petitionId,
    String? resolutionId,
  }) async {
    if (!_isServerBacked) {
      _notice('Open this world from your realm to play it.');
      return;
    }
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final payload = await _repository.act(
        worldKey: _worldKey,
        instanceId: widget.instanceId!,
        type: type,
        locationId: locationId,
        choiceId: choiceId,
        petitionId: petitionId,
        resolutionId: resolutionId,
      );
      if (!mounted) return;
      setState(() {
        _apply(payload);
        _acting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _acting = false);
      // The server owns the refusal and its wording; surface it rather than
      // guessing a reason the fiction has not given.
      _notice(_reasonFrom(error));
    }
  }

  String _reasonFrom(Object error) {
    final text = error.toString();
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(text);
    return match?.group(1) ?? 'That is not open to you.';
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _travel(WorldLocation destination) async {
    setState(() => _travellingTo = destination.id);
    await _act(type: 'move', locationId: destination.id);
    if (!mounted) return;
    final arrived = _state.currentLocationId == destination.id;
    setState(() {
      _travellingTo = null;
      if (arrived && destination.isEnterable) _view = _View.scene;
    });
  }

  @override
  Widget build(BuildContext context) {
    final world = _world;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0908),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
              onEnter: () => setState(() => _view = _View.scene),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF14100E)),
          )
        else
          const ColoredBox(color: Color(0xFF14100E)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xCC000000)],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _view = _View.map),
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
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
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
