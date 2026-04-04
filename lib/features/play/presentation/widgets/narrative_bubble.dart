import 'package:flutter/material.dart';
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

          // Narrative text
          Text(
            text,
            style: EverloreTheme.aiText,
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
