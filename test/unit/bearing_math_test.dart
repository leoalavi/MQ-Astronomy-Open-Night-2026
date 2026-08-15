import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/widgets/bearing_math.dart';

void main() {
  const origin = LatLng(0, 0);

  test('true bearing is normalized to [0,360)', () {
    // Due north and due south are unambiguous references.
    expect(trueBearingDegrees(origin, const LatLng(1, 0)), closeTo(0, 0.5));
    expect(trueBearingDegrees(origin, const LatLng(-1, 0)), closeTo(180, 0.5));
    // Due east is ~90; must be positive (not -270 or negative).
    final east = trueBearingDegrees(origin, const LatLng(0, 1));
    expect(east, closeTo(90, 0.5));
    expect(east, greaterThanOrEqualTo(0));
  });

  test('relative angle is the signed shortest delta, wrap-safe', () {
    expect(relativeAngleDegrees(10, 350), closeTo(20, 1e-9)); // 359->1 style wrap
    expect(relativeAngleDegrees(350, 10), closeTo(-20, 1e-9));
    expect(relativeAngleDegrees(90, 0), closeTo(90, 1e-9)); // target to the right
    expect(relativeAngleDegrees(0, 0), 0);
    expect(relativeAngleDegrees(180, 0).abs(), closeTo(180, 1e-9));
  });

  test('distance between two points in metres', () {
    final d = distanceBetweenMeters(origin, const LatLng(0, 0.001));
    expect(d, closeTo(111, 3)); // ~111 m per 0.001 deg lon at equator
  });

  test('cardinal buckets', () {
    expect(cardinalFor(0), Cardinal.n);
    expect(cardinalFor(45), Cardinal.ne);
    expect(cardinalFor(90), Cardinal.e);
    expect(cardinalFor(359), Cardinal.n); // wraps back to N
  });
}
