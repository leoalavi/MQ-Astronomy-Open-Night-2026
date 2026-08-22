import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _filesContaining(String needle) async {
  final hits = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if ((await entity.readAsString()).contains(needle)) hits.add(entity.path);
  }
  return hits..sort();
}

void main() {
  test('only maps_sdk_initializer.dart may call ensureInitialized', () async {
    // Flutter's own WidgetsFlutterBinding.ensureInitialized() shares the name,
    // so the needle is scoped to the initialiser's own call shape.
    final offenders = (await _filesContaining('MapsSdkInitializer'))
        .where((p) => !p.endsWith('maps_sdk_initializer.dart'))
        .where((p) => !p.endsWith('main.dart')) // the sanctioned override site
        .toList();

    expect(offenders, isEmpty,
        reason: 'spec §2b is enforced by mapsSdkReadyProvider, which checks '
            'consent BEFORE touching the initialiser. Naming MapsSdkInitializer '
            'outside its own library (or main.dart, which installs the '
            'production instance) means a call site can reach past that gate — '
            'watch mapsSdkReadyProvider instead.');
  });

  test('only embedded_map.dart may construct a GoogleMap', () async {
    // The consent gate protects the paths we know about. This makes a NEW
    // Google surface impossible to add without tripping a test — which is
    // exactly the failure mode that produced the google_nav_screen regression.
    final offenders = (await _filesContaining('GoogleMap('))
        .where((p) => !p.endsWith('embedded_map.dart'))
        .toList();

    expect(offenders, isEmpty,
        reason: 'route every Google surface through EmbeddedMap so it inherits '
            'the mapsSdkReadyProvider gate');
  });

  test('flutter_map is still in use — do NOT drop the dependency', () async {
    // Task 5 deleted DarkTileLayer, which invites "flutter_map is dead now".
    // It is not: map_screen renders the CrsSimple AON basemap with it, and
    // dropping the package would break the app's primary map.
    final consumers = await _filesContaining('package:flutter_map/');
    expect(consumers, contains('lib/screens/map_screen.dart'));
    expect(consumers, contains('lib/widgets/campus_basemap_layer.dart'));
  });

  test('no source file references an OpenStreetMap tile endpoint', () async {
    expect(await _filesContaining('tile.openstreetmap.org'), isEmpty,
        reason: 'Task 4 removed the last OSM tile layer; a reintroduced '
            'endpoint would silently restore a network dependency and an '
            'attribution obligation the app no longer meets');
  });
}
