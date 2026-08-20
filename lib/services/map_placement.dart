import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/campus_projection.dart';

/// The SINGLE source of placement truth (design §0b G5a) — used by both the
/// idle marker builder (G14) and `placeResolverProvider` (G5), so they can't
/// drift.
///
/// Priority: the OFFICIAL map's own printed marker, then a linked venue's baked
/// campusX/Y, then the verified GPS-affine position. Buildings are always
/// pixel-exact.
CampusMapPoint? placeVenue(Venue v, CampusProjection p) {
  // 1. The official artwork wins. It PRINTS this venue's marker at a spot the
  //    designer chose, spaced so markers don't collide — which a GPS centroid
  //    cannot reproduce (five venues share one coordinate) and which would
  //    otherwise draw the app's pin beside the printed disc for the same place.
  if (v.artworkX != null && v.artworkY != null) {
    return p.aonPixel(v.artworkX!, v.artworkY!);
  }
  // 2. A linked venue places pixel-exact from its baked campusX/Y (M3 G14).
  if (v.buildingId != null && v.campusX != null && v.campusY != null) {
    return p.projectPixel(v.campusX!, v.campusY!);
  }
  // 3. Otherwise the verified GPS-affine position, or nothing at all.
  return v.hasCoordinates
      ? p.project(GpsPoint(LatLng(v.latitude!, v.longitude!)))
      : null;
}

CampusMapPoint? placeBuilding(Building b, CampusProjection p) =>
    b.hasCampusCoordinates ? p.projectPixel(b.campusX!, b.campusY!) : null;
