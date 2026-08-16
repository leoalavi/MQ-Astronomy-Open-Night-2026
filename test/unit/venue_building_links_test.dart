import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/venue.dart';

void main() {
  final buildingsById = {
    for (final b in (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(Building.fromJson))
      b.id: b
  };
  final linked = VenuesData.all.where((v) => v.buildingId != null).toList();

  // G12: the exact curated mapping — an accidental 8th link or a wrong id fails.
  const expectedLinks = {
    'macquarie-theatre': 'MQTH',
    '1-central-courtyard': '1CC',
    '11-wallys-walk': '11WW',
    '17-wallys-walk': '17WW',
    'sport-and-aquatic-centre': 'SPORT',
    'astronomical-observatory': 'OBS',
    '14-sir-christopher-ondaatje-avenue': '14SCO',
  };

  test('exactly the 7 curated venue→building links (G12)', () {
    final actual = {for (final v in linked) v.id: v.buildingId};
    expect(actual, expectedLinks);
  });

  test('every buildingId resolves to exactly one Building', () {
    for (final v in linked) {
      expect(buildingsById.containsKey(v.buildingId), isTrue, reason: '${v.id}→${v.buildingId}');
    }
  });

  test('one venue ↔ one building (no building linked twice)', () {
    final ids = linked.map((v) => v.buildingId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('drift: each linked venue campusX/Y == its building campusX/Y', () {
    for (final v in linked) {
      final b = buildingsById[v.buildingId]!;
      expect(v.campusX, b.campusX, reason: '${v.id} campusX drifted from ${b.id}');
      expect(v.campusY, b.campusY, reason: '${v.id} campusY drifted from ${b.id}');
    }
  });

  test('G2: venue partial entrance does NOT fabricate a routing coordinate', () {
    const v = Venue(
      id: 't', name: 't', category: VenueCategory.other,
      entranceLatitude: -33.7, // longitude missing
      latitude: -33.8, longitude: 151.1,
    );
    expect(v.routingLatitude, -33.8); // centre pair, not -33.7
    expect(v.routingLongitude, 151.1);
  });
}
