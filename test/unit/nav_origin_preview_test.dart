import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/preview_location.dart';

/// Preview mode ("I'm not there yet") must drive walking-nav too.
///
/// ## The bug this file exists to prevent
///
/// Preview mode substitutes a simulated on-campus fix through
/// `effectiveLocationServiceProvider`, and the map dot + compass both read it —
/// so a tester far from campus can flip Settings → Preview and everything works.
/// But `navOriginProvider` read the RAW `locationServiceProvider`, so in preview
/// mode the walking-route origin still used real GPS and stayed blocked
/// off-campus. That single bypass is the whole "it breaks when I'm far away"
/// story for nav. The fix routes nav origin through the same abstraction.
class _FixedService implements LocationService {
  _FixedService(this.pos);
  final LatLng pos;
  @override
  Future<LocationStatus> status() async => LocationStatus.granted;
  @override
  Future<LocationStatus> request() async => LocationStatus.granted;
  @override
  Stream<UserLocationFix> watch() =>
      Stream.value(UserLocationFix(position: pos, accuracyMeters: 10));
  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  // Sydney CBD — comfortably outside the campus scope rectangle + its pad.
  const offCampus = LatLng(-33.8688, 151.2093);

  test('preview toggles nav origin on/off without leaking after disable',
      () async {
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(_FixedService(offCampus)),
    ]);
    addTearDown(c.dispose);
    c.listen(navOriginProvider, (_, _) {}); // keep the autoDispose alive

    // Preview OFF: real GPS is off-campus, so nav refuses the origin.
    expect(await c.read(navOriginProvider.future), isA<NavOriginOffCampus>());

    // Preview ON: the simulated campus fix yields a usable origin.
    c.read(previewLocationProvider.notifier).set(true);
    expect(await c.read(navOriginProvider.future), isA<NavOriginOnCampus>());

    // Preview OFF again: the override must not leak — back to real behaviour.
    c.read(previewLocationProvider.notifier).set(false);
    expect(await c.read(navOriginProvider.future), isA<NavOriginOffCampus>());
  });
}
