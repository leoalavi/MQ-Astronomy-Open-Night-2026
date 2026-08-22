import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/building_search.dart' show normalizeMapSearch;
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/search_providers.dart' show scoreEntry, searchIndexProvider;
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

/// One findable place with its live geometry to the user's fix. Geographic WGS84.
class NearbyTarget {
  const NearbyTarget({
    required this.placeKey,
    required this.title,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.trueBearingDegrees,
    required this.confidence,
  });
  final String placeKey;
  final String title;
  final PlaceKind kind;
  final double lat, lng;
  final double distanceMeters;
  final double trueBearingDegrees;
  final DataConfidence confidence;
}

/// Routing coords for an entry — SAME rule `placeResolverProvider` uses
/// (entrance pair else centre). Null ⇒ not locatable.
(double, double)? routingLatLngOf(SearchEntry e) {
  final (lat, lng) = switch (e) {
    VenueEntry(:final venue) => (venue.routingLatitude, venue.routingLongitude),
    BuildingEntry(:final building) => (building.routingLatitude, building.routingLongitude),
  };
  if (lat == null || lng == null) return null;
  return (lat, lng);
}

/// Venues carry provenance; buildings come from the survey registry (no field
/// ⇒ treated as confirmed).
DataConfidence confidenceOf(SearchEntry e) => switch (e) {
      VenueEntry(:final venue) => venue.coordinateConfidence,
      BuildingEntry() => DataConfidence.confirmed,
    };

NearbyTarget _target(SearchEntry e, LatLng fix, double lat, double lng) {
  final to = LatLng(lat, lng);
  return NearbyTarget(
    placeKey: e.placeKey,
    title: e.title,
    kind: e.kind,
    lat: lat,
    lng: lng,
    distanceMeters: distanceBetweenMeters(fix, to),
    trueBearingDegrees: trueBearingDegrees(fix, to),
    confidence: confidenceOf(e),
  );
}

int _byDistance(NearbyTarget a, NearbyTarget b) {
  final d = a.distanceMeters.compareTo(b.distanceMeters);
  return d != 0 ? d : a.placeKey.compareTo(b.placeKey);
}

/// Venue-biased nearest targets (§0R-2/§0R-3). The filter runs over the FULL
/// index first via M3's [scoreEntry] (so building codes/aliases match, not just
/// titles); empty filter → all locatable venues + nearest [maxBuildings]
/// buildings; non-empty filter → nearest [maxBuildings] of the scored matches.
List<NearbyTarget> nearestTargets(
  LatLng fix,
  List<SearchEntry> index, {
  String filter = '',
  int maxBuildings = MapConfig.compassMaxBuildingTargets,
  double maxDistanceMeters = MapConfig.locationCampusRadiusMeters,
}) {
  // Gate on the FIX, not on each target. §0R-2's venue-bias deliberately keeps
  // ALL locatable venues however far across campus they are — a per-target
  // ceiling would silently break that. What is absurd is not a distant venue,
  // it is the whole list when the user is nowhere near Macquarie: from
  // Cupertino every arrow points across the Pacific. Off campus the list is
  // empty and `NearbyList` renders `compassNothingNearby`, which was
  // unreachable before this gate because the list was never empty.
  if (!MapConfig.isNearCampus(GpsPoint(fix), radiusMeters: maxDistanceMeters)) {
    return const <NearbyTarget>[];
  }

  final q = normalizeMapSearch(filter);
  final located = <NearbyTarget>[];
  for (final e in index) {
    final ll = routingLatLngOf(e);
    if (ll == null) continue;
    if (q.isNotEmpty && scoreEntry(e, q) <= 0) continue; // M3 vocabulary (§0R-3)
    located.add(_target(e, fix, ll.$1, ll.$2));
  }
  located.sort(_byDistance);
  if (q.isNotEmpty) {
    return located.take(maxBuildings).toList(); // filtered: nearest-N of matches
  }
  final venues = located.where((t) => t.kind == PlaceKind.venue);
  final buildings = located.where((t) => t.kind == PlaceKind.building).take(maxBuildings);
  return [...venues, ...buildings]..sort(_byDistance);
}

/// Known-but-unlocatable venues (null coords) — surfaced as disabled rows so a
/// safety venue like First Aid is never silently dropped (§0R-4).
List<SearchEntry> unlocatableVenues(List<SearchEntry> index) => index
    .where((e) => e.kind == PlaceKind.venue && routingLatLngOf(e) == null)
    .toList();

/// The compass filter string (M3 vocabulary). Notifier method; no external set.
final compassFilterProvider =
    NotifierProvider<CompassFilter, String>(CompassFilter.new);

class CompassFilter extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

/// Venue-biased nearest targets for the current fix + filter. `const []` when no
/// fix (§0.6 empty). Watches only fix/index/filter — NOT heading (§0R-12).
final nearbyTargetsProvider = Provider<List<NearbyTarget>>((ref) {
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  if (fix == null) return const <NearbyTarget>[];
  final index = ref.watch(searchIndexProvider);
  final filter = ref.watch(compassFilterProvider);
  return nearestTargets(fix.position, index, filter: filter);
});
