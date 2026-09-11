import 'dart:async';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = StageRoomLayout.of(
          context,
          count: people.length,
          reservedPanelHeight: reservedPanelHeight,
          size: constraints.biggest,
          topInset:
              MediaQuery.paddingOf(context).top + StageMeasure.roomChromeTop,
        );

        // A crowd that cannot share the frame still has to be reachable.
        // Fitting them into the width is the other doll.
        if (people.length >= 3 && !layout.crowdFits) {
          final first = layout.figureAt(0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                top: first.top,
                width: layout.size.width,
                height: first.height,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemExtent: first.width,
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
      },
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
            arrive: true,
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
  final _scroll = ScrollController();
  bool _hasText = false;
  bool _composing = false;
  bool _followLatest = true;
  String _revealed = '';
  String _target = '';
  bool _revealing = false;
  Timer? _reveal;
  double _lastKeys = 0;

  @override
  void initState() {
    super.initState();
    _said.addListener(_onSaid);
    _scroll.addListener(_onScroll);
    final last = _lastLine;
    if (last != null && !last.fromPlayer) {
      _revealed = last.text;
      _target = last.text;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd(force: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keys = MediaQuery.viewInsetsOf(context).bottom;
    if (keys == _lastKeys) return;
    _lastKeys = keys;
    if (_composing) _scrollToEnd(force: true);
  }

  @override
  void didUpdateWidget(ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _stopReveal();
      _composing = false;
      _followLatest = true;
      final last = _lastLine;
      _revealed = last == null || last.fromPlayer ? '' : last.text;
      _target = _revealed;
      _scrollToEnd(force: true);
      return;
    }
    final next = _lastLine;
    final previous = oldWidget.lines.isEmpty ? null : oldWidget.lines.last;
    final grew = widget.lines.length != oldWidget.lines.length;
    if (next != null &&
        !next.fromPlayer &&
        next.text.isNotEmpty &&
        next.text != previous?.text) {
      // The reply is here. Turn to them at once and let the line arrive
      // the way a narrator turn does, instead of waiting for a tap.
      _beginReveal(next.text);
      return;
    }
    if (grew) {
      _scrollToEnd(force: true, animated: true);
    }
  }

  @override
  void dispose() {
    _stopReveal();
    _said.removeListener(_onSaid);
    _scroll.removeListener(_onScroll);
    _said.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  VisitLine? get _lastLine =>
      widget.lines.isEmpty ? _opening : widget.lines.last;

  VisitLine? get _opening {
    final meeting = widget.person.firstMet;
    if (meeting == null) return null;
    return VisitLine(
      fromPlayer: false,
      text: meeting,
      portraitUrl: widget.person.portraitUrl,
      meeting: true,
    );
  }

  List<VisitLine> get _transcript {
    if (widget.lines.isNotEmpty) return widget.lines;
    final opening = _opening;
    return opening == null ? const [] : [opening];
  }

  bool get _fromPlayer {
    if (_revealing) return false;
    return _lastLine?.fromPlayer ?? false;
  }

  String? get _face {
    for (var i = widget.lines.length - 1; i >= 0; i--) {
      final line = widget.lines[i];
      if (!line.fromPlayer && line.portraitUrl != null) return line.portraitUrl;
    }
    return widget.bearingUrl;
  }

  void _onSaid() {
    final has = _said.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _stopReveal() {
    _reveal?.cancel();
    _reveal = null;
    _revealing = false;
  }

  void _beginReveal(String target) {
    _reveal?.cancel();
    _target = target;
    final first = target.isEmpty
        ? ''
        : target.substring(0, target.length < 8 ? target.length : 8);
    _revealed = first;
    _revealing = true;
    _composing = false;
    _followLatest = true;
    if (first.length >= target.length) {
      _revealing = false;
      _scrollToEnd(force: true, animated: true);
      return;
    }
    _reveal = Timer.periodic(const Duration(milliseconds: 18), (_) {
      if (!mounted) return;
      if (_revealed.length >= _target.length) {
        _reveal?.cancel();
        _reveal = null;
        setState(() => _revealing = false);
        _scrollToEnd(force: true);
        return;
      }
      final remaining = _target.length - _revealed.length;
      final step = remaining <= 18
          ? remaining
          : (remaining / 3).ceil().clamp(8, 36);
      setState(() {
        _revealed = _target.substring(0, _revealed.length + step);
      });
      _scrollToEnd();
    });
    _scrollToEnd(force: true);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _followLatest = position.maxScrollExtent - position.pixels < 96;
  }

  /// Keep the latest beat on screen the way a playthrough does: jump to
  /// the current tail, then chase it across the frames a lazy list needs
  /// to learn its true extent.
  void _scrollToEnd({bool force = false, bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final isNearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (!force && !_followLatest && !isNearBottom) return;
      _followLatest = true;
      if (animated) {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(pos.maxScrollExtent);
      }
      _settleAtBottom();
    });
  }

  void _settleAtBottom({int remaining = 8}) {
    if (remaining <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_followLatest) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels <= 1) return;
      _scroll.jumpTo(position.maxScrollExtent);
      _settleAtBottom(remaining: remaining - 1);
    });
  }

  void _openCompose() {
    if (widget.busy || _composing || _revealing) return;
    setState(() => _composing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _scrollToEnd(force: true);
    });
  }

  void _submit() {
    if (widget.busy || _revealing) return;
    final text = _said.text.trim();
    if (text.isEmpty || text.length > _speakLimit) return;
    widget.onSpeak(text);
    _said.clear();
    _focus.unfocus();
    setState(() {
      _composing = false;
      _followLatest = true;
    });
    _scrollToEnd(force: true, animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final fromPlayer = _fromPlayer;
    final speaker = fromPlayer ? 'You' : widget.person.name;
    final padding = MediaQuery.paddingOf(context);
    final contextCue = <String>{
      widget.person.role.trim(),
      widget.person.faction.trim(),
    }.where((part) => part.isNotEmpty).join(' · ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = fromPlayer ? StageSide.right : StageSide.left;
        final slot = StageMeasure.speakRect(
          constraints.biggest,
          side,
          topInset: padding.top + StageMeasure.roomChromeTop,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            StageBackdrop(url: widget.backdropUrl, veil: StageVeil.room),
            Positioned(
              left: slot.left,
              top: slot.top,
              width: slot.width,
              height: slot.height,
              child: AnimatedSwitcher(
                duration: StageMeasure.arrive,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    ...previous,
                    if (current != null) current,
                  ],
                ),
                transitionBuilder: (child, animation) {
                  final player = child.key == const ValueKey<String>('player');
                  final from = Offset(player ? 0.22 : -0.22, 0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: from, end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: StageFigure(
                  key: ValueKey<String>(
                    fromPlayer ? 'player' : widget.person.id,
                  ),
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
              child: _TalkingStage(
                speaker: speaker,
                contextCue: contextCue,
                fromPlayer: fromPlayer,
                lines: _transcript,
                revealed: _revealing || _revealed.isNotEmpty
                    ? _revealed
                    : null,
                revealing: _revealing,
                busy: widget.busy,
                composing: _composing,
                canSpeak: _hasText && !widget.busy && !_revealing,
                said: _said,
                focus: _focus,
                scroll: _scroll,
                onCompose: _openCompose,
                onSubmit: _submit,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TalkingStage extends StatelessWidget {
  const _TalkingStage({
    required this.speaker,
    required this.contextCue,
    required this.fromPlayer,
    required this.lines,
    required this.revealed,
    required this.revealing,
    required this.busy,
    required this.composing,
    required this.canSpeak,
    required this.said,
    required this.focus,
    required this.scroll,
    required this.onCompose,
    required this.onSubmit,
  });

  final String speaker;
  final String contextCue;
  final bool fromPlayer;
  final List<VisitLine> lines;
  final String? revealed;
  final bool revealing;
  final bool busy;
  final bool composing;
  final bool canSpeak;
  final TextEditingController said;
  final FocusNode focus;
  final ScrollController scroll;
  final VoidCallback onCompose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final keys = MediaQuery.viewInsetsOf(context).bottom;
    final waiting = busy && (lines.isEmpty || lines.last.fromPlayer);
    final panelH = StageMeasure.panelHeightFor(
      screenHeight: size.height,
      needed: size.height * 0.42,
      keys: keys,
      composing: true,
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
              child: StagePanel(
                expand: true,
                padding: EdgeInsets.fromLTRB(
                  StageMeasure.panelPadX,
                  22,
                  StageMeasure.panelPadX,
                  10 + pad.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: lines.isEmpty
                          ? _EmptyCue(contextCue: contextCue)
                          : _Transcript(
                              lines: lines,
                              revealed: revealed,
                              scroll: scroll,
                            ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: KeyedSubtree(
                        key: ValueKey(
                          waiting
                              ? 'wait'
                              : composing
                              ? 'field'
                              : revealing
                              ? 'reveal'
                              : 'say',
                        ),
                        child: waiting
                            ? const _Waiting()
                            : composing
                            ? _SayField(
                                said: said,
                                focus: focus,
                                canSpeak: canSpeak,
                                enabled: !busy && !revealing,
                                onSubmit: onSubmit,
                              )
                            : revealing
                            ? const SizedBox.shrink()
                            : _SayAffordance(onTap: onCompose),
                      ),
                    ),
                  ],
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

class _EmptyCue extends StatelessWidget {
  const _EmptyCue({required this.contextCue});

  final String contextCue;

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
          const SizedBox(height: 8),
        ],
        Text(
          'Speak in your own words.',
          style: EverloreTheme.aiText.copyWith(
            color: StageMeasure.inkMuted,
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.lines,
    required this.revealed,
    required this.scroll,
  });

  final List<VisitLine> lines;
  final String? revealed;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final last = index == lines.length - 1;
        final text = last && revealed != null && !line.fromPlayer
            ? revealed!
            : line.text;
        return Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 14),
          child: Opacity(
            opacity: last ? 1 : 0.72,
            child: _BeatText(
              line: VisitLine(
                fromPlayer: line.fromPlayer,
                text: text,
                portraitUrl: line.portraitUrl,
                meeting: line.meeting,
              ),
              fromPlayer: line.fromPlayer,
            ),
          ),
        );
      },
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
      return Text.rich(
        TextSpan(
          children: playerInputSpans(
            line.text,
            dialogueStyle: base.copyWith(
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w600,
              color: StageMeasure.ink,
            ),
            narrationStyle: base.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: StageMeasure.ink.withValues(alpha: kNarrationMutedAlpha),
            ),
          ),
        ),
        style: base,
      );
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
            color: StageMeasure.ink.withValues(alpha: kNarrationMutedAlpha),
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

class _SayField extends StatefulWidget {
  const _SayField({
    required this.said,
    required this.focus,
    required this.canSpeak,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController said;
  final FocusNode focus;
  final bool canSpeak;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  State<_SayField> createState() => _SayFieldState();
}

class _SayFieldState extends State<_SayField> {
  final _focused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
    _focused.value = widget.focus.hasFocus;
  }

  @override
  void didUpdateWidget(_SayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focus, widget.focus)) {
      oldWidget.focus.removeListener(_onFocus);
      widget.focus.addListener(_onFocus);
      _focused.value = widget.focus.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    _focused.dispose();
    super.dispose();
  }

  void _onFocus() {
    final focused = widget.focus.hasFocus;
    if (_focused.value != focused) _focused.value = focused;
  }

  void _insertNarrationMarkers() {
    if (!widget.enabled) return;

    void insert() {
      final value = widget.said.value;
      final text = value.text;
      final selection = value.selection;
      final start = selection.isValid ? selection.start : text.length;
      final end = selection.isValid ? selection.end : text.length;
      final lo = start < end ? start : end;
      final hi = start < end ? end : start;
      final selected = text.substring(lo, hi);
      final markerText = selected.isEmpty ? '**' : '*$selected*';
      final next = text.replaceRange(lo, hi, markerText);
      final cursor = selected.isEmpty ? lo + 1 : lo + markerText.length;
      widget.said.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
        composing: TextRange.empty,
      );
    }

    if (!widget.focus.hasFocus) {
      widget.focus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) insert();
      });
      return;
    }
    insert();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _focused,
              builder: (context, focused, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused
                          ? StageMeasure.brassDeep
                          : StageMeasure.brassDim.withValues(alpha: 0.4),
                      width: focused ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _NarrationMarkerButton(
                        enabled: widget.enabled,
                        focused: focused,
                        onTap: _insertNarrationMarkers,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: 1,
                          height: 18,
                          color: StageMeasure.brassDim.withValues(
                            alpha: focused ? 0.45 : 0.28,
                          ),
                        ),
                      ),
                      Expanded(child: child!),
                    ],
                  ),
                );
              },
              child: _ComposerField(
                controller: widget.said,
                focusNode: widget.focus,
                enabled: widget.enabled,
                onSubmit: widget.enabled ? widget.onSubmit : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: widget.canSpeak ? widget.onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: StageMeasure.brassDeep,
              foregroundColor: StageMeasure.brassHot,
              disabledBackgroundColor: StageMeasure.brassDeep.withValues(
                alpha: 0.35,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Speak'),
          ),
        ],
      ),
    );
  }
}

