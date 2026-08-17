import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';

/// Quick Access must never dead-end.
///
/// ## The bug this file exists to prevent
///
/// Every Quick Access tile used to push the walking-directions planner with a
/// pre-seeded destination. Only two of the eight destinations have an authored
/// route, so five tiles (Toilets, First aid, Food and drink, Talks, Kids'
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

    test('the parking shortcut is the only one without a venue', () {
      final noVenue = EventConfig.astronomyOpenNight.quickAccess
          .where((q) => q.venueId == null)
          .map((q) => q.id);
      expect(noVenue, ['parking']);
    });
  });

  group('shortcuts WITHOUT a walking route', () {
    testWidgets('Toilets opens the venue sheet, not an empty planner', (
      tester,
    ) async {
      // Regression: this is one of the five tiles that used to dead-end.
      expect(
        RoutesData.all.any((r) => r.toId == 'toilets-1-central-courtyard'),
        isFalse,
        reason: 'if a route is later authored, this test needs rethinking',
      );

      await openQuickAccess(tester, 'Toilets');

      expect(find.byType(VenueInfoSheet), findsOneWidget);
      expect(find.byType(WayfindingScreen), findsNothing);
    });

    testWidgets('the sheet says what it cannot do instead of offering a dead '
        'directions button', (tester) async {
      await openQuickAccess(tester, 'First aid');

      expect(find.byType(VenueInfoSheet), findsOneWidget);
      await scrollInSheet(
        tester,
        find.textContaining('don’t have written walking directions'),
      );
      expect(
        find.textContaining('don’t have written walking directions'),
        findsOneWidget,
      );
      // No directions button at all — absent, not disabled.
      expect(find.text('Walking directions'), findsNothing);
    });

    testWidgets('the sheet still offers the map as a fallback', (tester) async {
      await openQuickAccess(tester, 'Toilets');
      expect(find.text('Show on map'), findsOneWidget);
    });

    testWidgets('a facility with no programme says so rather than showing an '
        'empty list', (tester) async {
      await openQuickAccess(tester, 'First aid');
      await scrollInSheet(tester, find.text('Nothing scheduled here tonight.'));
      expect(find.text('Nothing scheduled here tonight.'), findsOneWidget);
    });
  });

  group('shortcuts WITH a walking route', () {
    testWidgets('Telescopes offers real walking directions', (tester) async {
      expect(
        RoutesData.all.any((r) => r.toId == 'astronomical-observatory'),
        isTrue,
      );

      await openQuickAccess(tester, 'Telescopes');

      expect(find.byType(VenueInfoSheet), findsOneWidget);
      expect(find.text('Walking directions'), findsOneWidget);
    });

    testWidgets('the sheet lists what is on at that venue', (tester) async {
      await openQuickAccess(tester, 'Telescopes');
      // Telescope Park is the Observatory's programme entry.
      await scrollInSheet(tester, find.text('Telescope Park'));
      expect(find.text('Telescope Park'), findsOneWidget);
    });
  });

  group('parking', () {
    testWidgets('Parking opens the planner — that IS its answer', (
      tester,
    ) async {
      await openQuickAccess(tester, 'Parking');
      expect(find.byType(WayfindingScreen), findsOneWidget);
      expect(find.byType(VenueInfoSheet), findsNothing);
    });
  });
}
