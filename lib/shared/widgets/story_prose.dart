import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';

/// How far narration is dimmed against spoken words. Shared with the play
/// surface so a passage reads the same wherever it is shown.
const kNarrationMutedAlpha = 0.6;

/// Turn a passage of in-world prose into styled spans.
///
/// The models write in the register the play surface renders: `*a line of
/// action*` for narration and `"a line of speech"` for dialogue. Read as plain
/// text those markers are literal asterisks, which is what a world's opening
/// line looked like on its detail screen — the same passage that renders as
/// prose the moment the player is inside the story.
///
/// Lifted out of `narrative_bubble.dart` unchanged. It was private to the play
/// widget, so every other surface showing the same kind of text had no way to
/// render it; the bubble now calls through to this.
List<InlineSpan> storyProseSpans(
  String text, {
  TextStyle? dialogueStyle,
  TextStyle? narrationStyle,
}) {
  // Resolved only when a caller leaves one out. `aiText` is a Google font, so
  // reading it eagerly would have every caller pay for a typeface it may not
  // use — and would make this unusable anywhere fonts cannot be fetched.
  TextStyle base() => EverloreTheme.aiText;
  final narration =
      narrationStyle ??
      base().copyWith(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        color: EverloreTheme.parchment.withValues(alpha: kNarrationMutedAlpha),
      );
  final dialogue =
      dialogueStyle ??
      base().copyWith(
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.w600,
        color: EverloreTheme.parchment,
      );

  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var inNarration = false;
  var inQuote = false;

  TextStyle styleNow() {
    if (inQuote) return dialogue;
    if (inNarration) return narration;
    return narration;
  }

  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: styleNow()));
    buf.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];

    // Quotes are semantic dialogue boundaries, even inside `*narration*`.
    // Keeping narration mode active underneath lets us resume italic prose after
    // the closing quote while rendering every spoken span upright and bold.
    if (c == '"' || c == '“' || c == '”') {
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

    if (c == '*' && !inQuote) {
      flush();
      inNarration = !inNarration;
      if (i + 1 < text.length && text[i + 1] == '*') i++;
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

/// Prose that is cut to [collapsedLines] until the reader asks for the rest.
///
/// A world's lore entry is written by its author and has no length the app can
/// count on — the ones that read as a wall are the ones that push everything
/// worth deciding on, the stats and the way in, off the bottom of the screen.
///
/// The affordance appears only when the text genuinely does not fit, measured
/// against the width it is actually being given rather than guessed from a
/// character count. Short entries render exactly as they did before, with no
/// control and nothing to dismiss.
class ExpandableProse extends StatefulWidget {
  /// Plain text. Ignored when [spans] is given.
  final String? text;

  /// Pre-styled prose — from [storyProseSpans], for passages written in the
  /// world's own voice.
  final List<InlineSpan>? spans;

  /// Style for [text], and the fallback style for the span tree.
  final TextStyle style;

  /// Lines shown before expanding.
  final int collapsedLines;

  /// Colour of the reveal control.
  final Color accent;

  final String expandLabel;
  final String collapseLabel;

  const ExpandableProse({
    super.key,
    this.text,
    this.spans,
    required this.style,
    required this.accent,
    this.collapsedLines = 6,
    this.expandLabel = 'Read more',
    this.collapseLabel = 'Show less',
  }) : assert(
         text != null || spans != null,
         'ExpandableProse needs text or spans',
       );

  @override
  State<ExpandableProse> createState() => _ExpandableProseState();
}

class _ExpandableProseState extends State<ExpandableProse> {
  bool _expanded = false;

  InlineSpan _span() => widget.spans != null && widget.spans!.isNotEmpty
      ? TextSpan(style: widget.style, children: widget.spans)
      : TextSpan(text: widget.text ?? '', style: widget.style);

  @override
  Widget build(BuildContext context) {
    final span = _span();
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Laid out at the width the prose will actually occupy and at the
        // reader's own text scale, so a player at 200% system text gets the
        // control exactly when their copy overflows — not when a 100% copy
        // would have.
        final painter = TextPainter(
          text: span,
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        final body = Text.rich(
          span,
          maxLines: _expanded || !overflows ? null : widget.collapsedLines,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              // Collapsed prose fades into the cut rather than stopping at an
              // ellipsis: the sentence is not finished, and a soft edge says
              // "there is more" where "…" says "the rest was thrown away".
              child: overflows && !_expanded
                  ? ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: const [0, 0.72, 1],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: body,
                    )
                  : body,
            ),
            if (overflows) ...[
              const SizedBox(height: 6),
              // A full-width strip rather than a hit box around the words: the
              // whole line under a cut paragraph is where a thumb goes, and it
              // keeps the target at the 48pt minimum without padding the label
              // into something that looks like a button.
              Semantics(
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: Row(
                      children: [
                        Text(
                          _expanded ? widget.collapseLabel : widget.expandLabel,
                          style: EverloreTheme.ui(
                            size: 12.5,
                            color: widget.accent,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: widget.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
