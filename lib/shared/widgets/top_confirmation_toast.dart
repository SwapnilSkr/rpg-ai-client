import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

/// Shows a brief acknowledgement above the app content without covering the
/// composer or intercepting touch input.
void showTopConfirmationToast(
  BuildContext context, {
  required IconData icon,
  required String message,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      top: MediaQuery.paddingOf(overlayContext).top + 20,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: EverloreTheme.void3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EverloreTheme.gold.withValues(alpha: 0.42),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: EverloreTheme.gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: EverloreTheme.ui(
                            size: 13,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 3)).then((_) {
    if (entry.mounted) entry.remove();
  });
}
