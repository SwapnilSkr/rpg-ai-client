import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';

/// Renders a mosaic layout from a list of face URLs (1 to 6 faces) in a bounded parent.
/// 1: full
/// 2: side by side
/// 3: one tall left, two stacked right
/// 4: 2x2
/// 5: 2 over 3
/// 6: 2 columns, 3 rows
/// 1 dp void0 gaps, alignment Alignment(0, -0.6).
/// With no faces: forge-group-cover.webp.
class GroupFaceMosaic extends StatelessWidget {
  final List<String> faceUrls;
  final Alignment imageAlignment;

  const GroupFaceMosaic({
    super.key,
    required this.faceUrls,
    this.imageAlignment = const Alignment(0, -0.6),
  });

  @override
  Widget build(BuildContext context) {
    final valid = faceUrls.where((u) => u.trim().isNotEmpty).toList();

    if (valid.isEmpty) {
      return Image.asset(
        'assets/art/forge-group-cover.webp',
        fit: BoxFit.cover,
        alignment: imageAlignment,
        cacheWidth: 1080,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: EverloreTheme.void0),
      child: _buildLayout(valid),
    );
  }

  Widget _buildLayout(List<String> faces) {
    final count = faces.length;

    if (count == 1) {
      return _buildTile(faces[0]);
    }

    if (count == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildTile(faces[0])),
          const SizedBox(width: 1),
          Expanded(child: _buildTile(faces[1])),
        ],
      );
    }

    if (count == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildTile(faces[0])),
          const SizedBox(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTile(faces[1])),
                const SizedBox(height: 1),
                Expanded(child: _buildTile(faces[2])),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTile(faces[0])),
                const SizedBox(width: 1),
                Expanded(child: _buildTile(faces[1])),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTile(faces[2])),
                const SizedBox(width: 1),
                Expanded(child: _buildTile(faces[3])),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTile(faces[0])),
                const SizedBox(width: 1),
                Expanded(child: _buildTile(faces[1])),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTile(faces[2])),
                const SizedBox(width: 1),
                Expanded(child: _buildTile(faces[3])),
                const SizedBox(width: 1),
                Expanded(child: _buildTile(faces[4])),
              ],
            ),
          ),
        ],
      );
    }

    // 6 or more
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTile(faces[0])),
              const SizedBox(width: 1),
              Expanded(child: _buildTile(faces[1])),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTile(faces[2])),
              const SizedBox(width: 1),
              Expanded(child: _buildTile(faces[3])),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTile(faces[4])),
              const SizedBox(width: 1),
              Expanded(child: _buildTile(faces[5])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile(String url) {
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover, alignment: imageAlignment);
    }

    return EverloreNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: imageAlignment,
      placeholder: const SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(color: EverloreTheme.void2),
        ),
      ),
      errorWidget: const SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(color: EverloreTheme.void2),
        ),
      ),
    );
  }
}
