import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/widgets/map_config.dart';

/// The campus map is a printed event map, not a slippy world map.
///
/// ## The bugs this file exists to prevent
///
/// 1. **It rotated.** `flutter_map` defaults to `InteractiveFlag.all`, which
///    includes `rotate`, so a two-finger twist left the official artwork sitting
///    diagonally — legend, north arrow and all — as seen on device.
/// 2. **It could be dragged into nothing.** `CameraConstraint.containCenter`
///    only keeps the CENTRE inside the artwork, so the map could be pushed until
///    a corner remained and the rest of the screen was empty background.
void main() {
  group('rotation is impossible', () {
    test('the map flags exclude rotate but keep pan and zoom', () {
      const f = MapConfig.mapInteractiveFlags;
      expect(InteractiveFlag.hasRotate(f), isFalse,
          reason: 'the printed artwork is only legible north-up');
      // The gestures a visitor actually needs must survive the removal.
      expect(InteractiveFlag.hasDrag(f), isTrue);
      expect(InteractiveFlag.hasPinchZoom(f), isTrue);
      expect(InteractiveFlag.hasDoubleTapZoom(f), isTrue);
      expect(InteractiveFlag.hasPinchMove(f), isTrue);
    });

    test('the map screen never re-enables rotation behind our back', () {
      // Guards the call site as well as the constant: an InteractionOptions with
      // InteractiveFlag.all, or a rotation gesture wired by hand, would undo it.
      final src = File('lib/screens/map_screen.dart').readAsStringSync();
      expect(src.contains('MapConfig.mapInteractiveFlags'), isTrue,
          reason: 'the campus map must pass the rotation-free flag set');
      expect(src.contains('InteractiveFlag.all'), isFalse,
          reason: 'InteractiveFlag.all silently includes rotate');
    });
  });

  group('the artwork cannot be panned off screen', () {
    // A camera helper at a given zoom/centre inside a fixed viewport.
    MapCamera cameraAt(LatLng centre, double zoom, Size size) => MapCamera(
          crs: const CrsSimple(),
          center: centre,
          zoom: zoom,
          rotation: 0,
          // Rotation is locked to 0, so the rotated and non-rotated viewports
          // are the same box.
          nonRotatedSize: size,
          size: size,
        );

    final bounds = MapConfig.aonMapBounds;
    final artworkCentre = LatLng(
      (bounds.south + bounds.north) / 2,
      (bounds.west + bounds.east) / 2,
    );
    test('a centred camera is left alone', () {
      final c = ContainOrCentreCamera(bounds: bounds);
      final cam = cameraAt(artworkCentre, -6.3, const Size(390, 700));
      final out = c.constrain(cam);
      expect(out, isNotNull, reason: 'a legal camera must never be rejected');
      expect(out!.center.latitude, closeTo(artworkCentre.latitude, 1e-6));
      expect(out.center.longitude, closeTo(artworkCentre.longitude, 1e-6));
    });

    test('a far-away camera is pulled back so the artwork stays on screen', () {
      final c = ContainOrCentreCamera(bounds: bounds);
      const size = Size(390, 700);
      // Way off to the north-east of the artwork — the "empty black space" the
      // visitor could previously drag into.
      final cam = cameraAt(
        LatLng(bounds.north + 500, bounds.east + 500),
        -6.3,
        size,
      );
      final out = c.constrain(cam)!;

      // The invariant is about what is VISIBLE, not about where the centre sits:
      // when the artwork is smaller than the viewport the centre may legitimately
      // sit outside the artwork while the artwork is still fully in frame.
      final ne = out.projectAtZoom(bounds.northEast, out.zoom);
      final sw = out.projectAtZoom(bounds.southWest, out.zoom);
      final art = Rect.fromLTRB(
        math.min(sw.dx, ne.dx),
        math.min(sw.dy, ne.dy),
        math.max(sw.dx, ne.dx),
        math.max(sw.dy, ne.dy),
      );
      final centre = out.projectAtZoom(out.center, out.zoom);
      final view = Rect.fromCenter(
          center: centre, width: size.width, height: size.height);

      expect(view.overlaps(art), isTrue,
          reason: 'the campus must never leave the screen entirely');

      // The precise per-axis guarantee: on each axis, EITHER the artwork covers
      // the viewport (nothing empty can show) OR the artwork sits entirely
      // inside it (all of the map is in frame). Never a half-off-screen third
      // case, which is what the old containCenter allowed.
      void axisHolds(double viewLo, double viewHi, double artLo, double artHi,
          String axis) {
        final covers = artLo <= viewLo + 0.01 && artHi >= viewHi - 0.01;
        final inside = artLo >= viewLo - 0.01 && artHi <= viewHi + 0.01;
        expect(covers || inside, isTrue,
            reason: 'on $axis the artwork is neither covering the viewport nor '
                'fully inside it — i.e. it hangs half off screen');
      }

      axisHolds(view.left, view.right, art.left, art.right, 'x');
      axisHolds(view.top, view.bottom, art.top, art.bottom, 'y');
    });

    test('it never REJECTS a gesture (which would feel frozen)', () {
      // The built-in `contain` returns null when the artwork is smaller than the
      // viewport — the normal state at fit zoom — which is why it is unusable
      // here. Ours must always answer with a camera.
      final c = ContainOrCentreCamera(bounds: bounds);
      for (final zoom in [-7.0, -6.3, -5.0, -3.0, -2.0]) {
        final cam = cameraAt(artworkCentre, zoom, const Size(390, 700));
        expect(c.constrain(cam), isNotNull, reason: 'rejected at zoom $zoom');
      }
    });

    test('equality is by bounds, so flutter_map can diff it cheaply', () {
      expect(ContainOrCentreCamera(bounds: bounds),
          ContainOrCentreCamera(bounds: bounds));
    });
  });

  group('zoom bounds stay sane', () {
    test('the range is ordered and the focus zoom sits inside it', () {
      expect(MapConfig.mapMinZoom, lessThan(MapConfig.mapMaxZoom));
      expect(MapConfig.mapFocusZoom,
          inInclusiveRange(MapConfig.mapMinZoom, MapConfig.mapMaxZoom));
    });

    test('the pinned values are the tuned ones', () {
      // Pinned deliberately: these were tuned against the CrsSimple math and
      // on-device screenshots. Changing them must be a conscious act.
      expect(MapConfig.mapMinZoom, -7);
      expect(MapConfig.mapMaxZoom, -2);
    });
  });
}
