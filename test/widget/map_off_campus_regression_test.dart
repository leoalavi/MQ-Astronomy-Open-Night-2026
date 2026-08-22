import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

import '../support/fake_location_service.dart';
import '../support/map_harness.dart';

/// App Review, Cupertino. The app must be exercisable from there.
const _cupertino = LatLng(37.3349, -122.0090);

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
}
