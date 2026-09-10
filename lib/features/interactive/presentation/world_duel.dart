import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';
import 'world_frame.dart';

/// A VERDICT FOUGHT ON THE SAND.
///
/// Everything on this screen has already happened. The fight arrives staged —
/// who acts, what each exchange costs, where the bars stand afterwards and who
/// is left standing — because the flags it settles are what the rest of the
/// chapter is written against. Nothing here rolls, resolves or recomputes; a
/// device that decided its own winner would show the player a fight they lost
/// and then hand them a duchy.
///
/// So the only state this holds is how far through the reading the player has
/// got.
class DuelStage extends StatefulWidget {
  const DuelStage({super.key, required this.duel, required this.backdropUrl});

  final WorldDuel duel;

  /// The painting of the place it is fought in. Null renders bare ground
  /// rather than a broken frame.
  final String? backdropUrl;

  @override
  State<DuelStage> createState() => _DuelStageState();
}

/// Before the first blow. The Herald reads the matter out, and the tiers are
/// still sitting down.
const _herald = -1;

class _DuelStageState extends State<DuelStage> {
  int _step = _herald;
  bool _ready = false;

  List<WorldDuelBeat> get _beats => widget.duel.beats;
  bool get _over => _step >= _beats.length;
  WorldDuelBeat? get _beat =>
      _step >= 0 && _step < _beats.length ? _beats[_step] : null;

  /// The champion closer to the camera. [WorldDuelFighter.isPlayer] marks
  /// the player's own side — themselves, or a blade hired for the afternoon.
  /// Treating the two as a symmetrical pair is what made them portraits
  /// in slots instead of two people in the same space.
  WorldDuelFighter get _near {
    final duel = widget.duel;
    if (duel.defender.isPlayer && !duel.challenger.isPlayer) {
      return duel.defender;
    }
    return duel.challenger;
  }

  WorldDuelFighter get _far {
    final near = _near;
    return near.side == widget.duel.challenger.side
        ? widget.duel.defender
        : widget.duel.challenger;
  }

