import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/map_placement.dart';

/// Venue pins are placed on the OFFICIAL map's own printed markers.
///
/// The AON 2026 artwork already draws every event marker (A–I), the
/// registration and information points (1, 2, 3), the toilets (T) and first aid
/// (+) — positioned by the designer so they do not collide. The app used to
/// derive its pin positions from GPS centroids instead, which produced two
/// problems the artwork solves outright:
///
///  1. **Collisions.** Five venues share one coordinate
///     (-33.7733531, 151.1133796), so their pins stacked into identical hit
///     boxes and only the topmost was tappable.
///  2. **Duplicated markers.** Every app pin sat *beside* the printed disc for
///     the same place, so the map showed each venue twice.
///
/// `artworkX/artworkY` are measured off the published raster
/// (`tools/aon_map/measure_markers.py`) and are therefore authoritative for
/// WHERE THE MAP SAYS A THING IS. They are deliberately NOT treated as GPS:
/// `latitude`/`longitude` and their `coordinateConfidence` are untouched, so
/// bearing, distance, compass and routing keep using real coordinates.
void main() {
  const proj = CampusProjection();
  const venues = VenuesData.all;

  Venue byId(String id) => venues.firstWhere((v) => v.id == id);

  test('every printed marker on the official map has a venue pinned to it', () {
    // The artwork draws these; the app must place its pin on each one.
    const expected = {
      'macquarie-theatre',
      'mason-theatre',
      '14-sir-christopher-ondaatje-avenue',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
      'central-courtyard',
      'food-and-drink',
      'registration-point',
      'information-point-2',
      'information-point-3',
      'toilets-macquarie-theatre',
      'toilets-1-central-courtyard',
      'toilets-mason-theatre',
    };
    final placed = venues
        .where((v) => v.artworkX != null && v.artworkY != null)
        .map((v) => v.id)
        .toSet();
    expect(placed, expected);
  });

  test('artwork coordinates lie inside the published raster', () {
    for (final v in venues) {
      if (v.artworkX == null) continue;
      expect(v.artworkX, inInclusiveRange(0, CampusProjection.aonRenderWidth));
      expect(v.artworkY, inInclusiveRange(0, CampusProjection.aonRenderHeight));
    }
  });

  test('placeVenue prefers the artwork marker over the GPS centroid', () {
    final v = byId('registration-point');
    expect(v.artworkX, isNotNull);
    final placed = placeVenue(v, proj)!;
    final fromArtwork = proj.aonPixel(v.artworkX!, v.artworkY!);
    expect(placed.value, fromArtwork.value);
  });

  test('a venue with no artwork marker still places from GPS', () {
    // Transport pins (metro/bus/shuttle) keep their surveyed GPS placement.
    final metro = byId('metro-station');
    expect(metro.artworkX, isNull);
    expect(placeVenue(metro, proj), isNotNull);
  });

  test('unverified First Aid is not made into an interactive map place', () {
    expect(VenuesData.byId('first-aid'), isNull);
  });

  test('the Central Courtyard cluster no longer collides', () {
    // These five shared ONE coordinate. On the artwork the designer separated
    // them; assert they are now meaningfully apart in map units.
    const ids = [
      'registration-point',
      'information-point-2',
      'information-point-3',
      'food-and-drink',
      'central-courtyard',
    ];
    final pts = [for (final id in ids) placeVenue(byId(id), proj)!.value];
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d =
            (pts[i].latitude - pts[j].latitude).abs() +
            (pts[i].longitude - pts[j].longitude).abs();
        expect(
          d,
          greaterThan(0.8),
          reason: '${ids[i]} and ${ids[j]} still overlap (separation $d)',
        );
      }
    }
  });

  test('artwork placement does not disturb GPS truth', () {
    // The whole point: pins move, coordinates do not. Compass, bearing,
    // distance and routing all read latitude/longitude, so those must be
    // byte-identical to what they were.
    expect(byId('registration-point').latitude, -33.7733531);
    expect(byId('registration-point').longitude, 151.1133796);
    expect(byId('macquarie-theatre').latitude, -33.7746334);
    expect(byId('food-and-drink').longitude, 151.1133796);
  });

  test('no two venues claim the same printed map letter', () {
    // The artwork prints each legend marker exactly ONCE. Two venues sharing a
    // letter used to be harmless because both pins landed in the same pile;
    // now that pins sit on the real markers it would draw a letter the paper
    // map does not have. `central-courtyard` and `food-and-drink` both used
    // to claim "C".
    final seen = <String, String>{};
    for (final v in venues) {
      final ref = v.mapReference;
      if (ref == null) continue;
      expect(
        seen.containsKey(ref),
        isFalse,
        reason: '"$ref" claimed by both ${seen[ref]} and ${v.id}',
      );
      seen[ref] = v.id;
    }
  });
}
