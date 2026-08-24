import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/walking_route.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/widgets/embedded_map.dart';

/// Records that it was asked to render, without needing a platform view.
class _RecordingSurface implements EmbeddedMapSurface {
  int builds = 0;

  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) {
    builds++;
    return const SizedBox(key: Key('fake-google-surface'));
  }
}

class _Initializer implements MapsSdkInitializer {
  _Initializer(this.ready);
  final bool ready;

  @override
  Future<bool> ensureInitialized() async => ready;

  @override
  Future<String?> openSourceLicenseInfo() async => null;

  @override
  Future<String> resolveKey() async => '';
}

const _route = WalkingRoute(
  id: 'r1',
  fromId: 'p1',
  toId: 'v1',
  fromLabel: 'Car park',
  toLabel: 'Observatory',
  steps: [RouteStep(instruction: 'Walk toward the lit path.')],
  points: [LatLng(-33.7738, 151.1126), LatLng(-33.7745, 151.1133)],
  pathConfidence: DataConfidence.confirmed,
);

ProviderContainer _container(MapsConsent seed, {bool sdkReady = true}) {
  final c = ProviderContainer(overrides: [
    mapsConsentSnapshotProvider.overrideWithValue(seed),
    mapsSdkInitializerProvider.overrideWithValue(_Initializer(sdkReady)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('without consent no Google surface is built', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.unknown);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pump();

    expect(surface.builds, 0,
        reason: 'spec §2b: no Google surface may initialise before consent');
    expect(find.byKey(const Key('fake-google-surface')), findsNothing);
  });

  testWidgets('with accepted consent the Google surface is built', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.accepted);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, greaterThan(0));
    expect(find.byKey(const Key('fake-google-surface')), findsOneWidget);
  });

  testWidgets('declined consent leaves the written steps reachable', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.declined);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pump();

    expect(surface.builds, 0);
    // The map is a supporting visual; declining must not leave a blank gap that
    // reads as a bug. A placeholder stands in and says so.
    expect(find.byKey(const Key('wayfinding-map-declined')), findsOneWidget);
  });

  testWidgets('an unkeyed SDK yields no wayfinding Google surface', (t) async {
    final surface = _RecordingSurface();
    // Consent given, but the platform refuses to key the SDK (no secret file).
    final c = _container(MapsConsent.accepted, sdkReady: false);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, 0,
        reason: 'consent alone is not enough — the SDK must be keyed');
    expect(find.byKey(const Key('wayfinding-map-declined')), findsOneWidget);
  });
}
