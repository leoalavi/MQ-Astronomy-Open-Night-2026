import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/campus_projection.dart';

void main() {
  const p = CampusProjection();

  test('18WW pixel (2281,1882) → map (36.63, 58.63) [receipt]', () {
    final m = p.projectPixel(2281, 1882)!;
    expect(m.value.latitude, closeTo(36.63, 0.05));
    expect(m.value.longitude, closeTo(58.63, 0.05));
  });

  test('(0,0) sentinel and out-of-range → null; exact edges valid (G1 strict)', () {
    expect(p.projectPixel(0, 0), isNull); // sentinel
    expect(p.projectPixel(-0.001, 100), isNull); // just under 0 → null (no _eps slack)
    expect(p.projectPixel(4678.001, 100), isNull);
    expect(p.projectPixel(0, 1), isNotNull); // exact edges valid
    expect(p.projectPixel(4678, 0), isNotNull);
    expect(p.projectPixel(0, 3307), isNotNull);
  });

  test('ALL 170 buildings projectPixel successfully (necessity of pixel path)', () {
    final data = (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(Building.fromJson);
    for (final b in data) {
      expect(p.projectPixel(b.campusX!, b.campusY!), isNotNull, reason: b.id);
    }
  });
}
