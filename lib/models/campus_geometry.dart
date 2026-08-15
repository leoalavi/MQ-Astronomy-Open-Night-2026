import 'package:latlong2/latlong.dart';

/// WGS84 degrees (projection INPUT). A wrapper so a GPS `LatLng` cannot be
/// passed to a map layer un-projected. Does not validate range — the projection
/// validates (extension types guard semantics, not data).
extension type const GpsPoint(LatLng value) {}

/// CrsSimple map-units (projection OUTPUT, for flutter_map). NOT a geographic
/// lat/lng — never feed `.value` to latlong2 `Distance`/bearing/Phase B maths.
extension type const CampusMapPoint(LatLng value) {}
