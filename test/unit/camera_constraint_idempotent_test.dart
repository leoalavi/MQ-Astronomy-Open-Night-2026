import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/widgets/map_config.dart';

// MAP-006 regression (audit 2026-08-30).
//
// flutter_map's `MapControllerImpl.options=` asserts, on EVERY options change,
// `newOptions.cameraConstraint.constrain(camera) == camera`. The campus map's
// `MapOptions` is rebuilt on every layout (a fresh `onMapReady` closure makes it
// never `==`), so that assertion runs on every MapScreen rebuild. A search/focus
// selection calls `_controller.move(...)`, which flutter_map constrains once;
// the next rebuild then re-checks the invariant. If `constrain` is not perfectly
// idempotent — project → clamp → unproject does not round-trip to the bit — the
// re-check returns a marginally different camera, `== camera` is false, and the
// map dies with a red `_debugRelayoutBoundaryAlreadyMarkedNeedsLayout` screen
// (reproduced on an iPhone 17 Pro Max simulator: Map → Search → tap a result →
// dismiss the sheet).
//
// The contract that prevents it: constraining an ALREADY-constrained camera must
// return it byte-identical.

MapCamera _cameraAt(LatLng centre, double zoom, Size size) => MapCamera(
      crs: const CrsSimple(),
      center: centre,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: size,
      size: size,
    );

void main() {
  final bounds = MapConfig.aonMapBounds;
  final constraint = ContainOrCentreCamera(bounds: bounds);

  // Zoomed IN (artwork larger than the viewport), centred near a corner — the
  // "moved onto a venue" state a search selection produces, where the centre is
  // actually clamped.
  final nearCorner = LatLng(bounds.south + 0.0004, bounds.east - 0.0004);

  test('constrain is idempotent for a clamped camera (flutter_map options= '
      'invariant — MAP-006)', () {
    final cam = _cameraAt(nearCorner, -3.0, const Size(390, 700));
    final c1 = constraint.constrain(cam);
    expect(c1, isNotNull);

    // The load-bearing check: flutter_map does `constrain(c1) == c1`. Our
    // constrain must therefore return c1 with the SAME centre, exactly.
    final c2 = constraint.constrain(c1!);
    expect(c2, isNotNull);
    expect(c2!.center.latitude, c1.center.latitude,
        reason: 'a re-constrained camera must not drift in latitude');
    expect(c2.center.longitude, c1.center.longitude,
        reason: 'a re-constrained camera must not drift in longitude');
  });

  test('idempotent AT the cover-fit floor zoom — the crash case', () {
    // The map opens at (and clamps down to) this dynamic floor, so a search
    // selection moves the camera at this exact zoom, where the artwork just
    // covers the viewport and the containment math sits on its boundary.
    for (final size in const [Size(390, 700), Size(320, 568), Size(440, 900)]) {
      final z = MapConfig.minZoomForViewport(size)
          .clamp(MapConfig.mapMinZoom, MapConfig.mapMaxZoom);
      for (final corner in [
        LatLng(bounds.south + 0.0004, bounds.east - 0.0004),
        LatLng(bounds.north - 0.0004, bounds.west + 0.0004),
        LatLng(bounds.south + 0.0004, bounds.west + 0.0004),
      ]) {
        final c1 = constraint.constrain(_cameraAt(corner, z, size))!;
        final c2 = constraint.constrain(c1)!;
        expect(c2.center.latitude, c1.center.latitude,
            reason: 'lat @ z=$z size=$size $corner');
        expect(c2.center.longitude, c1.center.longitude,
            reason: 'lng @ z=$z size=$size $corner');
      }
    }
  });
}
