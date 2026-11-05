import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';
import 'loading_shimmer.dart';

/// Decode widths, ascending. Nearby box sizes share one decoded copy, and an
/// animating box does not re-decode the picture on every frame.
const List<int> _decodeTiers = [96, 160, 240, 360, 540, 720, 1080, 1440];

/// The width to decode a picture at, or null when the caller sized only the
/// height (that value is then kept as is and no width is set).
///
/// The larger side of the box is used because a cover fit of a portrait in a
/// wide box (or the reverse) must still fill without going soft. Only a width
/// is ever returned: giving [ResizeImage] both dimensions stretches the
/// picture and loses its aspect ratio.
@visibleForTesting
int? decodeWidthFor({
  required double maxWidth,
  required double maxHeight,
  required double devicePixelRatio,
  int? explicitWidth,
  int? explicitHeight,
}) {
  if (explicitWidth == null && explicitHeight != null) return null;
  final sides = [maxWidth, maxHeight].where((v) => v.isFinite && v > 0);
  if (sides.isEmpty) return explicitWidth ?? _decodeTiers.last;
  final wanted = sides.reduce((a, b) => a > b ? a : b) * devicePixelRatio;
  final tier = _decodeTiers.firstWhere(
    (t) => t >= wanted,
    orElse: () => _decodeTiers.last,
  );
  return explicitWidth == null || tier < explicitWidth ? tier : explicitWidth;
}

/// One image surface for remote world art.
///
/// The original stays on disk once (no per-size copies, so a thumbnail never
/// softens a later full-screen view). In memory the picture is decoded at about
/// the size it is shown, picked from the box it is laid out in, so no call site
/// has to remember to size it. A picture the player can zoom passes
/// [fullResolution] and is decoded whole. Every consumer also gets the same
/// restrained loading and failure treatment.
class EverloreNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  /// Which part of the picture stays in view when [fit] crops it.
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? semanticLabel;

  /// Explicit decode sizes still work; the smaller of [memCacheWidth] and the
  /// size derived from the box wins. Ignored when [fullResolution] is set.
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Decode at the picture's own size, for pictures the player can zoom.
  final bool fullResolution;

  const EverloreNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fullResolution = false,
  });

  @override
  Widget build(BuildContext context) {
    if (fullResolution) return _image(null, null);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => _image(
        decodeWidthFor(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          devicePixelRatio: dpr,
          explicitWidth: memCacheWidth,
          explicitHeight: memCacheHeight,
        ),
        memCacheHeight,
      ),
    );
  }

  Widget _image(int? decodeWidth, int? decodeHeight) {
    // Only one dimension may reach the provider, or ResizeImage stretches.
    final width = decodeHeight != null && decodeWidth == null ? null : decodeWidth;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      alignment: alignment,
      memCacheWidth: width,
      memCacheHeight: width == null ? decodeHeight : null,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholderFadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => placeholder ?? const ArtworkLoadingPlaceholder(),
      errorWidget: (_, __, ___) => errorWidget ?? const _ArtworkFallback(),
      // An Image fills loose constraints; the childless DecoratedBox it
      // replaces collapsed to 0x0 there and painted a black screen. An
      // unbounded side keeps the picture's own size: infinity would throw.
      imageBuilder: (context, imageProvider) => LayoutBuilder(
        builder: (context, box) => Image(
          image: imageProvider,
          fit: fit,
          alignment: alignment,
          width: box.hasBoundedWidth ? double.infinity : null,
          height: box.hasBoundedHeight ? double.infinity : null,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
        ),
      ),
    );
  }
}

class ArtworkLoadingPlaceholder extends StatefulWidget {
  const ArtworkLoadingPlaceholder({super.key});

  @override
  State<ArtworkLoadingPlaceholder> createState() =>
      _ArtworkLoadingPlaceholderState();
}

class _ArtworkLoadingPlaceholderState extends State<ArtworkLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const LoadingShimmer(height: double.infinity, radius: 0),
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: EverloreTheme.goldDim,
            ),
            builder: (context, child) => Transform.scale(
              scale: 0.92 + _pulse.value * 0.12,
              child: Opacity(opacity: 0.58 + _pulse.value * 0.42, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 1.1,
          colors: [EverloreTheme.void3, EverloreTheme.void0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 26,
          color: EverloreTheme.goldDim,
        ),
      ),
    );
  }
}
