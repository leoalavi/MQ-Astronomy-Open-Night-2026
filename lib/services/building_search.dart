import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/venue.dart';

String normalizeMapSearch(String value) => value.toLowerCase().trim();

/// The ranked band ladder, ported from MQ Journey. Bands: id-exact 120,
/// alias-exact 110, field-exact 100, id-prefix 90, alias-prefix 80,
/// field-prefix 70, contains 50, miss 0. Normalizes internally (G4).
int scoreTokens({
  required String id,
  required List<String> aliases,
  required List<String> fields,
  required String rawQuery,
}) {
  final q = normalizeMapSearch(rawQuery);
  if (q.isEmpty) return 0;
  final f = fields.map((s) => s.toLowerCase()).toList();
  final a = aliases.map((s) => s.toLowerCase()).toList();
  final lid = id.toLowerCase();

  if (lid == q) return 120;
  if (a.any((x) => x == q)) return 110;
  if (f.any((x) => x == q)) return 100;
  if (lid.startsWith(q)) return 90;
  if (a.any((x) => x.startsWith(q))) return 80;
  if (f.any((x) => x.startsWith(q))) return 70;
  if (f.any((x) => x.contains(q))) return 50;
  return 0;
}

int scoreBuildingMatch(Building b, String rawQuery) => scoreTokens(
      id: b.id,
      aliases: [...b.aliases, ...b.searchTokens],
      fields: [
        b.id, b.code, b.name,
        if (b.description != null) b.description!,
        if (b.gridRef != null) b.gridRef!,
        if (b.address != null) b.address!,
        ...b.aliases, ...b.searchTokens, ...b.tags,
      ],
      rawQuery: rawQuery,
    );

/// Venue field scoring — same bands over the venue's own vocabulary. A linked
/// venue additionally inherits its building's score (max), computed in T6.
int scoreVenue(Venue v, String rawQuery) => scoreTokens(
      id: v.id,
      aliases: v.aliases,
      fields: [
        v.id, v.name,
        if (v.building != null) v.building!,
        if (v.address != null) v.address!,
        if (v.mapReference != null) v.mapReference!,
        ...v.aliases,
      ],
      rawQuery: rawQuery,
    );
