import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/models/indoor_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'DATA INTEGRITY: every tour manifest loads from the bundle, parses, hotspots + images resolve',
    () async {
      for (final tour in PanoramaData.tours) {
        final raw = await rootBundle.loadString(tour.manifestAsset);
        final m = IndoorManifest.fromJson(raw);
        expect(m.isEmpty, isFalse, reason: tour.venueId);
        final ids = m.nodes.map((n) => n.id).toSet();
        for (final n in m.nodes) {
          for (final nb in n.neighbours) {
            expect(
              ids.contains(nb.id),
              isTrue,
              reason: '${tour.venueId} hotspot ${nb.id}',
            );
          }
          final img = 'assets/data/${n.image}';
          expect(
            (await rootBundle.load(img)).lengthInBytes,
            greaterThan(0),
            reason: img,
          );
        }
      }
    },
  );

  test(
    'tourFor is an exact lookup — unknown venueId returns null (no path injection)',
    () {
      expect(PanoramaData.tourFor('macquarie-theatre'), isNotNull);
      expect(PanoramaData.tourFor('../../etc/passwd'), isNull);
      expect(PanoramaData.tourFor('does-not-exist'), isNull);
    },
  );

  test('tours are the legend venues with photography, plus the route walk', () {
    // A, B, D, E, F, G, H and I. Only C (Food and drink) has no tour: no
    // panorama is planned for it. G shipped once its two Observatory
    // originals were found unused in the source set (2026-08-31).
    // Nothing outside the official map's A-I legend appears EXCEPT
    // gymnasium-road — the Solar system walk, a route rather than a lettered
    // venue (see PanoramaData doc). The Jim Piper Centre panorama, which the map
    // letters nowhere, still does not ship.
    expect(PanoramaData.tours.map((t) => t.venueId).toSet(), {
      'macquarie-theatre',
      'mason-theatre',
      '14-sir-christopher-ondaatje-avenue',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
      'gymnasium-road',
    });
  });

  test('tour registry has no duplicate venue or manifest mappings', () {
    final venueIds = PanoramaData.tours.map((tour) => tour.venueId).toList();
    final manifests = PanoramaData.tours
        .map((tour) => tour.manifestAsset)
        .toList();
    expect(venueIds.toSet(), hasLength(venueIds.length));
    expect(manifests.toSet(), hasLength(manifests.length));
    expect(PanoramaData.tourFor('food-and-drink'), isNull);
  });

  test('D-I tour mappings point to the correct venue manifests', () async {
    const expected = {
      '14-sir-christopher-ondaatje-avenue': (
        'assets/data/indoor/14-sir-christopher-ondaatje-avenue.json',
        'entrance',
        'indoor/14-sir-christopher-ondaatje-avenue_',
      ),
      '1-central-courtyard': (
        'assets/data/indoor/1-central-courtyard.json',
        'entrance',
        'indoor/1-central-courtyard_',
      ),
      'sport-and-aquatic-centre': (
        'assets/data/indoor/sport-and-aquatic-centre.json',
        'centre',
        'indoor/sport-and-aquatic-centre_',
      ),
      'astronomical-observatory': (
        'assets/data/indoor/astronomical-observatory.json',
        'approach',
        'indoor/astronomical-observatory_',
      ),
      '11-wallys-walk': (
        'assets/data/indoor/11-wallys-walk.json',
        'entrance',
        'indoor/11-wallys-walk_',
      ),
      '17-wallys-walk': (
        'assets/data/indoor/17-wallys-walk.json',
        'entrance',
        'indoor/17-wallys-walk_',
      ),
    };

    for (final entry in expected.entries) {
      final tour = PanoramaData.tourFor(entry.key)!;
      expect(tour.manifestAsset, entry.value.$1, reason: entry.key);
      final manifest = IndoorManifest.fromJson(
        await rootBundle.loadString(tour.manifestAsset),
      );
      expect(manifest.nodes.first.id, entry.value.$2, reason: entry.key);
      expect(
        manifest.nodes.every((node) => node.image.startsWith(entry.value.$3)),
        isTrue,
        reason: '${entry.key} contains an image assigned to another venue',
      );
    }
  });

  test('no shipped tour is a placeholder', () {
    // The demo tour showed a different building behind a "sample imagery"
    // disclaimer. Real photography replaced it; this fails if it comes back.
    expect(
      PanoramaData.tours.where((t) => t.placeholder).map((t) => t.venueId),
      isEmpty,
    );
  });

  test(
    'every tour carries the scenes its manifest was generated with',
    () async {
      const expected = {
        'macquarie-theatre': 2,
        'mason-theatre': 1,
        '14-sir-christopher-ondaatje-avenue': 6,
        '1-central-courtyard': 12,
        'sport-and-aquatic-centre': 3,
        'astronomical-observatory': 2,
        '11-wallys-walk': 3,
        '17-wallys-walk': 4,
        'gymnasium-road': 13,
      };
      for (final tour in PanoramaData.tours) {
        final m = IndoorManifest.fromJson(
          await rootBundle.loadString(tour.manifestAsset),
        );
        expect(m.nodes.length, expected[tour.venueId], reason: tour.venueId);
      }
    },
  );

  test(
    '1CC rail keeps Stairs, orders rooms, and excludes Downstairs',
    () async {
      final tour = PanoramaData.tourFor('1-central-courtyard')!;
      final manifest = IndoorManifest.fromJson(
        await rootBundle.loadString(tour.manifestAsset),
      );

      expect(manifest.nodes.map((node) => node.id).toList(), [
        'entrance',
        'stairs',
        'room-101',
        'room-105',
        'room-106',
        'room-107',
        'lounge-108',
        'room-109',
        'room-112',
        'room-114',
        'room-115',
        'room-116',
      ]);
      expect(manifest.nodes.first.id, 'entrance');
      expect(manifest.nodes[1].id, 'stairs');
      expect(manifest.nodes[2].id, 'room-101');
      expect(manifest.nodes.map((node) => node.id), contains('stairs'));
      expect(
        manifest.nodes.map((node) => node.id),
        isNot(contains('downstairs')),
      );
      expect(
        manifest.nodes.expand((node) => node.neighbours).map((node) => node.id),
        isNot(contains('downstairs')),
      );
    },
  );

  test(
    'Stairs and Downstairs image assets both remain bundled',
    () async {
      // Downstairs is no longer held out — it is the Solar system walk's scene
      // 4, reached by alias (not a duplicate encode). Its asset must stay put.
      for (final asset in [
        'assets/data/indoor/1-central-courtyard_stairs.jpg',
        'assets/data/indoor/1-central-courtyard_downstairs.jpg',
      ]) {
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
      }
    },
  );

  test(
    'Solar system walk runs the numbered route 1->13, reusing E/F/G imagery',
    () async {
      // Order is the organiser's own numbering (Raouf 2026-09-01), Central
      // Courtyard -> Telescope Park — the direction visitors walk it. This is
      // the regression that pins the sequence; getting it reversed or reshuffled
      // is the failure mode this test exists to catch.
      final tour = PanoramaData.tourFor('gymnasium-road')!;
      expect(tour.placeholder, isFalse);
      final m = IndoorManifest.fromJson(
        await rootBundle.loadString(tour.manifestAsset),
      );

      expect(m.nodes.map((n) => n.id).toList(), [
        'courtyard-entrance',
        'courtyard-approach-stairs',
        'courtyard-stairs',
        'courtyard-downstairs',
        'planetarium-approach',
        'planetarium-entrance',
        'sport-and-aquatic-centre',
        'sport-and-aquatic-centre-street',
        'nextsense',
        'gymnasium-road-south',
        'gymnasium-road-north',
        'observatory-gate',
        'telescope-park',
      ]);

      // A route tour makes "add a forward arrow" tempting; the bearing would
      // still be guessed. No source carries pose metadata, so neighbours stay
      // empty, exactly as every other tour.
      expect(m.nodes.every((n) => n.neighbours.isEmpty), isTrue);

      // Eight of the thirteen scenes REUSE imagery E/F/G already bundle rather
      // than duplicate it. If these stop pointing at the shared asset the bundle
      // silently regrows by ~14 MB — pin the exact reuse.
      final byId = {for (final n in m.nodes) n.id: n.image};
      expect(byId['courtyard-entrance'], 'indoor/1-central-courtyard_entrance.jpg');
      expect(byId['courtyard-stairs'], 'indoor/1-central-courtyard_stairs.jpg');
      expect(byId['courtyard-downstairs'],
          'indoor/1-central-courtyard_downstairs.jpg');
      expect(byId['planetarium-approach'],
          'indoor/sport-and-aquatic-centre_planetarium-approach.jpg');
      expect(byId['planetarium-entrance'],
          'indoor/sport-and-aquatic-centre_planetarium-entrance.jpg');
      expect(byId['sport-and-aquatic-centre'],
          'indoor/sport-and-aquatic-centre_centre.jpg');
      // The observatory arrives northbound: gate (Entrance 2) before the wide
      // approach with the dome (Entrance 1) — the walk's arrival order.
      expect(byId['observatory-gate'],
          'indoor/astronomical-observatory_entrance.jpg');
      expect(byId['telescope-park'],
          'indoor/astronomical-observatory_approach.jpg');

      // The five scenes unique to the walk carry its own venue prefix.
      for (final id in const [
        'courtyard-approach-stairs',
        'sport-and-aquatic-centre-street',
        'nextsense',
        'gymnasium-road-south',
        'gymnasium-road-north',
      ]) {
        expect(byId[id], startsWith('indoor/gymnasium-road_'), reason: id);
      }
    },
  );

  test(
    'G runs Observatory approach then entrance, with no invented hotspots',
    () async {
      // Order is the photographer's own "Entrance 1"/"Entrance 2" naming,
      // corroborated by the GPS capture stamps (15:18 then 15:22 on
      // 2026-08-23). The originals carry no pose metadata, so — as with every
      // other tour — neighbours stay empty rather than guess a bearing.
      final tour = PanoramaData.tourFor('astronomical-observatory')!;
      final manifest = IndoorManifest.fromJson(
        await rootBundle.loadString(tour.manifestAsset),
      );

      expect(manifest.nodes.map((node) => node.id).toList(), [
        'approach',
        'entrance',
      ]);
      expect(
        manifest.nodes.every((node) => node.neighbours.isEmpty),
        isTrue,
        reason: 'no source photo carries a bearing to draw a hotspot from',
      );
      for (final node in manifest.nodes) {
        expect(
          (await rootBundle.load('assets/data/${node.image}')).lengthInBytes,
          greaterThan(0),
          reason: node.id,
        );
      }
    },
  );
}
