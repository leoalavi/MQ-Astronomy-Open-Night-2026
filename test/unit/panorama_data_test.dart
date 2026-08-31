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

  test('tours are exactly the legend venues that have real photography', () {
    // A, B, D, E, F, G, H and I. Only C (Food and drink) has no tour: no
    // panorama is planned for it. G shipped once its two Observatory
    // originals were found unused in the source set (2026-08-31).
    // Nothing outside the official map's A-I legend appears — notably the
    // Jim Piper Centre panorama, which the map letters nowhere.
    expect(PanoramaData.tours.map((t) => t.venueId).toSet(), {
      'macquarie-theatre',
      'mason-theatre',
      '14-sir-christopher-ondaatje-avenue',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
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
    'Stairs and held-out Downstairs image assets both remain bundled',
    () async {
      for (final asset in [
        'assets/data/indoor/1-central-courtyard_stairs.jpg',
        'assets/data/indoor/1-central-courtyard_downstairs.jpg',
      ]) {
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
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
