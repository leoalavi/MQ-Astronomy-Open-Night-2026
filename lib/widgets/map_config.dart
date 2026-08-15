import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  // Zoom range for the CrsSimple campus map. CrsSimple scale = 256·2^zoom, so on
  // a phone the whole 120×85-unit campus frames at zoom ≈ -6.3 (verified
  // on-device). minZoom must sit BELOW that or initialCameraFit clamps and the
  // map opens far too zoomed-in; maxZoom must sit ABOVE the widget-test's
  // 0-size-viewport fit (0.0) or the camera throws (Map Parity M1, on-device
  // finding). Bracketed to satisfy both: whole campus at open, room to zoom in.
  static const double mapMinZoom = -8;
  static const double mapMaxZoom = 1;

  static const Distance _distance = Distance();

  /// One canonical calculation, consumed by BOTH the guard and the banner.
  static double distanceFromCampusMeters(LatLng p) =>
      _distance.as(LengthUnit.Meter, campusCentre, p);

  static bool isNearCampus(LatLng p,
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

  /// Standard OpenStreetMap raster tiles.
  ///
  /// **No API key.** That is the point — see `docs/architecture.md`. Usage is
  /// subject to the OSM Foundation Tile Usage Policy, which requires visible
  /// attribution and a genuine User-Agent, both of which we provide.
  ///
  /// For an event that could put thousands of devices on these tiles in one
  /// evening, the polite and more reliable path before the night is either a
  /// self-hosted tile server or a commercial provider. Flagged as a risk in
  /// the README.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String userAgentPackageName = 'au.edu.mq.astronomy.aon2026';
}
