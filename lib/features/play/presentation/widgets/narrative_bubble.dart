import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
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
        if (event.playerInput != null && event.playerInput!.isNotEmpty)
          _PlayerBubble(text: event.playerInput!),

        if (event.aiResponse != null && event.aiResponse!.isNotEmpty)
          GestureDetector(
            onLongPress: onLongPress,
            child: _NarratorPanel(
              text: event.aiResponse!,
              sceneTag: event.sceneTag,
              isEdited: event.isUserEdited,
            ),
          ),

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
          boxShadow: EverloreTheme.glow(EverloreTheme.violet, blur: 16, alpha: 0.22),
        ),
        child: Text(
          text,
          style: EverloreTheme.ui(
            size: 15,
            color: EverloreTheme.parchment,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _NarratorPanel extends StatelessWidget {
  final String text;
  final String? sceneTag;
  final bool isEdited;

  const _NarratorPanel({
    required this.text,
    this.sceneTag,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = EverloreTheme.sceneAccent(sceneTag);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 40, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF13132A).withValues(alpha: 0.72),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.16)),
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
                      Icon(Icons.auto_stories,
                          size: 11, color: accent.withValues(alpha: 0.7)),
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
                        Icon(Icons.edit,
                            size: 9,
                            color: EverloreTheme.ash.withValues(alpha: 0.4)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  MarkdownBody(
                    data: text,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheet: _narrativeMarkdownStyle(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (sceneTag != null)
                        _SceneTagBadge(tag: sceneTag!, accent: accent),
                      const Spacer(),
                      _CopyButton(text: text),
                    ],
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
  const _CopyButton({required this.text});

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
            Icon(Icons.copy_rounded,
                size: 13, color: EverloreTheme.ash.withValues(alpha: 0.7)),
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
        ),
      ),
    );
  }
}

MarkdownStyleSheet _narrativeMarkdownStyle() {
  final base = EverloreTheme.aiText;
  return MarkdownStyleSheet(
    p: base,
    pPadding: EdgeInsets.zero,
    blockSpacing: 12,
    h1: GoogleFonts.cinzel(
        fontSize: 22, fontWeight: FontWeight.w700, color: EverloreTheme.gold, height: 1.3),
    h1Padding: const EdgeInsets.only(top: 4, bottom: 8),
    h2: GoogleFonts.cinzel(
        fontSize: 19, fontWeight: FontWeight.w700, color: EverloreTheme.gold, height: 1.35),
    h2Padding: const EdgeInsets.only(top: 4, bottom: 6),
    h3: base.copyWith(
        fontSize: 18, fontWeight: FontWeight.w600, color: EverloreTheme.parchment, height: 1.4),
    h3Padding: const EdgeInsets.only(top: 2, bottom: 6),
    h4: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: EverloreTheme.parchment),
    h4Padding: const EdgeInsets.only(bottom: 4),
    h5: base.copyWith(fontWeight: FontWeight.w600),
    h5Padding: const EdgeInsets.only(bottom: 4),
    h6: base.copyWith(fontWeight: FontWeight.w600, color: EverloreTheme.ash),
    h6Padding: const EdgeInsets.only(bottom: 4),
    // Italic = narration / scene / inner thoughts: softer, cooler, like stage
    // directions. Plain text (p) = spoken dialogue, which stays bright and clear.
    em: base.copyWith(
        fontStyle: FontStyle.italic, color: const Color(0xFFAEA690)),
    strong: base.copyWith(fontWeight: FontWeight.w700, color: EverloreTheme.goldGlow),
    del: base.copyWith(decoration: TextDecoration.lineThrough),
    code: base.copyWith(
      fontFamily: 'monospace',
      fontSize: 14,
      backgroundColor: EverloreTheme.void4,
      color: EverloreTheme.goldGlow,
    ),
    blockquote: base.copyWith(color: EverloreTheme.ash, fontStyle: FontStyle.italic),
    blockquotePadding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.55), width: 3),
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
      border: Border(top: BorderSide(color: EverloreTheme.white10, width: 1)),
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
      margin: const EdgeInsets.fromLTRB(16, 6, 40, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13132A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.16)),
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
            const SizedBox(width: 12),
            Text(
              'The world is weaving your tale…',
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.ash.withValues(alpha: 0.5 + 0.3 * _pulse.value),
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
