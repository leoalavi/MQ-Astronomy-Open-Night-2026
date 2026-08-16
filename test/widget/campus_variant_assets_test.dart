import 'package:flutter/painting.dart'; // decodeImageFromList
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';

void main() {
  // Real decode guard (design §0 must-fix #4): a renamed/missing PNG *and* a
  // truncated/corrupt one both fail HERE at CI, not as a blank map at runtime.
  // lengthInBytes>0 is NOT enough — a corrupt PNG can be non-empty. decode it,
  // and asserting the exact 2048x1448 also pins the projection-critical
  // dimensions and the §0 memory receipt.
  testWidgets('every base + variant asset decodes at 2048x1448', (t) async {
    // decodeImageFromList does REAL async decoding on the engine; a testWidgets
    // fake-async zone never advances real time, so the await hangs (10-min
    // timeout) unless wrapped in runAsync.
    await t.runAsync(() async {
      final paths = [
        CampusVariantsData.baseAsset,
        for (final v in CampusVariantsData.all) v.assetPath,
      ];
      for (final p in paths) {
        final data = await rootBundle.load(p);
        final image = await decodeImageFromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        expect(image.width, 2048, reason: 'wrong width: $p');
        expect(image.height, 1448, reason: 'wrong height: $p');
        image.dispose();
      }
    });
  });
}
