import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/map_config.dart';
import '../support/fake_location_service.dart';
import '../support/map_harness.dart';

// MAP-001 regression. The follow-me recenter listener runs on EVERY location
// update, unconditionally, at the top of MapScreen.build. In 360°/Compass mode
// the FlutterMap is replaced (unmounted) by an if/else, so its MapController is
// detached — and `MapController.camera` / `.move` throw once the map is gone.
// `following` is NOT cleared by a mode switch (only a user pan, or leaving the
// Map tab, clears it). So a fix that arrives after the user has switched away
// from the map while following was on must NOT touch the controller.

final _p0 = LatLng(
    MapConfig.campusCentre.latitude + 0.001, MapConfig.campusCentre.longitude);
UserLocationFix _fix(double dLat) => UserLocationFix(
    position: LatLng(_p0.latitude + dLat, _p0.longitude), accuracyMeters: 10);

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

void main() {
  testWidgets(
      'a fix arriving after switching to 360° (FlutterMap unmounted) with '
      'follow-me ON must not touch the detached controller', (t) async {
    final svc = FakeLocationService();
    final c = mapContainer(svc);
    await t.pumpWidget(_app(c));

    // Follow-me ON in campus-map mode; the first fix recenters fine.
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_fix(0));
    await t.pump();
    await t.pump();
    expect(c.read(locationControllerProvider).following, isTrue);

    // Leave the map: 360° replaces the FlutterMap, detaching its controller.
    await t.tap(find.text('360°'));
    await t.pumpAndSettle();
    expect(find.byType(CampusBasemapLayer), findsNothing);

    // A new, sharper-or-moved fix arrives while following is still on.
    svc.emit(_fix(0.0003)); // ~33 m north → adopted, listener fires
    await t.pump();
    await t.pump();

    expect(t.takeException(), isNull,
        reason: 'follow-me must be gated to campus-map mode; a fix in 360° '
            'mode must not read/move the detached FlutterMap controller');
  });
}
