import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import 'stage_tokens.dart';

/// A transparent cut-out standing in the painting.
///
/// These portraits are full-body cut-outs of different widths, not a
/// shared 2:3. Speak fills the slot's width and crops at the parchment.
/// Fitting a fake 2:3 into the height is what sliced every room through
/// the chest.
///
/// A null portrait renders the hanging standard. The player has no
/// painted face, so this is the ordinary case — a broken-image glyph
/// would read as the world failing.
class StageFigure extends StatefulWidget {
  const StageFigure({
    super.key,
    required this.name,
    required this.portraitUrl,
    required this.side,
    this.rise = StageRise.speak,
    this.active = true,
    this.fallen = false,
    this.present = true,
    this.arrive = false,
    this.flashKey,
  });

  final String name;
  final String? portraitUrl;
  final StageSide side;
  final StageRise rise;
  final bool active;
  final bool fallen;

  /// False walks them back off the wing they came from.
  final bool present;

  /// First paint slides in from their own side. A parent that already
  /// stages the entrance (a speaker switch) must leave this off or the
  /// figure walks twice.
  final bool arrive;

  /// Keys the hit-flash to an exchange, so it plays once per blow
  /// rather than every time the screen rebuilds.
  final Object? flashKey;

  @override
  State<StageFigure> createState() => _StageFigureState();
}

class _StageFigureState extends State<StageFigure>
    with TickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: StageMeasure.flash,
  );
  late final AnimationController _wing = AnimationController(
    vsync: this,
    duration: StageMeasure.arrive,
  );

  @override
  void initState() {
    super.initState();
    if (widget.arrive && widget.present) {
      _wing.forward();
    } else {
      _wing.value = widget.present ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(StageFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.present != oldWidget.present) {
      if (widget.present) {
        _wing.forward();
      } else {
        _wing.reverse();
      }
    }
    if (widget.flashKey != null && widget.flashKey != oldWidget.flashKey) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _flash.value = 0;
        return;
      }
      _flash.forward(from: 0).then((_) {
        if (mounted) _flash.reverse();
      });
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _wing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fighting = widget.rise != StageRise.speak;
    // The one who just acted comes forward. The other stays where they
    // were, so an exchange reads as one person doing something to another
    // rather than as two portraits sitting side by side.
    final opacity = widget.fallen
        ? 0.32
        : widget.active
        ? 1.0
        : 0.72;
    final slide = widget.fallen
        ? 0.04
        : widget.active
        ? -0.02
        : 0.01;
    final lunge = fighting && widget.active && !widget.fallen
        ? (widget.side == StageSide.left
              ? StageMeasure.duelLunge
              : -StageMeasure.duelLunge)
        : 0.0;
    final fromWing = widget.side == StageSide.left ? -0.24 : 0.24;

    return AnimatedBuilder(
      animation: _wing,
      builder: (context, child) {
        final t = reduceMotion ? (widget.present ? 1.0 : 0.0) : _wing.value;
        return Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(fromWing * (1 - t), 0),
            child: child,
          ),
        );
      },
      child: AnimatedSlide(
      duration: reduceMotion ? Duration.zero : StageMeasure.step,
      curve: Curves.easeOutCubic,
      offset: Offset(reduceMotion ? 0 : lunge, reduceMotion ? 0 : slide),
      child: AnimatedOpacity(
        duration: reduceMotion ? Duration.zero : StageMeasure.step,
        opacity: opacity,
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, child) {
            final lift = _flash.value;
            if (lift == 0 || reduceMotion) return child!;
            final recoil = widget.side == StageSide.left
                ? -StageMeasure.duelRecoil
                : StageMeasure.duelRecoil;
            return Transform.translate(
              offset: Offset(recoil * lift, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(<double>[
                  1 + lift * 0.55,
                  0,
                  0,
                  0,
                  lift * 40,
                  0,
                  1 + lift * 0.55,
                  0,
                  0,
                  lift * 40,
                  0,
                  0,
                  1 + lift * 0.45,
                  0,
                  lift * 28,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: child,
              ),
            );
          },
          child: _Cutout(
            name: widget.name,
            portraitUrl: widget.portraitUrl,
            side: widget.side,
            rise: widget.rise,
          ),
        ),
      ),
    ),
    );
  }
}

