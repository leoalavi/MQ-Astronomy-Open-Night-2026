import 'package:flutter/foundation.dart';

import 'package:aon2026/models/data_confidence.dart';

/// A place on campus that the app can show on the map and route to.
///
/// This is a deliberately **cut-down rewrite** of MQ Journey's `Building`
/// entity (448 lines). That class carries faculty groups, student-services
/// drill-down groups, campus-hub groups, indoor level counts and a 40-token
/// search index — all of which exist to serve MQ Journey's year-round
/// student-services browse experience and mean nothing for a six-hour public
/// event. We keep only the fields this product actually renders.
///
/// Retained from `Building` (they earned their place):
/// * `entrance*` coordinates distinct from centroid — routing to a building
///   centroid drops people on the wrong side of a building at night.
/// * `aliases` — attendees search "Mason Theatre", not "14SCO".
@immutable
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.category,
    this.shortName,
    this.building,
    this.address,
    this.latitude,
    this.longitude,
    this.entranceLatitude,
    this.entranceLongitude,
    this.coordinateConfidence = DataConfidence.placeholder,
    this.mapReference,
    this.aliases = const [],
    this.accessibilityNotes,
    this.notes,
    this.buildingId,
    this.campusX,
    this.campusY,
    this.artworkX,
    this.artworkY,
  });

  final String id;

  /// Full official name, as printed in the event materials. Used in headings
  /// and detail views where there is room for it.
  final String name;

  /// Compact label for filter chips and other tight spaces.
  ///
  /// Chips clip rather than wrap, and several official names ("Macquarie
  /// University Astronomical Observatory") are far too long for a 375pt phone.
  /// Falls back to [name] when unset — see [chipLabel].
  final String? shortName;

  final VenueCategory category;

  /// Official building name, where the venue sits inside a larger building.
  /// e.g. Mason Theatre's building is "14 Sir Christopher Ondaatje Avenue".
  final String? building;

  final String? address;

  final double? latitude;
  final double? longitude;

  /// Preferred pedestrian entrance, when it differs from the centroid.
  final double? entranceLatitude;
  final double? entranceLongitude;

  /// Provenance of [latitude]/[longitude]. See [DataConfidence].
  final DataConfidence coordinateConfidence;

  /// The letter used on the official printed map legend (A–I), where the
  /// venue has one. Lets the app speak the same language as the paper map
  /// people are holding.
  final String? mapReference;

  final List<String> aliases;
  final String? accessibilityNotes;

  /// Free-text operational note shown on the venue sheet.
  final String? notes;

  /// Map Parity M3: when this venue *is* a registry building, its id (semantic
  /// authority stays with the venue; render placement comes from the building).
  final String? buildingId;

  /// Baked pixel-exact overlay coords copied from the linked building
  /// (drift-tested against buildings.json). Present iff [buildingId] is set.
  final double? campusX, campusY;

  /// Where this venue's marker is PRINTED on the official AON 2026 map, in the
  /// artwork's own 4680x3310 pixel space (see `CampusProjection.aonPixel`).
  ///
  /// The published map already places every A–I disc, the 1/2/3 points, the
  /// toilets and first aid, spaced by the designer so they do not collide.
  /// Measured off the raster by `tools/aon_map/measure_markers.py`, so the pin
  /// the app draws lands on the marker the paper map shows.
  ///
  /// A MAP-PLACEMENT coordinate, never a geographic one. It does not touch
  /// [latitude]/[longitude] or [coordinateConfidence] — bearing, distance,
  /// compass and routing keep reading real coordinates, and a venue with a
  /// printed marker but no GPS fix (first aid) stays honestly unroutable while
  /// still appearing on the map.
  final double? artworkX, artworkY;

  /// The label to use anywhere horizontal space is constrained.
  String get chipLabel => shortName ?? name;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasCampusCoordinates =>
      campusX != null && campusY != null && !(campusX == 0 && campusY == 0);

  // G2: entrance is used only when the PAIR is present, else the centre pair —
  // never mix entrance-lat with centre-lng (a coordinate that never existed).
  bool get hasEntranceCoordinates =>
      entranceLatitude != null && entranceLongitude != null;

  /// Best coordinate to route *to*. Prefers the entrance (as a pair).
  double? get routingLatitude => hasEntranceCoordinates ? entranceLatitude : latitude;
  double? get routingLongitude => hasEntranceCoordinates ? entranceLongitude : longitude;

  /// Case-insensitive match across name, building, address and aliases.
  /// Simpler than MQ Journey's 0–120 ranked scorer, which that app needs
  /// because it searches 170 buildings; we search ~20 venues.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (building?.toLowerCase().contains(q) ?? false) ||
        (address?.toLowerCase().contains(q) ?? false) ||
        (mapReference?.toLowerCase() == q) ||
        aliases.any((a) => a.toLowerCase().contains(q));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Venue && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Venue($id, $name)';
}

/// What kind of place this is — drives marker colour and the map filter chips.
enum VenueCategory {
  eventVenue('Event venue'),
  informationPoint('Information point'),
  registration('Registration'),
  toilets('Toilets'),
  firstAid('First aid'),
  foodAndDrink('Food and drink'),
  parking('Parking'),
  metro('Metro station'),
  other('Other');

  const VenueCategory(this.label);

  final String label;
}
