import 'package:flutter/material.dart';
import '../../../../core/telemetry/telemetry.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_sheet.dart';
import '../../../../shared/widgets/neu.dart';
import '../../models/keepsake_item.dart';
import 'keepsake_caption.dart';
import 'keepsake_faded_tile.dart';
import 'keepsake_format.dart';

/// A vertical feed post representing one Keepsake (§3.1).
class KeepsakeFeedPost extends StatefulWidget {
  final KeepsakeItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isAutoplayEnabled;

  const KeepsakeFeedPost({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRemove,
    this.isAutoplayEnabled = true,
  });

  @override
  State<KeepsakeFeedPost> createState() => _KeepsakeFeedPostState();
}

class _KeepsakeFeedPostState extends State<KeepsakeFeedPost> {
  bool _expanded = false;

  void _confirmRemove() {
    showEverloreSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.crimson.withValues(alpha: 0.15),
                border: Border.all(
                  color: EverloreTheme.crimson.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: EverloreTheme.crimson,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove from Keepsakes',
              style: EverloreTheme.serifDisplay(
                size: 18,
                color: EverloreTheme.parchment,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This hides this piece from your Keepsakes. It stays in your story.',
              textAlign: TextAlign.center,
              style: EverloreTheme.ui(
                size: 13.5,
                color: EverloreTheme.ash,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    label: 'Cancel',
                    primary: false,
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeuButton(
                    label: 'Remove',
                    primary: true,
                    accent: EverloreTheme.crimson,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onRemove();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _returnToMoment() {
    final target = keepsakeMomentRoute(widget.item);
    if (target == null) return;
    context.push(target);
  }

  Widget _buildHeader() {
    final world = widget.item.world;
    final isWorldRemoved = world == null;
    final worldTitle = keepsakeWorldTitle(world);
    final coverUrl = world?.coverUrl;
    final saveLabel = widget.item.saveLabel;
    final relativeTime = formatRelativeTime(widget.item.createdAt);

    final subtext = (saveLabel != null && saveLabel.isNotEmpty)
        ? '$saveLabel · $relativeTime'
        : relativeTime;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (!isWorldRemoved && widget.item.instanceId != null)
          ? () => context.push('/play/${widget.item.instanceId}')
          : null,
      child: Row(
        children: [
          // Crest
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EverloreTheme.void3,
              border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.35),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isWorldRemoved
                ? const Icon(Icons.auto_stories_outlined, color: EverloreTheme.ash, size: 16)
                : (coverUrl != null && coverUrl.isNotEmpty
                    ? EverloreNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: const DecoratedBox(
                          decoration: BoxDecoration(color: EverloreTheme.void3),
                        ),
                        errorWidget: _buildMonogram(worldTitle),
                      )
                    : _buildMonogram(worldTitle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  worldTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 14,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 11.5,
                    color: EverloreTheme.ash,
                  ),
                ),
              ],
            ),
          ),
          // More menu
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: EverloreTheme.ash, size: 20),
            onPressed: () {
              Telemetry.instance.sheet('keepsake_options');
              showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (modalCtx) => Container(
                  decoration: const BoxDecoration(
                    color: EverloreTheme.void2,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(0x33D8B878))),
                  ),
                  child: SheetFrame(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Icon(Icons.hide_image_outlined, color: EverloreTheme.ash),
                            title: Text(
                              'Remove from Keepsakes',
                              style: EverloreTheme.ui(size: 15, color: EverloreTheme.parchment),
                            ),
                            onTap: () {
                              Navigator.pop(modalCtx);
                              _confirmRemove();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonogram(String title) {
    final letter = title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : 'E';
    return Center(
      child: Text(
        letter,
        style: EverloreTheme.serifDisplay(
          size: 14,
          color: EverloreTheme.gold,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPiece(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTap: widget.onTap,
            child: widget.item.isVideo
                ? _FilmPiece(
                    item: widget.item,
                    isAutoplayEnabled: widget.isAutoplayEnabled,
                  )
                : _PicturePiece(url: widget.item.url),
          ),
        ),
      ),
    );
  }

  Widget _buildCaption() {
    final excerpt = widget.item.excerpt;
    final speakerName = widget.item.speakerName;
    final isLineFilm = widget.item.isLineFilm;

    if (excerpt == null || excerpt.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final baseStyle = EverloreTheme.aiText.copyWith(
      fontSize: 15,
      height: 1.45,
    );
    final spans = keepsakeCaptionSpans(
      widget.item,
      fontSize: 15,
      height: 1.45,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLineFilm && speakerName != null && speakerName.isNotEmpty) ...[
            Text(
              speakerName.toUpperCase(),
              style: EverloreTheme.ui(
                size: 10.5,
                weight: FontWeight.w800,
                color: EverloreTheme.goldDim,
                spacing: 1.2,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text.rich(
            TextSpan(style: baseStyle, children: spans),
            style: baseStyle,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (!_expanded && excerpt.length > 140)
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'more',
                  style: EverloreTheme.ui(
                    size: 12,
                    color: EverloreTheme.goldDim,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final canReturn = widget.item.world != null && widget.item.instanceId != null;

    if (!canReturn) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _returnToMoment,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: EverloreTheme.void3,
                    border: Border.all(
                      color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: EverloreTheme.gold,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Return to this moment',
                        style: EverloreTheme.ui(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildPiece(context),
          _buildCaption(),
          _buildActions(),
        ],
      ),
    );
  }
}

class _PicturePiece extends StatelessWidget {
  final String url;
  const _PicturePiece({required this.url});

  @override
  Widget build(BuildContext context) {
    return EverloreNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: const DecoratedBox(
        decoration: BoxDecoration(color: EverloreTheme.void2),
      ),
      errorWidget: const KeepsakeFadedTile(),
    );
  }
}

class _FilmPiece extends StatefulWidget {
  final KeepsakeItem item;
  final bool isAutoplayEnabled;

  const _FilmPiece({
    required this.item,
    required this.isAutoplayEnabled,
  });

  @override
  State<_FilmPiece> createState() => _FilmPieceState();
}

class _FilmPieceState extends State<_FilmPiece> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playbackFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo({bool force = false}) {
    final url = widget.item.url;
    if (url.isNotEmpty && (widget.isAutoplayEnabled || force)) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        _controller = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller?.setVolume(0.0);
              _controller?.setLooping(true);
              _controller?.play();
            }
          }).catchError((_) {
            if (mounted) {
              setState(() => _playbackFailed = true);
            }
          });
      }
    }
  }

  void _retry() {
    _controller?.dispose();
    _controller = null;
    setState(() {
      _playbackFailed = false;
      _initialized = false;
    });
    _initVideo(force: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = widget.item.posterUrl;
    final durationText = formatDuration(widget.item.durationMs);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or poster
        if (_controller != null && _initialized && !_playbackFailed)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (posterUrl != null && posterUrl.isNotEmpty)
          EverloreNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            errorWidget: const KeepsakeFadedTile(),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF241F1A), Color(0xFF141210)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.play_arrow_rounded, color: EverloreTheme.parchment, size: 48),
            ),
          ),

        // Failed to play overlay (§3.5)
        if (_playbackFailed)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _retry,
            child: Container(
              color: EverloreTheme.void0.withValues(alpha: 0.45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: EverloreTheme.parchment, size: 28),
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

        // Non-autoplay play glyph
        if (!widget.isAutoplayEnabled && !_playbackFailed && !_initialized)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EverloreTheme.void0.withValues(alpha: 0.45),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: EverloreTheme.parchment, size: 36),
            ),
          ),

        // Duration chip
        if (durationText.isNotEmpty)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: EverloreTheme.void0.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                durationText,
                style: EverloreTheme.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  color: EverloreTheme.parchment,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
