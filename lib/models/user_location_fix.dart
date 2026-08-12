import 'package:latlong2/latlong.dart';

/// A validated device-position fix (no heading — Phase A, spec §5.1).
///
/// Validation is a real runtime check, NOT `assert` — asserts are stripped in
/// release, and an invalid coordinate reaching flutter_map can crash a layer.
class UserLocationFix {
  UserLocationFix({required this.position, required this.accuracyMeters}) {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        !accuracyMeters.isFinite ||
        accuracyMeters <= 0) {
      throw ArgumentError(
          'Invalid fix: position=$position accuracyMeters=$accuracyMeters');
    }
  }

  final LatLng position;
  final double accuracyMeters;

  /// Above this, the accuracy circle would be a misleading blob — the layer
  /// omits it and the control shows a "low accuracy" state (spec §5.1).
  static const double poorAccuracyMeters = 200;
  bool get isLowAccuracy => accuracyMeters > poorAccuracyMeters;
}
