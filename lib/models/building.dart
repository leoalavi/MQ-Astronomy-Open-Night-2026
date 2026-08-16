import 'package:flutter/foundation.dart';

enum BuildingCategory {
  academic, services, health, food, sports, venue, research,
  residential, parking, transport, smoking, teaching, other; // 'teaching' is in the asset (#14)

  static BuildingCategory fromString(String? s) =>
      BuildingCategory.values.firstWhere((c) => c.name == s,
          orElse: () => BuildingCategory.other);
}

/// A campus building from the vendored MQ registry (170). Trimmed to what AON
/// uses — MQ's faculty/student-services/campus-hub group taxonomy is dropped.
@immutable
class Building {
  const Building({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.address,
    this.category = BuildingCategory.other,
    this.latitude,
    this.longitude,
    this.entranceLatitude,
    this.entranceLongitude,
    this.campusX,
    this.campusY,
    this.gridRef,
    this.aliases = const [],
    this.searchTokens = const [],
    this.tags = const [],
  });

  final String id, code, name;
  final String? description, address, gridRef;
  final BuildingCategory category;
  final double? latitude, longitude, entranceLatitude, entranceLongitude, campusX, campusY;
  final List<String> aliases, searchTokens, tags;

  // G2: entrance is used ONLY when the PAIR is present, else fall back to the
  // centre pair — never mix entrance-lat with centre-lng (fabricated coordinate).
  bool get hasEntranceCoordinates =>
      entranceLatitude != null && entranceLongitude != null;
  double? get routingLatitude => hasEntranceCoordinates ? entranceLatitude : latitude;
  double? get routingLongitude => hasEntranceCoordinates ? entranceLongitude : longitude;
  bool get hasGeographicCoordinates => latitude != null && longitude != null;
  bool get hasCampusCoordinates =>
      campusX != null && campusY != null && !(campusX == 0 && campusY == 0);

  factory Building.fromJson(Map<String, dynamic> j) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    final loc = j['location'] as Map<String, dynamic>?;
    final ent = j['entranceLocation'] as Map<String, dynamic>?;
    final camp = j['campusLocation'] as Map<String, dynamic>?;
    List<String> ls(Object? v) =>
        List.unmodifiable((v as List?)?.cast<String>() ?? const []); // G3
    return Building(
      id: j['id'] as String,
      code: j['code'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      address: j['address'] as String?,
      category: BuildingCategory.fromString(j['category'] as String?),
      latitude: d(j['latitude'] ?? loc?['lat']),
      longitude: d(j['longitude'] ?? loc?['lng']),
      entranceLatitude: d(j['entranceLatitude'] ?? ent?['lat']),
      entranceLongitude: d(j['entranceLongitude'] ?? ent?['lng']),
      campusX: d(j['campusX'] ?? camp?['x']),
      campusY: d(j['campusY'] ?? camp?['y']),
      gridRef: j['gridRef'] as String?,
      aliases: ls(j['aliases']),
      searchTokens: ls(j['searchTokens']),
      tags: ls(j['tags']),
    );
  }

  @override
  bool operator ==(Object other) => other is Building && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
