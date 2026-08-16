import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/routes_service.dart';

class _CountingService implements RoutesService {
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({
    required (double, double) origin,
    required (double, double) destination,
  }) async {
    calls++;
    return const RouteSuccess(NavRoute(polyline: [], distanceMeters: 0, eta: Duration.zero));
  }
}

void main() {
  test('same (origin,dest) → one walkingRoute call; different args → separate call (autoDispose keep-alive)', () async {
    final fake = _CountingService();
    final c = ProviderContainer(overrides: [
      routesServiceProvider.overrideWith((ref) => fake),
    ]);
    addTearDown(c.dispose);

    const a = ((-33.77, 151.11), (-33.78, 151.12));
    // Two simultaneous consumers of the SAME args. Keep the provider alive with
    // explicit listeners so autoDispose cannot tear it down between reads.
    final sub1 = c.listen(navRouteProvider(a), (_, _) {});
    addTearDown(sub1.close);
    final sub2 = c.listen(navRouteProvider(a), (_, _) {});
    addTearDown(sub2.close);
    await c.read(navRouteProvider(a).future);
    expect(fake.calls, 1); // one in-flight per (origin,dest) — billing rule

    const b = ((0.0, 0.0), (1.0, 1.0));
    final sub3 = c.listen(navRouteProvider(b), (_, _) {});
    addTearDown(sub3.close);
    await c.read(navRouteProvider(b).future);
    expect(fake.calls, 2); // different args → its own call
  });
}
