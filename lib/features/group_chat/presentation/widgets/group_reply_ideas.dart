import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';

/// Row of up to three reply idea chips above the composer.
///
/// Fades and rises in gently over about 250ms when appearing, and vanishes
/// immediately on send. Full text is readable (up to two lines), wrapped in a
/// thin hairline border over a dark translucent surface.
class GroupReplyIdeas extends StatefulWidget {
  final List<String> ideas;
  final ValueChanged<String> onSendIdea;
  final bool hidden;

  const GroupReplyIdeas({
    super.key,
    required this.ideas,
    required this.onSendIdea,
    this.hidden = false,
  });

  @override
  State<GroupReplyIdeas> createState() => _GroupReplyIdeasState();
}

class _GroupReplyIdeasState extends State<GroupReplyIdeas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _riseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _riseAnimation = Tween<Offset>(
      begin: const Offset(0, 10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.ideas.isNotEmpty && !widget.hidden) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant GroupReplyIdeas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasVisible = oldWidget.ideas.isNotEmpty && !oldWidget.hidden;
    final isVisible = widget.ideas.isNotEmpty && !widget.hidden;

    if (!wasVisible && isVisible) {
      _controller.forward(from: 0.0);
    } else if (wasVisible && !isVisible) {
      // Vanish immediately on send or when hidden.
      _controller.reset();
    } else if (isVisible && oldWidget.ideas != widget.ideas) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ideas.isEmpty || widget.hidden) {
      return const SizedBox.shrink();
    }

    final displayIdeas = widget.ideas.take(3).toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _riseAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < displayIdeas.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildChip(context, displayIdeas[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String idea) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onSendIdea(idea),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: EverloreTheme.void2.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              idea,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EverloreTheme.aiText.copyWith(
                fontSize: 13.5,
                height: 1.25,
                color: EverloreTheme.parchment,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
