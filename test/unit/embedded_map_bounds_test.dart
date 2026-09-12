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

  group('routeGeometryChanged (stale-line / camera-refit trigger)', () {
    test('identical geometry → not changed', () {
      const a = [(-33.774, 151.113), (-33.775, 151.115)];
      expect(routeGeometryChanged(a, a), isFalse);
      // A different list instance with equal values is still "unchanged".
      const b = [(-33.774, 151.113), (-33.775, 151.115)];
      expect(routeGeometryChanged(a, b), isFalse);
    });

    test('same length but different points → changed (the length-only bug)', () {
      // Selecting a second venue can return a polyline with the SAME number of
      // points as the first. A length comparison would call this "unchanged" and
      // leave the previous line drawn and the camera framing the old route.
      const first = [(-33.7737, 151.1134), (-33.7746, 151.1151)];
      const second = [(-33.7737, 151.1134), (-33.7760, 151.1180)];
      expect(first.length, second.length);
      expect(routeGeometryChanged(first, second), isTrue);
    });

    test('different length → changed', () {
      expect(
        routeGeometryChanged(
          const [(-33.774, 151.113)],
          const [(-33.774, 151.113), (-33.775, 151.115)],
        ),
        isTrue,
      );
    });

    test('a route appearing (empty → points) → changed', () {
      expect(
        routeGeometryChanged(const [], const [(-33.774, 151.113)]),
        isTrue,
      );
    });
  });
}
