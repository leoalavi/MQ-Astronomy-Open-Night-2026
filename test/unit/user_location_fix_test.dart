import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';

void main() {
  test('accepts a valid fix; low-accuracy threshold at 200m', () {
    final ok = UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 12);
    expect(ok.isLowAccuracy, isFalse);
    expect(
        UserLocationFix(position: const LatLng(-33.77, 151.11), accuracyMeters: 250)
            .isLowAccuracy,
        isTrue);
  });

  test('rejects impossible coords, NaN/infinity, and non-positive accuracy', () {
    UserLocationFix bad(double lat, double lng, double acc) =>
        UserLocationFix(position: LatLng(lat, lng), accuracyMeters: acc);
    expect(() => bad(200, 0, 5), throwsArgumentError); // lat > 90
    expect(() => bad(-33.77, 151.11, 0), throwsArgumentError); // acc <= 0
    expect(() => bad(-33.77, 151.11, -1), throwsArgumentError);
    expect(() => bad(double.nan, 151.11, 5), throwsArgumentError);
    expect(() => bad(-33.77, double.infinity, 5), throwsArgumentError);
    expect(() => bad(-33.77, 151.11, double.nan), throwsArgumentError);
    expect(() => bad(-33.77, 151.11, double.infinity), throwsArgumentError);
  });
}
