import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../shared/models/event.dart';
import '../../../../../app/theme/nexus_theme.dart';
import '../../../../../shared/app_icons.dart';

class NarrativeBubble extends StatelessWidget {
  final GameEvent event;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplay;
  final VoidCallback? onContinue;
  final ValueChanged<int>? onSelectReplayVariant;

  /// This turn is currently being re-woven (a replay variant is streaming in).
  final bool isReplaying;

  const NarrativeBubble({
    super.key,
    required this.event,
    this.onLongPress,
    this.onReplay,
    this.onContinue,
    this.onSelectReplayVariant,
    this.isReplaying = false,
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
                )
              : const _GeneratingIndicator(label: 'Re-weaving this turn…')
        else if (hasProse)
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
            ),
          )
        else if (event.isOptimistic)
          const _GeneratingIndicator(),
      ],
    );
  }
}

class _PlayerBubble extends StatelessWidget {
  final String text;
  const _PlayerBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(60, 10, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EverloreTheme.violet.withValues(alpha: 0.85),
              EverloreTheme.violetDim.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: EverloreTheme.violetBright.withValues(alpha: 0.3),
          ),
          boxShadow: EverloreTheme.glow(
            EverloreTheme.violet,
            blur: 16,
            alpha: 0.22,
          ),
        ),
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
                color: EverloreTheme.parchment.withValues(alpha: 0.9),
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
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

  const _NarratorPanel({
    required this.text,
    this.sceneTag,
    this.isEdited = false,
    this.replayVariants = const [],
    this.selectedReplayIndex = 0,
    this.onContinue,
    this.onReplay,
    this.onSelectReplayVariant,
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
                      Icon(
                        Icons.auto_stories,
                        size: 11,
                        color: accent.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'NARRATOR',
                        style: EverloreTheme.ui(
                          size: 9,
                          weight: FontWeight.w700,
                          spacing: 2.0,
                          color: accent.withValues(alpha: 0.7),
                        ),
                      ),
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
                  const SizedBox(height: 10),
                  SelectableText.rich(
                    TextSpan(children: _narrativeSpans(text)),
                  ),
                  const SizedBox(height: 12),
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

/// Renders narrative prose with asterisks as the narration boundary: text outside
/// `*...*` / `**...**` is spoken dialogue (bright, upright), while marked text is
/// narration/action/attribution (italic, muted). This is deterministic and
/// streaming-stable: a trailing unclosed marker reads as in-progress narration.
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
        color: const Color(0xFFA8A093),
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

  TextStyle styleNow() {
    return inNarration ? narration : dialogue;
  }

  void flush() {
    if (buf.isEmpty) return;
    spans.add(TextSpan(text: buf.toString(), style: styleNow()));
    buf.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];

    if (c == '*') {
      flush();
      inNarration = !inNarration;
      if (i + 1 < text.length && text[i + 1] == '*') i++;
      continue;
    }

    buf.write(c);
  }
  flush();

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: dialogue));
  }
  return spans;
}

class _GeneratingIndicator extends StatefulWidget {
  final String label;
  const _GeneratingIndicator({this.label = 'The world is weaving your tale…'});

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
        animation: _pulse,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 14,
              color: EverloreTheme.gold.withValues(
                alpha: 0.4 + 0.4 * _pulse.value,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.ash.withValues(
                  alpha: 0.5 + 0.3 * _pulse.value,
                ),
                spacing: 0.2,
                fontStyle: FontStyle.italic,
              ).copyWith(fontFamily: GoogleFonts.ebGaramond().fontFamily),
            ),
          ],
        ),
      ),
    );
  }
}
