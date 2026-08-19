import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/heading_math.dart';
import 'package:aon2026/services/heading_service.dart';

// Exercises the REAL SensorsHeadingService fusion + lifecycle off-hardware, via
// injected Vector3 streams + short timeouts (map audit P1 — this logic used to
// run only through a fake and only ever on a physical magnetometer).

// Flat device (gravity on +z) with the magnetic vector pointing +y → heading 0°.
const _accelFlat = Vector3(0, 0, 9.8);
const _magNorth = Vector3(0, 1, 0);

Future<void> _tick([int ms = 30]) => Future<void>.delayed(Duration(milliseconds: ms));

({SensorsHeadingService svc, StreamController<Vector3> acc, StreamController<Vector3> mag})
    _make({Duration acquire = const Duration(milliseconds: 200), Duration stale = const Duration(milliseconds: 80)}) {
  final acc = StreamController<Vector3>.broadcast();
  final mag = StreamController<Vector3>.broadcast();
  final svc = SensorsHeadingService(
    accelStream: () => acc.stream,
    magStream: () => mag.stream,
    acquireTimeout: acquire,
    staleTimeout: stale,
    isWeb: false,
  );
  return (svc: svc, acc: acc, mag: mag);
}

void main() {
  test('accel then mag → available with the tilt-compensated heading', () async {
    final h = _make();
    final samples = <HeadingSample>[];
    final sub = h.svc.watch().listen(samples.add);
    await _tick();
    expect(samples.first.availability, HeadingAvailability.acquiring); // emitted on listen
    h.acc.add(_accelFlat);
    h.mag.add(_magNorth);
    await _tick();
    final avail = samples.firstWhere((s) => s.availability == HeadingAvailability.available);
    expect(avail.magneticHeadingDegrees, closeTo(0, 0.5));
    await sub.cancel();
    await h.acc.close();
    await h.mag.close();
  });

  test('a magnetometer sample BEFORE the first accel is ignored (no false heading)', () async {
    final h = _make(acquire: const Duration(seconds: 5)); // long, so acquire can't fire here
    final samples = <HeadingSample>[];
    final sub = h.svc.watch().listen(samples.add);
    await _tick();
    h.mag.add(_magNorth); // no accel yet → must be ignored (wait-for-first-accel gate)
    await _tick();
    expect(samples.any((s) => s.availability == HeadingAvailability.available), isFalse);
    h.acc.add(_accelFlat);
    h.mag.add(_magNorth);
    await _tick();
    expect(samples.any((s) => s.availability == HeadingAvailability.available), isTrue);
    await sub.cancel();
    await h.acc.close();
    await h.mag.close();
  });

  test('no magnetometer within acquireTimeout → unavailable (the simulator path)', () async {
    final h = _make(acquire: const Duration(milliseconds: 40));
    final samples = <HeadingSample>[];
    final sub = h.svc.watch().listen(samples.add);
    h.acc.add(_accelFlat); // accel present, but the magnetometer never emits
    await _tick(120);
    expect(samples.last.availability, HeadingAvailability.unavailable);
    await sub.cancel();
    await h.acc.close();
    await h.mag.close();
  });

  test('available then silence past staleTimeout → unavailable, and it is TERMINAL', () async {
    final h = _make(stale: const Duration(milliseconds: 50));
    final samples = <HeadingSample>[];
    final sub = h.svc.watch().listen(samples.add);
    h.acc.add(_accelFlat);
    h.mag.add(_magNorth);
    await _tick(); // available
    expect(samples.any((s) => s.availability == HeadingAvailability.available), isTrue);
    await _tick(90); // no further mag → stale fires
    expect(samples.last.availability, HeadingAvailability.unavailable);
    final countAfterFail = samples.length;
    h.mag.add(_magNorth); // a late sample must NOT resurrect (subs cancelled by fail)
    await _tick();
    expect(samples.length, countAfterFail);
    await sub.cancel();
    await h.acc.close();
    await h.mag.close();
  });

  test('a sensor stream error fails to unavailable', () async {
    final h = _make();
    final samples = <HeadingSample>[];
    final sub = h.svc.watch().listen(samples.add);
    await _tick();
    h.acc.addError('sensor boom');
    await _tick();
    expect(samples.last.availability, HeadingAvailability.unavailable);
    await sub.cancel();
    await h.acc.close();
    await h.mag.close();
  });

  test('web → a single unsupported sample', () async {
    final svc = SensorsHeadingService(isWeb: true);
    final samples = await svc.watch().toList();
    expect(samples, hasLength(1));
    expect(samples.single.availability, HeadingAvailability.unsupported);
  });
}
