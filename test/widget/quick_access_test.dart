import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';
import 'package:aon2026/widgets/parking_choices_sheet.dart';
import 'package:aon2026/widgets/toilet_choices_sheet.dart';
import 'package:aon2026/widgets/information_points_sheet.dart';

/// Quick Access must never dead-end.
///
/// ## The bug this file exists to prevent
///
/// Every Quick Access tile used to push the walking-directions planner with a
/// pre-seeded destination. Only two of the eight destinations have an authored
/// route, so four tiles (Toilets, Food and drink, Talks, Kids'
/// activities) landed the visitor on an empty planner with nothing selected —
/// on Home, the first screen they ever see.
void main() {
  Widget app() {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
    });
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        routerConfig: buildRouter(),
      ),
    );
  }

  /// Scrolls inside the opened sheet (its own Scrollable is the last one).
  Future<void> scrollInSheet(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
      );

  Future<void> openQuickAccess(WidgetTester tester, String label) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // NB: scroll with the *plain* finder — a chained `.first` throws instead
    // of reporting "not yet built" while dragUntilVisible is still looking.
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // ensureVisible before tapping: scrollUntilVisible stops as soon as the
    // tile *starts* to appear, and a tap on its centre then lands outside the
    // viewport and silently does nothing.
    await tester.ensureVisible(find.text(label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  group('every configured shortcut resolves to something real', () {
    test('each venue-backed shortcut points at a venue that exists', () {
      for (final q in EventConfig.astronomyOpenNight.quickAccess) {
        if (q.venueId == null) continue;
        expect(
          VenuesData.byId(q.venueId!),
          isNotNull,
          reason: '"${q.id}" points at unknown venue "${q.venueId}"',
        );
      }
    });

    test('only the group shortcuts (parking, info points) have no venue', () {
      final noVenue = EventConfig.astronomyOpenNight.quickAccess
          .where((q) => q.venueId == null)
          .map((q) => q.id);
      expect(noVenue, ['parking', 'information-points']);
    });
  });

  group('shortcuts WITHOUT a walking route', () {
    testWidgets('the sheet offers Google directions for a located venue', (
      tester,
    ) async {
      // Google Maps routes anywhere, so there is no "no route" dead-end any
      // more — every venue sheet offers one Directions action.
      await openQuickAccess(tester, 'Food and drink');

      expect(find.byType(VenueInfoSheet), findsOneWidget);
      await scrollInSheet(tester, find.text('Directions'));
      expect(find.text('Directions'), findsOneWidget);
      expect(
        find.textContaining('don’t have written walking directions'),
        findsNothing,
      );
    });
  });

  group('toilets', () {
    testWidgets('Toilets opens a chooser listing all three buildings', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Toilets');

      // A chooser, not a single venue sheet and never an empty planner.
      expect(find.byType(ToiletChoicesSheet), findsOneWidget);
      expect(find.byType(VenueInfoSheet), findsNothing);
      expect(find.byType(WayfindingScreen), findsNothing);

      for (final building in [
        'Macquarie Theatre',
        '1 Central Courtyard',
        'Mason Theatre',
      ]) {
        expect(find.textContaining(building), findsWidgets,
            reason: '"$building" toilets should be listed');
      }
    });

    testWidgets('every listed toilet offers directions and a map focus', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Toilets');
      for (final id in [
        'toilets-macquarie-theatre',
        'toilets-1-central-courtyard',
        'toilets-mason-theatre',
      ]) {
        expect(find.byKey(Key('directions-venue:$id')), findsOneWidget);
        expect(find.byKey(Key('show-map-venue:$id')), findsOneWidget);
      }
      // Reachability: the last card's actions can be scrolled to and hit.
      final lastDirections = find.byKey(
        const Key('directions-venue:toilets-mason-theatre'),
      );
      await tester.ensureVisible(lastDirections);
      await tester.pumpAndSettle();
      expect(lastDirections.hitTestable(), findsOneWidget);
    });
  });

  group('shortcuts WITH a walking route', () {
    testWidgets('Telescopes offers Google directions', (tester) async {
      await openQuickAccess(tester, 'Telescopes');

      expect(find.byType(VenueInfoSheet), findsOneWidget);
      await scrollInSheet(tester, find.text('Directions'));
      expect(find.text('Directions'), findsOneWidget);
    });

    testWidgets('the sheet lists what is on at that venue', (tester) async {
      await openQuickAccess(tester, 'Telescopes');
      // Telescope Park is the Observatory's programme entry.
      await scrollInSheet(tester, find.text('Telescope Park'));
      expect(find.text('Telescope Park'), findsOneWidget);
    });
  });

  group('parking', () {
    testWidgets('Parking opens a chooser and never silently selects West 5', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Parking');
      expect(find.byType(ParkingChoicesSheet), findsOneWidget);
      expect(find.textContaining('West 5'), findsWidgets);
      expect(find.textContaining('West 6'), findsWidgets);
      expect(find.textContaining('South 2'), findsWidgets);
      expect(find.byType(WayfindingScreen), findsNothing);
      expect(
        find.byKey(const Key('directions-parking:west-5')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('show-map-parking:west-5')), findsOneWidget);
      expect(
        find.byKey(const Key('directions-parking:south-2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('show-map-parking:south-2')), findsOneWidget);
      // West 6 is now pinned to its Link Road car park, so it carries the same
      // two actions as West 5 and South 2 (it used to have none).
      expect(
        find.byKey(const Key('directions-parking:west-6')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('show-map-parking:west-6')), findsOneWidget);
    });

    testWidgets('parking actions can scroll fully above the floating tab bar', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Parking');
      final southDirections = find.byKey(
        const Key('directions-parking:south-2'),
      );
      await tester.ensureVisible(southDirections);
      await tester.pumpAndSettle();

      expect(southDirections.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('information points', () {
    testWidgets('Information points opens a chooser with all three points', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Information points');
      expect(find.byType(InformationPointsSheet), findsOneWidget);
      // Registration + points 2/3 all sit on the Central Courtyard coordinate
      // the map pins, so each offers a real Show on map + Directions.
      for (final id in const [
        'registration-point',
        'information-point-2',
        'information-point-3',
      ]) {
        expect(find.byKey(Key('info-point-card-$id')), findsOneWidget);
        expect(find.byKey(Key('show-map-venue:$id')), findsOneWidget);
        expect(find.byKey(Key('directions-venue:$id')), findsOneWidget);
      }
      expect(find.byType(WayfindingScreen), findsNothing);
    });
  });
}
