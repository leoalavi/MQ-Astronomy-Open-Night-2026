import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/heading_math.dart';

void main() {
  group('tiltCompensatedHeadingDegrees', () {
    // These absolute values are hand-derived from the Android algorithm below
    // (A=up, H=mag×A [east], M=A×H [north], azimuth=atan2(H.y,M.y)) for a flat
    // phone (accel=(0,0,9.8)). Verified: mag=(0,20,-40)→0°, mag=(-20,0,-40)→90°.
    test('flat phone, north field → ~0°', () {
      final h = tiltCompensatedHeadingDegrees(
          const Vector3(0, 20, -40), const Vector3(0, 0, 9.8))!;
      expect(h, closeTo(0, 5));
    });

    test('flat phone, east field → ~90°', () {
      final h = tiltCompensatedHeadingDegrees(
          const Vector3(-20, 0, -40), const Vector3(0, 0, 9.8))!;
      expect(h, closeTo(90, 5));
    });

    // Tilt-compensation is the whole point: rotate BOTH gravity and field by the
    // same 30° forward pitch (R_x(30°)) and the azimuth must stay ~0°.
    // R_x(30°)·(0,20,-40)=(0, 37.32, -24.64); R_x(30°)·(0,0,9.8)=(0, -4.9, 8.49).
    test('tilted phone reports the same azimuth as flat (~0°)', () {
      final tilted = tiltCompensatedHeadingDegrees(
          const Vector3(0, 37.32, -24.64), const Vector3(0, -4.9, 8.49))!;
      expect(tilted, closeTo(0, 6));
    });

    test('degenerate input (zero gravity) → null', () {
      expect(
          tiltCompensatedHeadingDegrees(
              const Vector3(1, 1, 1), const Vector3(0, 0, 0)),
          isNull);
    });
  });

  group('CircularSmoother', () {
    test('rejects an out-of-range alpha', () {
      expect(() => CircularSmoother(0), throwsA(anything));
      expect(() => CircularSmoother(1.5), throwsA(anything));
    });
    test('a hard wrap sequence stays near 0, never ~180', () {
      final s = CircularSmoother(0.5);
      double out = 0;
      for (final v in [358.0, 359.0, 0.0, 1.0, 2.0]) {
        out = s.add(v);
      }
      expect(out < 20 || out > 340, isTrue);
    });
    test('converges to a steady input', () {
      final s = CircularSmoother(0.5);
      double out = 0;
      for (var i = 0; i < 20; i++) {
        out = s.add(123);
      }
      expect(out, closeTo(123, 1));
    });
  });
}
