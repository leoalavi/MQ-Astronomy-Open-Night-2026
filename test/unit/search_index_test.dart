import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/map_placement.dart';
import 'package:aon2026/services/search_providers.dart';

const _proj = CampusProjection();

void main() {
  // ── G5a: the single placement helper ──
  test('placeVenue: linked→pixel, unlinked→GPS-affine, no-coord→null', () {
    const linked = Venue(id: 'x', name: 'x', category: VenueCategory.other,
        buildingId: 'B', campusX: 1000, campusY: 1000);
    const unlinked = Venue(id: 'y', name: 'y', category: VenueCategory.other,
        latitude: -33.7739, longitude: 151.1126);
    const none = Venue(id: 'z', name: 'z', category: VenueCategory.other);
    expect(placeVenue(linked, _proj), _proj.projectPixel(1000, 1000));
    expect(placeVenue(unlinked, _proj), isNotNull);
    expect(placeVenue(none, _proj), isNull);
  });

  test('placeBuilding: pixel when campus coords, null otherwise', () {
    const b = Building(id: 'B', code: 'B', name: 'B', campusX: 1200, campusY: 800);
    const noc = Building(id: 'N', code: 'N', name: 'N');
    expect(placeBuilding(b, _proj), _proj.projectPixel(1200, 800));
    expect(placeBuilding(noc, _proj), isNull);
  });

  // ── G10: deterministic async (Completer-controlled registry) ──
  test('G10: a building appears in results ONLY after the registry loads', () async {
    final completer = Completer<List<Building>>();
    final c = ProviderContainer(overrides: [
      buildingsProvider.overrideWith((ref) => completer.future),
    ]);
    addTearDown(c.dispose);
    c.read(mapSearchQueryProvider.notifier).setQuery('ZZZBLD');
    expect(c.read(mapSearchResultsProvider).any((e) => e.placeKey == 'building:ZZZBLD'),
        isFalse, reason: 'building absent while registry is loading');
    completer.complete(const [
      Building(id: 'ZZZBLD', code: 'ZZZBLD', name: 'Zed Block', campusX: 100, campusY: 100),
    ]);
    await c.read(buildingsProvider.future);
    // query unchanged → the building now surfaces automatically
    expect(c.read(mapSearchResultsProvider).any((e) => e.placeKey == 'building:ZZZBLD'), isTrue);
  });

  // ── dedup + vocab inherit + ordering, on the real registry ──
  testWidgets('OBS: venue wins (deduped), still found by building code (vocab)', (t) async {
    await t.runAsync(() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(buildingsProvider.future);
      c.read(mapSearchQueryProvider.notifier).setQuery('OBS');
      final r = c.read(mapSearchResultsProvider);
      expect(r.any((e) => e.placeKey == 'building:OBS'), isFalse); // deduped
      expect(r.any((e) => e.placeKey == 'venue:astronomical-observatory'), isTrue); // via vocab
    });
  });

  test('isPlaceableOnMap: placeholder/no-coord venue → false; placeable venue/building → true', () {
    const noCoord = Venue(id: 'z', name: 'z', category: VenueCategory.other);
    const placed = Venue(id: 'y', name: 'y', category: VenueCategory.other,
        latitude: -33.7739, longitude: 151.1126);
    expect(isPlaceableOnMap(VenueEntry(noCoord)), isFalse); // list-only affordance path
    expect(isPlaceableOnMap(VenueEntry(placed)), isTrue);
    expect(
        isPlaceableOnMap(BuildingEntry(
            const Building(id: 'B', code: 'B', name: 'B', campusX: 1200, campusY: 800))),
        isTrue);
    expect(isPlaceableOnMap(BuildingEntry(const Building(id: 'N', code: 'N', name: 'N'))),
        isFalse);
  });

  testWidgets('idle → event venues FIRST, capped 15; scored → non-increasing; non-match empty',
      (t) async {
    await t.runAsync(() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(buildingsProvider.future);
      c.read(mapSearchQueryProvider.notifier).setQuery('');
      final idle = c.read(mapSearchResultsProvider);
      expect(idle.length, 15);
      // Event venues lead the idle browse — never buried behind building:* keys
      // that all sort ahead of venue:* (map audit P2).
      expect(idle.any((e) => e.kind == PlaceKind.venue), isTrue);
      final firstBuilding = idle.indexWhere((e) => e.kind == PlaceKind.building);
      final lastVenue = idle.lastIndexWhere((e) => e.kind == PlaceKind.venue);
      if (firstBuilding != -1) {
        expect(firstBuilding, greaterThan(lastVenue)); // all venues precede all buildings
      }

      c.read(mapSearchQueryProvider.notifier).setQuery('a');
      final scored = c.read(mapSearchResultsProvider);
      final scores = [for (final e in scored) scoreEntry(e, 'a')];
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i] <= scores[i - 1], isTrue, reason: 'not score-descending');
      }
      c.read(mapSearchQueryProvider.notifier).setQuery('zzznomatchxyz');
      expect(c.read(mapSearchResultsProvider), isEmpty);
    });
  });

  // ── placeResolver (G5) ──
  testWidgets('placeResolver: venue sync, building data, missing/malformed → null', (t) async {
    await t.runAsync(() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(buildingsProvider.future);
      final venue = c.read(placeResolverProvider('venue:astronomical-observatory'));
      expect(venue.value!.renderPoint, isNotNull);
      final bld = c.read(placeResolverProvider('building:18WW'));
      expect(bld.value!.kind, PlaceKind.building);
      expect(c.read(placeResolverProvider('building:NOPE')).value, isNull);
      expect(c.read(placeResolverProvider('garbage')).value, isNull);
    });
  });
}
