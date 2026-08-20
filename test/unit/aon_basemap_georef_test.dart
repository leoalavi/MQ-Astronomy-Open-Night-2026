import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/map_config.dart';

/// Georeferencing of the OFFICIAL AON 2026 basemap.
///
/// The AON program map and MQ Journey's campus basemap are the SAME MQ
/// cartographic master at different crops, related by a pure similarity
/// (uniform scale + translation) fitted over 45 matched landmarks —
/// 0.77 px mean / 2.12 px max residual across a 4678 px-wide frame
/// (`tools/aon_map/fit_georef_*.py`; rotation -0.003 deg, shear -0.014 deg,
/// i.e. no rotation).
///
/// That similarity is what lets the official artwork drop in WITHOUT touching
/// the `gcp_affine` GPS calibration, `buildings.json` `campusX/Y`, or any baked
/// venue coordinate: the overlay simply carries its own bounds in the same
/// CrsSimple space. These tests pin the composition — if the constants drift,
/// every marker silently slides off the artwork, which is exactly the class of
/// bug paper review never catches.
void main() {
  const proj = CampusProjection();
  GpsPoint gps(double lat, double lng) => GpsPoint(LatLng(lat, lng));

  test('aonPixel composes the fitted similarity onto the MQ pixel frame', () {
    for (final (ax, ay) in const [
      (0.0, 0.0),
      (1234.0, 987.0),
      (2340.0, 1655.0),
      (4680.0, 3310.0),
    ]) {
      final mqX =
          ax * CampusProjection.aonToMqScale + CampusProjection.aonToMqTx;
      final mqY =
          ay * CampusProjection.aonToMqScale + CampusProjection.aonToMqTy;
      final viaMq = CampusProjection.mqPixelToMapUnits(mqX, mqY);
      final direct = proj.aonPixel(ax, ay);
      expect(direct.value.latitude, closeTo(viaMq.value.latitude, 1e-9));
      expect(direct.value.longitude, closeTo(viaMq.value.longitude, 1e-9));
    }
  });

  test('aonMapBounds is derived from the projector, never hand-typed', () {
    // SW = bottom-left of the render (0, H); NE = top-right (W, 0) — the
    // projector Y-flips.
    final sw = proj.aonPixel(0, CampusProjection.aonRenderHeight);
    final ne = proj.aonPixel(CampusProjection.aonRenderWidth, 0);
    expect(MapConfig.aonMapBounds.south, closeTo(sw.value.latitude, 1e-9));
    expect(MapConfig.aonMapBounds.west, closeTo(sw.value.longitude, 1e-9));
    expect(MapConfig.aonMapBounds.north, closeTo(ne.value.latitude, 1e-9));
    expect(MapConfig.aonMapBounds.east, closeTo(ne.value.longitude, 1e-9));
  });

  test('the AON artwork covers the whole GPS calibration domain', () {
    // Every GPS fix the projector ACCEPTS must land on the artwork, or the
    // location dot would be painted over blank background.
    final b = MapConfig.aonMapBounds;
    for (final (lat, lng) in const [
      (-33.7772506, 151.1080508), // frozen calibration-domain corners
      (-33.7772506, 151.1211352),
      (-33.7703261, 151.1080508),
      (-33.7703261, 151.1211352),
      (-33.7737, 151.1134), // Central Courtyard
    ]) {
      final p = proj.project(gps(lat, lng));
      if (p == null) continue; // rejected by the projector — nothing to draw
      expect(b.contains(p.value), isTrue,
          reason: 'GPS ($lat,$lng) projects off the AON artwork');
    }
  });

  test('AON artwork covers the MQ frame vertically, and horizontally to 4539.9',
      () {
    // The AON crop is TIGHTER than the MQ frame on the right. Pin the exact
    // coverage boundary so a re-render that shifts it fails loudly instead of
    // silently stranding markers on background.
    final b = MapConfig.aonMapBounds;
    for (final (x, y) in const [
      (1.0, 0.0), // (0,0) is projectPixel's "no campus coords" sentinel
      (0.0, 3307.0),
      (4539.0, 0.0),
      (4539.0, 3307.0),
      (2339.0, 1653.0),
    ]) {
      final p = proj.projectPixel(x, y);
      expect(p, isNotNull, reason: 'MQ pixel ($x,$y) must project');
      expect(b.contains(p!.value), isTrue,
          reason: 'MQ pixel ($x,$y) falls off the AON artwork');
    }
    // ...and just past the boundary it genuinely is off the artwork.
    final off = proj.projectPixel(4600, 1653)!;
    expect(b.contains(off.value), isFalse,
        reason: 'coverage boundary moved — re-derive the georeferencing');
  });

  test('exactly one vendored building falls outside the AON artwork', () {
    // DATA HONESTY: `Macquarie Centre` carries campusX 4678 — the MQ frame's
    // right EDGE, a clamped value for the off-campus shopping centre. The AON
    // crop ends at 4539.9, so its (search-only, transient) marker would sit on
    // background. Known and accepted; this test fails if the count ever grows,
    // which would mean real campus buildings had started drifting off.
    final raw = File('assets/data/buildings.json').readAsStringSync();
    final decoded = jsonDecode(raw);
    final rows = (decoded is List ? decoded : decoded['buildings']) as List;

    final b = MapConfig.aonMapBounds;
    final off = <String>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final x = (row['campusX'] as num?)?.toDouble() ?? 0;
      final y = (row['campusY'] as num?)?.toDouble() ?? 0;
      final p = proj.projectPixel(x, y);
      if (p == null) continue; // (0,0) "no campus coords" sentinel
      if (!b.contains(p.value)) off.add(row['name'] as String);
    }
    expect(off, ['Macquarie Centre'],
        reason: 'buildings drifting off the official artwork: $off');
  });
}
