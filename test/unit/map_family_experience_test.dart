import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/services/building_search.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/map_placement.dart';

/// The Map experience a family actually relies on at Astronomy Open Night:
/// they can find the important places, and "get directions" opens Google walking
/// navigation EMBEDDED INSIDE AON (never a hand-off to the external Google Maps
/// app). (The illustrated basemap, projection and marker internals have their
/// own dedicated suites — this pins the family-facing contract on top of them.)
void main() {
  const proj = CampusProjection();

  group('"Get directions" stays inside AON (embedded Google nav)', () {
    test('routes to the in-app google-nav screen for the place', () {
      // The directions CTA pushes the embedded nav route — NOT an external
      // Google Maps URL (removed 2026-08-30: users always stay in the app).
      final path = Routes.googleNavTo('building:central-courtyard');
      expect(path, startsWith('/google-nav/'));
      expect(path, contains(Uri.encodeComponent('building:central-courtyard')));
    });
  });

  group('important Astronomy Open Night locations are on the map', () {
    // Every venue Liz's email + the A3 map call out, by id.
    const importantIds = <String>[
      'central-courtyard',
      'macquarie-theatre',
      'mason-theatre',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
      '14-sir-christopher-ondaatje-avenue',
    ];

    test('each exists and can be pinned on the illustrated campus map', () {
      for (final id in importantIds) {
        final v = VenuesData.byId(id);
        expect(v, isNotNull, reason: 'missing important venue "$id"');
        expect(placeVenue(v!, proj), isNotNull,
            reason: '"$id" cannot be placed on the campus map');
      }
    });
  });

  group('map search finds what parents and children look for', () {
    // Query → at least one venue whose name/alias contains the answer. These are
    // the exact phrases a family types; each must return the right place.
    const expectations = <String, String>{
      'Central Courtyard': 'Central Courtyard',
      'central courtyard': 'Central Courtyard', // case-insensitive
      'Macquarie Theatre': 'Macquarie Theatre',
      'Mason Theatre': 'Mason Theatre',
      'Planetarium': 'Sport and Aquatic', // alias on the SAC
      'Observatory': 'Observatory',
      'Telescope': 'Observatory', // Telescope Park is at the Observatory
      'Food': 'Food',
      'Toilets': 'Toilets',
      'Kids': '1 Central Courtyard',
    };

    expectations.forEach((query, expectedFragment) {
      test('"$query" → a venue containing "$expectedFragment"', () {
        final hits = VenuesData.all
            .where((v) => scoreVenue(v, query) > 0)
            .map((v) => v.name)
            .toList();
        expect(hits, isNotEmpty, reason: '"$query" found nothing');
        expect(hits.any((n) => n.contains(expectedFragment)), isTrue,
            reason: '"$query" did not surface "$expectedFragment"; got $hits');
      });
    });

    test('partial words match (prefix)', () {
      // "Obser" should already find the Observatory.
      expect(VenuesData.all.where((v) => scoreVenue(v, 'Obser') > 0), isNotEmpty);
    });

    test('whitespace is trimmed', () {
      final a = VenuesData.all.where((v) => scoreVenue(v, '  Observatory  ') > 0);
      final b = VenuesData.all.where((v) => scoreVenue(v, 'Observatory') > 0);
      expect(a.length, b.length);
    });

    test('a nonsense query returns nothing, not everything', () {
      expect(
        VenuesData.all.where((v) => scoreVenue(v, 'zzzzz-not-a-place') > 0),
        isEmpty,
      );
    });

    test('an empty query scores nothing (idle browse handles the list)', () {
      for (final v in VenuesData.all) {
        expect(scoreVenue(v, ''), 0);
        expect(scoreVenue(v, '   '), 0);
      }
    });

    test('Persian queries resolve to the same venues (bilingual search)', () {
      // The app ships English + Persian. A Persian-speaking parent searches in
      // Persian; the aliases route those queries to the same official venues.
      const persian = <String, String>{
        'رصدخانه': 'Observatory',
        'تلسکوپ': 'Observatory',
        'سیاره‌نما': 'Sport and Aquatic',
        'حیاط مرکزی': 'Central Courtyard',
        'توالت': 'Toilets',
        'غذا': 'Food',
        'مترو': 'Metro',
      };
      persian.forEach((q, fragment) {
        final hits =
            VenuesData.all.where((v) => scoreVenue(v, q) > 0).map((v) => v.name);
        expect(hits, isNotEmpty, reason: '"\$q" found nothing');
        expect(hits.any((n) => n.contains(fragment)), isTrue,
            reason: '"\$q" did not surface "\$fragment"; got \${hits.toList()}');
      });
    });

    test('a Persian nonsense query returns nothing', () {
      expect(VenuesData.all.where((v) => scoreVenue(v, 'زززز') > 0), isEmpty);
    });

    test('exact-name matches outrank loose contains matches', () {
      // "Central Courtyard" exact must beat "1 Central Courtyard" (contains).
      final exact = VenuesData.byId('central-courtyard')!;
      final contains = VenuesData.byId('1-central-courtyard')!;
      expect(scoreVenue(exact, 'Central Courtyard'),
          greaterThan(scoreVenue(contains, 'Central Courtyard')));
    });
  });
}
