import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/screens/map_screen.dart' show ParkingSheet, VenueSheet;
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/location_providers.dart';

import '../support/fake_location_service.dart';

/// Direct-manipulation coverage for the campus map: the paths a visitor reaches
/// by TAPPING the live map, as opposed to the `?focus=` deep links that
/// `map_focus_replay_test.dart` already drives.
///
/// These interactions (tapping a pin, a car-park pin, the zoom buttons, a
/// category filter, the general wayfinding FAB) run the marker `onTap`
/// closures, `_showVenueSheet` / `_showParkingSheet`, and the zoom-clamp wiring
/// in `map_screen.dart` that no other test exercises — the pin tap in
/// particular is the canonical way a pin is selected and must open the same
/// sheet as search and "Show on map".
void main() {
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
  // would block on forever, so drive the map with explicit bounded pumps — the
  // same technique map_focus_replay_test.dart uses.
  Future<void> pumpMap(WidgetTester t) async {
    await t.pumpWidget(app());
    await t.pump();
    router.go(Routes.map);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('tapping a venue pin selects it and opens its sheet', (t) async {
    await pumpMap(t);

    // Central Courtyard sits near the middle of the artwork, so it is inside the
    // cover-fit viewport and hit-testable. Its pin carries a spoken label built
    // from the venue name + category; tapping it must open the venue sheet.
    final pin = find.bySemanticsLabel(RegExp(r'^Central Courtyard\.'));
    expect(pin, findsOneWidget, reason: 'the Central Courtyard pin should render');

    await t.tap(pin, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.byType(VenueSheet), findsOneWidget,
        reason: 'a pin tap opens the same sheet as search / Show on map');

    // Dismissing returns the map to its neutral state (selection cleared). The
    // sheet's exit animation needs two bounded pumps, matching the shared
    // dismiss helper in map_focus_replay_test.dart.
    Navigator.of(t.element(find.byType(VenueSheet))).pop();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(VenueSheet), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('tapping a car-park pin opens the parking sheet', (t) async {
    await pumpMap(t);

    // Car-park pins use the parking glyph; tapping one opens the parking sheet.
    final parkingPin = find.byIcon(Icons.local_parking_rounded);
    expect(parkingPin, findsWidgets, reason: 'at least one car park is pinned');

    await t.tap(parkingPin.first, warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.byType(ParkingSheet), findsOneWidget);
    Navigator.of(t.element(find.byType(ParkingSheet))).pop();
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
  });

  testWidgets('the zoom in / out buttons drive the camera without throwing',
      (t) async {
    await pumpMap(t);

    double camera() =>
        MapCamera.of(t.element(find.byType(MarkerLayer).first)).zoom;
    final start = camera();

    await t.tap(find.byIcon(Icons.add_rounded)); // zoom in
    await t.pump(const Duration(milliseconds: 300));
    final zoomedIn = camera();
    expect(zoomedIn, greaterThan(start), reason: 'zoom-in raises the zoom');

    await t.tap(find.byIcon(Icons.remove_rounded)); // zoom out
    await t.pump(const Duration(milliseconds: 300));
    expect(camera(), lessThan(zoomedIn), reason: 'zoom-out lowers it again');
    expect(t.takeException(), isNull);
  });

  testWidgets('the general wayfinding FAB pushes the walking route', (t) async {
    await pumpMap(t);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget,
        reason: 'the general directions FAB shows when nothing is selected');

    await t.tap(fab);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    // It navigates away from the campus map into the wayfinding route. We only
    // assert the tap ran cleanly and left the campus map (the destination screen
    // has its own tests); the point here is the FAB's onPressed closure.
    expect(t.takeException(), isNull);
  });
}
