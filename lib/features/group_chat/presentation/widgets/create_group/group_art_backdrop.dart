import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';

/// Backdrop artwork for group creation and editing flows.
/// Displays forge-group-cover.webp (or group cover when available)
/// with a 3-stop void1 gradient scrim that fades out smoothly.
class GroupArtBackdrop extends StatelessWidget {
  final String? coverUrl;
  final double height;
  final bool positioned;

  const GroupArtBackdrop({
    super.key,
    this.coverUrl,
    this.height = 360,
    this.positioned = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null && coverUrl!.isNotEmpty)
          EverloreNetworkImage(
            imageUrl: coverUrl!,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.2),
            placeholder: _assetImage(),
            errorWidget: _assetImage(),
          )
        else
          _assetImage(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void1.withValues(alpha: 0.35),
                  EverloreTheme.void1.withValues(alpha: 0.62),
                  EverloreTheme.void1,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );

    if (positioned) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: height,
        child: content,
      );
    }

    return SizedBox(height: height, width: double.infinity, child: content);
  }

  static Widget _assetImage() => Image.asset(
    'assets/art/forge-group-cover.webp',
    fit: BoxFit.cover,
    alignment: const Alignment(0, -0.2),
    cacheWidth: 1080,
  );
}
