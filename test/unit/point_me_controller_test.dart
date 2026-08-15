import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/map_config.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

const _target = LatLng(-33.7727, 151.1134); // ~111 m north of campus centre

ProviderContainer _c(FakeHeadingService h, FakeLocationService loc,
    {LatLng? target = _target}) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(loc),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  c.read(pointMeControllerProvider); // instantiate (subscribes)
  if (target != null) c.read(pointMeTargetProvider.notifier).set(target);
  return c;
}

PointMeState _state(ProviderContainer c) => c.read(pointMeControllerProvider);

Future<void> _activate(ProviderContainer c, FakeLocationService loc) async {
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  loc.emit(UserLocationFix(
      position: MapConfig.campusCentre, accuracyMeters: 8)); // user at centre
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('no fix yet → no bearing, hasFix false', () {
    final c = _c(FakeHeadingService(), FakeLocationService());
    final s = _state(c);
    expect(s.hasFix, isFalse);
    expect(s.trueBearingDegrees, isNull);
  });

  test('with a fix, bearing+distance computed even before heading', () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc);
    await _activate(c, loc);
    final s = _state(c);
    expect(s.hasFix, isTrue);
    expect(s.trueBearingDegrees, closeTo(0, 2)); // target due north
    expect(s.distanceMeters, closeTo(111, 5));
  });

  test('heading available → relativeAngle applies declination', () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    // device points at magnetic north (0). true heading = 0 + declination.
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.availability, HeadingAvailability.available);
    // bearing ~0 (north), trueHeading = declination → relative ≈ -declination
    expect(s.relativeAngleDegrees!,
        closeTo(-MapConfig.campusMagneticDeclinationDegrees, 2));
  });

  test('web/unsupported heading → availability unsupported, bearing still set',
      () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    h.emit(const HeadingSample(availability: HeadingAvailability.unsupported));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.availability, HeadingAvailability.unsupported);
    expect(s.trueBearingDegrees, isNotNull); // fallback card still works
  });

  test('near target flips nearTarget true (and short-circuits bearing)',
      () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc, target: MapConfig.campusCentre);
    await _activate(c, loc); // user also at campus centre
    final s = _state(c);
    expect(s.nearTarget, isTrue);
    expect(s.trueBearingDegrees, isNull); // no ill-defined bearing at ~0 range
  });

  test('low-accuracy fix → not reliable, no near-target claim', () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc, target: MapConfig.campusCentre);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    loc.emit(
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 250));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.locationReliable, isFalse);
    expect(s.nearTarget, isFalse); // never "you're here" on a ±250 m fix
  });

  test('PointMe keeps GPS alive when the Map tab is not visible', () async {
    final loc = FakeLocationService();
    final c = ProviderContainer(overrides: [
      headingServiceProvider.overrideWithValue(FakeHeadingService()),
      locationServiceProvider.overrideWithValue(loc),
    ]);
    addTearDown(c.dispose);
    c.read(mapVisibleProvider.notifier).set(false); // Map not the active tab
    c.read(pointMeActiveProvider.notifier).set(true); // PointMe screen open
    c.read(pointMeControllerProvider);
    c.read(pointMeTargetProvider.notifier).set(_target);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    loc.emit(
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 8));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(pointMeControllerProvider).hasFix, isTrue); // GPS not paused
  });

  test('clearing the target (screen left) cancels heading & drops to no-target',
      () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    c.read(pointMeTargetProvider.notifier).set(null); // screen disposed
    await Future<void>.delayed(Duration.zero);
    // A heading emitted after the screen left is ignored (stream cancelled).
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await Future<void>.delayed(Duration.zero);
    expect(_state(c).relativeAngleDegrees, isNull);
  });
}
