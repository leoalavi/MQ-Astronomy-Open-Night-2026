import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/embedded_map.dart';

void main() {
  test('boundsFor spans origin ∪ destination ∪ all route points (route extremes not clipped)', () {
    // Route reaches BEYOND origin/destination on both axes — a bounds over only
    // origin/dest would clip it; a bounds over only route would clip origin/dest.
    final b = boundsFor(
      origin: (-33.80, 151.10),
      destination: (-33.78, 151.14),
      route: const [(-33.79, 151.20), (-33.82, 151.12)],
    );
    expect(b.southwest.$1, closeTo(-33.82, 1e-9)); // min lat comes from a route point
    expect(b.northeast.$1, closeTo(-33.78, 1e-9)); // max lat from destination
    expect(b.southwest.$2, closeTo(151.10, 1e-9)); // min lng from origin
    expect(b.northeast.$2, closeTo(151.20, 1e-9)); // max lng from a route point
  });

  test('empty route → bounds is just origin ∪ destination', () {
    final b = boundsFor(origin: (-33.80, 151.10), destination: (-33.78, 151.14), route: const []);
    expect(b.southwest, (-33.80, 151.10));
    expect(b.northeast, (-33.78, 151.14));
  });
}
