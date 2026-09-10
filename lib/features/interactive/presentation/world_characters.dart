import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/story_prose.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';
import 'world_frame.dart';

/// The world refuses a longer word. Matching the field to that bound
/// keeps a line from being sent that the room will not keep.
const _speakLimit = 500;

/// One beat of a conversation that exists only for this visit.
///
/// The world keeps what matters. Repeating this after a reload would invent a
/// memory the player had not earned from the room they are in.
@immutable
class VisitLine {
  const VisitLine({
    required this.fromPlayer,
    required this.text,
    this.portraitUrl,
    this.meeting = false,
  });

  final bool fromPlayer;
  final String text;
  final String? portraitUrl;
  final bool meeting;
}

/// Who is in this room, standing the way a speaker already stands.
///
/// A fitted 2:3 cut-out in a short centred row is what put dolls on
/// the painting with their feet showing. These people use the same
/// speak rise, from rects against the screen.
class SceneCast extends StatelessWidget {
  const SceneCast({
    super.key,
    required this.people,
    required this.reservedPanelHeight,
    required this.onAddress,
    this.enabled = true,
  });

  final List<WorldPresence> people;

  /// The parchment's own keep, in pixels. A guessed quarter against a
  /// petition is how a face was read through the paper.
  final double reservedPanelHeight;
  final ValueChanged<WorldPresence> onAddress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final layout = StageRoomLayout.of(
      context,
      count: people.length,
      reservedPanelHeight: reservedPanelHeight,
    );

    // A crowd that cannot share the frame still has to be reachable.
    // Fitting them into the width is the other doll.
    if (people.length >= 3 && !layout.crowdFits) {
      final width = layout.figureAt(0).width;
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: layout.size.width,
            height: layout.slotHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemExtent: width,
              itemCount: people.length,
              itemBuilder: (context, index) => _RoomPerson(
                person: people[index],
                side: layout.sideAt(index),
                enabled: enabled,
                onTap: () => onAddress(people[index]),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < people.length; i++)
          _band(
            layout.figureAt(i),
            _RoomPerson(
              person: people[i],
              side: layout.sideAt(i),
              enabled: enabled,
              onTap: () => onAddress(people[i]),
            ),
          ),
      ],
    );
  }
}

/// A reserved standing place. Align in this stack is what sat two
/// people on one spot.
Positioned _band(Rect rect, Widget child) {
  return Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}

class _RoomPerson extends StatelessWidget {
  const _RoomPerson({
    required this.person,
    required this.side,
    required this.enabled,
    required this.onTap,
  });

  final WorldPresence person;
  final StageSide side;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: person.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: StageFigure(
            key: ValueKey<String>(person.id),
            name: person.name,
            portraitUrl: person.portraitUrl,
            side: side,
            rise: StageRise.speak,
          ),
        ),
      ),
    );
  }
}

