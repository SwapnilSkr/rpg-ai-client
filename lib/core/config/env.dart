import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    const compiled = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (compiled.isNotEmpty) return compiled;
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  }

  static String get wsBaseUrl {
    const compiled = String.fromEnvironment('WS_BASE_URL', defaultValue: '');
    if (compiled.isNotEmpty) return compiled;
    return dotenv.env['WS_BASE_URL'] ?? 'ws://localhost:3000';
  }
}
