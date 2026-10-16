import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../play/presentation/widgets/anchored_menu_popup.dart';

/// Shows the "Hear it · See them say it" anchored menu when a spoken line is long-pressed.
Future<void> showSpokenLineMenu({
  required BuildContext context,
  required VoidCallback onHearIt,
  required VoidCallback onSeeThemSayIt,
  Rect? anchorRect,
  double? composerTop,
}) {
  return showAnchoredMenu<void>(
    context: context,
    anchorRect: anchorRect,
    composerTop: composerTop,
    items: [
      AnchoredMenuItem(
        icon: const Icon(
          Icons.volume_up_rounded,
          color: EverloreTheme.goldGlow,
          size: 16,
        ),
        label: 'Hear it',
        onTap: onHearIt,
      ),
      AnchoredMenuItem(
        icon: const Icon(
          Icons.videocam_outlined,
          color: EverloreTheme.cyanBright,
          size: 16,
        ),
        label: 'See them say it',
        onTap: onSeeThemSayIt,
      ),
    ],
  );
}

