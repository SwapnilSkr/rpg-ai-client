import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One place that answers "how much room is there, really?".
///
/// Screens used to hard-code gutters, sheet heights and column widths, so the
/// same layout that looked right on a 393pt phone ran off the bottom of a
/// 320pt one and stretched into a slab on a tablet. Everything spatial should
/// come from here instead of from a literal.
enum EvWidthClass {
  /// Small phones, and any phone in landscape: ≤ 359pt.
  compact,

  /// The common phone range: 360–599pt.
  regular,

  /// Tablets, foldables open, desktop windows: ≥ 600pt.
  expanded,
}

class EvLayout {
  final Size size;

  /// Notch, home indicator, and the keyboard when it is up — the keyboard is
  /// folded into [bottomInset] because it takes room the same way.
  final EdgeInsets safe;
  final double bottomInset;

  const EvLayout._({
    required this.size,
    required this.safe,
    required this.bottomInset,
  });

  factory EvLayout.of(BuildContext context) {
    final media = MediaQuery.of(context);
    return EvLayout._(
      size: media.size,
      safe: media.padding,
      bottomInset: math.max(media.padding.bottom, media.viewInsets.bottom),
    );
  }

  EvWidthClass get widthClass => size.width >= 600
      ? EvWidthClass.expanded
      : (size.width < 360 ? EvWidthClass.compact : EvWidthClass.regular);

  bool get isCompact => widthClass == EvWidthClass.compact;
  bool get isExpanded => widthClass == EvWidthClass.expanded;

  /// Screens shorter than this cannot afford decorative vertical space —
  /// a 4" phone, or any phone with the keyboard up.
  bool get isShort => size.height - safe.vertical - bottomInset < 620;

  /// Horizontal page padding.
  double get gutter => switch (widthClass) {
    EvWidthClass.compact => 16,
    EvWidthClass.regular => 20,
    EvWidthClass.expanded => 28,
  };

  /// Reading measure. Past this a single column stops being a column and
  /// becomes a banner, so wide screens centre the content instead.
  double get maxContentWidth => 640;

  /// Vertical rhythm, squeezed on short screens rather than overflowing.
  double space(double base) => isShort ? base * 0.72 : base;

  /// The tallest a modal sheet may be: never past the status bar, and never
  /// so tall that the surface behind it disappears entirely.
  double get maxSheetHeight =>
      math.max(240.0, size.height - safe.top - 24 - (isShort ? 0 : 12));

  /// Room a sheet's scrollable body may use, keyboard accounted for.
  double sheetBodyMaxHeight({double chrome = 0}) =>
      math.max(160.0, maxSheetHeight - chrome - bottomInset);
}

extension EvLayoutContext on BuildContext {
  EvLayout get layout => EvLayout.of(this);
}

/// Caps and centres page content so a phone layout does not stretch edge to
/// edge on a tablet, and applies the width-class gutter.
class EvBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const EvBody({super.key, required this.child, this.maxWidth, this.padding});

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? layout.maxContentWidth,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: layout.gutter),
          child: child,
        ),
      ),
    );
  }
}

/// Clamps the system text scale.
///
/// Everything here is laid out to flex, but Android allows 200% and at that
/// size a two-line button label becomes five lines and the screen genuinely
/// cannot hold it. 1.4 is the point past which this app's densest screens
/// (the play composer, the nav bar) stop fitting on a small phone; below it
/// nothing is clipped.
class EvTextScaleGuard extends StatelessWidget {
  final Widget child;
  static const double maxScale = 1.4;

  const EvTextScaleGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(14) / 14;
    if (scale <= maxScale) return child;
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(maxScale)),
      child: child,
    );
  }
}

/// Centres its child when there is room and scrolls it when there is not.
///
/// The app was full of "centred, non-scrolling — fits the viewport" columns.
/// They fit the viewport of the phone they were written on; on a 320x568
/// screen, or with the keyboard up, or at 140% text, they overflowed and the
/// bottom of the content was simply gone. This keeps the centred look on
/// roomy screens without ever clipping on tight ones.
class EvCenteredScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const EvCenteredScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
