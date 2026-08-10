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
}
