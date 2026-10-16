import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../models/turn_media.dart';

/// Fullscreen viewer for picture and video media.
class MediaViewerSheet extends StatelessWidget {
  final TurnMedia media;

  const MediaViewerSheet({super.key, required this.media});

  static Future<void> show(BuildContext context, TurnMedia media) {
    return showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Media viewer',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => MediaViewerSheet(media: media),
      transitionBuilder: (context, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: media.isVideo
                ? _VideoPlayerView(url: media.url ?? '')
                : _PictureView(url: media.url ?? ''),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: EverloreTheme.parchment,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PictureView extends StatelessWidget {
  final String url;
  const _PictureView({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3.5,
      child: EverloreNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  final String url;
  const _VideoPlayerView({required this.url});

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _retry() {
    _controller?.dispose();
    _controller = null;
    setState(() {
      _initialized = false;
      _failed = false;
    });
    _initVideo();
  }

  void _initVideo() {
    if (widget.url.isNotEmpty) {
      final uri = Uri.tryParse(widget.url);
      if (uri != null) {
        _controller = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller?.play();
            }
          }).catchError((_) {
            if (mounted) {
              setState(() => _failed = true);
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

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _muted = !_muted;
      _controller!.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _retry,
          child: Container(
            color: EverloreTheme.void0.withValues(alpha: 0.45),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    color: EverloreTheme.parchment,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to try again',
                    style: EverloreTheme.ui(size: 12, color: EverloreTheme.parchment),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: EverloreTheme.gold),
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio > 0
              ? _controller!.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              GestureDetector(
                onTap: _togglePlay,
                behavior: HitTestBehavior.opaque,
                child: AnimatedOpacity(
                  opacity: isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 48,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: EverloreTheme.parchment,
                ),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: EverloreTheme.gold,
                    bufferedColor: EverloreTheme.ash.withValues(alpha: 0.3),
                    backgroundColor: EverloreTheme.white10,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: EverloreTheme.parchment,
                ),
                onPressed: _toggleMute,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