/// Kept out of focus-driven rebuilds so a tap places a cursor instead of
/// wedging selection on a `*` marker.
class _ComposerField extends StatefulWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback? onSubmit;

  @override
  State<_ComposerField> createState() => _ComposerFieldState();
}

class _ComposerFieldState extends State<_ComposerField> {
  void _onTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) return;
      final sel = widget.controller.selection;
      if (!sel.isValid || sel.isCollapsed) return;
      if (sel.end - sel.start != 1) return;
      widget.controller.selection = TextSelection.collapsed(offset: sel.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      maxLength: _speakLimit,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: EverloreTheme.aiText.copyWith(
        color: StageMeasure.ink,
        fontSize: 17,
        height: 1.45,
      ),
      cursorColor: StageMeasure.brassDeep,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        hintText: 'What do you say?',
        hintMaxLines: 1,
        hintStyle: EverloreTheme.aiText.copyWith(
          color: StageMeasure.inkSoft,
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      ),
      textInputAction: TextInputAction.newline,
      onTap: _onTap,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
    );
  }
}

class _NarrationMarkerButton extends StatelessWidget {
  const _NarrationMarkerButton({
    required this.enabled,
    required this.focused,
    required this.onTap,
  });

  final bool enabled;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wrap selection in *action* markers',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        splashColor: StageMeasure.brassDeep.withValues(alpha: 0.08),
        highlightColor: StageMeasure.brassDeep.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Text(
            '**',
            style: EverloreTheme.ui(
              size: 16,
              weight: FontWeight.w800,
              color: !enabled
                  ? StageMeasure.ink.withValues(alpha: 0.28)
                  : focused
                  ? StageMeasure.brassDeep
                  : StageMeasure.brassDeep.withValues(alpha: 0.7),
              spacing: 0.4,
            ),
          ),
        ),
      ),
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
