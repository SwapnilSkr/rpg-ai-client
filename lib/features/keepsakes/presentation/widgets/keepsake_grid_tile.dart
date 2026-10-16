import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../models/keepsake_item.dart';
import 'keepsake_faded_tile.dart';
import 'keepsake_feed_post.dart' show formatDuration;

/// One 9:16 tile in the Keepsakes grid (§3.2, §3.3).
class KeepsakeGridTile extends StatelessWidget {
  final KeepsakeItem item;
  final VoidCallback onTap;

  const KeepsakeGridTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFace = item.isPortrait;
    final isFilm = item.isVideo;
    final imageUrl = (isFilm && item.posterUrl != null && item.posterUrl!.isNotEmpty)
        ? item.posterUrl!
        : item.url;
    final durationText = formatDuration(item.durationMs);
    final characterName = item.character?.name ?? item.speakerName ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media image or faded tile
              EverloreNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: const DecoratedBox(
                  decoration: BoxDecoration(color: EverloreTheme.void2),
                ),
                errorWidget: const KeepsakeFadedTile(),
              ),

              // Bottom subtle dark vignette for chips/text
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: isFace ? 54 : 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        EverloreTheme.void0.withValues(alpha: 0.82),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Film: play glyph & duration
              if (isFilm) ...[
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EverloreTheme.void0.withValues(alpha: 0.6),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 13,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      if (durationText.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          durationText,
                          style: EverloreTheme.ui(
                            size: 10,
                            weight: FontWeight.w600,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Face: character name (max 2 lines, centered)
              if (isFace && characterName.isNotEmpty) ...[
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(
                    characterName,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(
                      size: 11,
                      weight: FontWeight.w700,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
