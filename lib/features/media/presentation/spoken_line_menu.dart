import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_sheet.dart';

/// Shows the "Hear it · See them say it" menu when a spoken line is long-pressed.
Future<void> showSpokenLineMenu({
  required BuildContext context,
  required VoidCallback onHearIt,
  required VoidCallback onSeeThemSayIt,
}) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: EverloreTheme.void2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrabHandle(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.volume_up_rounded,
              color: EverloreTheme.goldGlow,
            ),
            title: Text(
              'Hear it',
              style: EverloreTheme.ui(
                size: 15,
                color: EverloreTheme.parchment,
              ),
            ),
            subtitle: Text(
              'Listen to this line spoken in character.',
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              onHearIt();
            },
          ),
          const Divider(color: EverloreTheme.white10, height: 1),
          ListTile(
            leading: const Icon(
              Icons.videocam_outlined,
              color: EverloreTheme.cyanBright,
            ),
            title: Text(
              'See them say it',
              style: EverloreTheme.ui(
                size: 15,
                color: EverloreTheme.parchment,
              ),
            ),
            subtitle: Text(
              'Watch the character speak these words.',
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              onSeeThemSayIt();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
