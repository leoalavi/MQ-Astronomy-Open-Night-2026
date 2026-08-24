import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_url.dart';

/// Directions are WALKING ONLY, everywhere. The request contract test
/// (`google_routes_service_test`) already pins `travelMode: WALK` on the Routes
/// call; this file pins the OTHER two things the brief demands: the external
/// hand-off is walking, and no alternative travel mode exists ANYWHERE in the
/// source — so there is no code path, and no selector, that could ever ask for
/// driving, transit, cycling or two-wheeler.
void main() {
  test('the external Google Maps hand-off is walking mode', () {
    final uri = buildWalkingMapsUrl(destLat: -33.7738, destLng: 151.1146);
    expect(uri.queryParameters['travelmode'], 'walking');
    // No other travel mode is smuggled in via a second parameter.
    expect(uri.query.toLowerCase(), isNot(contains('driving')));
    expect(uri.query.toLowerCase(), isNot(contains('transit')));
    expect(uri.query.toLowerCase(), isNot(contains('bicycling')));
  });

  test('no alternative travel mode appears anywhere in lib/', () {
    // A grep the compiler cannot do for us: prove there is no DRIVE / TRANSIT /
    // BICYCLE / TWO_WHEELER request mode, and no `travelmode=driving`-style URL,
    // sitting in a dormant code path. WALK / walking are the only modes allowed.
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
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final b in banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'alternative travel mode found — directions must be walking only:\n'
            '${offenders.join('\n')}');
  });
}
