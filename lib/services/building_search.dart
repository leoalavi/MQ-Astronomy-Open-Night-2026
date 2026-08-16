import 'package:aon2026/models/building.dart';

String normalizeMapSearch(String value) => value.toLowerCase().trim();

/// Ranked substring match, ported from MQ Journey. Bands: id-exact 120,
/// alias-exact 110, field-exact 100, id-prefix 90, alias-prefix 80,
/// field-prefix 70, contains 50, miss 0. Normalizes internally (G4) — no
/// "caller must pre-normalize" footgun. `searchCampusBuildings` was NOT ported
/// (unused: the unified results provider ranks SearchEntries directly).
int scoreBuildingMatch(Building b, String rawQuery) {
  final q = normalizeMapSearch(rawQuery);
  if (q.isEmpty) return 0;
  final fields = <String>[
    b.id, b.code, b.name,
    if (b.description != null) b.description!,
    if (b.gridRef != null) b.gridRef!,
    if (b.address != null) b.address!,
    ...b.aliases, ...b.searchTokens, ...b.tags,
  ].map((s) => s.toLowerCase()).toList();
  final aliases = [...b.aliases, ...b.searchTokens].map((s) => s.toLowerCase()).toList();
  final id = b.id.toLowerCase();

  if (id == q) return 120;
  if (aliases.any((a) => a == q)) return 110;
  if (fields.any((f) => f == q)) return 100;
  if (id.startsWith(q)) return 90;
  if (aliases.any((a) => a.startsWith(q))) return 80;
  if (fields.any((f) => f.startsWith(q))) return 70;
  if (fields.any((f) => f.contains(q))) return 50;
  return 0;
}
