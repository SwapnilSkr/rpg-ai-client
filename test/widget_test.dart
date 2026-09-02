import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EverloreApp());

    // The splash animates the wordmark one LETTER at a time, so there is no
    // single "Everlore" Text to find — asserting on that string made this test
    // a tripwire for the branding rather than for booting. What "boots without
    // crashing" actually means is that the first frame built and the app is
    // mounted, so assert exactly that.
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
