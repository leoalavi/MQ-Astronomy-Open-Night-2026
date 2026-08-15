import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

/// Every curated venue/parking coordinate MUST project onto the campus map —
/// the new map silently skips null projections, so this makes a vanishing
/// curated marker impossible to miss. Deliberately-null records (e.g. west-6)
/// carry no coordinate and are excluded, not allowlisted.
void main() {
  const proj = CampusProjection();
  test('every venue/parking coordinate projects onto the campus map', () {
    final coords = <(String, double, double)>[
      for (final v in VenuesData.all)
        if (v.latitude != null && v.longitude != null)
          (v.id, v.latitude!, v.longitude!),
      for (final p in ParkingData.all)
        if (p.latitude != null && p.longitude != null)
          (p.id, p.latitude!, p.longitude!),
    ];
    expect(coords, isNotEmpty);
    final unprojectable = [
      for (final (id, lat, lng) in coords)
        if (!proj.canProject(GpsPoint(LatLng(lat, lng)))) id,
    ];
    expect(unprojectable, isEmpty, reason: 'unprojectable: $unprojectable');
  });
}
