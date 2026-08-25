import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

import '../support/fake_location_service.dart';
import '../support/map_harness.dart';

/// App Review, Cupertino. The app must be exercisable from there.
const _cupertino = LatLng(37.3349, -122.0090);

/// A fix on campus, ~111 m north of the centre — the positive control for
/// every "off campus hides the dot" claim below. Without it those tests would
/// also pass if the dot were broken everywhere.
final _onCampus = LatLng(
    MapConfig.campusCentre.latitude + 0.001, MapConfig.campusCentre.longitude);

/// Off-campus fixes at wildly different bearings and distances. A projection
/// that clamped rather than rejected would betray itself by mapping these to
/// the artwork's edge instead of to null.
const _offCampus = <(String, LatLng)>[
  ('Sydney Opera House', LatLng(-33.8568, 151.2153)),
  ('Sydney Airport', LatLng(-33.9399, 151.1753)),
  ('Parramatta', LatLng(-33.8150, 151.0000)),
  ('Cupertino', _cupertino),
  ('the North Pole', LatLng(90.0, 0.0)),
];

/// Pumps MapScreen, activates location, and delivers [fix] (null = permission
/// granted but no fix ever arrives).
Future<ProviderContainer> _pumpWithFix(
  WidgetTester t,
  LatLng? fix, {
  FakeLocationService? service,
}) async {
  final svc = service ?? FakeLocationService();
  final c = mapContainer(svc);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: MapScreen(),
    ),
  ));
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  if (fix != null) {
    svc.emit(UserLocationFix(position: fix, accuracyMeters: 10));
  }
  await t.pump();
  await t.pump();
  return c;
}

/// This file exists because revisions 1-4 of the release plan claimed the
/// position dot "silently vanishes with no explanation" off campus. It does
/// not: map_screen.dart already renders the distance note. These tests pin that
/// so nobody "fixes" it into existence twice.
void main() {
  test('a Cupertino fix is neither near campus nor projectable', () {
    expect(MapConfig.isNearCampus(const GpsPoint(_cupertino)), isFalse);
    expect(const CampusProjection().canProject(const GpsPoint(_cupertino)),
        isFalse);
  });

  testWidgets('a Cupertino fix shows the distance note, not a fake dot',
      (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    ));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(UserLocationFix(position: _cupertino, accuracyMeters: 10));
    await t.pump();
    await t.pump();

    expect(find.byType(UserLocationDot), findsNothing,
        reason: 'never a fake dot clamped to the edge of the artwork');
    expect(find.textContaining('km from campus'), findsOneWidget,
        reason: 'App Review must see a deliberate, explained state — not an '
            'absence that reads as a bug');
    expect(t.takeException(), isNull);
  });

  // ── The campus-boundary contract for the position dot ────────────────────
  //
  // The dot is drawn from `CampusProjection.project`, which returns null
  // outside the calibrated artwork. These tests prove that is a real guarantee
  // and not an accident of the two fixtures above: an off-campus visitor must
  // never see their position implied anywhere on the illustrated campus map.

  group('the dot follows the campus boundary', () {
    testWidgets('an ON-campus fix DOES show the marker (positive control)',
        (t) async {
      await _pumpWithFix(t, _onCampus);
      expect(find.byType(UserLocationDot), findsOneWidget,
          reason: 'the dot must work on campus, or the tests below prove '
              'nothing');
      expect(find.byType(UserLocationCircle), findsOneWidget,
          reason: 'the accuracy circle accompanies the dot');
      expect(t.takeException(), isNull);
    });

    for (final (name, point) in _offCampus) {
      testWidgets('$name: no marker, and the fix is REJECTED not clamped',
          (t) async {
        // The projection's own contract first — this is the mechanism.
        final projected = const CampusProjection().project(GpsPoint(point));
        expect(projected, isNull,
            reason: '$name projected to $projected instead of being refused; '
                'a clamped value would paint the visitor onto the artwork');

        await _pumpWithFix(t, point);
        expect(find.byType(UserLocationDot), findsNothing);
        expect(find.byType(UserLocationCircle), findsNothing,
            reason: 'an accuracy circle is a position claim too');
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('the boundary is genuinely a boundary, not a coincidence',
        (t) async {
      // Walk north from the campus centre until the projection refuses. There
      // must BE such a point (otherwise nothing is bounded) and it must be
      // local to campus rather than hundreds of kilometres away.
      const proj = CampusProjection();
      double? refusedAt;
      for (var d = 0.0; d <= 0.05; d += 0.0005) {
        final p = LatLng(MapConfig.campusCentre.latitude + d,
            MapConfig.campusCentre.longitude);
        if (!proj.canProject(GpsPoint(p))) {
          refusedAt = d;
          break;
        }
      }
      expect(refusedAt, isNotNull,
          reason: 'the projection accepted every point for 5 km north — it is '
              'not bounded at all');
      expect(refusedAt, lessThan(0.02),
          reason: 'the campus footprint should end within ~2 km of centre');
    });
  });

  group('the map degrades gracefully without a position', () {
    testWidgets('centring on an off-campus user leaves the camera on campus',
        (t) async {
      await _pumpWithFix(t, _cupertino);
      // The follow-me request is honoured as far as it honestly can be: no dot,
      // an explanatory note, and a camera still framed on the artwork rather
      // than flung to California.
      final camera = MapCamera.of(t.element(find.byType(MarkerLayer).first));
      expect(camera.center.latitude, greaterThan(0),
          reason: 'CrsSimple map-units, never a raw -33/37 degree latitude');
      expect(MapConfig.aonMapBounds.contains(camera.center), isTrue,
          reason: 'the camera wandered off the campus artwork');
      expect(t.takeException(), isNull);
    });

    testWidgets('permission denied: no crash, no dot, no phantom position',
        (t) async {
      await _pumpWithFix(t, null,
          service: FakeLocationService(grant: LocationStatus.denied));
      expect(find.byType(UserLocationDot), findsNothing);
      expect(find.byType(UserLocationCircle), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('permanently denied: still no crash and no dot', (t) async {
      await _pumpWithFix(t, null,
          service: FakeLocationService(grant: LocationStatus.deniedForever));
      expect(find.byType(UserLocationDot), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('granted but no fix ever arrives: no crash, no dot', (t) async {
      await _pumpWithFix(t, null);
      expect(find.byType(UserLocationDot), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
