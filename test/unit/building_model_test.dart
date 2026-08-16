import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';

void main() {
  test('fromJson (flat) parses core fields', () {
    final b = Building.fromJson(const {
      'id': '18WW', 'code': '18WW', 'name': "18 Wally's Walk",
      'category': 'services', 'latitude': -33.7739781, 'longitude': 151.1126116,
      'entranceLatitude': -33.77388, 'entranceLongitude': 151.11275,
      'campusX': 2281, 'campusY': 1882, 'gridRef': 'N16',
      'aliases': ['Tech Bar'], 'searchTokens': ['it help'], 'tags': ['services'],
    });
    expect(b.id, '18WW');
    expect(b.category, BuildingCategory.services);
    expect(b.campusX, 2281);
    expect(b.routingLatitude, -33.77388); // entrance pair present → entrance wins
    expect(b.hasCampusCoordinates, isTrue);
  });

  test('fromJson (nested) tolerates location/campusLocation', () {
    final b = Building.fromJson(const {
      'id': 'X', 'code': 'X', 'name': 'X', 'category': 'other',
      'location': {'lat': -33.77, 'lng': 151.11},
      'campusLocation': {'x': 100, 'y': 200},
    });
    expect(b.latitude, -33.77);
    expect(b.campusX, 100);
  });

  test('G2: partial entrance (lat only) does NOT fabricate a coordinate', () {
    final b = Building.fromJson(const {
      'id': 'P', 'code': 'P', 'name': 'P', 'category': 'other',
      'entranceLatitude': -33.7, // longitude missing
      'latitude': -33.8, 'longitude': 151.1,
    });
    expect(b.hasEntranceCoordinates, isFalse);
    expect(b.routingLatitude, -33.8);  // falls back to the CENTRE pair, not -33.7
    expect(b.routingLongitude, 151.1);
  });

  test('teaching category is preserved, not degraded to other (#14)', () {
    expect(BuildingCategory.fromString('teaching'), BuildingCategory.teaching);
    expect(BuildingCategory.fromString('nope'), BuildingCategory.other);
    expect(BuildingCategory.fromString(null), BuildingCategory.other);
  });

  test('equality by id only', () {
    expect(
        Building.fromJson(const {'id': 'A', 'code': 'A', 'name': 'A', 'category': 'other'}),
        Building.fromJson(const {'id': 'A', 'code': 'A2', 'name': 'A2', 'category': 'food'}));
  });

  test('the vendored asset parses to 170 Buildings, all campus-placeable', () {
    final data = (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final built = data.map(Building.fromJson).toList();
    expect(built.length, 170);
    expect(built.every((b) => b.hasCampusCoordinates), isTrue);
  });
}
