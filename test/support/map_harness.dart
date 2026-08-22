import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/location_providers.dart';

import 'fake_location_service.dart';

/// A `ProviderContainer` ready to pump `MapScreen`.
///
/// Lifted from `map_platform_wiring_test.dart` so a second copy never grows
/// alongside it. Fixes are delivered by `svc.emit(...)` after pumping, matching
/// the stream-based [FakeLocationService] the repo already shares.
///
/// Registers its own `addTearDown(dispose)`, exactly as the original private
/// helper did, so call sites stay unchanged.
ProviderContainer mapContainer(FakeLocationService svc) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}
