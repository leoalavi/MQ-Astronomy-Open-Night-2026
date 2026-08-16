import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/search_providers.dart';
import '../support/fake_location_service.dart';

BuildingEntry _b(String id, double lat, double lng) => BuildingEntry(Building(
    id: id, code: id, name: id, category: BuildingCategory.academic,
    latitude: lat, longitude: lng, campusX: 1, campusY: 1));

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('B4: compassVisible + ensureLocationActive keeps the stream alive', () async {
    final svc = FakeLocationService(grant: LocationStatus.granted);
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(svc),
    ]);
    addTearDown(c.dispose);
    c.read(locationControllerProvider);
    await c.read(locationControllerProvider.notifier).ensureLocationActive();
    c.read(compassVisibleProvider.notifier).set(true);
    svc.emit(UserLocationFix(position: const LatLng(-33.77, 151.11), accuracyMeters: 8));
    await _settle();
    expect(c.read(locationControllerProvider).fix, isNotNull); // streamed while compass-only
  });

  test('ensureLocationActive activates WITHOUT map-follow (§0R-11)', () async {
    final svc = FakeLocationService(grant: LocationStatus.granted);
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(svc),
    ]);
    addTearDown(c.dispose);
    await c.read(locationControllerProvider.notifier).ensureLocationActive();
    expect(c.read(locationControllerProvider).active, isTrue);
    expect(c.read(locationControllerProvider).following, isFalse); // NOT onLocateTapped
  });

  test('nearbyTargetsProvider e2e: [] on null fix; fix→target; filter narrows (PT-4)',
      () async {
    final svc = FakeLocationService(grant: LocationStatus.granted);
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(svc),
      searchIndexProvider.overrideWithValue([
        _b('near', -33.7738, 151.1134),
        _b('far', -33.79, 151.14),
      ]),
    ]);
    addTearDown(c.dispose);
    c.read(locationControllerProvider);
    expect(c.read(nearbyTargetsProvider), isEmpty); // null fix

    await c.read(locationControllerProvider.notifier).ensureLocationActive();
    c.read(compassVisibleProvider.notifier).set(true);
    svc.emit(UserLocationFix(position: const LatLng(-33.7737, 151.1134), accuracyMeters: 8));
    await _settle();
    expect(c.read(nearbyTargetsProvider).map((t) => t.placeKey), contains('building:near'));

    c.read(compassFilterProvider.notifier).set('near');
    expect(c.read(nearbyTargetsProvider).map((t) => t.placeKey), ['building:near']); // narrowed
  });
}
