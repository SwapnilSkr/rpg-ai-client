import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../shared/models/event.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/app_icons.dart';

const _kNarrationMutedAlpha = 0.6;

class NarrativeBubble extends StatelessWidget {
  final GameEvent event;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplay;
  final VoidCallback? onContinue;
  final ValueChanged<int>? onSelectReplayVariant;

  /// This turn is currently being re-woven (a replay variant is streaming in).
  final bool isReplaying;

  /// This bubble is still receiving/finalizing streamed prose.
  final bool isStreaming;

  /// Known character names — occurrences in the prose become tappable links
  /// into the bonds sheet (the text itself is the game board).
  final List<String> characterNames;
  final ValueChanged<String>? onCharacterTap;

  const NarrativeBubble({
    super.key,
    required this.event,
    this.onLongPress,
    this.onReplay,
    this.onContinue,
    this.onSelectReplayVariant,
    this.isReplaying = false,
    this.isStreaming = false,
    this.characterNames = const [],
    this.onCharacterTap,
  });

  @override
  Widget build(BuildContext context) {
    final ai = event.aiResponse ?? '';
    final hasProse = ai.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (event.playerInput != null && event.playerInput!.isNotEmpty)
          _PlayerBubble(text: event.playerInput!),

        // While re-weaving, show the weaving indicator until the first token,
        // then stream the variant into a plain narrator panel (no replay/arrow
        // actions until it settles) — the same feel as a fresh turn.
        if (isReplaying)
          hasProse
              ? _NarratorPanel(
                  text: ai,
                  sceneTag: event.sceneTag,
                  isEdited: event.isUserEdited,
                  replayVariants: event.replayVariants,
                  selectedReplayIndex: event.selectedReplayIndex,
                  onContinue: onContinue,
                  onReplay: null,
                  onSelectReplayVariant: onSelectReplayVariant,
                  isStreaming: true,
                )
              : const _GeneratingIndicator(label: 'Re-weaving this turn')
        else if (hasProse) ...[
          // Calendar-tick turns open with a passage-of-time ornament so a time
          // skip reads as an interlude card, not another chat reply.
          if (event.isTimePassage)
            _TimePassageHeader(
              label: event.timeAdvanced,
              fateStirs: (event.fateThread ?? '').isNotEmpty,
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: _NarratorPanel(
              text: ai,
              sceneTag: event.sceneTag,
              isEdited: event.isUserEdited,
              replayVariants: event.replayVariants,
              selectedReplayIndex: event.selectedReplayIndex,
              onContinue: onContinue,
              onReplay: onReplay,
              onSelectReplayVariant: onSelectReplayVariant,
              isStreaming: isStreaming,
              // Entity links only on settled prose: streaming text rebuilds
              // every frame and would churn gesture recognizers.
              characterNames: isStreaming ? const [] : characterNames,
              onCharacterTap: isStreaming ? null : onCharacterTap,
            ),
          ),
        ] else if (event.isOptimistic)
          const _GeneratingIndicator(),
      ],
    );
  }
}

/// Ornamental divider announcing a passage of story time (calendar tick).
class _TimePassageHeader extends StatelessWidget {
  final String? label;
  final bool fateStirs;

  const _TimePassageHeader({this.label, this.fateStirs = false});

