import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/screens/map_screen.dart' show VenueSheet;
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/location_providers.dart';

import '../support/fake_location_service.dart';

/// "Show on map" must work EVERY time — not just the first.
///
/// ## The bug this file exists to prevent
///
/// The Map tab lives in a `StatefulShellRoute.indexedStack`, so its state is
/// kept alive for the app's lifetime. Focus handling was a one-shot latch
/// (`_handledFocus`) that never reset, and both "Show on map" buttons navigate
/// to the SAME url `/map?focus=venue:X`. Tapping it a second time for the same
/// place therefore did nothing: go_router sees an identical branch location (no
/// rebuild), and even a rebuild would hit the latch. The camera never re-moved
/// and the sheet never re-opened — exactly what Pouya reported.
///
/// The fix treats focus as a consume-and-clear EVENT: after handling, the
/// `?focus=` query is stripped by route REPLACEMENT (no phantom history entry)
/// and the latch resets, so every tap is a genuine navigation change.
void main() {
  const venue = 'venue:macquarie-theatre';

  late GoRouter router;

  Widget app() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    router = buildRouter();
    return ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        buildingsProvider.overrideWith((ref) async => const <Building>[]),
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        routerConfig: router,
      ),
    );
  }

  // The campus basemap image schedules async decode work that `pumpAndSettle`
  // would block on forever, so drive the focus handoff with explicit pumps:
  // one to build the map branch, one to run the post-frame focus callback, and
  // a bounded pump for the camera move + the sheet's entrance animation.
  Future<void> pumpFocus(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> dismissSheet(WidgetTester t) async {
    // Pop the modal deterministically via its own navigator — a barrier tap is
    // flaky here, and a stale open sheet would mask the very bug under test.
    Navigator.of(t.element(find.byType(VenueSheet))).pop();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the SAME venue shows on the map on the second attempt too',
      (t) async {
    await t.pumpWidget(app());
    await t.pump();

    // First "Show on map".
    router.go(Routes.mapFocus(venue));
    await pumpFocus(t);
    expect(find.byType(VenueSheet), findsOneWidget,
        reason: 'first Show on map should open the venue sheet');

    // Dismiss, then leave the Map tab entirely.
    await dismissSheet(t);
    expect(find.byType(VenueSheet), findsNothing);
    router.go(Routes.home);
    await t.pump();

    // Second "Show on map" for the SAME venue — this is the regression.
    router.go(Routes.mapFocus(venue));
    await pumpFocus(t);
    expect(find.byType(VenueSheet), findsOneWidget,
        reason: 'second Show on map of the same venue must re-open the sheet');
  });

  testWidgets('venue A -> venue B -> venue A each re-shows', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    Future<void> showThenDismiss(String key) async {
      router.go(Routes.mapFocus(key));
      await pumpFocus(t);
      expect(find.byType(VenueSheet), findsOneWidget, reason: 'show $key');
      await dismissSheet(t);
    }

    await showThenDismiss(venue); // A
    await showThenDismiss('venue:mason-theatre'); // B
    // Back to A: stale focus state must not swallow it.
    router.go(Routes.mapFocus(venue));
    await pumpFocus(t);
    expect(find.byType(VenueSheet), findsOneWidget,
        reason: 'returning to venue A must re-show, not stay on stale state');
  });
}
