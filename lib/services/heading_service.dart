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
  static const _period = Duration(milliseconds: 50); // ~20 Hz
  static const _acquireTimeout = Duration(seconds: 4);
  static const _staleTimeout = Duration(seconds: 2);

  @override
  Stream<HeadingSample> watch() {
    if (kIsWeb) {
      return Stream<HeadingSample>.value(
          const HeadingSample(availability: HeadingAvailability.unsupported));
    }
    final controller = StreamController<HeadingSample>();
    final smoother = CircularSmoother(0.2); // fresh per session
    Vector3? latestAccel;
    StreamSubscription<AccelerometerEvent>? accSub;
    StreamSubscription<MagnetometerEvent>? magSub;
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
      acquireTimer = Timer(_acquireTimeout, fail);
      accSub = accelerometerEventStream(samplingPeriod: _period).listen(
          (e) => latestAccel = Vector3(e.x, e.y, e.z),
          onError: (Object _) => fail());
      magSub = magnetometerEventStream(samplingPeriod: _period).listen(
        (e) {
          final a = latestAccel;
          if (a == null) return; // wait for first accel sample
          final mag = tiltCompensatedHeadingDegrees(Vector3(e.x, e.y, e.z), a);
          if (mag == null) return; // degenerate reading; keep waiting
          acquireTimer?.cancel();
          staleTimer?.cancel();
          staleTimer = Timer(_staleTimeout, fail); // sensor stalled → unavailable
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
