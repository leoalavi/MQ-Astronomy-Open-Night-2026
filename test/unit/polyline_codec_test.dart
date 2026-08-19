import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/polyline_codec.dart';

void main() {
  test('decodes Google reference vector "_p~iF~ps|U_ulLnnqC_mqNvxq`@" — all 3 points, lat AND lng', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].$1, closeTo(38.5, 1e-5));
    expect(pts[0].$2, closeTo(-120.2, 1e-5));
    expect(pts[1].$1, closeTo(40.7, 1e-5));
    expect(pts[1].$2, closeTo(-120.95, 1e-5));
    expect(pts[2].$1, closeTo(43.252, 1e-3));
    expect(pts[2].$2, closeTo(-126.453, 1e-3)); // longitude decode covered
  });
  test('empty string → empty', () => expect(decodePolyline(''), isEmpty));
  test('truncated mid-longitude drops the incomplete pair (no spurious point)', () {
    // Full first point + a dangling second point that has a latitude delta but
    // no longitude — must decode to ONLY the complete first point, not a garbage
    // (lat, −0.00001) second point (map audit P2).
    final pts = decodePolyline('_p~iF~ps|U_ulL');
    expect(pts.length, 1);
    expect(pts[0].$1, closeTo(38.5, 1e-5));
    expect(pts[0].$2, closeTo(-120.2, 1e-5));
  });
}
