import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
