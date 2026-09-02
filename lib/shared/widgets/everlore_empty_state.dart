import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';
import '../../core/guide/guide_anchor.dart';
import '../../app/layout/responsive.dart';

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
  final String? artAsset;
  final bool fullBleedArt;

  /// When set, the guide may use the action button itself as a spotlight
  /// target (see [GuideAnchor]) — e.g. pointing the personas walkthrough at
  /// "Create persona" rather than at the whole empty state.
  final String? anchorId;

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
    this.artAsset,
    this.fullBleedArt = false,
    this.anchorId,
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

  Widget _actionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAction,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.48)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.actionIcon != null) ...[
                Icon(widget.actionIcon, size: 17, color: widget.accent),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // A short screen — a small phone, or any phone at large system text —
    // cannot afford the full emblem and the 40pt of air above it. Without
    // this the primary action ("Create persona") started life below the nav
    // bar, which is the one thing an empty state must never do.
    final layout = EvLayout.of(context);
    final tight = layout.isShort || layout.isCompact;
    final emblemSize = tight ? 58.0 : (widget.compact ? 76.0 : 104.0);
    final hasArt = widget.artAsset != null && !widget.fullBleedArt;
    final artRadius = BorderRadius.circular(20);
    final content = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          tight ? 22 : 32,
          tight ? 10 : 40,
          tight ? 22 : 32,
          // Clears the floating nav bar; the action must land above it, not
          // under it, or an empty tab has no way out of itself.
          112,
        ),
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
                  width: hasArt ? double.infinity : emblemSize,
                  height: hasArt ? (widget.compact ? 142 : 170) : emblemSize,
                  decoration: BoxDecoration(
                    shape: hasArt ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: hasArt ? artRadius : null,
                    gradient: RadialGradient(
                      colors: [
                        widget.accent.withValues(alpha: 0.20),
                        EverloreTheme.void2.withValues(alpha: 0.88),
                        EverloreTheme.void1,
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                    border: Border.all(
                      color: widget.accent.withValues(
                        alpha: hasArt ? 0.52 : 0.34,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.12),
                        blurRadius: hasArt ? 22 : 28,
                        spreadRadius: hasArt ? 0 : 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (hasArt)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: hasArt
                                ? artRadius
                                : BorderRadius.zero,
                            child: Image.asset(
                              widget.artAsset!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                      if (hasArt)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: artRadius,
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  EverloreTheme.void1.withValues(alpha: 0.72),
                                  EverloreTheme.void1.withValues(alpha: 0.12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (!hasArt)
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
                      if (!hasArt)
                        Icon(
                          widget.icon,
                          size: widget.compact ? 30 : 42,
                          color: widget.accent,
                        )
                      else
                        Positioned(
                          left: 14,
                          bottom: 12,
                          child: Icon(
                            widget.icon,
                            size: tight ? 20 : (widget.compact ? 20 : 24),
                            color: widget.accent.withValues(alpha: 0.96),
                            shadows: [
                              Shadow(
                                color: EverloreTheme.void0.withValues(
                                  alpha: 0.9,
                                ),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tight ? 12 : (widget.compact ? 18 : 24)),
              // The eyebrow is decoration; on a short screen it is the first
              // thing to go, because the action button is the last thing that
              // may be pushed under the nav bar.
              if (widget.eyebrow != null && !tight) ...[
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
                SizedBox(height: tight ? 14 : (widget.compact ? 20 : 28)),
                if (widget.anchorId == null)
                  _actionButton()
                else
                  GuideAnchor(id: widget.anchorId!, child: _actionButton()),
              ],
            ],
          ),
        ),
      ),
    );
    if (!widget.fullBleedArt || widget.artAsset == null) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.artAsset!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                EverloreTheme.void0.withValues(alpha: 0.24),
                EverloreTheme.void0.withValues(alpha: 0.6),
                EverloreTheme.void0.withValues(alpha: 0.84),
              ],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
        content,
      ],
    );
  }
}
