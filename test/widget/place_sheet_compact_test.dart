import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/map_config.dart';

/// The selected-place sheet must not swallow the map.
///
/// ## The bugs this file exists to prevent
///
/// 1. **The sheet hid the map.** "Show on map" exists to show a location ON the
///    map; a sheet that fills the screen defeats its own purpose.
/// 2. **The primary action was below the fold.** At ~35% height only the first
///    ~180pt is visible, and the sheet used to render notes, a confidence note
///    and the whole activity list BEFORE the Directions button — so the one
///    control the sheet exists to offer was the one you had to drag to find.
/// 3. **Two identical primary actions.** The map's floating Directions FAB
///    stayed visible behind the sheet, pointing at the Central Courtyard while
///    the sheet's button pointed at the selected venue.
void main() {
  final mapScreen = File('lib/screens/map_screen.dart').readAsStringSync();

  group('the collapsed sheet keeps the map dominant', () {
    test('it opens at no more than 35% of the viewport', () {
      expect(MapConfig.venueSheetInitialExtent, lessThanOrEqualTo(0.35),
          reason: 'the map must stay the dominant surface');
      expect(MapConfig.venueSheetInitialExtent, greaterThanOrEqualTo(0.25),
          reason: 'below ~25% the name and action stop fitting');
    });

    test('it can be dragged smaller, and up to full detail', () {
      expect(MapConfig.venueSheetMinExtent,
          lessThan(MapConfig.venueSheetInitialExtent));
      expect(MapConfig.venueSheetMaxExtent,
          greaterThan(MapConfig.venueSheetInitialExtent));
      expect(MapConfig.venueSheetMaxExtent, greaterThanOrEqualTo(0.8),
          reason: 'secondary detail must be reachable by dragging');
    });

    test('it does NOT open full-height', () {
      expect(MapConfig.venueSheetInitialExtent,
          lessThan(MapConfig.venueSheetMaxExtent));
    });
  });

  group('the primary action is above the fold', () {
    test('Directions renders BEFORE notes and the activity list', () {
      // Order in the source is order on screen for this ListView.
      final directions = mapScreen.indexOf('label: Text(l.mapDirections)');
      final notes = mapScreen.indexOf('venue.notes!');
      final activities = mapScreen.indexOf('l.mapOnHereTonight');

      expect(directions, greaterThan(0));
      expect(notes, greaterThan(0));
      expect(activities, greaterThan(0));
      expect(directions, lessThan(notes),
          reason: 'notes above the CTA push Directions below the fold');
      expect(directions, lessThan(activities),
          reason: 'the activity list must never precede the primary action');
    });
  });

  group('no duplicate Directions CTA', () {
    test('the floating FAB is suppressed while a place is selected', () {
      expect(
        mapScreen.contains(
            'floatingActionButton: (_mode != MapMode.campusMap || selectedKey != null)'),
        isTrue,
        reason: 'a selected venue must show exactly one Directions action — the '
            'one in its sheet, which targets THAT venue',
      );
    });

    test('the FAB still exists for the no-selection case', () {
      // It is a general "route me to the middle of campus" affordance, which is
      // meaningful only when nothing is selected — so it must not be deleted.
      expect(mapScreen.contains("googleNavTo('venue:central-courtyard')"), isTrue);
    });
  });
}
