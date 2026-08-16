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
  test('truncated/dangling encoding does not throw (returns what it decoded)', () {
    // a trailing chunk with the continuation bit set but no following byte
    expect(() => decodePolyline('_p~iF~ps|U_ulL'), returnsNormally);
  });
}
