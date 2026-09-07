import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../domain/interactive_world.dart';
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
    if (beat != null && beat.actor == fighter.side && beat.portraitUrl != null) {
      return beat.portraitUrl;
    }
    return fighter.portraitUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0908),
        body: Center(
          child: EverloreSessionLoader(message: 'The sand is set'),
        ),
      );
    }
    final duel = widget.duel;
    final size = MediaQuery.sizeOf(context);
    final beat = _beat;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0908),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.backdropUrl != null)
              EverloreNetworkImage(
                imageUrl: widget.backdropUrl!,
                fit: BoxFit.cover,
                placeholder: const ColoredBox(color: Color(0xFF14100E)),
                errorWidget: const ColoredBox(color: Color(0xFF14100E)),
              )
            else
              const ColoredBox(color: Color(0xFF14100E)),
            // The sand is lit; the tiers around it are not. Darkening top and
            // bottom is what puts the two fighters in the middle of a crowd
            // without painting one.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xDD000000), Color(0x33000000), Color(0xEE000000)],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.52,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Fighter(
                      fighter: duel.challenger,
                      portraitUrl: _face(duel.challenger),
                      acting: beat?.actor == 'challenger',
                      fallen: _standing('challenger') <= 0,
                      alignment: Alignment.bottomLeft,
                    ),
                  ),
                  Expanded(
                    child: _Fighter(
                      fighter: duel.defender,
                      portraitUrl: _face(duel.defender),
                      acting: beat?.actor == 'defender',
                      fallen: _standing('defender') <= 0,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Standing(
                            fighter: duel.challenger,
                            vigour: _standing('challenger'),
                            of: duel.vigour,
                            toll: beat?.actor == 'defender' ? beat?.toll ?? 0 : 0,
                            step: _step,
                            alignment: CrossAxisAlignment.start,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Standing(
                            fighter: duel.defender,
                            vigour: _standing('defender'),
                            of: duel.vigour,
                            toll: beat?.actor == 'challenger' ? beat?.toll ?? 0 : 0,
                            step: _step,
                            alignment: CrossAxisAlignment.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Matter(question: duel.question),
                  ],
                ),
              ),
            ),
            if (beat?.said != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: size.height * 0.34,
                child: Align(
                  alignment: beat!.actor == 'challenger'
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: _Said(text: beat.said!, name: beat.actorName),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _over
                  ? _VerdictPanel(
                      outcome: duel.outcome,
                      onLeave: () => Navigator.of(context).maybePop(),
                    )
                  : _BeatPanel(
                      text: beat?.action ?? duel.herald,
                      opening: beat == null,
                      onSkip: _skip,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One fighter, standing in the painting rather than framed in a card.
///
/// The portrait is never mirrored to make the two face each other: these are
/// painted people, and flipping one puts their blade in the wrong hand and
/// reverses whatever they are wearing.
class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.fighter,
    required this.portraitUrl,
    required this.acting,
    required this.fallen,
    required this.alignment,
  });

  final WorldDuelFighter fighter;
  final String? portraitUrl;
  final bool acting;
  final bool fallen;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // The one who just acted comes forward. The other stays where they were,
    // so an exchange reads as one person doing something to another rather
    // than as two portraits sitting side by side.
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      offset: Offset(0, acting ? -0.03 : 0.02),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: fallen
            ? 0.32
            : acting
            ? 1
            : 0.72,
        child: Align(
          alignment: alignment,
          child: FractionallySizedBox(
            heightFactor: 0.98,
            child: _Face(name: fighter.name, url: portraitUrl),
          ),
        ),
      ),
    );
  }
}

/// A missing face is still someone on the sand. The player has no painted
/// portrait at all, so this is the ordinary case for one side of a fight they
/// are in — a broken-image glyph would read as the world failing.
class _Face extends StatelessWidget {
  const _Face({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    // Anchored to the top of the fighter's band for the same reason a portrait
    // is: the band runs to the bottom of the screen and the panel covers the
    // last third of it, so anything centred in the band is behind the panel.
    if (url == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          heightFactor: 0.46,
          child: _StandardOf(name: name),
        ),
      );
    }
    return EverloreNetworkImage(
      imageUrl: url!,
      fit: BoxFit.contain,
      semanticLabel: name,
      placeholder: const ColoredBox(color: Colors.transparent),
      errorWidget: _StandardOf(name: name),
    );
  }
}

