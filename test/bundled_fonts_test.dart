import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every weight/style the app asks `google_fonts` for. A new weight used
/// without its file here would render in a fallback font offline, so add the
/// file under assets/google_fonts and list it below.
///
/// Cinzel: SemiBold (serifDisplay default, screenTitle, cardTitle), Bold
/// (displayTitle, onboarding/auth/splash titles), ExtraBold (welcome title).
/// EB Garamond: Regular (aiText and all prose), Italic (welcome tagline).
const _bundled = [
  'Cinzel-SemiBold.ttf',
  'Cinzel-Bold.ttf',
  'Cinzel-ExtraBold.ttf',
  'EBGaramond-Regular.ttf',
  'EBGaramond-Italic.ttf',
  'Cinzel-OFL.txt',
  'EBGaramond-OFL.txt',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final file in _bundled) {
    test('$file is in the asset bundle', () async {
      final data = await rootBundle.load('assets/google_fonts/$file');
      expect(data.lengthInBytes, greaterThan(1000));
    });
  }
}
