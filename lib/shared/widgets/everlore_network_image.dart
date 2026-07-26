import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/nexus_theme.dart';
import 'loading_shimmer.dart';

/// One image surface for remote world art.
///
/// The provider keeps a small decoded image in memory and the original on disk;
/// every consumer also gets the same restrained loading and failure treatment.
class EverloreNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? semanticLabel;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const EverloreNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: memCacheWidth,
      maxHeightDiskCache: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholderFadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => placeholder ?? const ArtworkLoadingPlaceholder(),
      errorWidget: (_, __, ___) => errorWidget ?? const _ArtworkFallback(),
      imageBuilder: (context, imageProvider) => Semantics(
        image: true,
        label: semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: fit),
          ),
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
