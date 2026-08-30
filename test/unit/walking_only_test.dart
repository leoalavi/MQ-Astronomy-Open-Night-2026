import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two brief-mandated source-level invariants the Dart compiler cannot check for
/// us, proven by grepping `lib/`:
///
///  1. **Walking only, everywhere (MAP #12).** The Routes request contract test
///     (`google_routes_service_test`) pins `travelMode: WALK`; this proves there
///     is no DRIVE / TRANSIT / BICYCLE / TWO_WHEELER mode and no
///     `travelmode=driving`-style URL sitting in any dormant code path — so no
///     selector or branch could ever ask for a non-walking mode.
///
///  2. **No external Google Maps hand-off (MAP #9).** Directions are embedded
///     inside AON. Prove the deleted external path cannot creep back: no
///     external-launcher service, no keyless `maps/dir/` URL builder, no
///     "open in Google Maps" affordance.
void main() {
  Iterable<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('MAP #12: no alternative travel mode appears anywhere in lib/', () {
    final banned = <String>[
      "'DRIVE'",
      "'TRANSIT'",
      "'BICYCLE'",
      "'TWO_WHEELER'",
      'travelmode=driving',
      'travelmode=transit',
      'travelmode=bicycling',
    ];
    final offenders = <String>[];
    for (final f in libDartFiles()) {
      final src = f.readAsStringSync();
      for (final b in banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'alternative travel mode found — directions must be walking only:\n'
            '${offenders.join('\n')}');
  });

  test('MAP #9: no external Google Maps hand-off remains in lib/', () {
    // Any of these reappearing means someone re-added a way to send the visitor
    // out of AON to the Google Maps app/site.
    final banned = <String>[
      'ExternalMapsLauncher',
      'externalMapsLauncherProvider',
      'buildWalkingMapsUrl',
      "'/maps/dir/'",
      'maps/dir/?api=1',
      'maps_url.dart',
      'external_maps_launcher.dart',
    ];
    final offenders = <String>[];
    for (final f in libDartFiles()) {
      final src = f.readAsStringSync();
      for (final b in banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'external Google Maps hand-off found — Directions must stay '
            'inside AON:\n${offenders.join('\n')}');
  });
}
