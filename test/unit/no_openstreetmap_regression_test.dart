import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OpenStreetMap must never come back.
///
/// The campus basemap is Macquarie University's illustrated map and turn-by-turn
/// walking directions use Google Maps — there is no OSM tile source, provider,
/// attribution, or dependency anywhere. This test scans the shipping surfaces so
/// a re-introduced `TileLayer(urlTemplate: 'https://tile.openstreetmap.org/...')`
/// (or a stray "© OpenStreetMap" string, or an osm dependency) fails CI instead
/// of silently shipping.
///
/// The two existing guards check one facet each (`maps_sdk_boundary_test` the
/// tile endpoint in Dart; `map_attribution_test` the shipped ARB strings). This
/// one is the belt-and-braces sweep across Dart + config + localisation.
void main() {
  // These files legitimately contain the word to guard against it — they are
  // the regression tests themselves.
  const allowlist = <String>{
    'test/unit/no_openstreetmap_regression_test.dart',
    'test/unit/maps_sdk_boundary_test.dart',
    'test/unit/map_attribution_test.dart',
    'test/widget/settings_screen_test.dart', // asserts OSM is absent
  };

  final osm = RegExp(r'openstreetmap|tile\.openstreetmap', caseSensitive: false);

  Iterable<File> scan(String root, Set<String> exts) sync* {
    final dir = Directory(root);
    if (!dir.existsSync()) return;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File) continue;
      if (e.path.contains('/generated/')) continue;
      if (exts.any((x) => e.path.endsWith(x))) yield e;
    }
  }

  test('no Dart source references OpenStreetMap', () {
    final offenders = <String>[];
    for (final f in scan('lib', {'.dart'})) {
      if (osm.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    // Test sources too, minus the deliberate guards.
    for (final f in scan('test', {'.dart'})) {
      final rel = f.path.replaceFirst('${Directory.current.path}/', '');
      if (allowlist.contains(rel)) continue;
      if (osm.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'OpenStreetMap re-appeared in: $offenders');
  });

  test('no shipped localisation string mentions OpenStreetMap', () {
    for (final f in scan('lib/l10n', {'.arb'})) {
      expect(osm.hasMatch(f.readAsStringSync()), isFalse,
          reason: '${f.path} mentions OpenStreetMap');
    }
  });

  test('pubspec declares no OpenStreetMap-only package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // flutter_map is kept for the illustrated basemap; it is NOT an OSM package.
    // What must never appear is a tile/OSM provider dependency.
    for (final banned in const [
      'flutter_map_tile_caching',
      'osm_nominatim',
      'open_street_map',
    ]) {
      expect(pubspec.toLowerCase().contains(banned), isFalse,
          reason: 'pubspec pulls an OSM package: $banned');
    }
    // And no OSM word anywhere in the manifest, comments included.
    expect(pubspec.toLowerCase().contains('openstreetmap'), isFalse,
        reason: 'pubspec.yaml still mentions OpenStreetMap');
  });

  test('no native/web config references an OSM tile host', () {
    for (final f in [
      ...scan('android/app/src', {'.xml', '.kts', '.gradle', '.properties'}),
      ...scan('ios/Runner', {'.plist', '.swift'}),
      ...scan('web', {'.html'}),
    ]) {
      expect(osm.hasMatch(f.readAsStringSync()), isFalse,
          reason: '${f.path} references OpenStreetMap');
    }
  });
}
