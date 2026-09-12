import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/polyline_codec.dart';
import 'package:aon2026/services/web_route_payload.dart';

const courtyardRoute = 'xlcmEwiiy[AcCrBANSDAEyD';
const courtyardPoints = [
  (-33.77373, 151.1134),
  (-33.77372, 151.11406),
  (-33.77430, 151.11407),
  (-33.77438, 151.11417),
  (-33.77441, 151.11418),
  (-33.77438, 151.11511),
];

void main() {
  test('227 m Google response decodes all six signed campus points', () {
    expect(decodePolyline(courtyardRoute), courtyardPoints);
  });
  test('route tuples serialize losslessly to lat/lng literals', () {
    final payload = webRoutePayload(
      origin: (-33.7737, 151.1134),
      destination: (-33.7746267, 151.1151193),
      route: decodePolyline(courtyardRoute),
    );
    expect(payload['origin'], {'lat': -33.7737, 'lng': 151.1134});
    expect(payload['destination'], {'lat': -33.7746267, 'lng': 151.1151193});
    expect(payload['polyline'], [
      for (final p in courtyardPoints) {'lat': p.$1, 'lng': p.$2},
    ]);
  });
}
