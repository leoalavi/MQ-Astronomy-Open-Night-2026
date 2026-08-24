import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/venue.dart';

enum PlaceKind { venue, building }

/// A row in the unified search index. Displayed identity: a linked venue stays
/// a [VenueEntry] (semantic authority), but carries its [linkedBuilding] so it
/// inherits that building's search vocabulary for ranking (§0b.B).
sealed class SearchEntry {
  String get placeKey;
  String get title;
  PlaceKind get kind;
}

class VenueEntry extends SearchEntry {
  VenueEntry(this.venue, {this.linkedBuilding});
  final Venue venue;
  final Building? linkedBuilding;
  @override
  String get placeKey => 'venue:${venue.id}';
  @override
  String get title => venue.name;
  @override
  PlaceKind get kind => PlaceKind.venue;
}

class BuildingEntry extends SearchEntry {
  BuildingEntry(this.building);
  final Building building;
  @override
  String get placeKey => 'building:${building.id}';
  @override
  String get title => building.name;
  @override
  PlaceKind get kind => PlaceKind.building;
}

/// A selection resolved from a [SearchEntry.placeKey] (G5). Bundles what the map
/// + detail sheet need: render placement and routing target (routing consumed
/// by M4). `renderPoint` null ⇒ not placeable (no fake pin).
class ResolvedPlace {
  const ResolvedPlace({
    required this.kind,
    required this.placeKey,
    required this.title,
    required this.subtitle,
    required this.renderPoint,
    required this.routingLat,
    required this.routingLng,
    this.venueCategory,
  });
  final PlaceKind kind;
  final String placeKey;
  final String title;

  /// English, for ranking and diagnostics. What the visitor reads comes from
  /// `ResolvedPlaceL10n.subtitleOf` — see `utils/timing_labels.dart`.
  final String? subtitle;

  /// Set for a venue, so the subtitle can be re-resolved in the visitor's
  /// language rather than shipped pre-rendered in English.
  final VenueCategory? venueCategory;
  final CampusMapPoint? renderPoint;
  final double? routingLat, routingLng;
}
