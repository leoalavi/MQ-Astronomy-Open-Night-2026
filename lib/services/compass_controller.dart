import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/point_me_controller.dart' show headingServiceProvider;
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

/// Locked target key (tap a blip/row). Compass-local; NOT pointMeTargetProvider.
final compassLockedProvider =
    NotifierProvider<CompassLocked, String?>(CompassLocked.new);

class CompassLocked extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? placeKey) => state = placeKey;
}

/// Immutable render state for the N-up rose (§0R-1: locked marker is ABSOLUTE).
class CompassState {
  const CompassState({
    required this.availability,
    this.trueHeadingDegrees,
    this.locked,
    this.lockedTrueBearingDegrees,
    this.lockedTurnDegrees,
    this.lockedNearTarget = false,
    this.lockedApproximate = false,
    this.locationReliable = false,
    this.hasFix = false,
  });
  final HeadingAvailability availability;
  final double? trueHeadingDegrees;
  final NearbyTarget? locked;

  /// Where the locked target sits on the N-up rose — the SAME absolute frame as
  /// every blip (§0R-1). The user rotates until [trueHeadingDegrees] overlaps it.
  final double? lockedTrueBearingDegrees;

  /// Optional relative turn (bearing − heading) for a TEXTUAL "turn X°" cue only;
  /// never the rose arrow.
  final double? lockedTurnDegrees;

  final bool lockedNearTarget;
  final bool lockedApproximate; // locked coord is placeholder/derived (§0R-6)
  final bool locationReliable, hasFix;
}

final compassControllerProvider =
    NotifierProvider<CompassController, CompassState>(CompassController.new);

class CompassController extends Notifier<CompassState> {
  StreamSubscription<HeadingSample>? _sub;
  int _gen = 0;
  bool _terminal = false; // §0R/M8: once unavailable in a session, latched
  HeadingAvailability _avail = HeadingAvailability.acquiring;
  double? _magnetic;

  @override
  CompassState build() {
    ref.onDispose(_cancelSub);
    // Run the heading sensor only while the compass is actually ON-SCREEN:
    // compass mode selected (compassVisible) AND the Map branch on-screen
    // (mapVisible). Gating on compassVisible alone strands the magnetometer +
    // accelerometer when the user leaves the Map tab with compass still
    // selected — `StatefulShellRoute.indexedStack` keeps the branch mounted so
    // CompassModeView.dispose never fires (map audit 2026-08-19, P0). Listening
    // to both means the sensor re-subscribes when the user returns to the tab.
    ref.listen(compassVisibleProvider, (_, _) => _syncSub());
    ref.listen(mapVisibleProvider, (_, _) => _syncSub());
    ref.listen(compassLockedProvider, (_, _) => _recompute());
    ref.listen(locationControllerProvider, (_, _) => _recompute());
    _syncSub(); // subscribe only if already on-screen
    return _compute();
  }

  bool get _onScreen =>
      ref.read(compassVisibleProvider) && ref.read(mapVisibleProvider);

  /// (Re)subscribe on an off→on transition; cancel when no longer on-screen.
  /// The `_sub == null` guard keeps an unrelated provider event from tearing
  /// down and resetting the terminal-unavailable latch mid-session.
  void _syncSub() {
    if (_onScreen) {
      if (_sub == null) _subscribe();
    } else {
      _cancelSub();
    }
  }

  void _subscribe() {
    _cancelSub();
    final gen = ++_gen;
    _terminal = false;
    _avail = HeadingAvailability.acquiring;
    _magnetic = null;
    _sub = ref.read(headingServiceProvider).watch().listen((s) {
      if (gen != _gen || _terminal) return; // stale session OR latched
      if (s.availability == HeadingAvailability.unavailable ||
          s.availability == HeadingAvailability.unsupported) {
        _terminal = true;
      }
      _avail = s.availability;
      _magnetic = s.magneticHeadingDegrees;
      _recompute();
    }, onError: (_) {
      if (gen != _gen) return;
      _terminal = true;
      _avail = HeadingAvailability.unavailable;
      _magnetic = null;
      _recompute();
    });
  }

  void _cancelSub() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void _recompute() => state = _compute();

  CompassState _compute() {
    final trueHeading = _magnetic == null
        ? null
        : normalizeBearing(_magnetic! + MapConfig.campusMagneticDeclinationDegrees);
    final fix = ref.read(locationControllerProvider).fix;
    final lockedKey = ref.read(compassLockedProvider);
    NearbyTarget? locked;
    double? lockedBearing, lockedTurn;
    var near = false, approx = false, reliable = false;
    if (lockedKey != null && fix != null) {
      locked = _resolveLocked(lockedKey, fix.position);
      if (locked != null) {
        lockedBearing = locked.trueBearingDegrees; // §0R-1: absolute
        approx = locked.confidence != DataConfidence.confirmed; // §0R-6
        // "You're here" is a strong claim → require a confirmed coordinate.
        reliable = !fix.isLowAccuracy && locked.confidence == DataConfidence.confirmed;
        near = reliable && locked.distanceMeters <= MapConfig.pointMeNearTargetMeters;
        if (trueHeading != null) {
          lockedTurn = relativeAngleDegrees(lockedBearing, trueHeading);
        }
      }
    }
    return CompassState(
      availability: _avail,
      trueHeadingDegrees: trueHeading,
      locked: locked,
      lockedTrueBearingDegrees: lockedBearing,
      lockedTurnDegrees: lockedTurn,
      lockedNearTarget: near,
      lockedApproximate: approx,
      locationReliable: reliable,
      hasFix: fix != null,
    );
  }

  /// Resolve the locked key against the FULL index (not the culled/filtered set).
  NearbyTarget? _resolveLocked(String key, LatLng fix) {
    for (final e in ref.read(searchIndexProvider)) {
      if (e.placeKey != key) continue;
      final ll = routingLatLngOf(e);
      if (ll == null) return null;
      final to = LatLng(ll.$1, ll.$2);
      return NearbyTarget(
        placeKey: key, title: e.title, kind: e.kind, lat: ll.$1, lng: ll.$2,
        distanceMeters: distanceBetweenMeters(fix, to),
        trueBearingDegrees: trueBearingDegrees(fix, to),
        confidence: confidenceOf(e),
      );
    }
    return null;
  }
}
