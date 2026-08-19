import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sensors_plus/sensors_plus.dart';

import 'package:aon2026/services/heading_math.dart';

enum HeadingAvailability { acquiring, available, unavailable, unsupported }

class HeadingSample {
  const HeadingSample({required this.availability, this.magneticHeadingDegrees});
  final HeadingAvailability availability;
  final double? magneticHeadingDegrees; // tilt-compensated magnetic, [0,360)
}

/// The sensor seam. Everything above is tested with a fake.
abstract interface class HeadingService {
  Stream<HeadingSample> watch();
}

/// Real adapter over sensors_plus. Fuses magnetometer + accelerometer with
/// combine-latest (emit on each magnetometer tick using the latest accel), applies
/// [tiltCompensatedHeadingDegrees], smooths (fresh smoother per session), and is
/// deterministic on failure. Web has no Magnetometer API in any browser, so it
/// short-circuits to a single `unsupported` WITHOUT subscribing.
class SensorsHeadingService implements HeadingService {
  /// The raw-sensor streams and timeouts are injectable so the fusion, the
  /// acquire/stale timeouts and the terminal `fail()` cascade can be exercised
  /// off-hardware (a simulator has no magnetometer) — map audit P1. Production
  /// uses the sensors_plus globals, mapped to the pure [Vector3].
  SensorsHeadingService({
    Stream<Vector3> Function()? accelStream,
    Stream<Vector3> Function()? magStream,
    this.acquireTimeout = const Duration(seconds: 4),
    this.staleTimeout = const Duration(seconds: 2),
    this.isWeb = kIsWeb,
  })  : _accelStream = accelStream ?? _defaultAccel,
        _magStream = magStream ?? _defaultMag;

  final Stream<Vector3> Function() _accelStream;
  final Stream<Vector3> Function() _magStream;
  final Duration acquireTimeout;
  final Duration staleTimeout;
  final bool isWeb;

  static const _period = Duration(milliseconds: 50); // ~20 Hz

  static Stream<Vector3> _defaultAccel() => accelerometerEventStream(samplingPeriod: _period)
      .map((e) => Vector3(e.x, e.y, e.z));
  static Stream<Vector3> _defaultMag() => magnetometerEventStream(samplingPeriod: _period)
      .map((e) => Vector3(e.x, e.y, e.z));

  @override
  Stream<HeadingSample> watch() {
    if (isWeb) {
      return Stream<HeadingSample>.value(
          const HeadingSample(availability: HeadingAvailability.unsupported));
    }
    final controller = StreamController<HeadingSample>();
    final smoother = CircularSmoother(0.2); // fresh per session
    Vector3? latestAccel;
    StreamSubscription<Vector3>? accSub;
    StreamSubscription<Vector3>? magSub;
    Timer? acquireTimer, staleTimer;
    var closed = false;

    // Any required-sensor failure OR a timeout is TERMINAL for this session:
    // cancel both streams, clear state, emit unavailable, stop. Never resurrect
    // the arrow from stale data.
    void fail() {
      acquireTimer?.cancel();
      staleTimer?.cancel();
      magSub?.cancel();
      accSub?.cancel();
      magSub = null;
      accSub = null;
      latestAccel = null;
      if (!closed) {
        controller.add(
            const HeadingSample(availability: HeadingAvailability.unavailable));
      }
    }

    controller.onListen = () {
      controller.add(
          const HeadingSample(availability: HeadingAvailability.acquiring));
      // No valid heading within the window → deterministic fallback (this is
      // what a no-magnetometer simulator/device hits instead of "finding north…").
      acquireTimer = Timer(acquireTimeout, fail);
      accSub = _accelStream().listen(
          (v) => latestAccel = v,
          onError: (Object _) => fail());
      magSub = _magStream().listen(
        (v) {
          final a = latestAccel;
          if (a == null) return; // wait for first accel sample
          final mag = tiltCompensatedHeadingDegrees(v, a);
          if (mag == null) return; // degenerate reading; keep waiting
          acquireTimer?.cancel();
          staleTimer?.cancel();
          staleTimer = Timer(staleTimeout, fail); // sensor stalled → unavailable
          controller.add(HeadingSample(
            availability: HeadingAvailability.available,
            magneticHeadingDegrees: smoother.add(mag),
          ));
        },
        onError: (Object _) => fail(),
      );
    };
    controller.onCancel = () async {
      closed = true;
      acquireTimer?.cancel();
      staleTimer?.cancel();
      await magSub?.cancel();
      await accSub?.cancel();
    };
    return controller.stream;
  }
}