/// The exchange with one person, as a visual-novel beat over the painting.
class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    super.key,
    required this.person,
    required this.bearingUrl,
    required this.backdropUrl,
    required this.lines,
    required this.busy,
    required this.onSpeak,
    required this.onLeave,
    this.playerPortraitUrl,
  });

  final WorldPresence person;
  final String? bearingUrl;

  /// The painting of the room. Null renders bare ground rather than a
  /// broken frame, and is the same veil the fight stands in.
  final String? backdropUrl;
  final List<VisitLine> lines;
  final bool busy;
  final ValueChanged<String> onSpeak;
  final VoidCallback onLeave;
  final String? playerPortraitUrl;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  final _said = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _composing = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _said.addListener(_onSaid);
    // A visit already in progress must open on the latest beat. Starting
    // at zero would replay the meeting after they had already walked away.
    _page = widget.lines.isEmpty ? 0 : widget.lines.length - 1;
  }

  @override
  void didUpdateWidget(ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _page = widget.lines.isEmpty ? 0 : widget.lines.length - 1;
      _composing = false;
      return;
    }
    if (widget.lines.length != oldWidget.lines.length) {
      // New speech is the beat they must see. Leaving _page behind would
      // hide their own line until they tapped, and the reply would land
      // on a panel that still held the previous voice.
      setState(() {
        _page = widget.lines.isEmpty ? 0 : widget.lines.length - 1;
        _composing = false;
      });
    }
  }

  @override
  void dispose() {
    _said.removeListener(_onSaid);
    _said.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSaid() {
    final has = _said.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  VisitLine? get _shown {
    if (widget.lines.isNotEmpty) {
      final i = _page.clamp(0, widget.lines.length - 1);
      return widget.lines[i];
    }
    // Opening a character must show their authored entrance. An empty
    // visit with first_met still on the person is how the rebuild left
    // a blank parchment and only "Say something".
    final meeting = widget.person.firstMet;
    if (meeting == null) return null;
    return VisitLine(
      fromPlayer: false,
      text: meeting,
      portraitUrl: widget.person.portraitUrl,
      meeting: true,
    );
  }

  bool get _fromPlayer => _shown?.fromPlayer ?? false;

  bool get _canAdvance =>
      !_composing && widget.lines.isNotEmpty && _page < widget.lines.length - 1;

  String? get _face {
    final line = _shown;
    if (line != null && !line.fromPlayer && line.portraitUrl != null) {
      return line.portraitUrl;
    }
    return widget.bearingUrl;
  }

  void _advance() {
    if (!_canAdvance) return;
    setState(() => _page += 1);
  }

  void _openCompose() {
    if (widget.busy || _composing) return;
    setState(() => _composing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _submit() {
    if (widget.busy) return;
    final text = _said.text.trim();
    if (text.isEmpty || text.length > _speakLimit) return;
    widget.onSpeak(text);
    _said.clear();
    setState(() => _composing = false);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final fromPlayer = _fromPlayer;
    final speaker = fromPlayer ? 'You' : widget.person.name;
    final size = MediaQuery.sizeOf(context);
    final side = fromPlayer ? StageSide.right : StageSide.left;
    final slot = StageMeasure.speakRect(size, side);
    final contextCue = <String>{
      widget.person.role.trim(),
      widget.person.faction.trim(),
    }.where((part) => part.isNotEmpty).join(' · ');
    return Stack(
      fit: StackFit.expand,
      children: [
        StageBackdrop(url: widget.backdropUrl, veil: StageVeil.room),
        Positioned(
          left: slot.left,
          top: slot.top,
          width: slot.width,
          height: slot.height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: StageFigure(
              key: ValueKey<String>(fromPlayer ? 'player' : widget.person.id),
              name: speaker,
              portraitUrl: fromPlayer ? widget.playerPortraitUrl : _face,
              side: side,
              rise: StageRise.speak,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: widget.onLeave,
                icon: const Icon(Icons.close_rounded),
                color: EverloreTheme.parchment,
                tooltip: 'Step away',
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: _TalkingStage(
            speaker: speaker,
            contextCue: contextCue,
            fromPlayer: fromPlayer,
            line: shown,
            busy: widget.busy,
            composing: _composing,
            canAdvance: _canAdvance,
            canSpeak: _hasText && !widget.busy,
            said: _said,
            focus: _focus,
            onAdvance: _advance,
            onCompose: _openCompose,
            onSubmit: _submit,
            ),
          ),
        ),
      ],
    );
  }
}

class _TalkingStage extends StatelessWidget {
  const _TalkingStage({
    required this.speaker,
    required this.contextCue,
    required this.fromPlayer,
    required this.line,
    required this.busy,
    required this.composing,
    required this.canAdvance,
    required this.canSpeak,
    required this.said,
    required this.focus,
    required this.onAdvance,
    required this.onCompose,
    required this.onSubmit,
  });

  final String speaker;
  final String contextCue;
  final bool fromPlayer;
  final VisitLine? line;
  final bool busy;
  final bool composing;
  final bool canAdvance;
  final bool canSpeak;
  final TextEditingController said;
  final FocusNode focus;
  final VoidCallback onAdvance;
  final VoidCallback onCompose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final keys = MediaQuery.viewInsetsOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);
    // Eighteen-point prose plus the say control used to clip inside a
    // clamp that never asked the reader's scaler. The panel grows with
    // the type, and when the field opens it cannot be taller than the
    // space above the keys.
    final prose = scaler.scale(18) * 1.55;
    final field = scaler.scale(17) * 1.45;
    final readyToSpeak = line == null;
    final needed = composing || readyToSpeak
        ? 22 + field * 4 + 24 + 10
        : 22 + prose * 3 + 48 + 10;
    final panelH = StageMeasure.panelHeightFor(
      screenHeight: size.height,
      needed: needed,
      keys: keys,
      composing: composing,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keys > 0 ? keys : 0),
      child: SizedBox(
        height: panelH + pad.bottom + StageMeasure.plateHeight / 2,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: StageMeasure.plateHeight / 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canAdvance ? onAdvance : null,
                  splashColor: StageMeasure.brass.withValues(alpha: 0.08),
                  child: StagePanel(
                    expand: true,
                    padding: EdgeInsets.fromLTRB(
                      StageMeasure.panelPadX,
                      22,
                      StageMeasure.panelPadX,
                      10 + pad.bottom,
                    ),
                    child: Stack(
                      children: [
                        composing
                            ? _SayField(
                                said: said,
                                focus: focus,
                                canSpeak: canSpeak,
                                onSubmit: onSubmit,
                              )
                            : readyToSpeak
                            ? _ReturnInvitation(
                                contextCue: contextCue,
                                said: said,
                                focus: focus,
                                canSpeak: canSpeak,
                                onSubmit: onSubmit,
                              )
                            : _PanelBody(
                                fromPlayer: fromPlayer,
                                line: line,
                                busy: busy,
                                canAdvance: canAdvance,
                                onCompose: onCompose,
                              ),
                        if (canAdvance)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: StageAdvance(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: fromPlayer ? null : StageMeasure.plateInset,
              right: fromPlayer ? StageMeasure.plateInset : null,
              child: StageNamePlate(name: speaker, seat: StagePlateSeat.panel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnInvitation extends StatelessWidget {
  const _ReturnInvitation({
    required this.contextCue,
    required this.said,
    required this.focus,
    required this.canSpeak,
    required this.onSubmit,
  });

  final String contextCue;
  final TextEditingController said;
  final FocusNode focus;
  final bool canSpeak;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contextCue.isNotEmpty) ...[
          Text(
            contextCue.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.brassDeep,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Speak in your own words.',
          style: EverloreTheme.aiText.copyWith(
            color: StageMeasure.inkMuted,
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _SayField(
            said: said,
            focus: focus,
            canSpeak: canSpeak,
            onSubmit: onSubmit,
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.fromPlayer,
    required this.line,
    required this.busy,
    required this.canAdvance,
    required this.onCompose,
  });

  final bool fromPlayer;
  final VisitLine? line;
  final bool busy;
  final bool canAdvance;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: line == null
              ? const SizedBox.shrink()
              : _ReadingRegion(line: line!, fromPlayer: fromPlayer),
        ),
        if (busy)
          const _Waiting()
        else if (!canAdvance)
          _SayAffordance(onTap: onCompose),
      ],
    );
  }
}

class _ReadingRegion extends StatefulWidget {
  const _ReadingRegion({required this.line, required this.fromPlayer});

  final VisitLine line;
  final bool fromPlayer;

  @override
  State<_ReadingRegion> createState() => _ReadingRegionState();
}

class _ReadingRegionState extends State<_ReadingRegion> {
  final _scroll = ScrollController();
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncAffordance);
    _afterLayout();
  }

  @override
  void didUpdateWidget(_ReadingRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.text != widget.line.text) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _afterLayout();
    }
  }

  void _afterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAffordance();
    });
  }

  void _syncAffordance() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final hasMore = position.maxScrollExtent - position.pixels > 1;
    if (hasMore != _hasMore && mounted) setState(() => _hasMore = hasMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_syncAffordance)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _afterLayout();
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: _hasMore,
              child: SingleChildScrollView(
                controller: _scroll,
                child: _BeatText(
                  line: widget.line,
                  fromPlayer: widget.fromPlayer,
                ),
              ),
            ),
          ),
          if (_hasMore)
            Positioned(
              left: 0,
              bottom: 0,
              child: Semantics(
                label: 'More of this reply follows. Swipe up to keep reading.',
                excludeSemantics: true,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00F2E7D0), StageMeasure.paper],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 10, 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'READ ON',
                            style: EverloreTheme.caption.copyWith(
                              color: StageMeasure.brassDeep,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: StageMeasure.brassDeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BeatText extends StatelessWidget {
  const _BeatText({required this.line, required this.fromPlayer});

  final VisitLine line;
  final bool fromPlayer;

  @override
  Widget build(BuildContext context) {
    final base = EverloreTheme.aiText.copyWith(
      color: StageMeasure.ink,
      fontSize: 18,
      height: 1.55,
    );
    if (fromPlayer) {
      return Text(line.text, style: base.copyWith(fontStyle: FontStyle.italic));
    }
    return Text.rich(
      TextSpan(
        children: storyProseSpans(
          line.text,
          dialogueStyle: base.copyWith(
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w600,
            color: StageMeasure.ink,
          ),
          narrationStyle: base.copyWith(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            color: StageMeasure.ink.withValues(alpha: 0.78),
          ),
        ),
      ),
      style: base,
    );
  }
}

class _SayAffordance extends StatelessWidget {
  const _SayAffordance({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: StageMeasure.brassDeep,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Say something',
          style: EverloreTheme.serifDisplay(
            size: 14,
            color: StageMeasure.brassDeep,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SayField extends StatelessWidget {
  const _SayField({
    required this.said,
    required this.focus,
    required this.canSpeak,
    required this.onSubmit,
  });

  final TextEditingController said;
  final FocusNode focus;
  final bool canSpeak;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four lines at the reader's scale will not fit once the keys
        // are up. Cap what is shown to the height actually left, so
        // the field scrolls instead of clipping the Speak control.
        final line = scaler.scale(17) * 1.45;
        final fit = constraints.hasBoundedHeight
            ? ((constraints.maxHeight - 20) / line).floor().clamp(1, 4)
            : 4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: said,
                focusNode: focus,
                maxLength: _speakLimit,
                minLines: 1,
                maxLines: fit,
                textCapitalization: TextCapitalization.sentences,
                style: EverloreTheme.aiText.copyWith(
                  color: StageMeasure.ink,
                  fontSize: 17,
                  height: 1.45,
                ),
                cursorColor: StageMeasure.brassDeep,
                decoration: InputDecoration(
                  hintText: 'What do you say?',
                  hintStyle: EverloreTheme.aiText.copyWith(
                    color: StageMeasure.inkSoft,
                    fontSize: 17,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0x33FFFFFF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: StageMeasure.brassDim.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: StageMeasure.brassDim.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: StageMeasure.brassDeep,
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSpeak ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: StageMeasure.brassDeep,
                foregroundColor: StageMeasure.brassHot,
                disabledBackgroundColor: StageMeasure.brassDeep.withValues(
                  alpha: 0.35,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text('Speak'),
            ),
          ],
        );
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 6),
      child: Row(
        children: [
          WorldStill(size: 14, color: StageMeasure.inkFaint),
          SizedBox(width: 10),
          _WaitingLine(),
        ],
      ),
    );
  }
}

class _WaitingLine extends StatelessWidget {
  const _WaitingLine();

  @override
  Widget build(BuildContext context) {
    return Text(
      'They hear you.',
      style: EverloreTheme.aiText.copyWith(
        color: StageMeasure.inkFaint,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
