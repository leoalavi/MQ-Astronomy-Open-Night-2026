import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/compass_mode_view.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/nearby_list.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

const _fix = LatLng(-33.7737, 151.1134);

BuildingEntry _b(String id, double lat, {String? name}) => BuildingEntry(Building(
    id: id, code: id, name: name ?? id, category: BuildingCategory.academic,
    latitude: lat, longitude: 151.1134, campusX: 1, campusY: 1));

ProviderContainer _c(FakeHeadingService h, FakeLocationService l,
    {List<SearchEntry> index = const []}) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(l),
    searchIndexProvider.overrideWithValue(index),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _pump(WidgetTester t, ProviderContainer c) {
  // CompassModeView is only ever shown on the Map tab, so the heading sensor's
  // on-screen gate (compassVisible && mapVisible) needs mapVisible true here.
  c.read(mapVisibleProvider.notifier).set(true);
  return t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: CompassModeView()),
      ),
    ),
  );
}

Future<AonL10n> _en() => AonL10n.delegate.load(const Locale('en'));

void main() {
  testWidgets('B4: fresh entry (Locate never tapped, granted) → auto-activates → targets appear',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('near', -33.7738, name: 'Library')]);
    await _pump(t, c);
    await t.pumpAndSettle(); // post-frame ensureLocationActive() activates
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget); // targets rendered without a pre-seeded fix
  });

  testWidgets('§0-L: denied → Enable-location affordance; retry works (not a dead end)', (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.denied);
    final c = _c(h, l);
    await _pump(t, c);
    await t.pumpAndSettle();
    final en = await _en();
    expect(find.text(en.compassEnableLocation), findsOneWidget); // NOT a silent dead compass
    l.grant = LocationStatus.granted; // user enables in settings
    await t.tap(find.text(en.compassEnableLocation));
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    expect(find.text(en.compassEnableLocation), findsNothing); // retry activated
  });

  testWidgets('§0-A: heading available → rose AND list coexist', (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('near', -33.7738)]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle(); // controller instantiates + subscribes before heading emit
    h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();
    expect(find.byType(CompassRadarView), findsOneWidget);
    expect(find.byType(NearbyList), findsOneWidget);
  });

  testWidgets(
      'heading unavailable → north-up rose STILL renders (graphic never vanishes) + honest note',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('near', -33.7738)]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle(); // controller subscribes before heading emit
    h.emit(const HeadingSample(availability: HeadingAvailability.unavailable));
    await t.pumpAndSettle();
    final en = await _en();
    // The rose is north-up with ABSOLUTE bearings — it does not need a heading to
    // be meaningful (only the facing arrow does, and that null-guards). So a
    // device with no magnetometer keeps the compass graphic instead of collapsing
    // to a bare list (field report, Pouya 2026-08-28: "compass disappears").
    expect(find.byType(CompassRadarView), findsOneWidget,
        reason: 'the north-up rose must persist when heading is unavailable');
    expect(find.byType(NearbyList), findsOneWidget,
        reason: 'the list stays as the canonical a11y path (§0R-9)');
    expect(find.text(en.compassUnavailable), findsOneWidget,
        reason: 'and an honest note explaining why the facing arrow is missing');
  });

  testWidgets(
      'MAP #1: rose survives leaving and returning to the Map tab (no disappear)',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('near', -33.7738)]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();
    expect(find.byType(CompassRadarView), findsOneWidget);

    // Leave the Map tab (main-tab switch): the branch stays mounted in the shell
    // IndexedStack, so only mapVisible flips false, then true on return.
    c.read(mapVisibleProvider.notifier).set(false);
    await t.pumpAndSettle();
    c.read(mapVisibleProvider.notifier).set(true);
    await t.pumpAndSettle();
    // Even with NO fresh heading sample yet (re-subscribe → acquiring), the rose
    // is on screen — it never blanks to a bare list.
    expect(find.byType(CompassRadarView), findsOneWidget,
        reason: 'the compass graphic must survive a tab round-trip');
  });

  testWidgets('sets compassVisible on entry, clears it on dispose (captured notifier, no crash)',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await _pump(t, c);
    await t.pumpAndSettle();
    expect(c.read(compassVisibleProvider), isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(c.read(compassVisibleProvider), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('§0-J: typing in the filter narrows the visible set', (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('lib', -33.7738, name: 'Library'), _b('gym', -33.7739, name: 'Gymnasium')]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Gymnasium'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'lib');
    await t.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Gymnasium'), findsNothing); // narrowed via compassFilterProvider
  });

  testWidgets('§0-K a11y: 320×568 / 2.0 — last list row reachable + tappable → locks', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final index = [for (var i = 0; i < 12; i++) _b('b$i', -33.7737 - i * 0.0006, name: 'Place$i')];
    final c = _c(h, l, index: index);
    c.read(mapVisibleProvider.notifier).set(true); // Map tab on-screen (heading gate)
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: Scaffold(body: CompassModeView()),
        ),
      ),
    ));
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle(); // controller subscribes before heading emit
    h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();
    final last = find.text('Place11');
    await t.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(last);
    await t.pumpAndSettle();
    await t.tap(last);
    await t.pumpAndSettle();
    expect(c.read(compassLockedProvider), 'building:b11'); // reachable + tappable
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'MAP #2: tapping a target row highlights it as selected + toggles off on re-tap',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    final c = _c(h, l, index: [_b('lib', -33.7738, name: 'Library')]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();

    // Before any tap, no row is selected.
    ListTile tileFor(String title) =>
        t.widget<ListTile>(find.ancestor(of: find.text(title), matching: find.byType(ListTile)));
    expect(tileFor('Library').selected, isFalse);

    await t.tap(find.text('Library'));
    await t.pumpAndSettle();
    expect(c.read(compassLockedProvider), 'building:lib',
        reason: 'tap aims the compass at the place (locks it)');
    expect(tileFor('Library').selected, isTrue,
        reason: 'and the row is visibly highlighted as the current target');

    // Re-tapping the SAME row clears the aim (not a one-way trap).
    await t.tap(find.text('Library'));
    await t.pumpAndSettle();
    expect(c.read(compassLockedProvider), isNull);
    expect(tileFor('Library').selected, isFalse);
  });

  testWidgets('§0R-8: a numbered cluster shows the "what the number means" legend',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    // Two buildings on the SAME bearing (both due north) cluster into one blip
    // showing "2" — exactly the number a field tester could not interpret.
    final c = _c(h, l, index: [
      _b('n1', -33.7730, name: 'North A'),
      _b('n2', -33.7728, name: 'North B'),
    ]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();

    final en = await _en();
    expect(find.text(en.compassClusterLegend), findsOneWidget,
        reason: 'a numbered blip must carry its explanation');
  });

  testWidgets('the legend is absent when every place has its own bearing',
      (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService(grant: LocationStatus.granted);
    // One target → no cluster count → nothing to explain.
    final c = _c(h, l, index: [_b('solo', -33.7730, name: 'Solo')]);
    await _pump(t, c);
    await t.pumpAndSettle();
    l.emit(UserLocationFix(position: _fix, accuracyMeters: 8));
    await t.pumpAndSettle();
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pumpAndSettle();

    final en = await _en();
    expect(find.text(en.compassClusterLegend), findsNothing);
  });
}
