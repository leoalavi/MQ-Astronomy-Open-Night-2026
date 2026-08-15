import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';

void main() {
  test('geometry wrappers hold their value without conflation', () {
    expect(GpsPoint(const LatLng(-33.77, 151.11)).value.latitude, -33.77);
    expect(CampusMapPoint(const LatLng(42.5, 60.1)).value.longitude, 60.1);
  });
}
