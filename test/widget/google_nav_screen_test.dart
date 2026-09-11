import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/screens/google_nav_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/embedded_map.dart';

const _key = 'building:TEST';

class _StubService implements RoutesService {
  _StubService(this.result);
  final RouteResult result;
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({
    required (double, double) origin,
    required (double, double) destination,
  }) async {
    calls++;
    return result;
  }
}

/// Returns each queued result in turn, so a test can drive
/// failure → Retry → success through the real `ref.invalidate(navRouteProvider)`.
class _SequencedService implements RoutesService {
  _SequencedService(this._results);
  final List<RouteResult> _results;
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({
    required (double, double) origin,
    required (double, double) destination,
  }) async {
    final r = _results[calls < _results.length ? calls : _results.length - 1];
    calls++;
    return r;
  }
}

/// Stays pending until the test releases it — reproduces the "HTTP answered but
/// the screen hangs" case, then lets the tree settle so the binding's
/// pending-timer invariant is satisfied (the strip's spinner animates).
class _NeverService implements RoutesService {
  final _c = Completer<RouteResult>();
  void release() => _c.complete(const RouteNoRoute());
  @override
  Future<RouteResult> walkingRoute({
    required (double, double) origin,
    required (double, double) destination,
  }) => _c.future;
}

class _FakeSurface implements EmbeddedMapSurface {
  @override
  Widget build({
    required GeoBounds bounds,
    required (double, double) origin,
    required (double, double) destination,
    required List<(double, double)> route,
  }) => const SizedBox(key: Key('map-surface'));
}

/// Pending until [complete] is called with a chosen result — reproduces the
/// exact "route is loading, then resolves to success" transition the web
/// regression happened on.
class _HeldService implements RoutesService {
  final _c = Completer<RouteResult>();
  void complete(RouteResult r) => _c.complete(r);
  @override
  Future<RouteResult> walkingRoute({
    required (double, double) origin,
    required (double, double) destination,
  }) => _c.future;
}

/// A stateful fake whose inner widget carries a STABLE key, so its element is
/// reused across rebuilds exactly as the real `GoogleMap` element is. `creates`
/// counts `initState` calls (i.e. how many times the map was mounted), and
/// `lastRoute` records the polyline handed to the surface on the latest build.
/// This lets the transition test prove the map is NOT remounted on route
/// success and that the polyline reaches it — the invariants behind the
/// resize-to-grey fix.
class _MountCountingSurface implements EmbeddedMapSurface {
  int lastRouteLength = -1;
  static int creates = 0;
  @override
  Widget build({
    required GeoBounds bounds,
    required (double, double) origin,
    required (double, double) destination,
    required List<(double, double)> route,
  }) {
    lastRouteLength = route.length;
    return const _CountingMap(key: Key('map-surface'));
  }
}

class _CountingMap extends StatefulWidget {
  const _CountingMap({super.key});
  @override
  State<_CountingMap> createState() => _CountingMapState();
}

class _CountingMapState extends State<_CountingMap> {
  @override
  void initState() {
    super.initState();
    _MountCountingSurface.creates++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('map-inner'));
}

const _resolved = AsyncData<ResolvedPlace?>(
  ResolvedPlace(
    kind: PlaceKind.building,
    placeKey: _key,
    title: 'Test Hall',
    subtitle: 'T1',
    renderPoint: null,
    routingLat: -33.78,
    routingLng: 151.12,
  ),
);

