import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../shared/widgets/story_prose.dart';
import '../domain/interactive_world.dart';

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
              memCacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                  .round(),
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
                  height: 148,
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

/// The exchange with one person, and the field that sends the next word.
class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    super.key,
    required this.person,
    required this.lines,
    required this.busy,
    required this.onSpeak,
    required this.onLeave,
  });

  final WorldPresence person;
  final List<VisitLine> lines;
  final bool busy;
  final ValueChanged<String> onSpeak;
  final VoidCallback onLeave;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  final _said = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _hasText = false;

  static const _limit = 500;

  @override
  void initState() {
    super.initState();
    _said.addListener(_onSaid);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pinToLatest());
  }

  @override
  void didUpdateWidget(ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length ||
        oldWidget.busy != widget.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pinToLatest());
    }
  }

  @override
  void dispose() {
    _said.removeListener(_onSaid);
    _said.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSaid() {
    final has = _said.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _pinToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _submit() {
    if (widget.busy) return;
    final text = _said.text.trim();
    if (text.isEmpty || text.length > _limit) return;
    widget.onSpeak(text);
    _said.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSpeak = _hasText && !widget.busy;
    final tall = MediaQuery.sizeOf(context).height;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      // Header, a short exchange and the field must stay on a phone. The
      // scene behind has to remain visible or this becomes a chat screen
      // that happens to have a painting.
      constraints: BoxConstraints(maxHeight: tall * 0.48),
      decoration: BoxDecoration(
        color: const Color(0xF20D0A09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2EC8A96A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.person.name,
                      style: const TextStyle(
                        color: EverloreTheme.parchment,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.person.role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.person.role,
                        style: const TextStyle(
                          color: Color(0x99C8A96A),
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onLeave,
                icon: const Icon(Icons.close_rounded),
                color: EverloreTheme.parchment,
                tooltip: 'Step away',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: tall * 0.26),
            child: ListView(
              controller: _scroll,
              shrinkWrap: true,
              children: [
                for (final line in widget.lines) _Line(line: line),
                if (widget.busy) const _Waiting(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _said,
                  focusNode: _focus,
                  enabled: !widget.busy,
                  maxLength: _limit,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What do you say?',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canSpeak ? _submit : null,
                child: widget.busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Speak'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final VisitLine line;

  @override
  Widget build(BuildContext context) {
    if (line.fromPlayer) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          line.text,
          style: const TextStyle(
            color: Color(0xD8C8A96A),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      );
    }

    final prose = Text.rich(
      TextSpan(children: storyProseSpans(line.text)),
      style: EverloreTheme.aiText.copyWith(fontSize: 16, height: 1.5),
    );

    if (!line.meeting) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: prose);
    }

    // The entrance is a moment, not another turn in a thread. A quiet rule
    // keeps it from collapsing into the replies that follow.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0x66C8A96A), width: 2),
          ),
          color: Color(0x14C8A96A),
        ),
        child: prose,
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          SizedBox(width: 10),
          Text(
            'They hear you.',
            style: TextStyle(
              color: Color(0x99EFE3CC),
              fontSize: 13,
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
  const _AbsentFace({required this.name});

  final String name;

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
      child: Center(
        child: Text(
          initial,
          style: EverloreTheme.serifDisplay(
            size: 34,
            color: EverloreTheme.goldDim.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
