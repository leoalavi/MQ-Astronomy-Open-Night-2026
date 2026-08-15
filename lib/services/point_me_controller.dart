import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

class PointMeState {
  const PointMeState({
    this.availability = HeadingAvailability.acquiring,
    this.relativeAngleDegrees,
    this.trueBearingDegrees,
    this.distanceMeters,
    this.nearTarget = false,
    this.hasFix = false,
    this.locationReliable = false,
  });
  final HeadingAvailability availability;
  final double? relativeAngleDegrees;
  final double? trueBearingDegrees;
  final double? distanceMeters;
  final bool nearTarget;
  final bool hasFix;
  final bool locationReliable;
}

final headingServiceProvider = Provider<HeadingService>(
    (ref) => throw UnimplementedError('override in main / a fake in tests'));

/// The current "point me there" target, or null when no such screen is open.
/// Set by `PointMeScreen` on open, cleared (null) on dispose/background — this
/// is the heading-stream lifecycle. Same tiny-notifier shape as MapVisible.
final pointMeTargetProvider =
    NotifierProvider<PointMeTargetNotifier, LatLng?>(PointMeTargetNotifier.new);

class PointMeTargetNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
  void set(LatLng? target) => state = target;
}

final pointMeControllerProvider =
    NotifierProvider<PointMeController, PointMeState>(PointMeController.new);

class PointMeController extends Notifier<PointMeState> {
  StreamSubscription<HeadingSample>? _sub;
  int _generation = 0; // discards late callbacks from a replaced/cancelled stream
  HeadingAvailability _availability = HeadingAvailability.acquiring;
  double? _magneticHeading;

  @override
  PointMeState build() {
    ref.onDispose(() => unawaited(_sub?.cancel()));
    ref.listen(pointMeTargetProvider, (_, target) => _onTargetChanged(target));
    ref.listen(locationControllerProvider, (_, _) => _recompute());
    _subscribe(ref.read(pointMeTargetProvider)); // subscribe ONLY — no state write
    return _compute(); // build RETURNS the initial state, never assigns `state`
  }

  void _onTargetChanged(LatLng? target) {
    _subscribe(target);
    _recompute(); // listener path may assign state (build is done)
  }

  /// (Re)subscribe to heading for [target]; a generation token makes any late
  /// event from the previous (cancelled) stream a no-op, avoiding a race.
  void _subscribe(LatLng? target) {
    unawaited(_sub?.cancel());
    _sub = null;
    final gen = ++_generation;
    _availability = HeadingAvailability.acquiring;
    _magneticHeading = null;
    if (target != null) {
      _sub = ref.read(headingServiceProvider).watch().listen((s) {
        if (gen != _generation) return; // stale session
        _availability = s.availability;
        _magneticHeading = s.magneticHeadingDegrees;
        _recompute();
      }, onError: (_) {
        if (gen != _generation) return;
        _availability = HeadingAvailability.unavailable;
        _magneticHeading = null;
        _recompute();
      });
    }
  }

  void _recompute() => state = _compute();

  PointMeState _compute() {
    final target = ref.read(pointMeTargetProvider);
    final fix = ref.read(locationControllerProvider).fix;
    if (target == null || fix == null) {
      return PointMeState(availability: _availability, hasFix: fix != null);
    }
    final reliable = !fix.isLowAccuracy; // Phase A: >200 m ⇒ unreliable
    final distance = distanceBetweenMeters(fix.position, target);
    // Near-target short-circuits direction: bearing is ill-defined at ~0 range,
    // and a low-accuracy fix must never claim "you're here".
    if (reliable && distance <= MapConfig.pointMeNearTargetMeters) {
      return PointMeState(
        availability: _availability,
        distanceMeters: distance,
        nearTarget: true,
        hasFix: true,
        locationReliable: true,
      );
    }
    final bearing = trueBearingDegrees(fix.position, target);
    double? relative;
    if (_magneticHeading != null) {
      final trueHeading = normalizeBearing(
          _magneticHeading! + MapConfig.campusMagneticDeclinationDegrees);
      relative = relativeAngleDegrees(bearing, trueHeading);
    }
    return PointMeState(
      availability: _availability,
      trueBearingDegrees: bearing,
      distanceMeters: distance,
      relativeAngleDegrees: relative,
      nearTarget: false,
      hasFix: true,
      locationReliable: reliable,
    );
  }
}