  @override
  void initState() {
    super.initState();
    // precacheImage reads the configuration off the tree. Asking from
    // initState, before the first frame, is a wait that never completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_unveil());
    });
  }

  /// The Herald reads before the first blow. Waiting on every exchange's
  /// bearing would hold the sand for faces that have not entered yet.
  Future<void> _unveil() async {
    if (!mounted) return;
    await awaitWorldFrame(
      context,
      urls: [
        widget.backdropUrl,
        widget.duel.challenger.portraitUrl,
        widget.duel.defender.portraitUrl,
      ],
    );
    if (mounted) setState(() => _ready = true);
  }

  void _advance() {
    if (_over) return;
    setState(() => _step += 1);
  }

  /// Reading the fight is optional; the outcome is not. Skipping lands on the
  /// Verdict itself rather than closing the screen, so nobody leaves the sand
  /// without being told what was decided on it.
  void _skip() => setState(() => _step = _beats.length);

  /// The bars stand where the last exchange left them. Before the first, both
  /// fighters are whole.
  int _standing(String side) {
    final beat = _beat;
    if (beat == null) {
      if (_step == _herald) return widget.duel.vigour;
      final last = _beats.last;
      return side == 'challenger' ? last.challengerVigour : last.defenderVigour;
    }
    return side == 'challenger' ? beat.challengerVigour : beat.defenderVigour;
  }

  /// The face a fighter wears right now. An exchange may change the actor's
  /// bearing; the other fighter keeps the one they came in with.
  String? _face(WorldDuelFighter fighter) {
    final beat = _beat;
    if (beat != null &&
        beat.actor == fighter.side &&
        beat.portraitUrl != null) {
      return beat.portraitUrl;
    }
    return fighter.portraitUrl;
  }

  /// Who the blow landed on. The actor struck; the other side is who
  /// the number and the flash belong to.
  String? get _struckSide {
    final beat = _beat;
    if (beat == null || beat.toll <= 0) return null;
    return beat.actor == _near.side ? _far.side : _near.side;
  }

  double _textHeight({
    required String text,
    required TextStyle style,
    required double width,
    required TextScaler scaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: width);
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: StageMeasure.ground,
        body: Center(child: EverloreSessionLoader(message: 'The sand is set')),
      );
    }
    final size = MediaQuery.sizeOf(context);
    final beat = _beat;
    final near = _near;
    final far = _far;
    final struck = _struckSide;
    final scaler = MediaQuery.textScalerOf(context);
    final textWidth = math.max(
      1.0,
      size.width - StageMeasure.panelGutter * 2 - StageMeasure.panelPadX * 2,
    );
    final beatStyle = EverloreTheme.aiText.copyWith(
      fontSize: 18,
      height: 1.55,
      fontStyle: beat == null ? FontStyle.italic : FontStyle.normal,
    );
    final verdictStyle = EverloreTheme.aiText.copyWith(
      fontSize: 18,
      height: 1.5,
    );
    final costStyle = EverloreTheme.aiText.copyWith(
      fontSize: 16,
      height: 1.5,
      fontStyle: FontStyle.italic,
    );
    // Counting an exchange as three lines overflowed as soon as the Herald
    // needed five. Measure the words that will actually be painted; the cap
    // still protects the arena when another world authors a longer reading.
    final needed = _over
        ? StageMeasure.panelChrome +
              22 +
              8 +
              _textHeight(
                text: widget.duel.outcome.verdict,
                style: verdictStyle,
                width: textWidth,
                scaler: scaler,
              ) +
              10 +
              _textHeight(
                text: widget.duel.outcome.cost,
                style: costStyle,
                width: textWidth,
                scaler: scaler,
              ) +
              14 +
              36
        : StageMeasure.panelPadY * 2 +
              _textHeight(
                text: beat?.action ?? widget.duel.herald,
                style: beatStyle,
                width: textWidth,
                scaler: scaler,
              ) +
              8 +
              StageMeasure.advanceGlyph;
    final panelH = StageMeasure.panelHeightFor(
      screenHeight: size.height,
      needed: needed,
      keys: 0,
      composing: false,
    );
    final layout = StageDuelLayout.of(context, panelHeight: panelH);
    final farSlot = layout.farFigure;
    final nearSlot = layout.nearFigure;
    final struckSlot = struck == far.side
        ? farSlot
        : struck == near.side
        ? nearSlot
        : null;
    final speakerSlot = beat == null
        ? null
        : beat.actor == far.side
        ? farSlot
        : nearSlot;
    return Scaffold(
      backgroundColor: StageMeasure.ground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StageBackdrop(url: widget.backdropUrl),
            _band(
              farSlot,
              StageFigure(
                name: far.name,
                portraitUrl: _face(far),
                side: StageSide.right,
                rise: StageRise.far,
                active: beat?.actor == far.side,
                fallen: _standing(far.side) <= 0,
                flashKey: struck == far.side ? _step : null,
              ),
            ),
            _band(
              nearSlot,
              StageFigure(
                name: near.name,
                portraitUrl: _face(near),
                side: StageSide.left,
                rise: StageRise.near,
                active: beat?.actor == near.side,
                fallen: _standing(near.side) <= 0,
                flashKey: struck == near.side ? _step : null,
              ),
            ),
            _band(
              layout.farPlate,
              Center(child: StageNamePlate(name: far.name)),
            ),
            _band(
              layout.nearPlate,
              Center(child: StageNamePlate(name: near.name)),
            ),
            _band(
              layout.question,
              StageInscription(text: widget.duel.question),
            ),
            if (struckSlot != null)
              Positioned(
                left: struckSlot.left + struckSlot.width * 0.12,
                top: struckSlot.top + struckSlot.height * 0.18,
                child: StageFloat(
                  key: ValueKey(_step),
                  text: '−${beat!.toll}',
                  alarming: beat.decisive,
                ),
              ),
            if (beat?.said != null && speakerSlot != null)
              Positioned(
                left: beat!.actor == near.side ? speakerSlot.left + 8 : null,
                right: beat.actor == far.side
                    ? size.width - speakerSlot.right + 8
                    : null,
                top: speakerSlot.top + 8,
                child: StageBubble(
                  text: beat.said!,
                  toward: beat.actor == near.side
                      ? StageSide.left
                      : StageSide.right,
                ),
              ),
            _band(
              layout.topStrip,
              StageMeter(
                name: far.name,
                role: far.role,
                portraitUrl: _face(far),
                vigour: _standing(far.side),
                of: widget.duel.vigour,
                seat: StageMeterSeat.far,
              ),
            ),
            if (!_over)
              _band(
                layout.skip,
                StageSkip(
                  label: beat == null ? 'Hear the Verdict' : 'Look away',
                  onSkip: _skip,
                ),
              ),
            _band(
              layout.panel,
              _over
                  ? _VerdictPanel(
                      outcome: widget.duel.outcome,
                      onLeave: () => Navigator.of(context).maybePop(),
                    )
                  : _BeatPanel(
                      text: beat?.action ?? widget.duel.herald,
                      opening: beat == null,
                    ),
            ),
            _band(
              layout.nearStrip,
              StageMeter(
                name: near.name,
                role: near.role,
                portraitUrl: _face(near),
                vigour: _standing(near.side),
                of: widget.duel.vigour,
                seat: StageMeterSeat.near,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The exchange as it is read. Tapping anywhere advances; the fight does not
/// run on its own, so nobody loses a blow to looking away.
class _BeatPanel extends StatefulWidget {
  const _BeatPanel({required this.text, required this.opening});

  final String text;
  final bool opening;

  @override
  State<_BeatPanel> createState() => _BeatPanelState();
}

class _BeatPanelState extends State<_BeatPanel> {
  final _scroll = ScrollController();
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(_BeatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!_scroll.hasClients) return;
    final hasMore = _scroll.position.maxScrollExtent - _scroll.position.pixels > 1;
    if (hasMore != _hasMore && mounted) setState(() => _hasMore = hasMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_sync)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: StagePanel(
        expand: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Text(
                  widget.text,
                  style: EverloreTheme.aiText.copyWith(
                    fontSize: 18,
                    color: StageMeasure.ink,
                    height: 1.55,
                    fontStyle: widget.opening ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
            if (_hasMore)
              const Positioned(
                right: 0,
                bottom: 0,
                child: StageAdvance(),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the Ring now holds to be true, and what it cost.
class _VerdictPanel extends StatelessWidget {
  const _VerdictPanel({required this.outcome, required this.onLeave});

  final WorldDuelOutcome outcome;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: StagePanel(
        expand: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'THE VERDICT',
                style: EverloreTheme.caption.copyWith(
                  color: StageMeasure.brassDeep,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                outcome.verdict,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 18,
                  color: StageMeasure.ink,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                outcome.cost,
                style: EverloreTheme.aiText.copyWith(
                  fontSize: 16,
                  color: StageMeasure.inkMuted,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onLeave,
                  style: TextButton.styleFrom(
                    foregroundColor: StageMeasure.brassDeep,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    'LEAVE THE SAND',
                    style: EverloreTheme.caption.copyWith(
                      color: StageMeasure.brassDeep,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reserved band. Align and Row are how both fighters sat on one
/// spot; every chrome piece on the sand is a rect against the screen.
Positioned _band(Rect rect, Widget child) {
  return Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}
