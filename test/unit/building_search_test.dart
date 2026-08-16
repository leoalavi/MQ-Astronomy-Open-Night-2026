import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/building_search.dart';

Building _b(String id,
        {String? code, String? name, List<String> aliases = const [], List<String> tokens = const []}) =>
    Building(id: id, code: code ?? id, name: name ?? id, aliases: aliases, searchTokens: tokens);

void main() {
  test('band ladder', () {
    final lib = _b('LIB', name: 'Library', aliases: ['books'], tokens: ['study']);
    expect(scoreBuildingMatch(lib, 'lib'), 120); // id exact
    expect(scoreBuildingMatch(lib, 'books'), 110); // alias exact
    expect(scoreBuildingMatch(lib, 'library'), 100); // field exact
    expect(scoreBuildingMatch(lib, 'li'), 90); // id prefix
    expect(scoreBuildingMatch(lib, 'boo'), 80); // alias prefix
    expect(scoreBuildingMatch(lib, 'libr'), 70); // 'lib' can't prefix 'libr'; 'library' field-prefix → 70
    expect(scoreBuildingMatch(lib, 'rary'), 50); // contains
    expect(scoreBuildingMatch(lib, 'zzznomatch'), 0); // G13: explicit non-match → 0
  });

  test('G4: normalizes internally — raw "  LIB  " scores like "lib"', () {
    expect(scoreBuildingMatch(_b('LIB', name: 'Library'), '  LIB  '), 120);
  });
  // Ranked ORDERING is proven in T6 (mapSearchResultsProvider), not here.
}
