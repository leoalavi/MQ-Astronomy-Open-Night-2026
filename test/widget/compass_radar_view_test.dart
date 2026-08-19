import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/map_config.dart';
import '../support/fake_compass_controller.dart';

// ── pure helpers ──────────────────────────────────────────────────────────
void main() {
  test('blipRadiusFraction: near→center, far→rim, clamped, monotonic (§0R-7)', () {
    expect(blipRadiusFraction(0), lessThan(0.15));
    expect(blipRadiusFraction(MapConfig.compassFarClampMeters * 2), 1.0); // clamped
    expect(blipRadiusFraction(MapConfig.compassNearClampMeters), inInclusiveRange(0.0, 1.0));
    expect(blipRadiusFraction(50), lessThan(blipRadiusFraction(400))); // monotonic
  });

  test('clusterByBearing: near-collinear merge; wrap 359/1 merges; separated stay apart (§0R-8)',
      () {
    NearbyTarget t(double b) => NearbyTarget(
        placeKey: 'k$b', title: '$b', kind: PlaceKind.building, lat: 0, lng: 0,
        distanceMeters: 100, trueBearingDegrees: b, confidence: DataConfidence.confirmed);
    expect(clusterByBearing([t(45), t(47)], 8).length, 1); // near-collinear
    expect(clusterByBearing([t(359), t(1)], 8).length, 1); // wrap: 2° apart, not 358°
    expect(clusterByBearing([t(0), t(90), t(180)], 8).length, 3); // distinct
  });

  // ── widget: acquiring (null heading) must not spin or throw (§0R-C) ─────────
  testWidgets('acquiring + null heading → static hint, NO spinner, no exception', (t) async {
    final c = ProviderContainer(overrides: [
      compassControllerProvider.overrideWith(() => FakeCompassController(
          const CompassState(availability: HeadingAvailability.acquiring))),
      nearbyTargetsProvider.overrideWithValue(const []),
    ]);
    addTearDown(c.dispose);
    await _pump(t, c);
    expect(find.byType(CircularProgressIndicator), findsNothing); // §0R-C: never a spinner
    expect(t.takeException(), isNull);
  });

  testWidgets('locked target renders a marker (absolute frame) + no exception (§0R-1)', (t) async {
    const locked = NearbyTarget(
        placeKey: 'building:T', title: 'Tower', kind: PlaceKind.building,
        lat: -33.77, lng: 151.11, distanceMeters: 120, trueBearingDegrees: 90,
        confidence: DataConfidence.confirmed);
    final c = ProviderContainer(overrides: [
      compassControllerProvider.overrideWith(() => FakeCompassController(const CompassState(
          availability: HeadingAvailability.available,
          trueHeadingDegrees: 30,
          locked: locked,
          lockedTrueBearingDegrees: 90))),
      nearbyTargetsProvider.overrideWithValue(const [locked]),
    ]);
    addTearDown(c.dispose);
    await _pump(t, c);
    expect(find.byKey(const ValueKey('compass-locked-marker')), findsOneWidget);
    expect(t.takeException(), isNull);

    // Position, not just existence: bearing 90° on an N-up rose is due EAST, so
    // the marker sits to the RIGHT and on the horizontal centre-line. If the
    // layer regressed to a RELATIVE angle (bearing − heading = 60°) the marker
    // would ride well ABOVE centre — this assertion catches that (map audit P2).
    final viewCenter = t.getCenter(find.byType(CompassRadarView));
    final marker = t.getCenter(find.byKey(const ValueKey('compass-locked-marker')));
    expect(marker.dx, greaterThan(viewCenter.dx + 100)); // east of centre
    expect((marker.dy - viewCenter.dy).abs(), lessThan(40)); // on the E axis, not up (relative 60°)
  });
}

Future<void> _pump(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: CompassRadarView()),
    ),
  ));
  await t.pump();
}
