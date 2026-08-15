import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('heading constants present', () {
    expect(MapConfig.campusMagneticDeclinationDegrees.isFinite, isTrue);
    expect(MapConfig.pointMeNearTargetMeters, 20);
  });
}
