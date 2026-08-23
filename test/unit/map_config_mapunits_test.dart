import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('map-unit bounds match the frozen receipt (sourced from projection)', () {
    expect(MapConfig.mapBounds.north, closeTo(85.0, 1e-3));
    expect(MapConfig.mapBounds.east, closeTo(120.2389, 1e-3));
    expect(MapConfig.mapBounds.south, 0);
    expect(MapConfig.mapBounds.west, 0);
    expect(MapConfig.mapMinZoom, -7);
    expect(MapConfig.mapMaxZoom, -2);
  });
}
