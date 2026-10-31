import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/features/play/presentation/play_screen.dart';

void main() {
  test('starter with an onboarding name adopts it', () {
    expect(starterAutoName(starter: true, playerName: '  Mira '), 'Mira');
  });

  test('starter without a usable name opens the sheet', () {
    expect(starterAutoName(starter: true, playerName: ''), isNull);
    expect(starterAutoName(starter: true, playerName: '   '), isNull);
    expect(starterAutoName(starter: true, playerName: null), isNull);
  });

  test('a non-starter story always opens the sheet', () {
    expect(starterAutoName(starter: false, playerName: 'Mira'), isNull);
  });
}
