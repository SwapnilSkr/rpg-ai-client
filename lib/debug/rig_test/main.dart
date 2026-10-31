// Throwaway entry point for the 2D character rig test (plan:
// everlore-docs/phases/rig-test.md). Run it on its own:
//
//   flutter run -t lib/debug/rig_test/main.dart
//
// Nothing in the real app imports this folder, so release builds never
// include it. The art is read at run time from the app's external files
// folder (<files>/rig/), never bundled.
import 'package:flutter/material.dart';

import 'rig_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RigTestApp());
}

class RigTestApp extends StatelessWidget {
  const RigTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rig test',
      theme: ThemeData.dark(useMaterial3: true),
      home: const RigLoadScreen(),
    );
  }
}
