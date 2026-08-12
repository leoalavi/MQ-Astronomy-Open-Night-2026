import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('campus centre is ~0 m away and near', () {
    expect(MapConfig.distanceFromCampusMeters(MapConfig.campusCentre),
        lessThan(1));
    expect(MapConfig.isNearCampus(MapConfig.campusCentre), isTrue);
  });

  test('a point ~5 km away is far', () {
    // ~0.045 deg latitude ≈ 5 km.
    final far = LatLng(MapConfig.campusCentre.latitude + 0.045,
        MapConfig.campusCentre.longitude);
    expect(MapConfig.distanceFromCampusMeters(far), greaterThan(4000));
    expect(MapConfig.isNearCampus(far), isFalse);
  });

  test('radius default is the config constant (2500 m)', () {
    expect(MapConfig.locationCampusRadiusMeters, 2500);
  });
}
