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
