import 'package:flutter/painting.dart'; // decodeImageFromList
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/campus_projection.dart';

void main() {
  // Real decode guard (design §0 must-fix #4): a renamed/missing PNG *and* a
  // truncated/corrupt one both fail HERE at CI, not as a blank map at runtime.
  // lengthInBytes>0 is NOT enough — a corrupt PNG can be non-empty. Decode it,
  // and assert the exact dimensions, which pin BOTH the §0 memory receipt
  // (2048x1448 RGBA == 11.3 MiB) and the georeferencing: the overlay bounds are
  // derived from a 4680x3310 render, so a re-render at a different aspect would
  // stretch the artwork away from the GPS calibration.
  testWidgets('the official AON basemap decodes at 2048x1448', (t) async {
    // decodeImageFromList does REAL async decoding on the engine; a testWidgets
    // fake-async zone never advances real time, so the await hangs (10-min
    // timeout) unless wrapped in runAsync.
    await t.runAsync(() async {
      const path = 'assets/maps/aon_event_map.png';
      final data = await rootBundle.load(path);
      final image = await decodeImageFromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      expect(image.width, 2048, reason: 'wrong width: $path');
      expect(image.height, 1448, reason: 'wrong height: $path');

      // The shipped raster must stay proportional to the render the
      // georeferencing was fitted against, or the ink slides off the pins.
      final shipped = image.width / image.height;
      const rendered = CampusProjection.aonRenderWidth /
          CampusProjection.aonRenderHeight;
      expect(shipped, closeTo(rendered, 1e-3),
          reason: 'aspect drift between the shipped asset and the georef render');
      image.dispose();
    });
  });
}
