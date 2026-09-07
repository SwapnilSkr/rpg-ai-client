import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../shared/widgets/story_prose.dart';
import '../domain/interactive_world.dart';
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

/// A tall transparent cut-out standing in the painting.
///
/// These portraits are drawn on empty ground. A filled card or a cover-crop
/// turns them back into icons, which is why they composite straight onto
/// whatever is behind them.
class CharacterCutout extends StatelessWidget {
  const CharacterCutout({
    super.key,
    required this.name,
    required this.portraitUrl,
    this.height = 156,
    this.onTap,
    this.enabled = true,
  });

  /// How tall a figure stands in the painting. The opening warms this
  /// decode size; any other height stocks a shelf these cut-outs will
  /// not paint from.
  static const standingHeight = 148.0;

  /// A different height here stocks a shelf the cut-out will not paint from.
  static int cacheHeightOf(
    BuildContext context, {
    double height = standingHeight,
  }) => (height * MediaQuery.devicePixelRatioOf(context)).round();

  final String name;
  final String? portraitUrl;
  final double height;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final width = height * 2 / 3;
    final face = SizedBox(
      width: width,
      height: height,
      child: portraitUrl == null
          ? _AbsentFace(name: name)
          : EverloreNetworkImage(
              imageUrl: portraitUrl!,
              fit: BoxFit.contain,
              memCacheHeight: cacheHeightOf(context, height: height),
              semanticLabel: name,
              placeholder: const ColoredBox(color: Colors.transparent),
              errorWidget: _AbsentFace(name: name),
            ),
    );

    if (onTap == null) return face;

    return Semantics(
      button: true,
      enabled: enabled,
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(opacity: enabled ? 1 : 0.55, child: face),
      ),
    );
  }
}

/// Who is in this room, standing in the painted place rather than listed.
class SceneCast extends StatelessWidget {
  const SceneCast({
    super.key,
    required this.people,
    required this.onAddress,
    this.enabled = true,
  });

  final List<WorldPresence> people;
  final ValueChanged<WorldPresence> onAddress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final figures = [
      for (final who in people)
        _StandingFigure(
          person: who,
          enabled: enabled,
          onTap: () => onAddress(who),
        ),
    ];

    // A short gathering stands as a group. A scrolling strip is only for a
    // crowd that will not fit the painting, so two people are not shoved to
    // the leading edge like a roster.
    if (people.length <= 3) {
      return SizedBox(
        height: 188,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < figures.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              figures[i],
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: figures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => figures[index],
      ),
    );
  }
}

class _StandingFigure extends StatelessWidget {
  const _StandingFigure({
    required this.person,
    required this.enabled,
    required this.onTap,
  });

  final WorldPresence person;
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
          child: SizedBox(
            width: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CharacterCutout(
                  name: person.name,
                  portraitUrl: person.portraitUrl,
                  height: CharacterCutout.standingHeight,
                ),
                const SizedBox(height: 6),
                Text(
                  person.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
    required this.lines,
    required this.busy,
    required this.onSpeak,
    required this.onLeave,
  });

  final WorldPresence person;
  final String? bearingUrl;
  final List<VisitLine> lines;
  final bool busy;
  final ValueChanged<String> onSpeak;
  final VoidCallback onLeave;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel>
    with SingleTickerProviderStateMixin {
  final _said = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _chevron;
  bool _hasText = false;
  bool _composing = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _said.addListener(_onSaid);
    _chevron = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
    _chevron.dispose();
    super.dispose();
  }

