import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_closeness_picker.dart';

/// What stands in for a face before one is painted.
/// An unpainted person stands in a lit archway with a bond-toned radial glow.
/// Stack(fit: expand), always inside a sized parent.
class GroupFaceFrame extends StatefulWidget {
  final String? initial;
  final IconData? icon;
  final GroupCloseness? bond;
  final Color? tone;
  final bool pulsing;
  final double archBottom;

  const GroupFaceFrame({
    super.key,
    this.initial,
    this.icon,
    this.bond,
    this.tone,
    this.pulsing = false,
    this.archBottom = 64.0,
  });

  static Color resolveBondTone(GroupCloseness? bond, [Color? tone]) =>
      GroupClosenessPicker.toneOf(bond, tone);

  @override
  State<GroupFaceFrame> createState() => _GroupFaceFrameState();
}

class _GroupFaceFrameState extends State<GroupFaceFrame>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) {
      _initAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
    )..addListener(() => setState(() {}));
    _controller!.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GroupFaceFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !oldWidget.pulsing) {
      if (_controller == null) {
        _initAnimation();
      } else {
        _controller!.repeat(reverse: true);
      }
    } else if (!widget.pulsing && oldWidget.pulsing) {
      _controller?.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTone = GroupFaceFrame.resolveBondTone(widget.bond, widget.tone);
    final pulseValue = widget.pulsing && _animation != null
        ? _animation!.value
        : null;

    final glowAlpha = pulseValue != null
        ? (pulseValue * (0.22 / 0.32)).clamp(0.0, 1.0)
        : 0.22;
    final archBorderAlpha = pulseValue != null
        ? pulseValue.clamp(0.0, 1.0)
        : 0.32;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 180.0;
        final fontSize = (cardWidth * 0.3).clamp(16.0, 72.0);

        final letter =
            widget.initial != null && widget.initial!.trim().isNotEmpty
            ? widget.initial!.trim()[0].toUpperCase()
            : '';

        final Widget centerChild;
        if (widget.icon != null) {
          centerChild = Icon(
            widget.icon,
            size: 36,
            color: EverloreTheme.goldDim.withValues(alpha: 0.6),
          );
        } else {
          centerChild = Text(
            letter,
            style: EverloreTheme.serifDisplay(
              size: fontSize,
              color: EverloreTheme.goldDim.withValues(alpha: 0.6),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Base: cardDecoration gradient colours
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: EverloreTheme.cardDecoration.gradient,
              ),
            ),
            // 2. Radial glow: centre (0, -0.25), radius 0.85, bond tone at 0.22 to transparent
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.25),
                    radius: 0.85,
                    colors: [
                      activeTone.withValues(alpha: glowAlpha),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // 3. Arch: Positioned(left: 18, right: 18, top: 16, bottom: 64)
            Positioned(
              left: 18,
              right: 18,
              top: 16,
              bottom: widget.archBottom,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: EverloreTheme.goldDim.withValues(
                      alpha: archBorderAlpha,
                    ),
                    width: 1.0,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(999),
                  ),
                ),
                child: Center(child: centerChild),
              ),
            ),
          ],
        );
      },
    );
  }
}
