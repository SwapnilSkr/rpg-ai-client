import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_routes.dart';
import 'app/theme/nexus_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {}
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
