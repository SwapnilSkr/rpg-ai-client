import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EverloreApp());
    expect(find.text('Everlore'), findsAny);
  });
}