  @override
  Widget build(BuildContext context) {
    final caption = (label == null || label!.isEmpty)
        ? 'TIME PASSES'
        : 'TIME PASSES — ${label!.toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 2),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ornamentLine(rightToLeft: false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 11,
                      color: EverloreTheme.gold.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      caption,
                      style: EverloreTheme.ui(
                        size: 10,
                        weight: FontWeight.w700,
                        color: EverloreTheme.gold.withValues(alpha: 0.75),
                        spacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _ornamentLine(rightToLeft: true)),
            ],
          ),
          if (fateStirs)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✦ fate stirs ✦',
                style: EverloreTheme.ui(
                  size: 10,
                  color: EverloreTheme.ember.withValues(alpha: 0.85),
                  fontStyle: FontStyle.italic,
                  spacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ornamentLine({required bool rightToLeft}) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: rightToLeft ? Alignment.centerRight : Alignment.centerLeft,
          end: rightToLeft ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            EverloreTheme.gold.withValues(alpha: 0.45),
            EverloreTheme.gold.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _PlayerBubble extends StatelessWidget {
  final String text;
  const _PlayerBubble({required this.text});

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(6),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(12),
  );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(60, 10, 16, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EverloreTheme.void4.withValues(alpha: 0.85),
              EverloreTheme.void3.withValues(alpha: 1.10),
            ],
          ),
          borderRadius: _radius,
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.16),
          ),
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 17, 12),
                child: Text.rich(
                  TextSpan(
                    children: _playerInputSpans(
                      text,
                      // The player's voice uses the UI font; their *actions* italic, speech upright.
                      dialogueStyle: EverloreTheme.ui(
                        size: 15,
                        color: EverloreTheme.parchment,
                        height: 1.45,
                      ),
                      narrationStyle: EverloreTheme.ui(
                        size: 15,
                        color: EverloreTheme.parchment.withValues(
                          alpha: _kNarrationMutedAlpha,
                        ),
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
              // Champagne spine on the right — mirrors the narrator panel's left strip.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        EverloreTheme.gold.withValues(alpha: 0.7),
                        EverloreTheme.gold.withValues(alpha: 0.15),
                      ],
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

/// Player bubble renderer: text wrapped in *...* (or **...**) is treated as
/// action/narration and styled in italics; text outside markers is spoken text.
/// This makes mixed inputs like `*I step closer* Tell me the truth` visually
/// separable without extra punctuation.
List<InlineSpan> _playerInputSpans(
  String text, {
  required TextStyle dialogueStyle,
  required TextStyle narrationStyle,
}) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var inNarration = false;

  TextStyle styleNow() => inNarration ? narrationStyle : dialogueStyle;

  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: styleNow()));
    buf.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    // Accept either *...* or **...** as the player's narration markers.
    if (c == '*') {
      final isDouble = i + 1 < text.length && text[i + 1] == '*';
      flush();
      inNarration = !inNarration;
      if (isDouble) i++;
      continue;
    }
    buf.write(c);
  }
  flush();

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: dialogueStyle));
  }
  return spans;
}

class _NarratorPanel extends StatelessWidget {
  final String text;
  final String? sceneTag;
  final bool isEdited;
  final List<ReplayVariant> replayVariants;
  final int selectedReplayIndex;
  final VoidCallback? onContinue;
  final VoidCallback? onReplay;
  final ValueChanged<int>? onSelectReplayVariant;
  final bool isStreaming;
  final List<String> characterNames;
  final ValueChanged<String>? onCharacterTap;

