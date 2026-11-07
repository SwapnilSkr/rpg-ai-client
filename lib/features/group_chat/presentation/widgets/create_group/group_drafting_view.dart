import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';

/// A calm full-screen wait while the server writes the group.
///
/// "Writing your group. This takes about a minute."
class GroupDraftingView extends StatelessWidget {
  const GroupDraftingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: EverloreTheme.gold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Writing your group. This takes about a minute.',
              textAlign: TextAlign.center,
              style: EverloreTheme.aiText.copyWith(
                fontSize: 16,
                color: EverloreTheme.parchment,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
