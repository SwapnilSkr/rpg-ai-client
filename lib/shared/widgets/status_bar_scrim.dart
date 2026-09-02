import 'package:flutter/material.dart';

/// A short gradient behind the status bar.
///
/// Screens with a hero image use a transparent app bar so the art reads at
/// full strength — which also means scrolled prose passes straight under the
/// clock and the battery with nothing behind it. This restores the separation
/// without putting a solid bar over the artwork.
///
/// Place it in the Stack *after* the scrolling content, so it paints on top.
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.paddingOf(context).top + 10,
      child: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD90A0807), Color(0x000A0807)],
            ),
          ),
        ),
      ),
    );
  }
}
