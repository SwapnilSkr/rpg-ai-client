import 'package:flutter/material.dart';

/// Unfocuses the primary focus (dismissing the soft keyboard) when the user
/// taps outside an interactive control.
///
/// Mount once at the app root via [MaterialApp.builder].
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Let taps reach buttons, fields, etc. first; still receive taps on
      // "empty" scaffold/scroll areas that do not handle gestures themselves.
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
