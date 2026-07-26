import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';

/// A calm, actionable empty state for the primary app surfaces.
///
/// It intentionally reserves visual drama for the illustration/emblem while
/// keeping the copy and action compact, so an empty tab feels inviting rather
/// than like a dead end.
class EverloreEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? eyebrow;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color accent;
  final bool compact;

  const EverloreEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.eyebrow,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.accent = EverloreTheme.gold,
    this.compact = false,
  });

  @override
  State<EverloreEmptyState> createState() => _EverloreEmptyStateState();
}

class _EverloreEmptyStateState extends State<EverloreEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emblemSize = widget.compact ? 76.0 : 104.0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 112),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: 0.975 + _pulse.value * 0.035,
                  child: child,
                ),
                child: Container(
                  width: emblemSize,
                  height: emblemSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accent.withValues(alpha: 0.20),
                        EverloreTheme.void2.withValues(alpha: 0.88),
                        EverloreTheme.void1,
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.34),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.12),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: emblemSize * 0.68,
                        height: emblemSize * 0.68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      Icon(
                        widget.icon,
                        size: widget.compact ? 30 : 42,
                        color: widget.accent,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: widget.compact ? 18 : 24),
              if (widget.eyebrow != null) ...[
                Text(
                  widget.eyebrow!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EverloreTheme.ui(
                    size: 10,
                    color: widget.accent,
                    weight: FontWeight.w700,
                    spacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: EverloreTheme.serifDisplay(
                  size: widget.compact ? 20 : 24,
                  color: EverloreTheme.parchment,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: EverloreTheme.ui(
                  size: 13,
                  color: EverloreTheme.ash,
                  height: 1.5,
                ),
              ),
              if (widget.onAction != null && widget.actionLabel != null) ...[
                SizedBox(height: widget.compact ? 20 : 28),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onAction,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.48),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.actionIcon != null) ...[
                            Icon(
                              widget.actionIcon,
                              size: 17,
                              color: widget.accent,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.actionLabel!,
                            style: EverloreTheme.ui(
                              size: 13,
                              color: widget.accent,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
