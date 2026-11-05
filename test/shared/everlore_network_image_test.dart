import 'package:everlore/shared/widgets/everlore_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int? w(double mw, double mh, double dpr, {int? ew, int? eh}) => decodeWidthFor(
        maxWidth: mw,
        maxHeight: mh,
        devicePixelRatio: dpr,
        explicitWidth: ew,
        explicitHeight: eh,
      );

  test('a 38px avatar at 3x rounds up to 160', () {
    expect(w(38, 38, 3), 160);
  });
  test('a 390x844 box at 3x caps at 1440', () {
    expect(w(390, 844, 3), 1440);
  });
  test('an exact tier stays', () {
    expect(w(120, 80, 3), 360);
    expect(w(32, 32, 3), 96);
  });
  test('above the top tier caps at 1440', () {
    expect(w(2000, 100, 3), 1440);
  });
  test('the larger bounded side wins when one is unbounded', () {
    expect(w(double.infinity, 100, 2), 240);
  });
  test('fully unbounded falls back to explicit width or 1440', () {
    expect(w(double.infinity, double.infinity, 3), 1440);
    expect(w(double.infinity, double.infinity, 3, ew: 300), 300);
  });
  test('the smaller of explicit width and tier wins', () {
    expect(w(390, 844, 3, ew: 200), 200);
    expect(w(38, 38, 3, ew: 600), 160);
  });
  test('height-only callers keep their height and get no width', () {
    expect(w(38, 38, 3, eh: 300), isNull);
  });
}
