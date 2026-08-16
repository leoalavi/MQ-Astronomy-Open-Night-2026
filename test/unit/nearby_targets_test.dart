import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/nearby_targets.dart';

// Campus-ish anchor.
const _fix = LatLng(-33.7737, 151.1134);

Venue _v(String id,
        {double? lat, double? lng, DataConfidence c = DataConfidence.confirmed}) =>
    Venue(
        id: id,
        name: id,
        category: VenueCategory.other,
        latitude: lat,
        longitude: lng,
        coordinateConfidence: c);

Building _b(String id,
        {required double lat, required double lng, String? name, String? code}) =>
    Building(
        id: id,
        code: code ?? id,
        name: name ?? id,
        category: BuildingCategory.academic,
        latitude: lat,
        longitude: lng,
        campusX: 1,
        campusY: 1);

void main() {
  test('routingLatLngOf: venue/building present, null when no coords', () {
    expect(routingLatLngOf(VenueEntry(_v('a', lat: -33.77, lng: 151.11))), isNotNull);
    expect(routingLatLngOf(VenueEntry(_v('b'))), isNull); // null coords
    expect(routingLatLngOf(BuildingEntry(_b('c', lat: -33.77, lng: 151.11))), isNotNull);
  });

  test('confidenceOf: venue carries its confidence; building = confirmed', () {
    expect(
        confidenceOf(VenueEntry(
            _v('a', lat: -33.77, lng: 151.11, c: DataConfidence.placeholder))),
        DataConfidence.placeholder);
    expect(confidenceOf(BuildingEntry(_b('c', lat: -33.77, lng: 151.11))),
        DataConfidence.confirmed);
  });

  test('default set: ALL locatable venues + nearest maxBuildings buildings (§0R-2 venue-bias)',
      () {
    final index = <SearchEntry>[
      VenueEntry(_v('vFar', lat: -33.80, lng: 151.14)), // far venue: still kept
      for (var i = 0; i < 20; i++)
        BuildingEntry(_b('b$i', lat: -33.7737 + i * 0.0005, lng: 151.1134)),
    ];
    final out = nearestTargets(_fix, index, maxBuildings: 12);
    expect(out.where((t) => t.kind == PlaceKind.venue).length, 1); // far venue survives
    expect(out.where((t) => t.kind == PlaceKind.building).length, 12); // capped
  });

  test('filter uses M3 scoreEntry over the FULL index — 13th-nearest still findable (§0R-3)',
      () {
    final index = <SearchEntry>[
      for (var i = 0; i < 20; i++)
        BuildingEntry(_b('Lib$i', lat: -33.7737 + (20 - i) * 0.001, lng: 151.1134)),
    ]; // Lib19 nearest, Lib0 farthest
    final filtered = nearestTargets(_fix, index, filter: 'Lib0');
    expect(filtered.map((t) => t.placeKey), contains('building:Lib0')); // far, but matched
  });

  test('filter matches a building CODE not present in the title (§0R-3/§0R-14)', () {
    final index = <SearchEntry>[
      BuildingEntry(_b('c-18ww', lat: -33.7738, lng: 151.1134, name: 'Central', code: '18WW')),
      BuildingEntry(_b('other', lat: -33.7739, lng: 151.1134, name: 'Other', code: 'OTH')),
    ];
    final out = nearestTargets(_fix, index, filter: '18ww');
    expect(out.map((t) => t.placeKey), ['building:c-18ww']); // matched on code only
  });

  test('filtered set is capped to maxBuildings (§0R-2)', () {
    final index = <SearchEntry>[
      for (var i = 0; i < 20; i++)
        BuildingEntry(_b('h$i', lat: -33.7737 + i * 0.0005, lng: 151.1134, name: 'Hall')),
    ];
    final out = nearestTargets(_fix, index, filter: 'Hall', maxBuildings: 12);
    expect(out.length, 12); // 20 match 'Hall' → capped
  });

  test('null-coord entries excluded; sorted by distance then placeKey', () {
    final index = <SearchEntry>[
      VenueEntry(_v('noCoord')),
      BuildingEntry(_b('near', lat: -33.7738, lng: 151.1134)),
      BuildingEntry(_b('far', lat: -33.79, lng: 151.14)),
    ];
    final out = nearestTargets(_fix, index);
    expect(out.map((t) => t.placeKey), ['building:near', 'building:far']);
  });

  test('unlocatableVenues: venues with null coords surfaced (safety rows)', () {
    final index = <SearchEntry>[
      VenueEntry(_v('first-aid')),
      VenueEntry(_v('ok', lat: -33.77, lng: 151.11)),
      BuildingEntry(_b('b', lat: -33.77, lng: 151.11)),
    ];
    expect(unlocatableVenues(index).map((e) => e.placeKey), ['venue:first-aid']);
  });
}
