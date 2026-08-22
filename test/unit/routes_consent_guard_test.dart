import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/routes_service.dart';

class _SpyRoutes implements RoutesService {
  int calls = 0;

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    calls++;
    return const RouteNetworkFailure();
  }
}

/// Flips consent while the "request" is in flight.
class _SlowRoutes implements RoutesService {
  _SlowRoutes({required this.onCall});
  final void Function() onCall;
  int calls = 0;

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    calls++;
    onCall(); // user revokes in Settings while we await
    await Future<void>.delayed(Duration.zero);
    return const RouteNetworkFailure();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const origin = (-33.7737, 151.1134);
  const dest = (-33.7738, 151.1126);

  test('an unknown-consent request never reaches the network', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.unknown,
    );

    final result = await guarded.walkingRoute(origin: origin, destination: dest);

    expect(spy.calls, 0, reason: 'spec §2c: blocked, not merely hidden');
    expect(result, isA<RouteConsentRefused>());
  });

  test('a declined-consent request never reaches the network', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.declined,
    );

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 0);
  });

  test('an accepted-consent request passes through', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.accepted,
    );

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1);
  });

  test('consent is read per call, so revoking mid-session takes effect',
      () async {
    final spy = _SpyRoutes();
    var consent = MapsConsent.accepted;
    final guarded =
        ConsentGuardedRoutesService(inner: spy, consent: () => consent);

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1);

    consent = MapsConsent.unknown; // user revoked in Settings
    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1, reason: 'a cached accepted value would leak a request');
  });

  test('a response arriving after revocation is discarded', () async {
    // The honest half of the contract: the request is already on the wire, so
    // it cannot be recalled — but its result must not reach the UI.
    var consent = MapsConsent.accepted;
    final slow = _SlowRoutes(onCall: () => consent = MapsConsent.unknown);
    final guarded =
        ConsentGuardedRoutesService(inner: slow, consent: () => consent);

    final result = await guarded.walkingRoute(origin: origin, destination: dest);

    expect(slow.calls, 1, reason: 'the request did go out — we do not pretend');
    expect(result, isA<RouteConsentRefused>(),
        reason: 'but its response must never reach the UI after a revoke');
  });

  test('production routesServiceProvider returns a GUARDED service', () async {
    // Every wrapper test above passes even if the provider forgot to wrap.
    final c = ProviderContainer(overrides: [
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.unknown),
      androidRoutesKeyProvider.overrideWithValue('k'),
      iosRoutesKeyProvider.overrideWithValue('k'),
    ]);
    addTearDown(c.dispose);

    final svc = await c.read(routesServiceProvider.future);
    expect(svc, isA<ConsentGuardedRoutesService>());
    expect(await svc.walkingRoute(origin: origin, destination: dest),
        isA<RouteConsentRefused>());
  });
}
