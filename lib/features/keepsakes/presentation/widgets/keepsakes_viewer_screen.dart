import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/neu.dart';
import '../../../chronicle/presentation/character_memory_screen.dart';
import '../../models/keepsake_item.dart';
import 'keepsake_caption.dart';
import 'keepsake_faded_tile.dart';
import 'keepsake_format.dart';

/// Fullscreen vertical reel viewer for Keepsakes (§3.4).
class KeepsakesViewerScreen extends StatefulWidget {
  final List<KeepsakeItem> items;
  final int initialIndex;

  const KeepsakesViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<KeepsakeItem> items,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => KeepsakesViewerScreen(
          items: items,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, anim, _, child) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          if (reduced) {
            return FadeTransition(opacity: anim, child: child);
          }
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<KeepsakesViewerScreen> createState() => _KeepsakesViewerScreenState();
}

class _KeepsakesViewerScreenState extends State<KeepsakesViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNextPieces(_currentIndex);
  }

  void _precacheNextPieces(int index) {
    for (var i = 1; i <= 2; i++) {
      final target = index + i;
      if (target < widget.items.length) {
        final item = widget.items[target];
        final url = item.isVideo ? (item.posterUrl ?? item.url) : item.url;
        if (url.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
        }
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _precacheNextPieces(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: EverloreTheme.void0,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: EverloreTheme.parchment),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _ViewerPiece(
                item: item,
                isActive: index == _currentIndex,
                isWide: isWide,
              );
            },
          ),
          // Top controls (Close button)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EverloreTheme.void0.withValues(alpha: 0.45),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: EverloreTheme.parchment,
                      size: 24,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerPiece extends StatefulWidget {
  final KeepsakeItem item;
  final bool isActive;
  final bool isWide;

  const _ViewerPiece({
    required this.item,
    required this.isActive,
    required this.isWide,
  });

  @override
  State<_ViewerPiece> createState() => _ViewerPieceState();
}

class _ViewerPieceState extends State<_ViewerPiece>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isPlaying = false;
  AnimationController? _kenBurnsController;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initVideo();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _kenBurnsController?.stop();
    } else if (!widget.item.isVideo && _kenBurnsController == null) {
      _initKenBurns();
    }
  }

  void _initKenBurns() {
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  void _initVideo() {
    final url = widget.item.url;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        _videoController = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (mounted) {
              if (widget.isActive) {
                // Sound on in the viewer, and loop
                _videoController?.setVolume(1.0);
                _videoController?.setLooping(true);
                _videoController?.play();
              }
              _videoController?.addListener(_onVideoControllerUpdate);
              setState(() {
                _videoInitialized = true;
                _isPlaying = _videoController?.value.isPlaying ?? false;
              });
            }
          }).catchError((_) {});
      }
    }
  }

  void _onVideoControllerUpdate() {
    if (!mounted || _videoController == null) return;
    final playing = _videoController!.value.isPlaying;
    if (_isPlaying != playing) {
      setState(() => _isPlaying = playing);
    }
  }

  @override
  void didUpdateWidget(covariant _ViewerPiece oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.isVideo && _videoController != null && _videoInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _videoController?.setVolume(1.0);
        _videoController?.play();
        setState(() => _isPlaying = _videoController?.value.isPlaying ?? true);
      } else if (!widget.isActive && oldWidget.isActive) {
        _videoController?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.dispose();
    _kenBurnsController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    setState(() {
      _isPlaying = _videoController!.value.isPlaying;
    });
  }

  void _onPrimaryAction() {
    if (widget.item.isPortrait) {
      // Faces action is "Open their card" (§3.3)
      _showCharacterCardSheet();
    } else {
      // "Return to this moment" (§3.1, §3.4)
      final target = keepsakeMomentRoute(widget.item);
      if (target == null) return;

      Navigator.of(context).pop(); // close viewer
      context.push(target);
    }
  }

  void _showCharacterCardSheet() {
    final char = widget.item.character;
    final instanceId = widget.item.instanceId;
    if (char == null || instanceId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterMemoryScreen(
          instanceId: instanceId,
          characterId: char.id,
          characterName: char.name,
        ),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    if (widget.item.isVideo) {
      if (_videoController != null && _videoInitialized) {
        return GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              if (!_isPlaying)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EverloreTheme.void0.withValues(alpha: 0.45),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 48,
                    color: EverloreTheme.parchment,
                  ),
                ),
            ],
          ),
        );
      }
      final poster = widget.item.posterUrl;
      return (poster != null && poster.isNotEmpty)
          ? EverloreNetworkImage(
              imageUrl: poster,
              fit: BoxFit.cover,
              placeholder: const DecoratedBox(
                decoration: BoxDecoration(color: EverloreTheme.void1),
              ),
              errorWidget: const KeepsakeFadedTile(),
            )
          : const KeepsakeFadedTile();
    }

    final picture = EverloreNetworkImage(
      imageUrl: widget.item.url,
      fit: BoxFit.cover,
      placeholder: const DecoratedBox(
        decoration: BoxDecoration(color: EverloreTheme.void1),
      ),
      errorWidget: const KeepsakeFadedTile(),
    );

    // Picture with subtle Ken Burns drift
    if (reducedMotion || _kenBurnsController == null) {
      return picture;
    }

    return AnimatedBuilder(
      animation: _kenBurnsController!,
      builder: (context, child) {
        // ≤ 4% scale
        final scale = 1.0 + 0.04 * _kenBurnsController!.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: picture,
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final item = widget.item;
    final world = item.world;
    final isWorldRemoved = world == null;
    final worldTitle = keepsakeWorldTitle(world);
    final isFace = item.isPortrait;
    final hasCharacter =
        item.character != null && item.character!.id.isNotEmpty && item.instanceId != null;
    final primaryActionLabel = isFace ? 'Open their card' : 'Return to this moment';
    final canPerformAction =
        isFace ? hasCharacter : (!isWorldRemoved && item.instanceId != null);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              EverloreTheme.void0.withValues(alpha: 0.92),
              EverloreTheme.void0.withValues(alpha: 0.65),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.4)),
                      color: EverloreTheme.void3,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (world?.coverUrl != null && world!.coverUrl!.isNotEmpty)
                        ? EverloreNetworkImage(
                            imageUrl: world.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: const DecoratedBox(
                              decoration: BoxDecoration(color: EverloreTheme.void3),
                            ),
                          )
                        : Center(
                            child: Text(
                              worldTitle.isNotEmpty ? worldTitle[0].toUpperCase() : 'E',
                              style: EverloreTheme.serifDisplay(size: 13, color: EverloreTheme.gold),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worldTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 14,
                            weight: FontWeight.w700,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                        if (item.saveLabel != null && item.saveLabel!.isNotEmpty)
                          Text(
                            '${item.saveLabel} · ${formatRelativeTime(item.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EverloreTheme.ui(size: 11.5, color: EverloreTheme.ash),
                          )
                        else
                          Text(
                            formatRelativeTime(item.createdAt),
                            style: EverloreTheme.ui(size: 11.5, color: EverloreTheme.ash),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Caption / excerpt
              if (item.excerpt != null && item.excerpt!.trim().isNotEmpty) ...[
                if (item.isLineFilm && item.speakerName != null) ...[
                  Text(
                    item.speakerName!.toUpperCase(),
                    style: EverloreTheme.ui(
                      size: 10.5,
                      weight: FontWeight.w800,
                      color: EverloreTheme.goldDim,
                      spacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Builder(
                  builder: (context) {
                    final baseStyle = EverloreTheme.aiText.copyWith(
                      fontSize: 14.5,
                      height: 1.4,
                    );
                    final spans = keepsakeCaptionSpans(
                      item,
                      fontSize: 14.5,
                      height: 1.4,
                    );
                    return Text.rich(
                      TextSpan(style: baseStyle, children: spans),
                      style: baseStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Action button
              if (canPerformAction)
                NeuButton(
                  label: primaryActionLabel,
                  icon: isFace ? Icons.badge_outlined : Icons.history_rounded,
                  primary: true,
                  accent: EverloreTheme.gold,
                  onTap: _onPrimaryAction,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWide) {
      // Tablet letterboxing with blurred background of the same piece (§3.5)
      return Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Opacity(
                opacity: 0.35,
                child: widget.item.url.isNotEmpty
                    ? EverloreNetworkImage(
                        imageUrl: widget.item.url,
                        fit: BoxFit.cover,
                        placeholder: const DecoratedBox(
                          decoration: BoxDecoration(color: EverloreTheme.void1),
                        ),
                      )
                    : Container(color: EverloreTheme.void0),
              ),
            ),
          ),
          // Centered 9:16 letterbox
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMediaContent(context),
                  _buildOverlay(context),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMediaContent(context),
        _buildOverlay(context),
      ],
    );
  }
}
