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
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';
import '../support/map_harness.dart';

const _proj = CampusProjection();

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

final _nearPoint = LatLng(
    MapConfig.campusCentre.latitude + 0.001, MapConfig.campusCentre.longitude);
UserLocationFix _near() =>
    UserLocationFix(position: _nearPoint, accuracyMeters: 10);
UserLocationFix _far() => UserLocationFix(
    position: LatLng(MapConfig.campusCentre.latitude + 0.05,
        MapConfig.campusCentre.longitude),
    accuracyMeters: 10);

Widget _appL(ProviderContainer c, Locale locale) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const MapScreen(),
      ),
    );

// ~523 m from centre (near campus) but NORTH of the calibrated footprint, so it
// is projectable == false → exercises the off-illustration note.
const _nearOffFootprint = LatLng(-33.7690, 151.1134);
UserLocationFix _nearOff() =>
    UserLocationFix(position: _nearOffFootprint, accuracyMeters: 10);

MapCamera _cam(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(MarkerLayer).first));

Future<void> _activate(WidgetTester t, ProviderContainer c,
    FakeLocationService svc, UserLocationFix fix) async {
  await t.pumpWidget(_app(c));
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  svc.emit(fix);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('near fix: base + dot render; ALL markers inside map bounds',
      (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await _activate(t, c, svc, _near());
    expect(find.byType(CampusBasemapLayer), findsOneWidget);
    expect(find.byType(UserLocationDot), findsOneWidget);
    // Pin: no marker is stranded at raw WGS84 (-33,151) — every point is a
    // CrsSimple map-unit inside the campus bounds. Catches "left unprojected".
    for (final layer in t.widgetList<MarkerLayer>(find.byType(MarkerLayer))) {
      for (final m in layer.markers) {
        expect(MapConfig.mapBounds.contains(m.point), isTrue,
            reason: 'stranded marker at ${m.point}');
      }
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('active + null fix → no crash, no dot', (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    await t.pump(); // active, but no fix emitted yet
    expect(find.byType(UserLocationDot), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('off-footprint fix → no dot (not a clamped edge dot)', (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await _activate(t, c, svc, _far()); // 5.5 km away → projects to null
    expect(_proj.project(GpsPoint(_far().position)), isNull); // fixture guard
    expect(find.byType(UserLocationDot), findsNothing);
  });

  testWidgets('follow-me moves the camera to the PROJECTED point, not raw',
      (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await _activate(t, c, svc, _near());
    final expected = _proj.project(GpsPoint(_nearPoint))!.value;
    expect(_cam(t).center.latitude, closeTo(expected.latitude, 0.5));
    expect(_cam(t).center.latitude, greaterThan(0)); // map-units, never -33
  });

  testWidgets('panorama toggle still switches modes', (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await t.pumpWidget(_app(c));
    await t.tap(find.text('360°'));
    await t.pumpAndSettle();
    expect(find.byType(CampusBasemapLayer), findsNothing); // left the map
    expect(t.takeException(), isNull);
  });

  // ── Task 10: off-illustration note (EN + FA) + viewport matrix ──

  testWidgets('fixture guard: near campus AND off the footprint', (t) async {
    expect(MapConfig.isNearCampus(const GpsPoint(_nearOffFootprint)), isTrue);
    expect(_proj.canProject(const GpsPoint(_nearOffFootprint)), isFalse);
  });

  testWidgets('off-illustration note shows (EN), 320x568 / 2.0, no overflow',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await _activate(t, c, svc, _nearOff());
    expect(find.byType(UserLocationDot), findsNothing); // not a fake dot
    expect(find.textContaining('campus map'), findsOneWidget); // EN note
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('off-illustration note renders under FA', (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await t.pumpWidget(_appL(c, const Locale('fa')));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_nearOff());
    await t.pump();
    await t.pump();
    expect(find.textContaining('یافتن'), findsOneWidget); // FA "locating" (unique)
    expect(t.takeException(), isNull);
  });

  testWidgets('camera viewport matrix: framed + zoom in range', (t) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final size in const [Size(320, 568), Size(1280, 800), Size(390, 844)]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      final svc = FakeLocationService();
      final c = mapContainer(svc);
      await t.pumpWidget(_app(c));
      await t.pump();
      final cam = _cam(t);
      expect(cam.zoom,
          inInclusiveRange(MapConfig.mapMinZoom, MapConfig.mapMaxZoom),
          reason: 'zoom out of range at $size');
      expect(MapConfig.mapBounds.contains(cam.center), isTrue,
          reason: 'camera off the campus map at $size');
      expect(t.takeException(), isNull);
    }
  });
}
