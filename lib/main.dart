import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_routes.dart';
import 'app/theme/nexus_theme.dart';
import 'shared/widgets/dismiss_keyboard.dart';
import 'core/network/ws_manager.dart';
import 'core/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {}
  runApp(const EverloreApp());
}

class EverloreApp extends StatefulWidget {
  const EverloreApp({super.key});

  @override
  State<EverloreApp> createState() => _EverloreAppState();
}

class _EverloreAppState extends State<EverloreApp> {
  StreamSubscription<void>? _accountDeletedSub;

  @override
  void initState() {
    super.initState();
    // If the server reports this account was deleted (e.g. from another device),
    // drop the live session and bounce to auth instead of running on against a
    // dead account until the next request 401s.
    _accountDeletedSub = WsManager().onAccountDeleted.listen((_) async {
      await AuthService.logout();
      router.go('/auth');
    });
  }

  @override
  void dispose() {
    _accountDeletedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Everlore',
      debugShowCheckedModeBanner: false,
      theme: NexusTheme.dark,
      routerConfig: router,
      builder: (context, child) =>
          DismissKeyboard(child: child ?? const SizedBox.shrink()),
    );
  }
}
