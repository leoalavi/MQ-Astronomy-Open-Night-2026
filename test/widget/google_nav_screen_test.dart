import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/screens/google_nav_screen.dart';
import 'package:aon2026/services/external_maps_launcher.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/embedded_map.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';

const _key = 'building:TEST';

class _StubService implements RoutesService {
  _StubService(this.result);
  final RouteResult result;
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({required (double, double) origin, required (double, double) destination}) async {
    calls++;
    return result;
  }
}

class _FakeLauncher implements ExternalMapsLauncher {
  Uri? opened;
  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return true;
  }
}

/// Launcher that reports failure (no Maps app / launch refused).
class _FailLauncher implements ExternalMapsLauncher {
  @override
  Future<bool> open(Uri uri) async => false;
}

class _FakeSurface implements EmbeddedMapSurface {
  @override
  Widget build({
    required GeoBounds bounds,
    required (double, double) origin,
    required (double, double) destination,
    required List<(double, double)> route,
  }) =>
      const SizedBox(key: Key('map-surface'));
}

const _resolved = AsyncData<ResolvedPlace?>(ResolvedPlace(
  kind: PlaceKind.building,
  placeKey: _key,
  title: 'Test Hall',
  subtitle: 'T1',
  renderPoint: null,
  routingLat: -33.78,
  routingLng: 151.12,
));

Widget _app(ProviderContainer c, {EmbeddedMapSurface? surface}) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: GoogleNavScreen(placeKey: _key, surface: surface ?? _FakeSurface()),
      ),
    );

class _ReadyMapsSdk implements MapsSdkInitializer {
  const _ReadyMapsSdk(this.ready);
  final bool ready;
  @override
  Future<bool> ensureInitialized() async => ready;
  @override
  Future<String?> openSourceLicenseInfo() async => null;

  @override
  Future<String> resolveKey() async => '';
}

