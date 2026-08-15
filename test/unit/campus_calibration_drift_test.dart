import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

/// Proves the compiled `CampusProjection` constants have not drifted from the
/// vendored MQ calibration: recomputes expected map-units straight from the
/// JSON and asserts the projector agrees. Real chain, not JSON-vs-literals.
void main() {
  test('CampusProjection agrees with the vendored MQ calibration JSON', () {
    final j = jsonDecode(
        File('docs/fixtures/campus_overlay_meta.json').readAsStringSync());
    final pb = j['pixelBounds'];
    final pw = (pb['east'] as num).toDouble();
    final ph = (pb['north'] as num).toDouble();
    final aff = j['gpsProjection']['affine'];
    final ax = (aff['x'] as List).map((e) => (e as num).toDouble()).toList();
    final ay = (aff['y'] as List).map((e) => (e as num).toDouble()).toList();
    final n = aff['normalization'];
    final minLat = (n['minLat'] as num).toDouble();
    final maxLat = (n['maxLat'] as num).toDouble();
    final minLng = (n['minLng'] as num).toDouble();
    final maxLng = (n['maxLng'] as num).toDouble();
    final scale = [1.0, pw / 170, ph / 85].reduce((a, b) => a > b ? a : b);

    LatLng expected(double lat, double lng) {
      final nLng = (lng - minLng) / (maxLng - minLng);
      final nLat = (lat - minLat) / (maxLat - minLat);
      final x = ax[0] + ax[1] * nLng + ax[2] * nLat;
      final y = ay[0] + ay[1] * nLng + ay[2] * nLat;
      return LatLng((ph - y) / scale, x / scale);
    }

    const proj = CampusProjection();
    for (final gps in const [
      LatLng(-33.7737, 151.1134), // centre
      LatLng(-33.7726489, 151.1105693), // sport/aquatic
      LatLng(-33.7768086, 151.1175848), // metro
    ]) {
      final got = proj.project(GpsPoint(gps))!;
      final exp = expected(gps.latitude, gps.longitude);
      expect(got.value.latitude, closeTo(exp.latitude, 1e-9), reason: '$gps');
      expect(got.value.longitude, closeTo(exp.longitude, 1e-9), reason: '$gps');
    }
    expect(CampusProjection.mapNorth, closeTo(ph / scale, 1e-9));
    expect(CampusProjection.mapEast, closeTo(pw / scale, 1e-9));
  });
}
