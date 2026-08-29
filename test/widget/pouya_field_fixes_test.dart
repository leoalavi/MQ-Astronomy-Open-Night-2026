import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';
import 'package:aon2026/widgets/user_location_layer.dart';
import '../support/fake_compass_controller.dart';

// Field fixes from Pouya's 28 Aug on-device testing (voice notes + screenshots):
//   1. The user-location dot/circle was amber (accent) — he asked for the
//      conventional BLUE "you are here" indicator.
//   2. The 360° picker's last card ("I · 17 Wally's Walk") hid behind the
//      floating glass tab bar — it never reserved the nav clearance the compass
//      list already does.
//   3. The compass rose showed targets' bearings but no marker for the user's
//      OWN position at the centre, so the facing pin at the rim read as
//      "a person over there".

const _proj = CampusProjection();
const _gps = LatLng(-33.7737, 151.1134);
final _centre = _proj.project(const GpsPoint(_gps))!;

Widget _mapHost(Widget child) => MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            crs: const CrsSimple(),
            initialCenter: _centre.value,
            initialZoom: -3.4,
            minZoom: -5,
            maxZoom: 0,
          ),
          children: [child],
        ),
      ),
    );

void main() {
  group('location indicator is the conventional blue, not amber', () {
    testWidgets('the dot centre uses mapUserLocation (blue), never accent',
        (t) async {
      await t.pumpWidget(_mapHost(UserLocationDot(center: _centre)));
      await t.pump();
      final colors = t
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();
      expect(colors, contains(AonPalette.light.mapUserLocation));
      expect(colors, isNot(contains(AonPalette.light.accent)));
    });

    testWidgets('the accuracy circle is tinted from mapUserLocation', (t) async {
      final fix = UserLocationFix(position: _gps, accuracyMeters: 15);
      await t.pumpWidget(
          _mapHost(UserLocationCircle(center: _centre, fix: fix)));
      await t.pump();
      final circle =
          t.widget<CircleLayer>(find.byType(CircleLayer)).circles.single;
      expect(circle.borderColor.withValues(alpha: 1.0),
          AonPalette.light.mapUserLocation);
    });
  });

  testWidgets('360° picker reserves clearance for the floating tab bar',
      (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: Scaffold(body: PanoramaBuildingPicker(onOpen: (_) {})),
      ),
    ));
    await t.pump();
    final padding = t
        .widget<ListView>(find.byType(ListView))
        .padding!
        .resolve(TextDirection.ltr);
    // Must clear the floating island, like NearbyList already does — well above
    // the old uniform space4.
    expect(padding.bottom, greaterThanOrEqualTo(AonNavMetrics.barHeight));
  });

  testWidgets('compass rose shows a "you are here" marker at the centre',
      (t) async {
    const target = NearbyTarget(
        placeKey: 'building:T',
        title: 'Tower',
        kind: PlaceKind.building,
        lat: -33.77,
        lng: 151.11,
        distanceMeters: 120,
        trueBearingDegrees: 90,
        confidence: DataConfidence.confirmed);
    final c = ProviderContainer(overrides: [
      compassControllerProvider.overrideWith(() => FakeCompassController(
          const CompassState(
              availability: HeadingAvailability.available,
              trueHeadingDegrees: 30))),
      nearbyTargetsProvider.overrideWithValue(const [target]),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: CompassRadarView()),
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('compass-you-marker')), findsOneWidget);
    // It sits at the rose centre (that IS the user's position).
    final viewCenter = t.getCenter(find.byType(CompassRadarView));
    final you = t.getCenter(find.byKey(const ValueKey('compass-you-marker')));
    expect((you.dx - viewCenter.dx).abs(), lessThan(20));
    expect((you.dy - viewCenter.dy).abs(), lessThan(20));
  });
}