ProviderContainer _c({
  required _StubService service,
  MapsConsent consent = MapsConsent.accepted,
  (double, double)? origin = const (-33.77, 151.11),
  bool enabled = true,
  ExternalMapsLauncher? launcher,
  bool sdkReady = true,
  AsyncValue<ResolvedPlace?> resolved = _resolved,
  NavOrigin? navOrigin,
}) {
  final c = ProviderContainer(overrides: [
    googleNavEnabledProvider.overrideWithValue(enabled),
    // Task 1 deferred GMSServices.provideAPIKey off app launch, so rendering a
    // Google surface now needs a KEYED SDK as well as consent. The default
    // initialiser fails closed, so these tests must say the SDK is ready.
    mapsSdkInitializerProvider.overrideWithValue(_ReadyMapsSdk(sdkReady)),
    mapsConsentSnapshotProvider.overrideWithValue(consent),
    placeResolverProvider(_key).overrideWithValue(resolved),
    // origin == null models "no permission / no fix"; a coordinate models an
    // on-campus fix. `navOrigin`, when supplied, is used verbatim (the
    // off-campus case).
    navOriginProvider.overrideWith((ref) async =>
        navOrigin ??
        (origin == null ? const NavOriginUnavailable() : NavOriginOnCampus(origin))),
    routesServiceProvider.overrideWith((ref) => service),
    externalMapsLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<AonL10n> _en() => AonL10n.delegate.load(const Locale('en'));

void main() {
  testWidgets('capability off → unavailable panel (no routing)', (t) async {
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, enabled: false)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavUnavailable), findsOneWidget);
    expect(svc.calls, 0);
  });

  testWidgets('success → map surface + distance/ETA + walking warning (Google mandate)', (t) async {
    final svc = _StubService(const RouteSuccess(NavRoute(
      polyline: [(-33.77, 151.11), (-33.78, 151.12)],
      distanceMeters: 412,
      eta: Duration(minutes: 6),
      warnings: [],
    )));
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.byKey(const Key('map-surface')), findsOneWidget);
    expect(find.textContaining('412 m'), findsOneWidget);
    expect(find.textContaining('6 min'), findsOneWidget);
    expect(find.text(l.mapNavWalkingWarning), findsOneWidget); // #13
  });

  testWidgets('Google-supplied route warnings are rendered on success (ToS display gap)', (t) async {
    final svc = _StubService(const RouteSuccess(NavRoute(
      polyline: [(-33.77, 151.11)],
      distanceMeters: 100,
      eta: Duration(minutes: 2),
      warnings: ['Sidewalk closed ahead', 'Use caution at night'],
    )));
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavWarningsTitle), findsOneWidget);
    expect(find.text('• Sidewalk closed ahead'), findsOneWidget);
    expect(find.text('• Use caution at night'), findsOneWidget);
  });

  testWidgets('external hand-off failure surfaces a toast (not a silent dead-end)', (t) async {
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, launcher: _FailLauncher())));
    await t.pumpAndSettle();
    final l = await _en();
    await t.tap(find.text(l.mapNavOpenExternal));
    await t.pumpAndSettle();
    expect(find.text(l.mapNavOpenExternalFailed), findsOneWidget);
  });

  testWidgets('RouteNoRoute → no-route panel with retry + external', (t) async {
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavNoRoute), findsOneWidget);
    expect(find.text(l.mapNavRetry), findsOneWidget);
  });

  testWidgets('RouteNetworkFailure → offline panel', (t) async {
    final svc = _StubService(const RouteNetworkFailure());
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavOffline), findsOneWidget);
  });

  testWidgets('RouteApiFailure → error panel', (t) async {
    final svc = _StubService(const RouteApiFailure(403));
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavError), findsOneWidget);
  });

  testWidgets('no location → needLocation panel with external fallback', (t) async {
    final svc = _StubService(const RouteNoRoute());
    final launcher = _FakeLauncher();
    await t.pumpWidget(_app(_c(service: svc, origin: null, launcher: launcher)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavNeedLocation), findsOneWidget);
    expect(svc.calls, 0); // never routed without an origin
    await t.tap(find.text(l.mapNavOpenExternal));
    await t.pumpAndSettle();
    expect(launcher.opened.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=-33.78%2C151.12&travelmode=walking');
  });

  testWidgets('deep-link with consent != accepted → disclosure shows, no location/route touched (#21)', (t) async {
    final svc = _StubService(const RouteSuccess(NavRoute(polyline: [], distanceMeters: 1, eta: Duration.zero)));
    await t.pumpWidget(_app(_c(service: svc, consent: MapsConsent.unknown)));
    await t.pumpAndSettle();
    expect(find.byType(MapsNavDisclosure), findsOneWidget);
    expect(svc.calls, 0); // consent gates before any Google call
  });

  testWidgets('accepting the disclosure proceeds to the route', (t) async {
    final svc = _StubService(const RouteSuccess(NavRoute(
      polyline: [(-33.77, 151.11)], distanceMeters: 200, eta: Duration(minutes: 3), warnings: [])));
    await t.pumpWidget(_app(_c(service: svc, consent: MapsConsent.unknown)));
    await t.pumpAndSettle();
    final l = await _en();
    await t.tap(find.text(l.mapNavDisclosureAccept));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-surface')), findsOneWidget);
    expect(svc.calls, 1);
  });

  // ── Campus scope ──────────────────────────────────────────────────────────

  testWidgets('origin OFF campus → "come to campus" message, never routes', (t) async {
    final svc = _StubService(const RouteSuccess(NavRoute(
      polyline: [(-33.77, 151.11)], distanceMeters: 5000, eta: Duration(minutes: 60))));
    await t.pumpWidget(_app(_c(service: svc, navOrigin: const NavOriginOffCampus())));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavOffCampusOrigin), findsOneWidget);
    expect(svc.calls, 0); // the whole point: no long walk-in route is generated
    // No external hand-off here either — it would start the very walk we blocked.
    expect(find.text(l.mapNavOpenExternal), findsNothing);
  });

  testWidgets('destination OFF campus → honest message, never routes', (t) async {
    // A resolved place whose routing coordinate is in the Sydney CBD.
    const offCampus = AsyncData<ResolvedPlace?>(ResolvedPlace(
      kind: PlaceKind.building,
      placeKey: _key,
      title: 'Opera House',
      subtitle: null,
      renderPoint: null,
      routingLat: -33.8568,
      routingLng: 151.2153,
    ));
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, resolved: offCampus)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavDestinationOffCampus), findsOneWidget);
    expect(svc.calls, 0);
  });

  testWidgets('a destination with NO coordinates (e.g. West 6) is handled honestly, not faked', (t) async {
    // West 6's coordinate is an unresolved placeholder, so the resolver yields
    // null routing. The screen must show the error-back panel — never a route.
    const noCoords = AsyncData<ResolvedPlace?>(ResolvedPlace(
      kind: PlaceKind.building,
      placeKey: _key,
      title: 'West 6',
      subtitle: null,
      renderPoint: null,
      routingLat: null,
      routingLng: null,
    ));
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, resolved: noCoords)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavError), findsOneWidget);
    expect(svc.calls, 0);
    expect(find.byKey(const Key('map-surface')), findsNothing); // no fake map
  });
}
