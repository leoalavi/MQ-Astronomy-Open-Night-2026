import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/user_location_fix.dart';

enum LocationStatus { unknown, granted, denied, deniedForever, serviceOff }

/// The hardware seam. Everything above this is tested with a fake (spec §5.2).
abstract interface class LocationService {
  Future<LocationStatus> status();
  Future<LocationStatus> request();
  Stream<UserLocationFix> watch();
  Stream<bool> serviceEnabledChanges();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationStatus> status() async {
    // Web: checkPermission can falsely say denied — do not gate on it here;
    // request()/watch() attempt acquisition and the browser prompts (§5.2.1).
    if (kIsWeb) return LocationStatus.unknown;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationStatus> request() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.serviceOff;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Stream<UserLocationFix> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(distanceFilter: 5),
      )
          .where((p) =>
              p.latitude.abs() <= 90 &&
              p.longitude.abs() <= 180 &&
              p.accuracy.isFinite &&
              p.accuracy > 0)
          .map((p) => UserLocationFix(
                position: LatLng(p.latitude, p.longitude),
                accuracyMeters: p.accuracy,
              ));

  @override
  Stream<bool> serviceEnabledChanges() {
    if (kIsWeb) return const Stream<bool>.empty(); // unsupported on web
    return Geolocator.getServiceStatusStream()
        .map((s) => s == ServiceStatus.enabled);
  }

  @override
  Future<void> openAppSettings() async {
    if (kIsWeb) return; // UnsupportedError on web
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    if (kIsWeb) return; // UnsupportedError on web
    await Geolocator.openLocationSettings();
  }

  LocationStatus _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationStatus.granted,
        LocationPermission.denied => LocationStatus.denied,
        LocationPermission.deniedForever => LocationStatus.deniedForever,
        LocationPermission.unableToDetermine => LocationStatus.unknown,
      };
}
