import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/router/app_router.dart';

/// "Show on map" must carry the venue with it.
///
/// ## The bug this file exists to prevent
///
/// Both "Show on map" actions called `context.go(Routes.map)`. That switches to
/// the Map tab and DISCARDS the venue entirely: the visitor arrives at an
/// unchanged campus map, nothing selected, no sheet, no camera move — left to
/// find the pin themselves among every venue, car park and facility on the
/// artwork. `Routes.mapFocus` carries the place key so the tab can select it,
/// move the camera onto it and open its sheet.
void main() {
  group('the focus route', () {
    test('carries the place key as a query parameter', () {
      final uri = Uri.parse(Routes.mapFocus('venue:macquarie-theatre'));
      expect(uri.path, '/map');
      expect(uri.queryParameters['focus'], 'venue:macquarie-theatre');
    });

    test('encodes keys safely rather than breaking the URI', () {
      // Place keys contain a colon; anything exotic must survive a round trip.
      final uri = Uri.parse(Routes.mapFocus('building:17 Wally’s Walk'));
      expect(uri.queryParameters['focus'], 'building:17 Wally’s Walk');
    });

    test('is still the Map tab, so the shell keeps its branch', () {
      // A different path would push a new page instead of switching tabs, and
      // the bottom nav would lose its Map highlight.
      expect(Routes.mapFocus('venue:x').startsWith(Routes.map), isTrue);
    });
  });

  group('every Show-on-map call site uses it', () {
    test('no screen navigates to a bare Routes.map for "show on map"', () {
      // The regression in one line: `go(Routes.map)` next to actionShowOnMap.
      const callSites = [
        'lib/screens/event_detail_screen.dart',
        'lib/widgets/venue_info_sheet.dart',
      ];
      final offenders = <String>[];
      for (final path in callSites) {
        final src = File(path).readAsStringSync();
        if (!src.contains('Routes.mapFocus')) {
          offenders.add('$path does not pass a focus key');
        }
        if (RegExp(r'go\(\s*Routes\.map\s*\)').hasMatch(src)) {
          offenders.add('$path still drops the venue via go(Routes.map)');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('the map screen accepts and consumes a focus key', () {
      final src = File('lib/screens/map_screen.dart').readAsStringSync();
      expect(src.contains('focusPlaceKey'), isTrue);
      // It must actually act on it, not merely accept it.
      expect(src.contains('_onPlaceSelected'), isTrue);
      expect(src.contains('mapFocusZoom'), isTrue);
    });

    test('the router feeds the query parameter into the screen', () {
      final src = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(src.contains("queryParameters['focus']"), isTrue);
    });
  });
}
