import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

/// Map camera and tile configuration.
///
/// Extracted so the map screen and the wayfinding screen share exactly one
/// definition of "where campus is" — two slightly different campus centres
/// would be a maddening bug to track down.
abstract final class MapConfig {
  /// Roughly the Central Courtyard, the event's centre of gravity.
  static const LatLng campusCentre = LatLng(-33.7737, 151.1134);

  static const double initialZoom = 16.2;
  static const double minZoom = 14;
  static const double maxZoom = 19;

  /// Bounding box for the Macquarie University campus, derived from the
  /// GPS bounds in MQ Journey's `campus_overlay_meta.json` and padded
  /// slightly to include the Metro station in the south-east.
  static final LatLngBounds campusBounds = LatLngBounds(
    const LatLng(-33.7800, 151.1030),
    const LatLng(-33.7680, 151.1230),
  );

  /// Follow-me only recenters within this radius of campus; beyond it the map
  /// stays framed on campus and shows an "off campus" note (spec §5.4).
  static const double locationCampusRadiusMeters = 2500;

  // ── CrsSimple campus-map units (Map Parity M1). Bounds come straight from
  //    CampusProjection so they can never drift from the projector — one
  //    geometry, one source of truth.
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(0, 0),
    const LatLng(CampusProjection.mapNorth, CampusProjection.mapEast),
  );

  /// Footprint of the OFFICIAL AON 2026 basemap (`assets/aon_event_map.png`,
  /// page 1 of the published program-and-map PDF) in the SAME CrsSimple space
  /// as [mapBounds].
  ///
  /// The artwork is a slightly different crop of the same MQ cartographic
  /// master, so it does NOT coincide with [mapBounds] — it overhangs to the
  /// west/north and stops ~138 px short on the east. Derived from the projector
  /// rather than hand-typed, so the artwork and the GPS calibration can never
  /// drift apart (see `CampusProjection.aonPixel` and the georef test).
  static final LatLngBounds aonMapBounds = () {
    const proj = CampusProjection();
    final sw = proj.aonPixel(0, CampusProjection.aonRenderHeight);
    final ne = proj.aonPixel(CampusProjection.aonRenderWidth, 0);
    return LatLngBounds(sw.value, ne.value);
  }();
  // Zoom range for the CrsSimple campus map. CrsSimple screen-px per map-unit =
  // 256·2^zoom, so the ~123×87-unit AON artwork frames on a phone at zoom ≈
  // -6.3 (390 px) to -6.6 (320 px), and the 4680-px raster reaches its native
  // 1:1 (beyond which it upscales/pixelates) at zoom ≈ -2.75.
  //
  //   minZoom -7  : just below the tightest phone fit, so the opening fit never
  //                 clamps, yet the furthest zoom-out still shows the whole map
  //                 large and readable — not the tiny thumbnail -8 allowed.
  //   maxZoom -2  : just inside the 1:1 raster limit, so the closest zoom-in
  //                 keeps labels legible without the heavy pixelation +1 gave.
  // Tuned against the CrsSimple math above and the on-device screenshots; the
  // initial fit (≈ -6.3) sits comfortably inside the range so it is authoritative.
  static const double mapMinZoom = -7;
  static const double mapMaxZoom = -2;

  static const Distance _distance = Distance();

  /// One canonical calculation, consumed by BOTH the guard and the banner.
  /// Takes a [GpsPoint], not a raw [LatLng], so a [CampusMapPoint] in map-units
  /// can't be fed to a geographic distance and yield a nonsense value that
  /// drives the off-campus banner / follow guard (map audit P2).
  static double distanceFromCampusMeters(GpsPoint p) =>
      _distance.as(LengthUnit.Meter, campusCentre, p.value);

  static bool isNearCampus(GpsPoint p,
          {double radiusMeters = locationCampusRadiusMeters}) =>
      distanceFromCampusMeters(p) <= radiusMeters;

  /// Magnetic declination at campus (east-positive), so magnetic heading + this
  /// = true heading. Preflight-verified (Map Parity Phase B, Task 0 receipt):
  ///   WMM2025 @ -33.7737,151.1134 @ 2026-09-19 = 12.752° E
  ///   (BGS geomagnetic web service, retrieved 2026-08-13).
  static const double campusMagneticDeclinationDegrees = 12.752;

  /// Below this range the arrow twitches (accuracy > remaining distance) and a
  /// bearing is less useful — show the "you're basically there" state instead.
  static const double pointMeNearTargetMeters = 20;

  /// Compass mode (M5). Max NEAREST buildings in the default (unfiltered) rose;
  /// venues are never culled by this — it bounds only the building fill (§0R-2).
  static const int compassMaxBuildingTargets = 12;

  /// Blip radius transfer clamps (metres): distance ≤ near ⇒ centre, ≥ far ⇒ rim
  /// (§0R-7). Radius fraction = ((m − near)/(far − near)).clamp(0,1).
  static const double compassNearClampMeters = 25;
  static const double compassFarClampMeters = 800;

  /// Targets whose true bearings fall within this gap are CLUSTERED into one
  /// marker (§0R-8) — never angularly/radially displaced (that would lie about
  /// bearing/distance).
  static const double compassMinAngularSepDegrees = 8;

}
