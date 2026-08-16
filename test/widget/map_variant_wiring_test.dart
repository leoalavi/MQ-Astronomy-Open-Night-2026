import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

ProviderContainer _container(FakeLocationService svc) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

// A near, on-footprint fix — the M1 suite proves this renders a dot, so the
// "dot survives" assertion below is non-vacuous.
UserLocationFix _near() => UserLocationFix(
    position: LatLng(MapConfig.campusCentre.latitude + 0.001,
        MapConfig.campusCentre.longitude),
    accuracyMeters: 10);

MapCamera _cam(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(MarkerLayer).first));

String _basemapAsset(WidgetTester t) {
  final layer = t.widget<OverlayImageLayer>(find.descendant(
      of: find.byType(CampusBasemapLayer),
      matching: find.byType(OverlayImageLayer)));
  // imageProvider is declared on BaseOverlayImage (overlay_image.dart:10), so
  // no cast to the OverlayImage subtype is needed.
  final img = layer.overlayImages.single;
  return (img.imageProvider as AssetImage).assetName;
}

// Total markers across every MarkerLayer (venue pins + the dot's own layer).
int _markerCount(WidgetTester t) => t
    .widgetList<MarkerLayer>(find.byType(MarkerLayer))
    .fold(0, (sum, l) => sum + l.markers.length);

// The picker's own scrollable (not the map's or filter bar's).
Finder _sheetScroll() => find.descendant(
    of: find.byType(CampusVariantPicker), matching: find.byType(Scrollable));

void main() {
  testWidgets('Layers button opens the picker sheet', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    await t.tap(find.byTooltip('Map layers'));
    await t.pumpAndSettle();
    expect(find.byType(CampusVariantPicker), findsOneWidget);
  });

  testWidgets('variant swap keeps the dot, accuracy circle AND every marker',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near());
    await t.pump();
    await t.pump();
    expect(find.byType(UserLocationDot), findsOneWidget);    // dot pre-swap
    expect(find.byType(UserLocationCircle), findsOneWidget); // accuracy circle pre-swap
    expect(_basemapAsset(t), CampusVariantsData.baseAsset);
    final markersBefore = _markerCount(t);
    expect(markersBefore, greaterThan(0)); // non-vacuous: markers actually exist
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.parking);
    await t.pump();
    expect(_basemapAsset(t), 'assets/maps/overlay_parking_dark.png'); // ink changed
    expect(find.byType(UserLocationDot), findsOneWidget);            // dot survived
    expect(find.byType(UserLocationCircle), findsOneWidget);         // circle survived
    expect(_markerCount(t), markersBefore);       // same COUNT — not just "a layer"
    expect(t.takeException(), isNull);
  });

  testWidgets('variant swap preserves camera + zoom + FOLLOW + accuracy circle',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near()); // active + following, on-footprint → dot + circle
    await t.pump();
    await t.pump();
    // Move OFF the fit so "unchanged" is a real assertion, not fit==fit. A
    // programmatic move fires onPositionChanged with hasGesture:false, so it
    // does NOT cancel follow.
    await t.tap(find.byTooltip('Zoom in'));
    await t.pump();
    final before = _cam(t);
    final followBefore = c.read(locationControllerProvider).following;
    expect(followBefore, isTrue); // precondition: we ARE following
    expect(find.byType(UserLocationCircle), findsOneWidget);
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.water);
    await t.pump();
    final after = _cam(t);
    expect(after.zoom, before.zoom); // no re-fit on variant change
    expect(after.center.latitude, before.center.latitude);
    expect(after.center.longitude, before.center.longitude);
    expect(c.read(locationControllerProvider).following, followBefore); // follow intact
    expect(find.byType(UserLocationCircle), findsOneWidget);            // circle intact
    expect(_basemapAsset(t), 'assets/maps/overlay_water_dark.png');     // only ink changed
  });

  testWidgets('Layers button is exactly one "Map layers" button semantics node',
      (t) async {
    final handle = t.ensureSemantics();
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    // Exactly one control (no duplicate wrapping Semantics — it's a bare
    // IconButton). getSemantics() itself throws if the finder resolves to
    // ambiguous/duplicate semantics nodes, so this IS the single-node guard.
    expect(find.byTooltip('Map layers'), findsOneWidget);
    final node = t.getSemantics(find.byTooltip('Map layers'));
    expect(node.flagsCollection.isButton, isTrue);
    // Flutter exposes an icon-only button's tooltip as the semantics `tooltip`
    // (announced by TalkBack/VoiceOver); the localised name lives there.
    expect(node.tooltip, 'Map layers');
    handle.dispose();
  });

  testWidgets('Layers button hidden in panorama mode', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.tap(find.text('360°'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Map layers'), findsNothing);
  });

  testWidgets(
      'real modal at 320x568 / 2.0: open → scroll to last → select → LAYER swaps',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    await t.tap(find.byTooltip('Map layers'));
    await t.pumpAndSettle();
    // Drinking water is the BOTTOM row — Parking sits near the top and would
    // pass even if the sheet were clipped at 320×568/2.0.
    final target = find.text('Drinking water');
    await t.scrollUntilVisible(target, 100, scrollable: _sheetScroll());
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pump();
    // Full path in ONE test: button → sheet → controller → basemap layer.
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
    expect(_basemapAsset(t), 'assets/maps/overlay_water_dark.png');
    expect(t.takeException(), isNull);
  });
}