  const _NarratorPanel({
    required this.text,
    this.sceneTag,
    this.isEdited = false,
    this.replayVariants = const [],
    this.selectedReplayIndex = 0,
    this.onContinue,
    this.onReplay,
    this.onSelectReplayVariant,
    this.isStreaming = false,
    this.characterNames = const [],
    this.onCharacterTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = EverloreTheme.sceneAccent(sceneTag);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 40, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF13132A).withValues(alpha: 0.72),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isEdited) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit,
                          size: 9,
                          color: EverloreTheme.ash.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                  _ProseText(
                    text: text,
                    characterNames: characterNames,
                    onCharacterTap: onCharacterTap,
                  ),
                  if (isStreaming) ...[
                    const SizedBox(height: 10),
                    const _InlineStreamingIndicator(),
                  ],
                  const SizedBox(height: 12),
                  if (!isStreaming)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 300;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (onContinue != null)
                                    _ContinueTurnButton(onTap: onContinue!),
                                  if (onReplay != null)
                                    _ReplayButton(
                                      onTap: onReplay!,
                                      compact: compact,
                                    ),
                                  if (sceneTag != null)
                                    _SceneTagBadge(
                                      tag: sceneTag!,
                                      accent: accent,
                                    ),
                                  if (replayVariants.length > 1)
                                    _ReplayArrows(
                                      count: replayVariants.length,
                                      selectedIndex: selectedReplayIndex.clamp(
                                        0,
                                        replayVariants.length - 1,
                                      ),
                                      onSelect: onSelectReplayVariant,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CopyButton(text: text, compact: compact),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            // Scene-tinted illuminated spine, stretched to the panel's height
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.7),
                      accent.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueTurnButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ContinueTurnButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Let the story continue on its own',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: EverloreTheme.void3.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: EverloreTheme.violet.withValues(alpha: 0.35),
            ),
          ),
          child: const EvIcon(AppIcons.continueStory, size: 15),
        ),
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _ReplayButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 13,
              color: EverloreTheme.cyanBright.withValues(alpha: 0.85),
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                'Replay',
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.cyanBright.withValues(alpha: 0.85),
                  spacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplayArrows extends StatelessWidget {
  final int count;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  const _ReplayArrows({
    required this.count,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final canPrev = selectedIndex > 0;
    final canNext = selectedIndex < count - 1;

    Widget arrow({
      required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 15,
            color: enabled
                ? EverloreTheme.gold.withValues(alpha: 0.85)
                : EverloreTheme.ash.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EverloreTheme.void3.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EverloreTheme.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            onTap: () => onSelect?.call(selectedIndex - 1),
          ),
          const SizedBox(width: 4),
          Text(
            '${selectedIndex + 1}/$count',
            style: EverloreTheme.ui(
              size: 10,
              color: EverloreTheme.ash,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          arrow(
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            onTap: () => onSelect?.call(selectedIndex + 1),
          ),
        ],
      ),
    );
  }
}

class _SceneTagBadge extends StatelessWidget {
  final String tag;
  final Color accent;
  const _SceneTagBadge({required this.tag, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EverloreTheme.ui(
          size: 9,
          weight: FontWeight.w700,
          spacing: 1.4,
          color: accent,
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String text;
  final bool compact;
  const _CopyButton({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Copied to clipboard',
              style: EverloreTheme.ui(size: 13, color: EverloreTheme.parchment),
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: EverloreTheme.void3,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy_rounded,
              size: 13,
              color: EverloreTheme.ash.withValues(alpha: 0.7),
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                'Copy',
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.ash.withValues(alpha: 0.7),
                  spacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders narrative prose with quote and asterisk boundaries:
/// - `"spoken words"` are dialogue (bright, upright)
/// - `*narration/actions/attributions*` are narration (italic, muted)
/// - malformed unmarked text defaults to narration, not dialogue.
/// This is a single streaming-stable pass: trailing unclosed quote/asterisk
/// reads as the in-progress span type.
/// Narrative prose with optional tappable character names. Owns the tap
/// recognizers so they are reliably disposed (spans alone would leak them).
class _ProseText extends StatefulWidget {
  final String text;
  final List<String> characterNames;
  final ValueChanged<String>? onCharacterTap;

  const _ProseText({
    required this.text,
    this.characterNames = const [],
    this.onCharacterTap,
  });

  @override
  State<_ProseText> createState() => _ProseTextState();
}

class _ProseTextState extends State<_ProseText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Split [span]'s text on character-name occurrences, linking each match.
  List<InlineSpan> _linkNames(TextSpan span, RegExp namePattern) {
    final text = span.text ?? '';
    if (text.isEmpty) return [span];
    final matches = namePattern.allMatches(text).toList();
    if (matches.isEmpty) return [span];

    final out = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        out.add(TextSpan(text: text.substring(cursor, m.start), style: span.style));
      }
      final name = m.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onCharacterTap?.call(name);
      _recognizers.add(recognizer);
      out.add(
        TextSpan(
          text: name,
          recognizer: recognizer,
          style: (span.style ?? const TextStyle()).copyWith(
            color: EverloreTheme.gold.withValues(alpha: 0.95),
            decoration: TextDecoration.underline,
            decorationColor: EverloreTheme.gold.withValues(alpha: 0.35),
            decorationThickness: 1,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      out.add(TextSpan(text: text.substring(cursor), style: span.style));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Recognizers are rebuilt with the spans every build; retire the old set.
    _disposeRecognizers();

    var spans = _narrativeSpans(widget.text);

    final names = widget.characterNames
        .where((n) => n.trim().length >= 3)
        .map(RegExp.escape)
        .toList();
    if (names.isNotEmpty && widget.onCharacterTap != null) {
      final pattern = RegExp('\\b(?:${names.join('|')})\\b');
      spans = [
        for (final s in spans)
          if (s is TextSpan) ..._linkNames(s, pattern) else s,
      ];
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

List<InlineSpan> _narrativeSpans(
  String text, {
  TextStyle? dialogueStyle,
  TextStyle? narrationStyle,
}) {
  final base = EverloreTheme.aiText;
  final narration =
      narrationStyle ??
      base.copyWith(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        color: EverloreTheme.parchment.withValues(alpha: _kNarrationMutedAlpha),
      );
  final dialogue =
      dialogueStyle ??
      base.copyWith(
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.w600,
        color: EverloreTheme.parchment,
      );

  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var inNarration = false;
  var inQuote = false;

  TextStyle styleNow() {
    if (inNarration) return narration;
    if (inQuote) return dialogue;
    return narration;
  }

  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: styleNow()));
    buf.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];

    if (c == '*' && !inQuote) {
      flush();
      inNarration = !inNarration;
      if (i + 1 < text.length && text[i + 1] == '*') i++;
      continue;
    }

    if ((c == '"' || c == '“' || c == '”') && !inNarration) {
      if (!inQuote) {
        flush();
        inQuote = true;
        buf.write(c == '“' || c == '”' ? '"' : c);
      } else {
        buf.write(c == '“' || c == '”' ? '"' : c);
        flush();
        inQuote = false;
      }
      continue;
    }

    buf.write(c);
  }
  flush();

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: narration));
  }
  return spans;
}

class _GeneratingIndicator extends StatefulWidget {
  final String label;
  const _GeneratingIndicator({this.label = 'The world is weaving'});

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 40, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13132A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.ash.withValues(alpha: 0.78),
                spacing: 0.2,
                fontStyle: FontStyle.italic,
              ).copyWith(fontFamily: GoogleFonts.ebGaramond().fontFamily),
            ),
            const SizedBox(width: 8),
            _StreamingDots(value: _controller.value),
          ],
        ),
      ),
    );
  }
}

class _InlineStreamingIndicator extends StatefulWidget {
  const _InlineStreamingIndicator();

  @override
  State<_InlineStreamingIndicator> createState() =>
      _InlineStreamingIndicatorState();
}

class _InlineStreamingIndicatorState extends State<_InlineStreamingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StreamingDots(value: _controller.value, dotSize: 5, lift: 2.5),
        ],
      ),
    );
  }
}

class _StreamingDots extends StatelessWidget {
  final double value;
  final double dotSize;
  final double lift;

  const _StreamingDots({required this.value, this.dotSize = 6, this.lift = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          _LoadingDot(
            progress: (value + i * 0.18) % 1,
            size: dotSize,
            lift: lift,
          ),
          if (i < 2) SizedBox(width: dotSize * 0.8),
        ],
      ],
    );
  }
}

class _LoadingDot extends StatelessWidget {
  final double progress;
  final double size;
  final double lift;

  const _LoadingDot({required this.progress, this.size = 6, this.lift = 3});

  @override
  Widget build(BuildContext context) {
    final lift = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    return Transform.translate(
      offset: Offset(0, -this.lift * lift),
      child: Opacity(
        opacity: 0.35 + 0.55 * lift,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: EverloreTheme.gold,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}
