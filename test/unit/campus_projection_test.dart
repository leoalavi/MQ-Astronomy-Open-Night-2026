import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/user_location_layer.dart' show accuracyRadiusScale;

const _proj = CampusProjection();
const _centre = GpsPoint(LatLng(-33.7737, 151.1134)); // Central Courtyard

void main() {
  test('geometry wrappers hold their value without conflation', () {
    expect(GpsPoint(const LatLng(-33.77, 151.11)).value.latitude, -33.77);
    expect(CampusMapPoint(const LatLng(42.5, 60.1)).value.longitude, 60.1);
  });

  test('a campus point projects inside the map bounds', () {
    final p = _proj.project(_centre)!;
    expect(p.value.latitude, inInclusiveRange(0, CampusProjection.mapNorth));
    expect(p.value.longitude, inInclusiveRange(0, CampusProjection.mapEast));
  });

  test('reference vector: affine matches MQ published coefficients', () {
    final p = _proj.project(_centre)!;
    const minLat = -33.7772506, maxLat = -33.7703261;
    const minLng = 151.1080508, maxLng = 151.1211352;
    final nLng = (151.1134 - minLng) / (maxLng - minLng);
    final nLat = (-33.7737 - minLat) / (maxLat - minLat);
    final x = 880.374832 + 3889.927306 * nLng + 12.547607 * nLat;
    final y = 2862.069113 - 64.093654 * nLng - 2349.078357 * nLat;
    expect(p.value.longitude, closeTo(x / (3307 / 85), 1e-6));
    expect(p.value.latitude, closeTo((3307 - y) / (3307 / 85), 1e-6));
  });

  test('OFF the footprint → null (never clamps to an edge)', () {
    expect(_proj.project(const GpsPoint(LatLng(-33.90, 151.30))), isNull);
    expect(_proj.canProject(const GpsPoint(LatLng(-33.90, 151.30))), isFalse);
  });

  test('invalid GPS → null (NaN / out of range)', () {
    expect(_proj.project(GpsPoint(LatLng(double.nan, 151.11))), isNull);
    expect(_proj.project(const GpsPoint(LatLng(200, 151.11))), isNull);
  });

  test('deterministic', () {
    expect(_proj.project(_centre)!.value, _proj.project(_centre)!.value);
  });

  test('anisotropy ≤5% → average scale; >5% → conservative (larger)', () {
    expect(accuracyRadiusScale(10.0, 10.2), closeTo(10.1, 1e-9)); // ~2% → average
    expect(accuracyRadiusScale(10.0, 12.0), 12.0); // 20% → larger
  });
}
