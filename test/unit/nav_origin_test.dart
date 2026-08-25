import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/maps_nav_providers.dart';

/// Deterministic stub: [watch] yields a single value (or an error/empty stream)
/// so `navOriginProvider`'s `.first` resolves without real timing.
class _StubLoc implements LocationService {
  _StubLoc({
    required this.statusGrant,
    LocationStatus? requestGrant,
    this.fix,
    this.errorStream = false,
  }) : requestGrant = requestGrant ?? statusGrant;

  final LocationStatus statusGrant;
  final LocationStatus requestGrant;
  final UserLocationFix? fix;
  final bool errorStream;

  @override
  Future<LocationStatus> status() async => statusGrant;
  @override
  Future<LocationStatus> request() async => requestGrant;
  @override
  Stream<UserLocationFix> watch() {
    if (errorStream) return Stream<UserLocationFix>.error(StateError('no fix'));
    final f = fix;
    return f == null ? const Stream.empty() : Stream.value(f);
  }

  @override
  Stream<bool> serviceEnabledChanges() => const Stream.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

UserLocationFix _fixAt(double lat, double lng) =>
    UserLocationFix(position: LatLng(lat, lng), accuracyMeters: 8);

Future<NavOrigin> _resolve(_StubLoc loc) async {
  final container = ProviderContainer(
    overrides: [locationServiceProvider.overrideWithValue(loc)],
  );
  addTearDown(container.dispose);
  return container.read(navOriginProvider.future);
}

void main() {
  // Campus box is lat[-33.7772506, -33.7703261], lng[151.1080508, 151.1211352]
  // plus a 500 m pad. Midpoint is unambiguously on campus.
  const onCampus = (-33.77379, 151.11459);
  // Sydney CBD — ~10 km away, far beyond the 500 m tolerance.
  const offCampus = (-33.8688, 151.2093);

  group('navOriginProvider', () {
    test('permission refused (and stays refused) is unavailable', () async {
      final origin = await _resolve(_StubLoc(statusGrant: LocationStatus.denied));
      expect(origin, isA<NavOriginUnavailable>());
    });

    test('a refused status is re-requested; a granted on-campus fix routes',
        () async {
      final origin = await _resolve(_StubLoc(
        statusGrant: LocationStatus.denied,
        requestGrant: LocationStatus.granted,
        fix: _fixAt(onCampus.$1, onCampus.$2),
      ));
      expect(origin, isA<NavOriginOnCampus>());
      expect((origin as NavOriginOnCampus).point.$1, closeTo(onCampus.$1, 1e-9));
      expect(origin.point.$2, closeTo(onCampus.$2, 1e-9));
    });

    test('an off-campus fix is refused, not routed as a long walk-in', () async {
      final origin = await _resolve(_StubLoc(
        statusGrant: LocationStatus.granted,
        fix: _fixAt(offCampus.$1, offCampus.$2),
      ));
      expect(origin, isA<NavOriginOffCampus>());
    });

    test('granted but no fix arrives is unavailable, never a crash', () async {
      final origin = await _resolve(
        _StubLoc(statusGrant: LocationStatus.granted, errorStream: true),
      );
      expect(origin, isA<NavOriginUnavailable>());
    });
  });
}
