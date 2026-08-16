import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/maps_url.dart';

void main() {
  test('keyless walking directions URL: https host, /maps/dir/, walking, no origin', () {
    final u = buildWalkingMapsUrl(destLat: -33.78, destLng: 151.12);
    expect(u.scheme, 'https');
    expect(u.host, 'www.google.com');
    expect(u.path, '/maps/dir/');
    expect(u.queryParameters['api'], '1');
    expect(u.queryParameters['destination'], '-33.78,151.12');
    expect(u.queryParameters['travelmode'], 'walking');
    expect(u.queryParameters.containsKey('origin'), isFalse); // Google uses device location
  });
}
