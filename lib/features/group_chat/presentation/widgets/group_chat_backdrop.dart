import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_network_image.dart';

/// Top, middle and bottom alpha for the vertical readability scrim gradient.
/// Named constants for tuning the atmospheric balance on device.
const double kGroupBackdropScrimTopAlpha = 0.72;
const double kGroupBackdropScrimMidAlpha = 0.60;
const double kGroupBackdropScrimBottomAlpha = 0.86;

/// Chrome (app bar and composer) alpha allowing the backdrop to show through.
const double kGroupChromeAlpha = 0.72;

/// Full-bleed atmospheric backdrop for group chat rooms and direct threads.
///
/// Draws remote artwork with [BoxFit.cover] under a vertical readability scrim.
/// When the URL is empty or the remote image fails to load, renders flat
/// [EverloreTheme.void1] with no broken-image icon. Loading states also render
/// [EverloreTheme.void1] rather than a shimmer placeholder.
class GroupChatBackdrop extends StatelessWidget {
  final String? imageUrl;
  final Alignment alignment;

  const GroupChatBackdrop({
    super.key,
    this.imageUrl,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: EverloreTheme.void1);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: EverloreNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: alignment,
            memCacheWidth: 1440,
            placeholder: const ColoredBox(color: EverloreTheme.void1),
            errorWidget: const ColoredBox(color: EverloreTheme.void1),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimTopAlpha),
                  EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimMidAlpha),
                  EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimBottomAlpha),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
