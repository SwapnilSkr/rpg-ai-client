import 'package:everlore/shared/widgets/everlore_top_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compactInk', () {
    test('a balance that fits is printed as it is', () {
      expect(compactInk(0), '0');
      expect(compactInk(180), '180');
      expect(compactInk(9999), '9999');
    });

    test('a granted reserve is shortened rather than widening the pill', () {
      // The case this exists for: a grant runs to eight digits, and printing
      // it in full pushed the pill across the title beside it.
      expect(compactInk(10000), '10K');
      expect(compactInk(250000), '250K');
      expect(compactInk(1200000), '1.2M');
      expect(compactInk(100000000), '100M');
    });

    test('an unread balance shows an em dash, not a zero', () {
      // Zero means spent. Nothing loaded yet must not read as spent.
      expect(compactInk(null), '—');
    });
  });
}
