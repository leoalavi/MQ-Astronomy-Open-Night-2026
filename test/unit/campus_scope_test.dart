import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/services/campus_scope.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/models/campus_geometry.dart';

/// The campus scope is the single gate that keeps in-app walking directions on
/// campus. Its whole job is a boolean, so the tests are a table of real points:
/// places that ARE the event, and places that are unambiguously not.
void main() {
  const scope = CampusScope();

  group('on-campus points are in scope', () {
    // The AON venues/car parks that carry real coordinates. If any of these
    // fell out of scope, its Directions button would wrongly refuse to route.
    const onCampus = <(String, double, double)>[
      ('campus centre', -33.77379, 151.11459),
      ('West 5 car park', -33.773501, 151.109232),
      ('South 2 car park', -33.776533, 151.114171),
      // The origin the google-nav widget tests use — ~36 m NORTH of the printed
      // map crop. A real visitor can stand here; the pad is exactly why it counts.
      ('northern campus edge', -33.77, 151.11),
    ];

    for (final (name, lat, lng) in onCampus) {
      test('$name is on campus', () {
        expect(scope.contains(lat, lng), isTrue, reason: '$name should be in scope');
      });
    }

    test('the car parks that have coordinates are all in scope', () {
      for (final p in ParkingData.all.where((p) => p.hasCoordinates)) {
        expect(scope.contains(p.latitude!, p.longitude!), isTrue,
            reason: '${p.name} routes as a destination, so must be in scope');
      }
    });
  });

  group('off-campus points are rejected', () {
    // Arbitrary Sydney locations — the exact thing the gate exists to block.
    const offCampus = <(String, double, double)>[
      ('Sydney Opera House', -33.8568, 151.2153),
      ('Sydney Airport', -33.9399, 151.1753),
      ('Parramatta', -33.8150, 151.0000),
      ('~2 km north of campus', -33.752, 151.115),
    ];

    for (final (name, lat, lng) in offCampus) {
      test('$name is NOT on campus', () {
        expect(scope.contains(lat, lng), isFalse, reason: '$name should be out of scope');
      });
    }

    test('a non-finite fix is out of scope, not a crash', () {
      expect(scope.contains(double.nan, 151.11), isFalse);
      expect(scope.contains(-33.77, double.infinity), isFalse);
    });
  });

  group('the boundary tracks the official basemap (drift guard)', () {
    // The scope rectangle mirrors CampusProjection's georeference domain. We
    // cannot read its private constants, so we tie the two behaviourally: a
    // point the projection accepts is on campus, and a point it rejects (the
    // CBD) is off campus. If someone re-georeferenced the map to a different
    // extent, or moved the scope box, these diverge and this fails.
    const p = CampusProjection();
    GpsPoint gps(double lat, double lng) => GpsPoint(LatLng(lat, lng));

    test('the campus centre both projects and is in scope', () {
      expect(p.canProject(gps(-33.77379, 151.11459)), isTrue);
      expect(scope.contains(-33.77379, 151.11459), isTrue);
    });

    test('the CBD neither projects nor is in scope', () {
      expect(p.canProject(gps(-33.8568, 151.2153)), isFalse);
      expect(scope.contains(-33.8568, 151.2153), isFalse);
    });
  });
}
