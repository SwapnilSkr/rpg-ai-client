import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';
import 'world_frame.dart';
import 'world_mist.dart';

/// A fight already decided, staged so the player can see it happen.
///
/// Nothing here rolls. The flags are already law. The sand is only a
/// reading: the two people enter, the blows play, they leave, and then
/// the parchment says what was decided. A box under their feet while
/// they were still fighting is the old failure.
class DuelStage extends StatefulWidget {
  const DuelStage({super.key, required this.duel, required this.backdropUrl});

  final WorldDuel duel;

  /// The painting of the place it is fought in. Null renders bare ground
  /// rather than a broken frame.
  final String? backdropUrl;

  @override
  State<DuelStage> createState() => _DuelStageState();
}

enum _DuelAct { veil, clash, part, told }

class _DuelStageState extends State<DuelStage> {
  _DuelAct _act = _DuelAct.veil;
  int _step = 0;
  Timer? _play;

  List<WorldDuelBeat> get _beats => widget.duel.beats;
  bool get _clashing => _act == _DuelAct.clash;
  bool get _told => _act == _DuelAct.told;
  bool get _onSand => _act == _DuelAct.clash || _act == _DuelAct.part;
  WorldDuelBeat? get _beat =>
      _clashing && _step >= 0 && _step < _beats.length ? _beats[_step] : null;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_unveil());
    });
  }

  @override
  void dispose() {
    _play?.cancel();
    super.dispose();
  }

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
    if (!mounted) return;
    setState(() => _act = _DuelAct.clash);
    _arm();
  }

  void _arm() {
    _play?.cancel();
    if (!_clashing) return;
    _play = Timer(const Duration(milliseconds: 1700), _advance);
  }

  void _advance() {
    if (_act == _DuelAct.told || _act == _DuelAct.part) return;
    if (_act == _DuelAct.veil) return;
    if (_beats.isEmpty || _step >= _beats.length - 1) {
      unawaited(_part());
      return;
    }
    setState(() => _step += 1);
    _arm();
  }

  /// Reading is optional; the outcome is not. Skip still lands on the
  /// telling, after the fighters have left.
  void _skip() => unawaited(_part());

  Future<void> _part() async {
    _play?.cancel();
    if (_act == _DuelAct.told || _act == _DuelAct.part) return;
    setState(() {
      _step = _beats.length;
      _act = _DuelAct.part;
    });
    await Future<void>.delayed(StageMeasure.arrive);
    if (!mounted) return;
    setState(() => _act = _DuelAct.told);
  }

  int _standing(String side) {
    final beat = _beat;
    if (beat == null) {
      if (_act == _DuelAct.veil || (_clashing && _beats.isEmpty)) {
        return widget.duel.vigour;
      }
      if (_beats.isEmpty) return widget.duel.vigour;
      final last = _beats.last;
      return side == 'challenger' ? last.challengerVigour : last.defenderVigour;
    }
    return side == 'challenger' ? beat.challengerVigour : beat.defenderVigour;
  }

  String? _face(WorldDuelFighter fighter) {
    final beat = _beat;
    if (beat != null &&
        beat.actor == fighter.side &&
        beat.portraitUrl != null) {
      return beat.portraitUrl;
    }
    return fighter.portraitUrl;
  }

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
    if (_act == _DuelAct.veil) {
      return const Scaffold(
        backgroundColor: StageMeasure.ground,
        body: WorldMist(),
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
    final verdictStyle = EverloreTheme.aiText.copyWith(
      fontSize: 18,
      height: 1.5,
    );
    final costStyle = EverloreTheme.aiText.copyWith(
      fontSize: 16,
      height: 1.5,
      fontStyle: FontStyle.italic,
    );
    final heraldStyle = EverloreTheme.aiText.copyWith(
      fontSize: 16,
      height: 1.5,
      fontStyle: FontStyle.italic,
    );
    final needed = _told
        ? StageMeasure.panelChrome +
              (widget.duel.herald.isEmpty
                  ? 0
                  : 8 +
                        _textHeight(
                          text: widget.duel.herald,
                          style: heraldStyle,
                          width: textWidth,
                          scaler: scaler,
                        )) +
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
        : 8.0;
    final panelH = _told
        ? StageMeasure.panelHeightFor(
            screenHeight: size.height,
            needed: needed,
            keys: 0,
            composing: false,
          )
        : 8.0;
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
        onTap: _clashing ? _advance : null,
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
                arrive: true,
                present: _onSand,
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
                arrive: true,
                present: _onSand,
                active: beat?.actor == near.side,
                fallen: _standing(near.side) <= 0,
                flashKey: struck == near.side ? _step : null,
              ),
            ),
            if (_onSand) ...[
              _band(
                layout.farPlate,
                Center(child: StageNamePlate(name: far.name)),
              ),
              _band(
                layout.nearPlate,
                Center(child: StageNamePlate(name: near.name)),
              ),
            ],
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
            if (_clashing)
              _band(
                layout.skip,
                StageSkip(label: 'Skip', onSkip: _skip),
              ),
            if (_told)
              _band(
                layout.panel,
                _OutcomePanel(
                  herald: widget.duel.herald,
                  outcome: widget.duel.outcome,
                  onLeave: () => Navigator.of(context).maybePop(),
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

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({
    required this.herald,
    required this.outcome,
    required this.onLeave,
  });

  final String herald;
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
              if (herald.isNotEmpty) ...[
                Text(
                  herald,
                  style: EverloreTheme.aiText.copyWith(
                    fontSize: 16,
                    color: StageMeasure.inkMuted,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'WHAT WAS DECIDED',
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
                    'CONTINUE',
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

Positioned _band(Rect rect, Widget child) {
  return Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}