/// Who is fighting, said in cloth rather than in a face: a hanging standard
/// with their initial on it.
class _StandardOf extends StatelessWidget {
  const _StandardOf({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '' : trimmed[0].toUpperCase();
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Hung, not framed: dark cloth fading out at the hem, held by two
            // brass edges. A filled panel with a border on all four sides
            // reads as a piece of the interface sitting on top of the arena.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.62),
                Colors.black.withValues(alpha: 0.06),
              ],
            ),
            border: Border(
              left: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.32),
              ),
              right: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.32),
              ),
            ),
          ),
          child: Align(
            alignment: const Alignment(0, -0.45),
            child: Text(
              initial,
              style: EverloreTheme.serifDisplay(
                size: 52,
                color: EverloreTheme.goldDim.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How much fight is left in someone, drawn and never numbered.
///
/// The bar is the only thing on this screen that could contradict the words,
/// so it is fed straight from the staged exchange rather than accumulated
/// here: a total this widget added up itself could drift a hit out of step and
/// leave the loser standing while the Herald reads out that they fell.
class _Standing extends StatelessWidget {
  const _Standing({
    required this.fighter,
    required this.vigour,
    required this.of,
    required this.toll,
    required this.step,
    required this.alignment,
  });

  final WorldDuelFighter fighter;
  final int vigour;
  final int of;

  /// What this exchange just took off this bar, if anything.
  final int toll;

  /// Keys the rising number to the exchange, so it plays once per blow rather
  /// than every time the screen rebuilds.
  final int step;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final left = of <= 0 ? 0.0 : (vigour / of).clamp(0.0, 1.0);
    final right = alignment == CrossAxisAlignment.end;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          fighter.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: EverloreTheme.caption.copyWith(
            color: EverloreTheme.parchment,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(
                    color: EverloreTheme.goldDeep.withValues(alpha: 0.7),
                  ),
                ),
                child: Align(
                  alignment: right
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: left, end: left),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      // The expanded child is load-bearing: a ColoredBox with
                      // nothing in it collapses to nothing under a loose
                      // constraint and paints no bar at all, silently.
                      child: ColoredBox(
                        color: value > 0.5
                            ? EverloreTheme.gold
                            : value > 0.25
                            ? EverloreTheme.ember
                            : EverloreTheme.crimson,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (toll > 0)
              Positioned(
                left: right ? null : 0,
                right: right ? 0 : null,
                top: 6,
                child: _Toll(key: ValueKey(step), toll: toll),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          fighter.role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: EverloreTheme.caption.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

/// What the blow took, rising off the bar and fading.
class _Toll extends StatelessWidget {
  const _Toll({super.key, required this.toll});

  final int toll;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: (1 - value).clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 18 * value), child: child),
      ),
      child: Text(
        '−$toll',
        style: EverloreTheme.serifDisplay(size: 20, color: EverloreTheme.crimson),
      ),
    );
  }
}

/// The matter on the sand, kept in front of the player the whole way through.
/// A fight whose question has scrolled away is a brawl.
class _Matter extends StatelessWidget {
  const _Matter({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        border: Border(
          left: BorderSide(
            color: EverloreTheme.goldDim.withValues(alpha: 0.55),
            width: 2,
          ),
        ),
      ),
      child: Text(
        question,
        style: EverloreTheme.bodyDim.copyWith(
          color: EverloreTheme.parchment.withValues(alpha: 0.82),
          height: 1.45,
        ),
      ),
    );
  }
}

/// Words shouted mid-fight. Only where the author wrote any — a bubble on
/// every exchange turns a Verdict into banter.
class _Said extends StatelessWidget {
  const _Said({required this.text, required this.name});

  final String text;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xF2F0E4CC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: EverloreTheme.goldDeep.withValues(alpha: 0.5),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.toUpperCase(),
              style: EverloreTheme.caption.copyWith(
                color: const Color(0xFF6E5A2E),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '“$text”',
              style: EverloreTheme.aiText.copyWith(
                fontSize: 16,
                color: const Color(0xFF2A2118),
                height: 1.4,
                fontWeight: FontWeight.w600,
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
class _BeatPanel extends StatelessWidget {
  const _BeatPanel({
    required this.text,
    required this.opening,
    required this.onSkip,
  });

  final String text;

  /// The Herald's reading, before anyone has moved.
  final bool opening;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            // Cinzel is the ceremonial face and sets a paragraph in small
            // caps, which is a proclamation rather than something to read.
            // The exchanges are told in the same voice as the rest of the
            // story.
            style: EverloreTheme.aiText.copyWith(
              fontSize: 18,
              color: const Color(0xFF2A2118),
              height: 1.55,
              fontStyle: opening ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                // Thirty-two dips used to be the whole target, and a
                // thumb missed it beside the chevron. Forty-four is
                // the floor.
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF6E5A2E),
                ),
                child: Text(
                  opening ? 'Hear the Verdict' : 'Look away',
                  style: EverloreTheme.caption.copyWith(
                    color: const Color(0xFF6E5A2E),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const _Chevron(),
            ],
          ),
        ],
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
    return _Parchment(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'THE VERDICT',
            style: EverloreTheme.caption.copyWith(
              color: const Color(0xFF6E5A2E),
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            outcome.verdict,
            style: EverloreTheme.aiText.copyWith(
              fontSize: 18,
              color: const Color(0xFF2A2118),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            outcome.cost,
            style: EverloreTheme.aiText.copyWith(
              fontSize: 16,
              color: const Color(0xFF5A4A38),
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
                foregroundColor: const Color(0xFF6E5A2E),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                'LEAVE THE SAND',
                style: EverloreTheme.caption.copyWith(
                  color: const Color(0xFF6E5A2E),
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The panel everything on the sand is read off. This duchy keeps its law on
/// paper, and a Verdict is read out before it is carved.
class _Parchment extends StatelessWidget {
  const _Parchment({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2E7D0), Color(0xFFE2D3B4)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x556E5A2E)),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 10)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Somewhere to go next, said without a word.
class _Chevron extends StatefulWidget {
  const _Chevron();

  @override
  State<_Chevron> createState() => _ChevronState();
}

class _ChevronState extends State<_Chevron>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_pulse),
      child: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF6E5A2E),
        size: 26,
      ),
    );
  }
}
