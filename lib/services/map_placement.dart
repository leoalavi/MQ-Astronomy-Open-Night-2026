import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/campus_projection.dart';

/// The SINGLE source of placement truth (design §0b G5a) — used by both the
/// idle marker builder (G14) and `placeResolverProvider` (G5), so they can't
/// drift. A linked venue places pixel-exact (its baked campusX/Y); an unlinked
/// venue keeps its verified GPS-affine position; buildings always pixel-exact.
CampusMapPoint? placeVenue(Venue v, CampusProjection p) =>
    (v.buildingId != null && v.campusX != null && v.campusY != null)
        ? p.projectPixel(v.campusX!, v.campusY!)
        : (v.hasCoordinates
            ? p.project(GpsPoint(LatLng(v.latitude!, v.longitude!)))
            : null);

CampusMapPoint? placeBuilding(Building b, CampusProjection p) =>
    b.hasCampusCoordinates ? p.projectPixel(b.campusX!, b.campusY!) : null;
