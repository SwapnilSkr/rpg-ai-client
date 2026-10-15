import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../models/turn_media.dart';
import 'media_viewer_sheet.dart';

/// Row of media items under a narrative turn.
class MediaThumbnailRow extends StatelessWidget {
  final List<TurnMedia> media;

  const MediaThumbnailRow({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final item in media)
            _MediaItemThumbnail(item: item),
        ],
      ),
    );
  }
}

class _MediaItemThumbnail extends StatelessWidget {
  final TurnMedia item;

  const _MediaItemThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isQueued) {
      return const _TakingShapePlaceholder();
    }

    if (!item.isReady) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => MediaViewerSheet.show(context, item),
      child: Container(
        width: 120,
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.28),
          ),
          color: EverloreTheme.void3,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: item.isVideo
            ? _VideoThumbnail(item: item)
            : _PictureThumbnail(url: item.url!),
      ),
    );
  }
}

class _TakingShapePlaceholder extends StatefulWidget {
  const _TakingShapePlaceholder();

  @override
  State<_TakingShapePlaceholder> createState() =>
      _TakingShapePlaceholderState();
}

class _TakingShapePlaceholderState extends State<_TakingShapePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: EverloreTheme.void3.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + 0.2 * _anim.value,
                child: Opacity(
                  opacity: 0.5 + 0.5 * _anim.value,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: EverloreTheme.goldGlow,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Taking shape…',
            style: EverloreTheme.ui(
              size: 12,
              color: EverloreTheme.ash,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _PictureThumbnail extends StatelessWidget {
  final String url;
  const _PictureThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EverloreNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fullscreen_rounded,
              size: 12,
              color: EverloreTheme.parchment,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final TurnMedia item;
  const _VideoThumbnail({required this.item});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.url != null && widget.item.url!.isNotEmpty) {
      final uri = Uri.tryParse(widget.item.url!);
      if (uri != null) {
        _controller = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              // "A video the player just asked for plays once, muted until tapped."
              if (widget.item.justRequested) {
                _controller?.setVolume(0.0);
                _controller?.play();
              }
            }
          });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _initialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: EverloreTheme.parchment,
              ),
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Icon(
        Icons.videocam_outlined,
        color: EverloreTheme.ash,
        size: 22,
      ),
    );
  }
}
