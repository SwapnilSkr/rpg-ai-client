import 'package:everlore/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what a release build is allowed to connect to', () {
    // The Play listing declares that everything this app sends is encrypted
    // in transit. That is only honest if a shipping binary cannot be pointed
    // at a plaintext endpoint, so this is the check that backs the claim.
    test('encrypted schemes are accepted', () {
      expect(AppConfig.isSecureEndpoint('https://api.everloreapp.com'), isTrue);
      expect(AppConfig.isSecureEndpoint('wss://api.everloreapp.com/ws/play'), isTrue);
      expect(AppConfig.isSecureEndpoint('HTTPS://api.everloreapp.com'), isTrue);
    });

    test('plaintext schemes are rejected', () {
      // The two the dev flow uses, which are exactly what a forgotten
      // --dart-define would leave baked into a release bundle.
      expect(AppConfig.isSecureEndpoint('http://192.168.0.100:8081'), isFalse);
      expect(AppConfig.isSecureEndpoint('ws://192.168.0.100:8081'), isFalse);
      expect(AppConfig.isSecureEndpoint('http://localhost:3000'), isFalse);
    });

    test('a malformed or schemeless value is not mistaken for secure', () {
      expect(AppConfig.isSecureEndpoint('api.everloreapp.com'), isFalse);
      expect(AppConfig.isSecureEndpoint(''), isFalse);
      expect(AppConfig.isSecureEndpoint('://'), isFalse);
    });

    test('a scheme that merely starts with an encrypted one is rejected', () {
      // Guards the check against ever being loosened to a prefix match.
      expect(AppConfig.isSecureEndpoint('wssx://api.everloreapp.com'), isFalse);
      expect(AppConfig.isSecureEndpoint('httpsx://api.everloreapp.com'), isFalse);
    });
  });
}
