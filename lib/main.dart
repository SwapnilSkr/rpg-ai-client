import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'app/theme/nexus_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EverloreApp());
}

class EverloreApp extends StatelessWidget {
  const EverloreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Everlore',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.dark,
      routerConfig: router,
    );
  }
}
