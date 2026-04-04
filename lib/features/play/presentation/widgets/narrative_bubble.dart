import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../shared/models/event.dart';
import '../../../../../app/theme/nexus_theme.dart';

class NarrativeBubble extends StatelessWidget {
  final GameEvent event;
  final VoidCallback? onLongPress;

  const NarrativeBubble({
    super.key,
    required this.event,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Player action — right aligned, violet tint
        if (event.playerInput != null && event.playerInput!.isNotEmpty)
          _PlayerBubble(text: event.playerInput!),

        // AI narrative response — left aligned, styled like a tome
        if (event.aiResponse != null && event.aiResponse!.isNotEmpty)
          GestureDetector(
            onLongPress: onLongPress,
            child: _NarratorBubble(
              text: event.aiResponse!,
              sceneTag: event.sceneTag,
              isEdited: event.isUserEdited,
            ),
          ),

        // Generating indicator
        if (event.isOptimistic && event.aiResponse == null)
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
        margin: const EdgeInsets.fromLTRB(64, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EverloreTheme.violetDim.withValues(alpha: 0.8),
              EverloreTheme.violet.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: EverloreTheme.violetBright.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: EverloreTheme.parchment,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _NarratorBubble extends StatelessWidget {
  final String text;
  final String? sceneTag;
  final bool isEdited;

  const _NarratorBubble({
    required this.text,
    this.sceneTag,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 64, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Narrator label
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                size: 11,
                color: EverloreTheme.gold.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                'NARRATOR',
                style: TextStyle(
                  color: EverloreTheme.gold.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
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

          // Narrative text (model may emit **bold**, *italic*, lists, etc.)
          MarkdownBody(
            data: text,
            selectable: true,
            shrinkWrap: true,
            styleSheet: _narrativeMarkdownStyle(),
          ),

          // Scene tag
          if (sceneTag != null) ...[
            const SizedBox(height: 12),
            _SceneTagBadge(tag: sceneTag!),
          ],
        ],
      ),
    );
  }
}

class _SceneTagBadge extends StatelessWidget {
  final String tag;
  const _SceneTagBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Color _tagColor(String tag) {
    return switch (tag) {
      'combat' => EverloreTheme.crimson,
      'intimate' => const Color(0xFFEC4899),
      'exploration' => EverloreTheme.verdant,
      'existential' => EverloreTheme.cyanBright,
      'cosmic' => EverloreTheme.violetBright,
      'dialogue' => EverloreTheme.gold,
      'mundane' => EverloreTheme.ash,
      _ => EverloreTheme.ash,
    };
  }
}

MarkdownStyleSheet _narrativeMarkdownStyle() {
  const base = EverloreTheme.aiText;
  return MarkdownStyleSheet(
    p: base,
    pPadding: EdgeInsets.zero,
    blockSpacing: 10,
    h1: base.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: EverloreTheme.gold,
      height: 1.3,
    ),
    h1Padding: const EdgeInsets.only(top: 4, bottom: 8),
    h2: base.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: EverloreTheme.gold,
      height: 1.35,
    ),
    h2Padding: const EdgeInsets.only(top: 4, bottom: 6),
    h3: base.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: EverloreTheme.parchment,
      height: 1.4,
    ),
    h3Padding: const EdgeInsets.only(top: 2, bottom: 6),
    h4: base.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: EverloreTheme.parchment,
    ),
    h4Padding: const EdgeInsets.only(bottom: 4),
    h5: base.copyWith(fontWeight: FontWeight.w600),
    h5Padding: const EdgeInsets.only(bottom: 4),
    h6: base.copyWith(
      fontWeight: FontWeight.w600,
      color: EverloreTheme.ash,
    ),
    h6Padding: const EdgeInsets.only(bottom: 4),
    em: base.copyWith(fontStyle: FontStyle.italic),
    strong: base.copyWith(
      fontWeight: FontWeight.w700,
      color: EverloreTheme.parchment,
    ),
    del: base.copyWith(decoration: TextDecoration.lineThrough),
    code: base.copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: EverloreTheme.void4,
      color: EverloreTheme.goldGlow,
    ),
    blockquote: base.copyWith(
      color: EverloreTheme.ash,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: EverloreTheme.goldDim.withValues(alpha: 0.55),
          width: 3,
        ),
      ),
    ),
    a: base.copyWith(
      color: EverloreTheme.cyanBright,
      decoration: TextDecoration.underline,
      decorationColor: EverloreTheme.cyanBright.withValues(alpha: 0.45),
    ),
    listBullet: base,
    listIndent: 22,
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: EverloreTheme.white10, width: 1),
      ),
    ),
    codeblockDecoration: BoxDecoration(
      color: EverloreTheme.void0,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: EverloreTheme.white10),
    ),
    codeblockPadding: const EdgeInsets.all(12),
  );
}

class _GeneratingIndicator extends StatefulWidget {
  const _GeneratingIndicator();

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
      margin: const EdgeInsets.fromLTRB(16, 4, 64, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.18),
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
              color: EverloreTheme.gold.withValues(alpha: 0.4 + 0.4 * _pulse.value),
            ),
            const SizedBox(width: 10),
            Text(
              'The world is weaving your tale...',
              style: TextStyle(
                color: EverloreTheme.ash.withValues(alpha: 0.5 + 0.3 * _pulse.value),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
