import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeLocationService svc, {bool visible = true}) {
  final c = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(svc),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(visible);
  return c;
}

UserLocationFix _fix([double acc = 8]) => UserLocationFix(
    position: const LatLng(-33.7737, 151.1134), accuracyMeters: acc);

/// A service whose every call throws — stands in for a plugin/platform failure
/// (or a forgotten provider override) so we can prove the entry prompt swallows
/// it and leaves the Map usable.
class _ThrowingLocationService implements LocationService {
  @override
  Future<LocationStatus> request() async => throw StateError('boom');
  @override
  Future<LocationStatus> status() async => throw StateError('boom');
  @override
  Stream<UserLocationFix> watch() => const Stream.empty();
  @override
  Stream<bool> serviceEnabledChanges() => const Stream.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  test('locate grants -> active + following; dot updates', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    expect(c.read(locationControllerProvider).active, isTrue);
    expect(c.read(locationControllerProvider).following, isTrue);
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix, isNotNull);
  });

  test('user pan exits follow but keeps the live dot', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(locationControllerProvider.notifier).onUserPan();
    final s = c.read(locationControllerProvider);
    expect(s.following, isFalse);
    expect(s.active, isTrue); // dot still live (decoupling, §P1-1/§P1-2)
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix, isNotNull);
  });

  test('tap while active-not-following re-enables follow', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    final n = c.read(locationControllerProvider.notifier);
    await n.onLocateTapped();
    n.onUserPan(); // follow off
    await n.onLocateTapped(); // re-follow (already active)
    expect(c.read(locationControllerProvider).following, isTrue);
  });

  test('deniedForever opens app settings; serviceOff opens location settings',
      () async {
    final denied = FakeLocationService(grant: LocationStatus.deniedForever);
    final c1 = _c(denied);
    await c1.read(locationControllerProvider.notifier).onLocateTapped();
    expect(denied.appSettingsOpened, 1);
    expect(c1.read(locationControllerProvider).active, isFalse);

    final off = FakeLocationService(grant: LocationStatus.serviceOff);
    final c2 = _c(off);
    await c2.read(locationControllerProvider.notifier).onLocateTapped();
    expect(off.locationSettingsOpened, 1);
  });

  test('stream error resets AND re-evaluates status (not hardcoded serviceOff)',
      () async {
    // The fake still reports granted; a transient stream error must NOT be
    // mislabelled serviceOff — it re-evaluates via status() (§5.7, review #5).
    final svc = FakeLocationService(); // grant defaults to granted
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emitError(StateError('gps lost'));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final s = c.read(locationControllerProvider);
    expect(s.active, isFalse);
    expect(s.following, isFalse);
    expect(s.fix, isNull);
    expect(s.status, LocationStatus.granted); // re-evaluated, not serviceOff
  });

  test('service switched off mid-session -> serviceOff status', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emitServiceEnabled(false); // OS toggled Location Services off
    await Future<void>.delayed(Duration.zero);
    final s = c.read(locationControllerProvider);
    expect(s.active, isFalse);
    expect(s.status, LocationStatus.serviceOff); // this reason we DO know
  });

  group('Map entry checks existing permission without prompting', () {
    test('grant -> active, dot shown, but NOT following (camera not hijacked)',
        () async {
      final svc = FakeLocationService();
      final c = _c(svc);
      await c
          .read(locationControllerProvider.notifier)
          .restoreGrantedLocation();
      final s = c.read(locationControllerProvider);
      expect(svc.requestCount, 0); // existing grant; no permission dialog
      expect(s.active, isTrue); // location live — the dot renders
      expect(s.following, isFalse); // opening campus-fit camera left alone
      svc.emit(_fix());
      await Future<void>.delayed(Duration.zero);
      expect(c.read(locationControllerProvider).fix, isNotNull);
    });

    test('denied leaves the Map usable and does not re-prompt on a second entry',
        () async {
      final svc = FakeLocationService(grant: LocationStatus.denied);
      final c = _c(svc);
      final n = c.read(locationControllerProvider.notifier);
      await n.restoreGrantedLocation();
      expect(svc.requestCount, 0);
      expect(c.read(locationControllerProvider).active, isFalse); // still usable
      // A passive "denied" is NOT adopted: checkPermission says denied for a
      // never-asked fresh install too, and the button must still invite the
      // first tap ("Show my location"), not read "Location unavailable".
      expect(c.read(locationControllerProvider).status, LocationStatus.unknown);
      // Re-entering the Map tab (or any rebuild) must NOT prompt again.
      await n.restoreGrantedLocation();
      expect(svc.requestCount, 0); // browsing never opens a permission dialog
    });

    test('deniedForever on first entry does NOT auto-open Settings', () async {
      // Only an explicit Locate tap should deep-link to Settings; a silent
      // entry-time prompt must never yank the visitor out of the app.
      final svc = FakeLocationService(grant: LocationStatus.deniedForever);
      final c = _c(svc);
      await c
          .read(locationControllerProvider.notifier)
          .restoreGrantedLocation();
      expect(svc.appSettingsOpened, 0);
      // Not adopted from a passive check either; the explicit tap learns it.
      expect(c.read(locationControllerProvider).status, LocationStatus.unknown);
    });

    test('serviceOff on entry IS adopted — a reason the button can name', () async {
      final svc = FakeLocationService(grant: LocationStatus.serviceOff);
      final c = _c(svc);
      await c.read(locationControllerProvider.notifier).restoreGrantedLocation();
      expect(c.read(locationControllerProvider).status, LocationStatus.serviceOff);
      expect(c.read(locationControllerProvider).active, isFalse);
    });

    test('a throwing location service on entry never crashes the Map', () async {
      final c = ProviderContainer(overrides: [
        locationServiceProvider.overrideWithValue(_ThrowingLocationService()),
      ]);
      addTearDown(c.dispose);
      c.read(mapVisibleProvider.notifier).set(true);
      // Must complete without throwing.
      await c
          .read(locationControllerProvider.notifier)
          .restoreGrantedLocation();
      final s = c.read(locationControllerProvider);
      expect(s.active, isFalse); // Map stays usable, location just inactive
      expect(s.status, LocationStatus.unknown); // neutral -> Locate offers retry
    });

    test('already active (Locate tapped first) -> entry prompt is a no-op',
        () async {
      final svc = FakeLocationService();
      final c = _c(svc);
      final n = c.read(locationControllerProvider.notifier);
      await n.onLocateTapped(); // grants + follows
      expect(svc.requestCount, 1);
      await n.restoreGrantedLocation();
      expect(svc.requestCount, 1); // no second prompt
      expect(c.read(locationControllerProvider).following, isTrue); // untouched
    });
  });

  test('explicit location actions recover from platform failure', () async {
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(_ThrowingLocationService()),
    ]);
    addTearDown(c.dispose);
    final n = c.read(locationControllerProvider.notifier);
    await n.onLocateTapped();
    await n.ensureLocationActive();
    expect(c.read(locationControllerProvider).active, isFalse);
    expect(c.read(locationControllerProvider).status, LocationStatus.unknown);
  });

  test('hidden map pauses the stream and drops follow', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(mapVisibleProvider.notifier).set(false); // tab hidden
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).following, isFalse);
    // A fix emitted while hidden is ignored (stream cancelled).
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    // active intent retained for resume:
    expect(c.read(locationControllerProvider).active, isTrue);
  });
}
