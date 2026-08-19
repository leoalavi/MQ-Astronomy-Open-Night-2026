import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('heading constants pinned', () {
    // Pin the exact WMM2025 value, not just `.isFinite`: a wrong sign
    // (−12.752, wrong hemisphere) or 0.0 would throw every point-me bearing off
    // by ~25°/13° yet stay green under an isFinite check (map audit P2).
    expect(MapConfig.campusMagneticDeclinationDegrees, closeTo(12.752, 1e-3));
    expect(MapConfig.pointMeNearTargetMeters, 20);
  });
}
