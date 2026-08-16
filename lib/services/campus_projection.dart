import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';

/// GPS → CrsSimple map-units via MQ Journey's `gcp_affine` calibration.
///
/// Compile-time constants (validity is a build/test invariant — see the
/// calibration drift test). **NEVER clamps:** returns `null` outside the frozen
/// domain (normalization box ∧ raster footprint). Fail-closed — no linear
/// fallback in production. `CampusMapPoint` values are NOT geographic lat/lng.
class CampusProjection {
  const CampusProjection();

  static const double _pw = 4678, _ph = 3307;
  // EXACT (no truncation): scale = max(1, max(pw/170, ph/85)); ph/85 is the max,
  // so scale == 3307/85 exactly and mapNorth == 85.0 exactly. One geometry, one
  // source of truth — MapConfig consumes these, does not re-hardcode them.
  static const double _scale = _ph / 85.0; // 3307/85 = 38.905882…
  static const List<double> _ax = [880.374832, 3889.927306, 12.547607];
  static const List<double> _ay = [2862.069113, -64.093654, -2349.078357];
  static const double _minLat = -33.7772506, _maxLat = -33.7703261;
  static const double _minLng = 151.1080508, _maxLng = 151.1211352;
  static const double _eps = 1e-9;

  static const double mapNorth = _ph / _scale; // == 85.0 exactly
  static const double mapEast = _pw / _scale; // 4678*85/3307 = 120.2389…

  CampusMapPoint? project(GpsPoint gps) {
    final lat = gps.value.latitude, lng = gps.value.longitude;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    final nLng = (lng - _minLng) / (_maxLng - _minLng);
    final nLat = (lat - _minLat) / (_maxLat - _minLat);
    if (nLng < -_eps || nLng > 1 + _eps || nLat < -_eps || nLat > 1 + _eps) {
      return null; // outside the calibration domain
    }
    final x = _ax[0] + _ax[1] * nLng + _ax[2] * nLat;
    final y = _ay[0] + _ay[1] * nLng + _ay[2] * nLat;
    if (x < -_eps || x > _pw + _eps || y < -_eps || y > _ph + _eps) {
      return null; // outside the raster footprint
    }
    return CampusMapPoint(LatLng((_ph - y) / _scale, x / _scale)); // Y-flip
  }

  bool canProject(GpsPoint gps) => project(gps) != null;

  /// Pixel-exact placement for MQ building `campusX/Y`, which live in the same
  /// 4678x3307 calibration space as [project]'s internal pixel step. STRICT
  /// raster bounds (no `_eps` slack — a fixed integer raster, not a float
  /// affine); null on the `(0,0)` "no campus coords" sentinel. NEVER clamps.
  CampusMapPoint? projectPixel(double x, double y) {
    if (x == 0 && y == 0) return null;
    if (x < 0 || x > _pw || y < 0 || y > _ph) return null;
    return CampusMapPoint(LatLng((_ph - y) / _scale, x / _scale)); // Y-flip, as project
  }
}
