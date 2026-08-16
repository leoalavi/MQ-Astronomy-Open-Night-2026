import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';

class LocationSnapshot {
  const LocationSnapshot({
    this.status = LocationStatus.unknown,
    this.fix,
    this.active = false,
    this.following = false,
  });
  final LocationStatus status;
  final UserLocationFix? fix;
  final bool active;
  final bool following;

  LocationSnapshot copyWith({
    LocationStatus? status,
    bool clearFix = false,
    UserLocationFix? fix,
    bool? active,
    bool? following,
  }) =>
      LocationSnapshot(
        status: status ?? this.status,
        fix: clearFix ? null : (fix ?? this.fix),
        active: active ?? this.active,
        following: following ?? this.following,
      );
}

final locationServiceProvider =
    Provider<LocationService>((ref) => throw UnimplementedError(
        'override with GeolocatorLocationService in main / a fake in tests'));

/// Whether the Map shell branch is on-screen. Driven by [AppShell] from
/// `StatefulNavigationShell.currentIndex` (the authoritative branch signal),
/// NOT by animation infrastructure. GPS runs only when this is true AND
/// location is active. Riverpod 3 removed `StateProvider`, so a tiny notifier
/// stands in — the repo's established pattern (see `SelectedIdNotifier`).
final mapVisibleProvider =
    NotifierProvider<MapVisibleNotifier, bool>(MapVisibleNotifier.new);

class MapVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool visible) {
    if (state != visible) state = visible;
  }
}

/// True while a PointMeScreen is open. GPS must stay alive off the Map tab, so
/// this is OR'd into the location gate below (Map Parity Phase B).
final pointMeActiveProvider =
    NotifierProvider<PointMeActiveNotifier, bool>(PointMeActiveNotifier.new);

class PointMeActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool active) {
    if (state != active) state = active;
  }
}

/// True while the compass mode (M5) is on-screen. OR'd into the location gate so
/// GPS stays alive in compass mode (§0.1/B4). Same tiny-notifier shape.
final compassVisibleProvider =
    NotifierProvider<CompassVisibleNotifier, bool>(CompassVisibleNotifier.new);

class CompassVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool visible) {
    if (state != visible) state = visible;
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationSnapshot>(
        LocationController.new);

class LocationController extends Notifier<LocationSnapshot> {
  StreamSubscription<UserLocationFix>? _sub;
  StreamSubscription<bool>? _serviceSub;

  LocationService get _svc => ref.read(locationServiceProvider);

  @override
  LocationSnapshot build() {
    ref.onDispose(_cancel);
    ref.listen(mapVisibleProvider, (_, _) => _sync());
    ref.listen(pointMeActiveProvider, (_, _) => _sync());
    ref.listen(compassVisibleProvider, (_, _) => _sync());
    return const LocationSnapshot();
  }

  /// Activate location for a consumer (compass, §0R-11) that needs the position
  /// stream but NOT map-follow/camera semantics. No-op if already active;
  /// requests permission when inactive. Deliberately never sets `following`
  /// (that is [onLocateTapped]'s map behaviour, and its 2nd-call follow toggle
  /// would misfire on compass re-entry).
  Future<void> ensureLocationActive() async {
    if (state.active) return;
    final s = await _svc.request();
    state = state.copyWith(status: s);
    if (s == LocationStatus.granted) {
      state = state.copyWith(active: true);
      _sync();
    }
  }

  /// The locate button's single action.
  Future<void> onLocateTapped() async {
    if (!state.active) {
      final s = await _svc.request();
      state = state.copyWith(status: s);
      switch (s) {
        case LocationStatus.granted:
          state = state.copyWith(active: true, following: true);
          _sync();
        case LocationStatus.deniedForever:
          await _svc.openAppSettings();
        case LocationStatus.serviceOff:
          await _svc.openLocationSettings();
        case LocationStatus.denied:
        case LocationStatus.unknown:
          break; // stay inactive; tap again re-prompts
      }
      return;
    }
    state = state.copyWith(following: !state.following); // toggle follow only
  }

  /// A deliberate user map-pan exits follow but keeps the dot (§P1-2).
  void onUserPan() {
    if (state.following) state = state.copyWith(following: false);
  }

  void _sync() {
    final wantStream = state.active &&
        (ref.read(mapVisibleProvider) ||
            ref.read(pointMeActiveProvider) ||
            ref.read(compassVisibleProvider));
    if (wantStream && _sub == null) {
      _sub = _svc.watch().listen(_onFix, onError: (_) => _onStreamError());
      _serviceSub = _svc.serviceEnabledChanges().listen((enabled) {
        if (!enabled) _onServiceOff();
      });
    } else if (!wantStream) {
      _cancel();
      if (!ref.read(mapVisibleProvider) && state.following) {
        state = state.copyWith(following: false); // hidden ⇒ drop follow
      }
    }
  }

  void _onFix(UserLocationFix fix) => state = state.copyWith(fix: fix);

  /// The OS told us Location Services were switched off — this reason we DO
  /// know, so route the user to the location settings.
  void _onServiceOff() {
    _cancel();
    state = state.copyWith(
        active: false,
        following: false,
        clearFix: true,
        status: LocationStatus.serviceOff);
  }

  /// A position-stream error can be many things (permission revoked mid-session,
  /// acquisition lost, a platform error). Do NOT assume "service off" —
  /// re-evaluate. On web `status()` isn't authoritative, so fall back to a
  /// generic `unknown` (the button shows a neutral retry affordance) (§5.7).
  Future<void> _onStreamError() async {
    _cancel();
    final status = kIsWeb ? LocationStatus.unknown : await _svc.status();
    state = state.copyWith(
        active: false, following: false, clearFix: true, status: status);
  }

  void _cancel() {
    _sub?.cancel();
    _sub = null;
    _serviceSub?.cancel();
    _serviceSub = null;
  }
}
