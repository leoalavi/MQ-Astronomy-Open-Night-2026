import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/services/search_providers.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

const _fixLatLng = LatLng(-33.7737, 151.1134);

ProviderContainer _c(
  FakeHeadingService h,
  FakeLocationService l, {
  List<SearchEntry> index = const [],
}) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(l),
    searchIndexProvider.overrideWithValue(index), // §0R-14: no FutureProvider race
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

const _sample = HeadingSample(
    availability: HeadingAvailability.available, magneticHeadingDegrees: 0);

void main() {
  test('unavailable is TERMINAL — a later available does NOT resurrect (0R/M8)', () async {
    final h = FakeHeadingService();
    final c = _c(h, FakeLocationService());
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider); // subscribe synchronously
    await _settle();
    h.emit(_sample);
    await _settle();
    h.emit(const HeadingSample(availability: HeadingAvailability.unavailable));
    await _settle();
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 90));
    await _settle();
    expect(c.read(compassControllerProvider).availability, HeadingAvailability.unavailable);
  });

  test('declination applied to true heading', () async {
    final h = FakeHeadingService();
    final c = _c(h, FakeLocationService());
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider);
    await _settle();
    h.emit(_sample); // 0 magnetic + 12.752 E = 12.752 true
    await _settle();
    expect(c.read(compassControllerProvider).trueHeadingDegrees, closeTo(12.752, 0.01));
  });

  test('locked target resolves against the FULL index; rose uses ABSOLUTE bearing (0R-1)',
      () async {
    final h = FakeHeadingService();
    final l = FakeLocationService();
    final c = _c(h, l, index: [
      BuildingEntry(const Building(id: 'T', code: 'T', name: 'Tower',
          category: BuildingCategory.academic,
          latitude: -33.7700, longitude: 151.1134, campusX: 1, campusY: 1)),
    ]);
    await c.read(locationControllerProvider.notifier).ensureLocationActive();
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider);
    l.emit(UserLocationFix(position: _fixLatLng, accuracyMeters: 8));
    await _settle();
    c.read(compassLockedProvider.notifier).set('building:T');
    h.emit(_sample);
    await _settle();
    final s = c.read(compassControllerProvider);
    expect(s.locked?.placeKey, 'building:T');
    expect(s.locked!.distanceMeters, greaterThan(0));
    expect(s.lockedTrueBearingDegrees, closeTo(s.locked!.trueBearingDegrees, 0.001)); // absolute
  });

  test('placeholder-coord lock: no crisp "you\'re here"; flagged approximate (0R-6)', () async {
    final h = FakeHeadingService();
    final l = FakeLocationService();
    final c = _c(h, l, index: [
      VenueEntry(const Venue(id: 'reg', name: 'Registration', category: VenueCategory.registration,
          latitude: -33.7737, longitude: 151.1134,
          coordinateConfidence: DataConfidence.placeholder)),
    ]);
    await c.read(locationControllerProvider.notifier).ensureLocationActive();
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider);
    l.emit(UserLocationFix(position: _fixLatLng, accuracyMeters: 5)); // accurate GPS, ~0 m to target
    await _settle();
    c.read(compassLockedProvider.notifier).set('venue:reg');
    h.emit(_sample);
    await _settle();
    final s = c.read(compassControllerProvider);
    expect(s.lockedNearTarget, isFalse); // placeholder coord ⇒ NOT "you're here"
    expect(s.lockedApproximate, isTrue);
  });
}
