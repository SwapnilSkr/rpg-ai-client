import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';
import 'neu.dart';

/// Confirmation dialog required before enabling mature themes.
/// Returns true if confirmed (18 or older), false otherwise.
Future<bool> showAgeConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: EverloreTheme.void0.withValues(alpha: 0.8),
    builder: (context) => const AgeConfirmDialog(),
  );
  return result ?? false;
}

class AgeConfirmDialog extends StatelessWidget {
  const AgeConfirmDialog({super.key});

  static Future<bool> show(BuildContext context) =>
      showAgeConfirmDialog(context);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EverloreTheme.void2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: EverloreTheme.goldDim.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Before you continue',
              textAlign: TextAlign.center,
              style: EverloreTheme.cardTitle.copyWith(
                fontSize: 19,
                color: EverloreTheme.parchment,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mature themes are for adults only.',
              textAlign: TextAlign.center,
              style: EverloreTheme.aiText.copyWith(
                color: EverloreTheme.ash,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            NeuButton(
              label: "I'm 18 or older",
              primary: true,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.ash,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
