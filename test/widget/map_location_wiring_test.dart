import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

// Under CrsSimple the camera lives in map-units, not WGS84 degrees. The camera
// fit centres on the ARITHMETIC middle of the bounds (not LatLngBounds.center,
// which is a spherical midpoint). A follow moves to the PROJECTED fix.
//
// The fit frames the OFFICIAL AON artwork, whose footprint is a different crop
// of the same master than the MQ calibration frame — so this is derived from
// MapConfig.aonMapBounds, never from mapNorth/mapEast, which would silently
// drift from what the screen actually fits.
final _mapCentre = LatLng(
  (MapConfig.aonMapBounds.south + MapConfig.aonMapBounds.north) / 2,
  (MapConfig.aonMapBounds.west + MapConfig.aonMapBounds.east) / 2,
);

ProviderContainer _container(FakeLocationService svc) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true); // map is on-screen
  return c;
}

Widget _app(ProviderContainer c, {Locale? locale}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const MapScreen(),
      ),
    );

// The camera lives below FlutterMap — read it from any layer's element.
MapCamera _cam(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(MarkerLayer).first));

// ~111 m north of centre: distinct from the start, well inside campus bounds.
final _nearPoint = LatLng(
    MapConfig.campusCentre.latitude + 0.001, MapConfig.campusCentre.longitude);
UserLocationFix _near() =>
    UserLocationFix(position: _nearPoint, accuracyMeters: 10);
UserLocationFix _far() => UserLocationFix(
    position: LatLng(MapConfig.campusCentre.latitude + 0.05,
        MapConfig.campusCentre.longitude),
    accuracyMeters: 10);
UserLocationFix _lowAccNear() =>
    UserLocationFix(position: _nearPoint, accuracyMeters: 500);

Future<void> _activateWith(WidgetTester t, ProviderContainer c,
    FakeLocationService svc, UserLocationFix fix) async {
  await t.pumpWidget(_app(c));
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  svc.emit(fix);
  await t.pump(); // deliver stream event
  await t.pump(); // rebuild + apply follow move
}


// Zooms in before a follow, so the artwork is LARGER than the viewport and the
// camera is free to travel to the fix.
//
// At the opening fit zoom the whole campus is on screen, and the camera
// constraint deliberately keeps it that way — so a follow can only nudge the
// map a few points before the artwork would start leaving the frame. That is
// correct behaviour (the dot is already visible; panning would only reveal
// empty background), but it means "follow moves the camera ONTO the fix" is a
// claim that only makes sense zoomed in, which is when following actually
// matters.
Future<void> _zoomIn(WidgetTester t, double zoom) async {
  t.widget<FlutterMap>(find.byType(FlutterMap)).mapController!
      .move(_cam(t).center, zoom);
  await t.pump();
}

void main() {
  testWidgets('entering the Map tab requests location (no Locate tap needed)',
      (t) async {
    final svc = FakeLocationService(); // grants
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await t.pump(); // let the post-frame entry prompt run + resolve
    expect(svc.requestCount, 1); // prompted purely by entering the tab
    final s = c.read(locationControllerProvider);
    expect(s.active, isTrue); // dot goes live
    expect(s.following, isFalse); // opening campus-fit camera not hijacked
    // Camera untouched by the entry prompt (a fix would move it; none emitted).
    expect(_cam(t).center.latitude, closeTo(_mapCentre.latitude, 1.0));
  });

  testWidgets('denied on entry -> Map still renders and stays usable',
      (t) async {
    final svc = FakeLocationService(grant: LocationStatus.denied);
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await t.pump();
    expect(t.takeException(), isNull); // no crash, no blocked navigation
    expect(find.byType(FlutterMap), findsOneWidget); // map is fully present
    expect(c.read(locationControllerProvider).active, isFalse);
    // The map's controls remain interactive — Locate button is still there as
    // the deliberate retry/re-enable path.
    expect(svc.requestCount, 1);
  });

  testWidgets('entry prompt also fires under the Persian locale', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c, locale: const Locale('fa')));
    await t.pump();
    expect(svc.requestCount, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('near fix -> circle + dot, camera MOVES to the fix, no banner',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await _zoomIn(t, MapConfig.mapMaxZoom);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near());
    await t.pump();
    await t.pump();
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsWidgets); // venue pins + user dot
    expect(find.textContaining('from campus'), findsNothing);
    // Earns the follow claim: camera recentred onto the PROJECTED fix (map-units).
    final projected = const CampusProjection().project(GpsPoint(_nearPoint))!;
    expect(_cam(t).center.latitude, closeTo(projected.value.latitude, 0.5));
    expect(_cam(t).center.latitude, greaterThan(0)); // map-unit, never raw -33
  });

  testWidgets('far fix -> off-campus banner AND camera stays on campus',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _far());
    expect(find.textContaining('from campus'), findsOneWidget);
    // Far fix projects to null → no follow → camera stays at the map-centre fit.
    expect(_cam(t).center.latitude, closeTo(_mapCentre.latitude, 1.0));
    expect(_cam(t).center.longitude, closeTo(_mapCentre.longitude, 1.0));
  });

  testWidgets('low-accuracy fix -> dot, no circle, note, NO auto-recenter',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _lowAccNear());
    expect(find.byType(CircleLayer), findsNothing); // circle omitted
    expect(find.byType(MarkerLayer), findsWidgets); // dot still shown
    expect(find.textContaining('accuracy is low'), findsOneWidget);
    // A fuzzy fix must not yank the camera — stays at the map-centre fit.
    expect(_cam(t).center.latitude, closeTo(_mapCentre.latitude, 1.0));
    expect(_cam(t).center.longitude, closeTo(_mapCentre.longitude, 1.0));
  });

  testWidgets('user pan clears follow', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    // Zoomed in, so the drag genuinely moves the camera: at fit zoom the
    // constraint holds the fully-visible artwork in place and there is no
    // position change for the pan handler to react to.
    await _zoomIn(t, MapConfig.mapMaxZoom);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    expect(c.read(locationControllerProvider).following, isTrue);
    await t.drag(find.byType(FlutterMap), const Offset(-60, 0));
    await t.pump();
    expect(c.read(locationControllerProvider).following, isFalse);
  });

  testWidgets('off-campus banner has no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _far());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('off-campus banner renders under FA locale', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c, locale: const Locale('fa')));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_far());
    await t.pump();
    await t.pump();
    // "کیلومتر با پردیس فاصله دارید" — the distance banner specifically. Plain
    // 'پردیس' now also matches the campus-map attribution added in Task 5.
    expect(find.textContaining('فاصله دارید'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
