import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/map_placement.dart';

/// Every curated venue/parking marker MUST land somewhere on the campus map —
/// the map silently skips null placements, so this makes a vanishing curated
/// marker impossible to miss. Records with no coordinate at all are excluded,
/// not allowlisted.
void main() {
  const proj = CampusProjection();
  test('every venue coordinate projects onto the campus map', () {
    final coords = <(String, double, double)>[
      for (final v in VenuesData.all)
        if (v.latitude != null && v.longitude != null)
          (v.id, v.latitude!, v.longitude!),
    ];
    expect(coords, isNotEmpty);
    final unprojectable = [
      for (final (id, lat, lng) in coords)
        if (!proj.canProject(GpsPoint(LatLng(lat, lng)))) id,
    ];
    expect(unprojectable, isEmpty, reason: 'unprojectable: $unprojectable');
  });

  test('every car park with a location places onto the campus map', () {
    // Parking uses the shared placement rule: the artwork marker if the car
    // park has one (West 6, whose GPS sits off the western crop), else the
    // GPS-affine position. Either way the pin must be non-null so it renders.
    final unplaceable = [
      for (final p in ParkingData.all)
        if (p.hasCoordinates || p.hasArtworkPin)
          if (placeParking(p, proj) == null) p.id,
    ];
    expect(unplaceable, isEmpty, reason: 'unplaceable: $unplaceable');
  });
}