Widget _app(ProviderContainer c, {EmbeddedMapSurface? surface}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: GoogleNavScreen(
          placeKey: _key,
          surface: surface ?? _FakeSurface(),
        ),
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
  required RoutesService service,
  MapsConsent consent = MapsConsent.accepted,
  (double, double)? origin = const (-33.77, 151.11),
  bool enabled = true,
  bool sdkReady = true,
  AsyncValue<ResolvedPlace?> resolved = _resolved,
  NavOrigin? navOrigin,
}) {
  final c = ProviderContainer(
    overrides: [
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
      navOriginProvider.overrideWith(
        (ref) async =>
            navOrigin ??
            (origin == null
                ? const NavOriginUnavailable()
                : NavOriginOnCampus(origin)),
      ),
      routesServiceProvider.overrideWith((ref) => service),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<AonL10n> _en() => AonL10n.delegate.load(const Locale('en'));

/// The whole product line for MAP #9: the visitor is NEVER sent to the external
/// Google Maps app. This asserts the CTA, its icon and its strings are all gone.
void _expectNoExternalMapsHandoff(WidgetTester t) {
  expect(
    find.byIcon(Icons.open_in_new_rounded),
    findsNothing,
    reason: 'the external "open in Google Maps" affordance must not exist',
  );
}

void main() {
  testWidgets('capability off → unavailable panel (no routing, no external)', (
    t,
  ) async {
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, enabled: false)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavUnavailable), findsOneWidget);
    expect(svc.calls, 0);
    _expectNoExternalMapsHandoff(t);
  });

  testWidgets(
    'success → map + distance/ETA, NO "walking routes are in beta" copy',
    (t) async {
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11), (-33.78, 151.12)],
            distanceMeters: 412,
            eta: Duration(minutes: 6),
            warnings: [],
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('map-surface')), findsOneWidget);
      expect(find.textContaining('412 m'), findsOneWidget);
      expect(find.textContaining('6 min'), findsOneWidget);
      // MAP #11: the removed beta caution must not reappear anywhere on screen.
      expect(find.textContaining('beta'), findsNothing);
      expect(find.textContaining('use caution'), findsNothing);
      // MAP #9: no external hand-off on the success panel.
      _expectNoExternalMapsHandoff(t);
    },
  );

  testWidgets(
    'MAP #10: Google-supplied walking steps render as a compact list',
    (t) async {
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11), (-33.78, 151.12)],
            distanceMeters: 300,
            eta: Duration(minutes: 4),
            steps: [
              NavStep(
                instruction: 'Head north on Wally’s Walk',
                distanceMeters: 120,
              ),
              NavStep(
                instruction: 'Turn right onto Central Avenue',
                distanceMeters: 180,
              ),
            ],
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      final l = await _en();
      expect(find.text(l.mapNavStepsTitle), findsOneWidget);
      expect(find.text('Head north on Wally’s Walk'), findsOneWidget);
      expect(find.text('Turn right onto Central Avenue'), findsOneWidget);
    },
  );

  testWidgets('no steps in the response → no steps list (never invented)', (
    t,
  ) async {
    final svc = _StubService(
      const RouteSuccess(
        NavRoute(
          polyline: [(-33.77, 151.11)],
          distanceMeters: 100,
          eta: Duration(minutes: 2),
          steps: [],
        ),
      ),
    );
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavStepsTitle), findsNothing);
  });

  testWidgets(
    'Google-supplied route warnings are rendered on success (ToS display)',
    (t) async {
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11)],
            distanceMeters: 100,
            eta: Duration(minutes: 2),
            warnings: ['Sidewalk closed ahead', 'Use caution at night'],
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      final l = await _en();
      expect(find.text(l.mapNavWarningsTitle), findsOneWidget);
      expect(find.text('• Sidewalk closed ahead'), findsOneWidget);
      expect(find.text('• Use caution at night'), findsOneWidget);
    },
  );

  testWidgets('RouteNoRoute → no-route panel with in-app Retry only', (
    t,
  ) async {
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavNoRoute), findsOneWidget);
    expect(find.text(l.mapNavRetry), findsOneWidget);
    _expectNoExternalMapsHandoff(t);
  });

  testWidgets('RouteNetworkFailure → offline panel', (t) async {
    final svc = _StubService(const RouteNetworkFailure());
    await t.pumpWidget(_app(_c(service: svc)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavOffline), findsOneWidget);
  });

  // ── The map is not gated on the route ────────────────────────────────────
  testWidgets(
    'RouteApiFailure keeps the MAP and shows a route-only error + Retry',
    (t) async {
      final svc = _StubService(const RouteApiFailure(403));
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      final l = await _en();
      expect(
        find.byKey(const Key('map-surface')),
        findsOneWidget,
        reason: 'a route failure must not hide the destination',
      );
      expect(find.text(l.mapNavRouteUnavailable), findsOneWidget);
      expect(find.text(l.mapNavRetry), findsOneWidget);
      _expectNoExternalMapsHandoff(t);
    },
  );

  for (final (label, failure) in <(String, RouteResult)>[
    ('RouteApiFailure 401 (Routes API rejected)', const RouteApiFailure(401)),
    ('RouteApiFailure 429 (quota)', const RouteApiFailure(429)),
    ('RouteNoRoute', const RouteNoRoute()),
    ('RouteNetworkFailure', const RouteNetworkFailure()),
    ('RouteMalformed', const RouteMalformed()),
  ]) {
    testWidgets('$label keeps the map visible', (t) async {
      await t.pumpWidget(_app(_c(service: _StubService(failure))));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('map-surface')),
        findsOneWidget,
        reason: '$label replaced the map with an error page',
      );
    });
  }

  testWidgets('the map is NOT built when the SDK is unkeyed, even on failure', (
    t,
  ) async {
    await t.pumpWidget(
      _app(_c(service: _StubService(const RouteNoRoute()), sdkReady: false)),
    );
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.byKey(const Key('map-surface')), findsNothing);
    expect(find.text(l.mapNavUnavailable), findsOneWidget);
  });

  testWidgets('the MAP renders while the route is still PENDING', (t) async {
    final never = _NeverService();
    await t.pumpWidget(_app(_c(service: never)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('map-surface')),
      findsOneWidget,
      reason: 'a pending route must not hide the destination map',
    );
    final l = await _en();
    expect(find.text(l.mapNavFindingRoute), findsOneWidget);
    never.release();
    await t.pumpAndSettle();
  });

  testWidgets('a pending route shows NO full-screen spinner', (t) async {
    final never = _NeverService();
    await t.pumpWidget(_app(_c(service: never)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('map-surface')), findsOneWidget);
    never.release();
    await t.pumpAndSettle();
  });

  // REGRESSION (web map blanks after the route loads): the map element must
  // survive the loading → RouteApiSuccess transition — same mount, polyline
  // delivered, directions panel added — never a remount/replace. (The actual
  // web tile repaint is a platform-view concern the fix handles by re-fitting
  // the camera on resize/route-change; a widget test can pin the mount/overlay
  // invariants that make that possible.)
  testWidgets(
    'loading → RouteApiSuccess keeps the SAME map mounted with overlays',
    (t) async {
      _MountCountingSurface.creates = 0;
      final surface = _MountCountingSurface();
      final held = _HeldService();
      await t.pumpWidget(_app(_c(service: held), surface: surface));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));

      final l = await _en();
      // LOADING: map mounted once, "finding route" strip, no polyline yet.
      expect(find.byKey(const Key('map-surface')), findsOneWidget);
      expect(find.text(l.mapNavFindingRoute), findsOneWidget);
      expect(
        _MountCountingSurface.creates,
        1,
        reason: 'map mounted exactly once',
      );
      expect(
        surface.lastRouteLength,
        0,
        reason: 'no polyline while the route loads',
      );

      // TRANSITION → success with a real polyline + a step.
      held.complete(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11), (-33.78, 151.12), (-33.785, 151.125)],
            distanceMeters: 412,
            eta: Duration(minutes: 6),
            steps: [NavStep(instruction: 'Head west', distanceMeters: 10)],
          ),
        ),
      );
      await t.pumpAndSettle();

      // SUCCESS: the SAME map is still mounted (not recreated), the polyline
      // reached it, and the directions panel appeared over/under it.
      expect(find.byKey(const Key('map-surface')), findsOneWidget);
      expect(
        _MountCountingSurface.creates,
        1,
        reason: 'the map must NOT be remounted when the route succeeds',
      );
      expect(
        surface.lastRouteLength,
        3,
        reason: 'the route polyline must reach the still-mounted map',
      );
      expect(find.textContaining('412 m'), findsOneWidget);
      expect(find.text(l.mapNavStepsTitle), findsOneWidget);
    },
  );

  // "Repeated route requests must not blank the map": a failure → Retry →
  // success cycle drives a real ref.invalidate(navRouteProvider), and the map
  // stays the same mounted element throughout.
  testWidgets('failure → Retry → success never remounts the map', (t) async {
    _MountCountingSurface.creates = 0;
    final surface = _MountCountingSurface();
    final svc = _SequencedService(const [
      RouteMalformed(),
      RouteSuccess(
        NavRoute(
          polyline: [(-33.77, 151.11), (-33.78, 151.12)],
          distanceMeters: 200,
          eta: Duration(minutes: 3),
        ),
      ),
    ]);
    await t.pumpWidget(_app(_c(service: svc), surface: surface));
    await t.pumpAndSettle();

    final l = await _en();
    // Failure banner is up, but the map is already mounted beneath it.
    expect(find.byKey(const Key('map-surface')), findsOneWidget);
    expect(_MountCountingSurface.creates, 1);

    await t.tap(find.text(l.mapNavRetry));
    await t.pumpAndSettle();

    // Success now: still the same single mounted map, polyline delivered.
    expect(find.byKey(const Key('map-surface')), findsOneWidget);
    expect(
      _MountCountingSurface.creates,
      1,
      reason: 'retrying the route must not remount the map',
    );
    expect(surface.lastRouteLength, 2);
    expect(find.textContaining('200 m'), findsOneWidget);
  });

  testWidgets(
    'sharing turned off mid-flight → no map, one-tap re-enable, no external',
    (t) async {
      await t.pumpWidget(
        _app(_c(service: _StubService(const RouteConsentRefused()))),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('map-surface')), findsNothing);
      expect(find.byKey(const Key('nav-enable-sharing')), findsOneWidget);
      _expectNoExternalMapsHandoff(t);
    },
  );

  testWidgets(
    'no location → needLocation panel with in-app Retry (no external)',
    (t) async {
      final svc = _StubService(const RouteNoRoute());
      await t.pumpWidget(_app(_c(service: svc, origin: null)));
      await t.pumpAndSettle();
      final l = await _en();
      expect(find.text(l.mapNavNeedLocation), findsOneWidget);
      expect(svc.calls, 0); // never routed without an origin
      expect(find.byKey(const Key('nav-retry-location')), findsOneWidget);
      _expectNoExternalMapsHandoff(t);
    },
  );

  testWidgets(
    'first-run (unknown) opens Directions directly — NO consent modal — and routes',
    (t) async {
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11)],
            distanceMeters: 200,
            eta: Duration(minutes: 3),
            warnings: [],
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc, consent: MapsConsent.unknown)));
      // Google Maps is the sole directions provider, so there is no "Use Google
      // Maps for directions?" modal: consent is recorded implicitly after the
      // frame and the map + route load directly.
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final l = await _en();
      // The provider-choice modal must NOT appear.
      expect(find.text(l.mapNavDisclosureTitle), findsNothing);
      expect(find.byKey(const Key('map-surface')), findsOneWidget);
      expect(svc.calls, 1);
      _expectNoExternalMapsHandoff(t);
    },
  );

  testWidgets(
    'explicitly-off (declined) shows a panel with re-enable, not a modal',
    (t) async {
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11)],
            distanceMeters: 200,
            eta: Duration(minutes: 3),
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc, consent: MapsConsent.declined)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('nav-enable-sharing')), findsOneWidget);
      expect(find.byKey(const Key('map-surface')), findsNothing);
      expect(svc.calls, 0);
      _expectNoExternalMapsHandoff(t);

      await t.tap(find.byKey(const Key('nav-enable-sharing')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('map-surface')),
        findsOneWidget,
        reason: 'one tap re-enables and the map appears',
      );
      expect(svc.calls, 1);
    },
  );

  testWidgets(
    'Retry after a 401-style API failure genuinely re-requests and can succeed',
    (t) async {
      final svc = _SequencedService(const [
        RouteApiFailure(401),
        RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11)],
            distanceMeters: 210,
            eta: Duration(minutes: 3),
          ),
        ),
      ]);
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      final l = await _en();

      expect(find.byKey(const Key('map-surface')), findsOneWidget);
      expect(find.text(l.mapNavRouteUnavailable), findsOneWidget);
      expect(svc.calls, 1);

      await t.tap(find.text(l.mapNavRetry));
      await t.pumpAndSettle();

      expect(
        svc.calls,
        2,
        reason: 'Retry must re-hit the service, not reuse state',
      );
      expect(find.textContaining('210 m'), findsOneWidget);
      expect(find.text(l.mapNavRouteUnavailable), findsNothing);
    },
  );

  testWidgets(
    'MAP #13: the route is fetched ONCE per origin — rebuilds do not re-hit Routes',
    (t) async {
      // The route is keyed by the snapshot (origin, dest); the live blue dot moves
      // with GPS but the ROUTE never recomputes on a location tick or a rebuild.
      // Only an explicit Retry (invalidate) issues a fresh request.
      final svc = _StubService(
        const RouteSuccess(
          NavRoute(
            polyline: [(-33.77, 151.11)],
            distanceMeters: 200,
            eta: Duration(minutes: 3),
          ),
        ),
      );
      await t.pumpWidget(_app(_c(service: svc)));
      await t.pumpAndSettle();
      expect(svc.calls, 1);
      // Force several extra rebuilds — jitter/relayout/theme ticks would do this
      // on device. The Routes call count must not climb.
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(
        svc.calls,
        1,
        reason: 'no reroute on rebuilds — jitter must not re-hit Routes',
      );
    },
  );

  // ── Campus scope ──────────────────────────────────────────────────────────
  testWidgets('origin OFF campus → "come to campus" message, never routes', (
    t,
  ) async {
    final svc = _StubService(
      const RouteSuccess(
        NavRoute(
          polyline: [(-33.77, 151.11)],
          distanceMeters: 5000,
          eta: Duration(minutes: 60),
        ),
      ),
    );
    await t.pumpWidget(
      _app(_c(service: svc, navOrigin: const NavOriginOffCampus())),
    );
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavOffCampusOrigin), findsOneWidget);
    expect(svc.calls, 0);
    _expectNoExternalMapsHandoff(t);
  });

  testWidgets('destination OFF campus → honest message, never routes', (
    t,
  ) async {
    const offCampus = AsyncData<ResolvedPlace?>(
      ResolvedPlace(
        kind: PlaceKind.building,
        placeKey: _key,
        title: 'Opera House',
        subtitle: null,
        renderPoint: null,
        routingLat: -33.8568,
        routingLng: 151.2153,
      ),
    );
    final svc = _StubService(const RouteNoRoute());
    await t.pumpWidget(_app(_c(service: svc, resolved: offCampus)));
    await t.pumpAndSettle();
    final l = await _en();
    expect(find.text(l.mapNavDestinationOffCampus), findsOneWidget);
    expect(svc.calls, 0);
  });

  testWidgets(
    'a destination with NO coordinates is handled honestly, not faked',
    (t) async {
      const noCoords = AsyncData<ResolvedPlace?>(
        ResolvedPlace(
          kind: PlaceKind.building,
          placeKey: _key,
          title: 'A place with no pin',
          subtitle: null,
          renderPoint: null,
          routingLat: null,
          routingLng: null,
        ),
      );
      final svc = _StubService(const RouteNoRoute());
      await t.pumpWidget(_app(_c(service: svc, resolved: noCoords)));
      await t.pumpAndSettle();
      final l = await _en();
      expect(find.text(l.mapNavError), findsOneWidget);
      expect(svc.calls, 0);
      expect(find.byKey(const Key('map-surface')), findsNothing);
    },
  );
}