class _Cutout extends StatelessWidget {
  const _Cutout({
    required this.name,
    required this.portraitUrl,
    required this.side,
    required this.rise,
  });

  final String name;
  final String? portraitUrl;
  final StageSide side;
  final StageRise rise;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded or zero slot is how a published portrait painted
        // as empty room. Refuse to invent a size from Infinity.
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final slotW = constraints.maxWidth;
        final slotH = constraints.maxHeight;
        final dpr = MediaQuery.devicePixelRatioOf(context);

        // Speak fills the slot's width and hangs extra height off the
        // bottom, so a tall cut-out is a person cropped by the
        // parchment. Height-first 2:3 overflow was wider than the slot
        // and every room clipped a torso.
        final Size painted;
        final Alignment overflowAlign;
        final BoxFit fit;
        if (rise == StageRise.speak) {
          final paintedW = slotW;
          final paintedH = math.max(
            slotH,
            slotW / StageMeasure.figureCutoutAspectFloor,
          );
          painted = Size(paintedW, paintedH);
          overflowAlign = Alignment.topCenter;
          fit = BoxFit.fitWidth;
        } else {
          final paintedH = slotW / StageMeasure.figureAspect;
          painted = Size(slotW, paintedH);
          overflowAlign = side == StageSide.left
              ? Alignment.topLeft
              : Alignment.topRight;
          fit = BoxFit.contain;
        }

        // Cloth is always the 2:3 that fits the slot. Speak portraits
        // may overflow; the standard never does.
        final clothH = slotW / StageMeasure.figureAspect;
        final cloth = Size(slotW, clothH < slotH ? clothH : slotH);

        // The standard is the same rect a portrait occupies in this
        // slot. Putting it inside the overflow box is what stretched
        // one initial into a translucent sheet across the arena.
        if (portraitUrl == null) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cloth.width,
              height: cloth.height,
              child: StageStandard(name: name),
            ),
          );
        }

        return ClipRect(
          child: OverflowBox(
            alignment: overflowAlign,
            minWidth: painted.width,
            maxWidth: painted.width,
            minHeight: painted.height,
            maxHeight: painted.height,
            child: SizedBox(
              width: painted.width,
              height: painted.height,
              child: EverloreNetworkImage(
                imageUrl: portraitUrl!,
                fit: fit,
                alignment: Alignment.topCenter,
                memCacheHeight: (painted.height * dpr).round(),
                semanticLabel: name,
                placeholder: const ColoredBox(
                  color: Colors.transparent,
                  child: SizedBox.expand(),
                ),
                errorWidget: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: cloth.width,
                    height: cloth.height,
                    child: StageStandard(name: name),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Who is standing when there is no painted face: a hanging standard
/// with their initial on it.
///
/// Hung, not framed. A filled panel with a border on all four sides
/// reads as a piece of the interface sitting on top of the arena.
/// The letter follows the cloth; a screen-sized point size is how
/// one initial became a poster.
class StageStandard extends StatelessWidget {
  const StageStandard({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '' : trimmed[0].toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final short = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final letter = (short * StageMeasure.standardLetter).clamp(18.0, 72.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: StageMeasure.standardTop),
                Colors.black.withValues(alpha: StageMeasure.standardBottom),
              ],
            ),
            border: Border(
              left: BorderSide(
                color: StageMeasure.brassDim.withValues(alpha: 0.45),
              ),
              right: BorderSide(
                color: StageMeasure.brassDim.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Text(
              initial,
              style: EverloreTheme.serifDisplay(
                size: letter,
                color: StageMeasure.brassDim.withValues(alpha: 0.82),
              ),
            ),
          ),
        );
      },
    );
  }
}
