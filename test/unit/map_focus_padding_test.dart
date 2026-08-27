import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/map_config.dart';

/// A focused marker must land where the visitor can see it.
///
/// ## The bug this file exists to prevent
///
/// `MapController.move` centres its target in the FULL widget viewport, and
/// nothing about the camera knows the selected-place sheet exists. The sheet
/// covers the bottom ~35% of the map, so "Show on map" centred the venue and
/// then drew the sheet straight over it — the one thing the visitor had asked
/// to see was the one thing hidden.
void main() {
  group('the offset moves the marker out from behind the sheet', () {
    test('it is positive, so the marker rises up the screen', () {
      final d = MapConfig.focusOffsetMapUnits(
          zoom: MapConfig.mapFocusZoom, obscuredBottomPx: 300);
      expect(d, greaterThan(0),
          reason: 'shifting the target down the map lifts the marker');
    });

    test('no sheet means no offset', () {
      expect(
        MapConfig.focusOffsetMapUnits(
            zoom: MapConfig.mapFocusZoom, obscuredBottomPx: 0),
        0,
      );
      expect(
        MapConfig.focusOffsetMapUnits(
            zoom: MapConfig.mapFocusZoom, obscuredBottomPx: -50),
        0,
        reason: 'a negative band is nonsense, not a reverse shift',
      );
    });

    test('it is exactly half the obscured band, converted to map-units', () {
      // Half, because the visible strip runs from the map top to the sheet top,
      // so its centre sits obscured/2 above the widget centre.
      const zoom = -4.0;
      const obscured = 256.0; // one map-unit at zoom 0 scaling
      final px = MapConfig.pixelsPerMapUnit(zoom);
      expect(
        MapConfig.focusOffsetMapUnits(zoom: zoom, obscuredBottomPx: obscured),
        closeTo((obscured / 2) / px, 1e-9),
      );
    });

    test('the same pixel gap is a BIGGER map-unit shift when zoomed out', () {
      // Zoom-dependence is the whole reason this is computed rather than a
      // constant: a fixed map-unit nudge would overshoot when zoomed in.
      final zoomedOut = MapConfig.focusOffsetMapUnits(
          zoom: MapConfig.mapMinZoom, obscuredBottomPx: 300);
      final zoomedIn = MapConfig.focusOffsetMapUnits(
          zoom: MapConfig.mapMaxZoom, obscuredBottomPx: 300);
      expect(zoomedOut, greaterThan(zoomedIn));
    });
  });

  group('the obscured band tracks the real sheet', () {
    test('it is the sheet fraction of the screen', () {
      expect(MapConfig.sheetObscuredHeight(800),
          closeTo(800 * MapConfig.venueSheetInitialExtent, 1e-9));
    });

    for (final (name, height) in <(String, double)>[
      ('narrow phone (iPhone SE)', 667),
      ('standard phone', 844),
      ('tablet / web viewport', 1180),
    ]) {
      test('$name: the marker clears the sheet', () {
        final obscured = MapConfig.sheetObscuredHeight(height);
        final shiftUnits = MapConfig.focusOffsetMapUnits(
            zoom: MapConfig.mapFocusZoom, obscuredBottomPx: obscured);
        final shiftPx = shiftUnits * MapConfig.pixelsPerMapUnit(MapConfig.mapFocusZoom);

        // The marker ends up shiftPx above centre; the sheet top is
        // obscured/2 above centre. Landing exactly there is the goal.
        expect(shiftPx, closeTo(obscured / 2, 0.01),
            reason: 'on a ${height}pt screen the marker must sit at the centre '
                'of the visible strip, not behind the sheet');
        // And it must be a real, perceptible move, not a rounding artefact.
        expect(shiftPx, greaterThan(50));
      });
    }
  });

  group('the map screen actually applies it', () {
    test('the focus path calls focusOffsetMapUnits', () {
      final src = File('lib/screens/map_screen.dart').readAsStringSync();
      expect(src.contains('MapConfig.focusOffsetMapUnits'), isTrue,
          reason: 'the helper is useless unless the focus path uses it');
      expect(src.contains('MapConfig.sheetObscuredHeight'), isTrue);
    });

    test('an ordinary recentre is NOT offset', () {
      // Only an external focus opens a sheet; shifting every recentre would
      // leave the map permanently off-centre.
      final src = File('lib/screens/map_screen.dart').readAsStringSync();
      expect(src.contains('zoom == null\n          ? target'), isTrue,
          reason: 'the offset must be conditional on a sheet-opening focus');
    });
  });
}
