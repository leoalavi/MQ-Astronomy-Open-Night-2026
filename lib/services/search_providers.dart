import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/building_search.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/map_placement.dart';
import 'package:aon2026/services/providers.dart' show venuesProvider;

const _proj = CampusProjection();
const _idleCap = 15; // parity with MQ's _defaultVisibleBuildings

/// Mutable search text (G3: query state is separate from derived results, so
/// results recompute when the registry loads). AON idiom — a method, not `.state`.
class MapSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final mapSearchQueryProvider =
    NotifierProvider<MapSearchQuery, String>(MapSearchQuery.new);

/// The currently-selected place, as a stable `PlaceKey` (never a live entry).
/// Set on selection, cleared when the detail sheet closes (G15).
class SelectedPlaceKey extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? key) => state = key;
  void clear() => state = null;
}

final selectedPlaceKeyProvider =
    NotifierProvider<SelectedPlaceKey, String?>(SelectedPlaceKey.new);

/// Unified index over venues ⊕ buildings, deduped on the curated identity link.
/// Venues are always present; buildings fold in when `buildingsProvider` loads
/// (venues-only meanwhile). A linked venue drops the matching building and
/// carries it as `linkedBuilding` for vocab-inherited ranking (§0b.B).
final searchIndexProvider = Provider<List<SearchEntry>>((ref) {
  final venues = ref.watch(venuesProvider);
  final buildings = ref.watch(buildingsProvider).asData?.value ?? const <Building>[];
  final byId = {for (final b in buildings) b.id: b};
  final linkedIds = {for (final v in venues) if (v.buildingId != null) v.buildingId!};
  return <SearchEntry>[
    for (final v in venues)
      VenueEntry(v, linkedBuilding: v.buildingId != null ? byId[v.buildingId] : null),
    for (final b in buildings)
      if (!linkedIds.contains(b.id)) BuildingEntry(b),
  ];
});

/// Score an entry. A linked venue takes the MAX of its own fields and the
/// linked building's vocabulary, so dedup can never make search worse.
int scoreEntry(SearchEntry e, String q) => switch (e) {
      BuildingEntry(:final building) => scoreBuildingMatch(building, q),
      VenueEntry(:final venue, :final linkedBuilding) => [
          scoreVenue(venue, q),
          if (linkedBuilding != null) scoreBuildingMatch(linkedBuilding, q),
        ].reduce((a, b) => a > b ? a : b),
    };

/// Ranked results. Empty query → first 15 by `placeKey` asc. Non-empty →
/// `score>0`, score desc, `placeKey` asc tiebreak, capped at 15 (G11/G13).
final mapSearchResultsProvider = Provider<List<SearchEntry>>((ref) {
  final q = normalizeMapSearch(ref.watch(mapSearchQueryProvider));
  final index = ref.watch(searchIndexProvider);
  if (q.isEmpty) {
    final sorted = [...index]..sort((a, b) => a.placeKey.compareTo(b.placeKey));
    return sorted.take(_idleCap).toList();
  }
  final scored = [
    for (final e in index)
      if (scoreEntry(e, q) case final s when s > 0) (e: e, s: s),
  ]..sort((a, b) {
      final byScore = b.s.compareTo(a.s);
      return byScore != 0 ? byScore : a.e.placeKey.compareTo(b.e.placeKey);
    });
  return [for (final r in scored.take(_idleCap)) r.e];
});

/// Resolve a `PlaceKey` → the map/detail payload (G5). `venue:` resolves
/// synchronously; `building:` follows the registry (loading → data → null if
/// absent); malformed key → data(null). Render + routing via the shared helpers.
final placeResolverProvider =
    Provider.family<AsyncValue<ResolvedPlace?>, String>((ref, key) {
  if (key.startsWith('venue:')) {
    final v = VenuesData.byId(key.substring('venue:'.length));
    if (v == null) return const AsyncData(null);
    return AsyncData(ResolvedPlace(
      kind: PlaceKind.venue, placeKey: key, title: v.name, subtitle: v.category.label,
      renderPoint: placeVenue(v, _proj),
      routingLat: v.routingLatitude, routingLng: v.routingLongitude,
    ));
  }
  if (key.startsWith('building:')) {
    final id = key.substring('building:'.length);
    return ref.watch(buildingsProvider).when(
          loading: () => const AsyncLoading(),
          error: (_, _) => const AsyncData(null),
          data: (list) {
            Building? b;
            for (final x in list) {
              if (x.id == id) { b = x; break; }
            }
            if (b == null) return const AsyncData(null);
            return AsyncData(ResolvedPlace(
              kind: PlaceKind.building, placeKey: key, title: b.name, subtitle: b.code,
              renderPoint: placeBuilding(b, _proj),
              routingLat: b.routingLatitude, routingLng: b.routingLongitude,
            ));
          },
        );
  }
  return const AsyncData(null);
});