  void _onSaid() {
    final has = _said.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  VisitLine? get _shown {
    if (widget.lines.isEmpty) return null;
    final i = _page.clamp(0, widget.lines.length - 1);
    return widget.lines[i];
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
    return Stack(
      fit: StackFit.expand,
      children: [
        const _PanelScrim(),
        _VnSpeaker(
          name: widget.person.name,
          portraitUrl: _face,
          onRight: fromPlayer,
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
          child: _ParchmentStage(
            speaker: speaker,
            fromPlayer: fromPlayer,
            line: shown,
            busy: widget.busy,
            composing: _composing,
            canAdvance: _canAdvance,
            canSpeak: _hasText && !widget.busy,
            chevron: _chevron,
            said: _said,
            focus: _focus,
            onAdvance: _advance,
            onCompose: _openCompose,
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }
}

/// Darkens only the band the parchment sits on. A full-frame veil would
/// swallow the painting the figure is meant to stand in.
class _PanelScrim extends StatelessWidget {
  const _PanelScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00000000),
              Color(0x00000000),
              Color(0x59000000),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A 2:3 full-body cut-out framed as a half-body speaker.
///
/// Fitting the whole figure in this slot would put their feet on a phone
/// that is taller than 3:2 at 60% width. Cover-scaling from the top keeps
/// the head and lets the legs leave the frame.
class _VnSpeaker extends StatelessWidget {
  const _VnSpeaker({
    required this.name,
    required this.portraitUrl,
    required this.onRight,
  });

  final String name;
  final String? portraitUrl;
  final bool onRight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedAlign(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: size.width * 0.62,
        height: size.height,
        child: portraitUrl == null
            ? _AbsentFace(name: name, large: true)
            : _TopAnchoredCutout(name: name, portraitUrl: portraitUrl!),
      ),
    );
  }
}

class _TopAnchoredCutout extends StatelessWidget {
  const _TopAnchoredCutout({required this.name, required this.portraitUrl});

  final String name;
  final String portraitUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotH = constraints.maxHeight;
        // 1.42× the slot makes a 2:3 body taller than the phone, so the
        // bottom edge crops at the thigh instead of showing a figurine.
        final paintedH = slotH * 1.42;
        final paintedW = paintedH * 2 / 3;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: paintedW,
            maxWidth: paintedW,
            minHeight: paintedH,
            maxHeight: paintedH,
            child: SizedBox(
              width: paintedW,
              height: paintedH,
              child: EverloreNetworkImage(
                imageUrl: portraitUrl,
                fit: BoxFit.contain,
                memCacheHeight: (paintedH * dpr).round(),
                semanticLabel: name,
                placeholder: const ColoredBox(color: Colors.transparent),
                errorWidget: _AbsentFace(name: name, large: true),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParchmentStage extends StatelessWidget {
  const _ParchmentStage({
    required this.speaker,
    required this.fromPlayer,
    required this.line,
    required this.busy,
    required this.composing,
    required this.canAdvance,
    required this.canSpeak,
    required this.chevron,
    required this.said,
    required this.focus,
    required this.onAdvance,
    required this.onCompose,
    required this.onSubmit,
  });

  final String speaker;
  final bool fromPlayer;
  final VisitLine? line;
  final bool busy;
  final bool composing;
  final bool canAdvance;
  final bool canSpeak;
  final Animation<double> chevron;
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
    final panelH = (size.height * 0.26).clamp(168.0, 252.0);
    return Padding(
      padding: EdgeInsets.only(bottom: keys > 0 ? keys : 0),
      child: SizedBox(
        height: panelH + pad.bottom + 18,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 18,
              child: _ParchmentPanel(
                fromPlayer: fromPlayer,
                line: line,
                busy: busy,
                composing: composing,
                canAdvance: canAdvance,
                canSpeak: canSpeak,
                chevron: chevron,
                said: said,
                focus: focus,
                bottomInset: pad.bottom,
                onAdvance: onAdvance,
                onCompose: onCompose,
                onSubmit: onSubmit,
              ),
            ),
            Positioned(
              top: 0,
              left: fromPlayer ? null : 22,
              right: fromPlayer ? 22 : null,
              child: _NameRibbon(name: speaker),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParchmentPanel extends StatelessWidget {
  const _ParchmentPanel({
    required this.fromPlayer,
    required this.line,
    required this.busy,
    required this.composing,
    required this.canAdvance,
    required this.canSpeak,
    required this.chevron,
    required this.said,
    required this.focus,
    required this.bottomInset,
    required this.onAdvance,
    required this.onCompose,
    required this.onSubmit,
  });

  final bool fromPlayer;
  final VisitLine? line;
  final bool busy;
  final bool composing;
  final bool canAdvance;
  final bool canSpeak;
  final Animation<double> chevron;
  final TextEditingController said;
  final FocusNode focus;
  final double bottomInset;
  final VoidCallback onAdvance;
  final VoidCallback onCompose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canAdvance ? onAdvance : null,
        splashColor: const Color(0x14C8A96A),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8D5B0), Color(0xFFD4C09A)],
            ),
            border: Border(
              top: BorderSide(color: Color(0x66C8A96A)),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            children: [
              const _PaperGrain(),
              Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 22, 10 + bottomInset),
                child: composing
                    ? _SayField(
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
              ),
              if (canAdvance)
                Positioned(
                  right: 14,
                  bottom: 8 + bottomInset,
                  child: _AdvanceChevron(animation: chevron),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperGrain extends StatelessWidget {
  const _PaperGrain();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x33FFFFFF),
              Color(0x00000000),
              Color(0x14000000),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class _NameRibbon extends StatelessWidget {
  const _NameRibbon({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            EverloreTheme.goldDeep,
            EverloreTheme.ember,
            EverloreTheme.gold,
          ],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Text(
          name,
          style: EverloreTheme.serifDisplay(
            size: 13,
            color: EverloreTheme.goldHot,
            weight: FontWeight.w600,
            spacing: 0.6,
          ),
        ),
      ),
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
              : _BeatText(line: line!, fromPlayer: fromPlayer),
        ),
        if (busy)
          const _Waiting()
        else if (!canAdvance)
          _SayAffordance(onTap: onCompose),
      ],
    );
  }
}

class _BeatText extends StatelessWidget {
  const _BeatText({required this.line, required this.fromPlayer});

  final VisitLine line;
  final bool fromPlayer;

  static const _ink = Color(0xFF2A2118);

  @override
  Widget build(BuildContext context) {
    final base = EverloreTheme.aiText.copyWith(
      color: _ink,
      fontSize: 18,
      height: 1.55,
    );
    if (fromPlayer) {
      return Text(
        line.text,
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    }
    return Text.rich(
      TextSpan(
        children: storyProseSpans(
          line.text,
          dialogueStyle: base.copyWith(
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          narrationStyle: base.copyWith(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            color: _ink.withValues(alpha: 0.78),
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
          foregroundColor: EverloreTheme.goldDeep,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Say something',
          style: EverloreTheme.serifDisplay(
            size: 14,
            color: EverloreTheme.goldDeep,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: said,
            focusNode: focus,
            maxLength: _speakLimit,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: EverloreTheme.aiText.copyWith(
              color: const Color(0xFF2A2118),
              fontSize: 17,
              height: 1.45,
            ),
            cursorColor: EverloreTheme.goldDeep,
            decoration: InputDecoration(
              hintText: 'What do you say?',
              hintStyle: EverloreTheme.aiText.copyWith(
                color: const Color(0x992A2118),
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
                borderSide: const BorderSide(color: Color(0x66C8A96A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x66C8A96A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: EverloreTheme.goldDeep,
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
            backgroundColor: EverloreTheme.goldDeep,
            foregroundColor: EverloreTheme.goldHot,
            disabledBackgroundColor: EverloreTheme.goldDeep.withValues(
              alpha: 0.35,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text('Speak'),
        ),
      ],
    );
  }
}

class _AdvanceChevron extends StatelessWidget {
  const _AdvanceChevron({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, animation.value * 4 - 2),
          child: child,
        );
      },
      child: const Icon(
        Icons.expand_more_rounded,
        size: 26,
        color: Color(0xCC6E5A2E),
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
          WorldStill(size: 14, color: Color(0xCC6E5A2E)),
          SizedBox(width: 10),
          Text(
            'They hear you.',
            style: TextStyle(
              color: Color(0xCC2A2118),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// A missing face is still a person in the room. A broken-image glyph would
/// say the painting failed, which is not what happened.
class _AbsentFace extends StatelessWidget {
  const _AbsentFace({required this.name, this.large = false});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '' : name.trim()[0].toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x332A2219), Color(0x00000000)],
        ),
        border: Border(
          left: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.28)),
          right: BorderSide(
            color: EverloreTheme.goldDim.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: Align(
        alignment: large ? const Alignment(0, -0.35) : Alignment.center,
        child: Text(
          initial,
          style: EverloreTheme.serifDisplay(
            size: large ? 72 : 34,
            color: EverloreTheme.goldDim.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
