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

  test(
    'tours are exactly the legend venues that have real photography',
    () {
      // A, B, D, E, H and I. C (Food and drink), F (Sport and Aquatic Centre)
      // and G (Astronomical Observatory) have no imagery yet and correctly
      // have no tour. Nothing outside the official map's A-I legend appears —
      // notably the Jim Piper Centre panorama, which the map letters nowhere.
      expect(PanoramaData.tours.map((t) => t.venueId).toSet(), {
        'macquarie-theatre',
        'mason-theatre',
        '14-sir-christopher-ondaatje-avenue',
        '1-central-courtyard',
        '11-wallys-walk',
        '17-wallys-walk',
      });
    },
  );

  test('no shipped tour is a placeholder', () {
    // The demo tour showed a different building behind a "sample imagery"
    // disclaimer. Real photography replaced it; this fails if it comes back.
    expect(
      PanoramaData.tours.where((t) => t.placeholder).map((t) => t.venueId),
      isEmpty,
    );
  });

  test('every tour carries the scenes its manifest was generated with', () async {
    const expected = {
      'macquarie-theatre': 2,
      'mason-theatre': 1,
      '14-sir-christopher-ondaatje-avenue': 6,
      '1-central-courtyard': 12,
      '11-wallys-walk': 3,
      '17-wallys-walk': 4,
    };
    for (final tour in PanoramaData.tours) {
      final m = IndoorManifest.fromJson(
        await rootBundle.loadString(tour.manifestAsset),
      );
      expect(m.nodes.length, expected[tour.venueId], reason: tour.venueId);
    }
  });
}
