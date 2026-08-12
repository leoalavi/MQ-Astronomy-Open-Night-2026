import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

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

void main() {
  testWidgets('near fix -> circle + dot, camera MOVES to the fix, no banner',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _near());
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsWidgets); // venue pins + user dot
    expect(find.textContaining('from campus'), findsNothing);
    // Earns the follow claim: camera actually recentred onto the fix.
    expect(_cam(t).center.latitude, closeTo(_nearPoint.latitude, 1e-4));
  });

  testWidgets('far fix -> off-campus banner AND camera stays on campus',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _far());
    expect(find.textContaining('from campus'), findsOneWidget);
    expect(_cam(t).center.latitude,
        closeTo(MapConfig.campusCentre.latitude, 1e-4)); // did NOT fly away
  });

  testWidgets('low-accuracy fix -> dot, no circle, note, NO auto-recenter',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await _activateWith(t, c, svc, _lowAccNear());
    expect(find.byType(CircleLayer), findsNothing); // circle omitted
    expect(find.byType(MarkerLayer), findsWidgets); // dot still shown
    expect(find.textContaining('accuracy is low'), findsOneWidget);
    // A fuzzy fix must not yank the camera even though it's near campus.
    expect(_cam(t).center.latitude,
        closeTo(MapConfig.campusCentre.latitude, 1e-4));
  });

  testWidgets('user pan clears follow', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
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
    expect(find.textContaining('پردیس'), findsOneWidget); // FA "campus"
    expect(t.takeException(), isNull);
  });
}
