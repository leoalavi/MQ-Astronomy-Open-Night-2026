import 'package:flutter/painting.dart' show Color;

/// Which single illustrated basemap the map renders. Exactly one is shown at a
/// time — these are alternate full basemaps (M0), not stacked layers. `base` is
/// the plain dark campus; the rest are reskinned thematic variants.
enum CampusMapVariant { base, parking, accessibility, water, permits }

/// One *thematic* variant. `base` is not a row here — it is the enum default and
/// its asset is owned by [CampusVariantsData.baseAsset].
class CampusVariant {
  const CampusVariant({
    required this.variant,
    required this.assetPath,
    required this.swatch,
    required this.eventVisible,
    required this.contentApproved,
  });

  final CampusMapVariant variant;
  final String assetPath;

  /// Source-legend ink colour (documented `context.aon` exemption — it names the
  /// map's own ink, not app chrome).
  final Color swatch;

  /// Listed in the event picker. Permits is built but hidden.
  final bool eventVisible;

  /// Content-validity gate (design §0 must-fix #6): a variant may be
  /// [eventVisible] only once its underlying data is signed off for the event.
  final bool contentApproved;
}

abstract final class CampusVariantsData {
  static const String baseAsset = 'assets/maps/mqcampus_dark.png';

  static const List<CampusVariant> all = [
    CampusVariant(
      variant: CampusMapVariant.parking,
      assetPath: 'assets/maps/overlay_parking_dark.png',
      swatch: Color(0xFF3B82F6),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.accessibility,
      assetPath: 'assets/maps/overlay_accessibility_dark.png',
      swatch: Color(0xFFA855F7),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.water,
      assetPath: 'assets/maps/overlay_water_dark.png',
      swatch: Color(0xFF06B6D4),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.permits,
      assetPath: 'assets/maps/overlay_permits_dark.png',
      swatch: Color(0xFFF97316),
      eventVisible: false,
      contentApproved: true,
    ),
  ];

  static List<CampusVariant> get eventVisible =>
      all.where((v) => v.eventVisible).toList();

  static CampusVariant? byVariant(CampusMapVariant v) {
    for (final row in all) {
      if (row.variant == v) return row;
    }
    return null;
  }

  /// The asset for any variant, total. `base` (and any unmatched value) →
  /// [baseAsset] — the map is never left without a basemap.
  static String assetFor(CampusMapVariant v) => v == CampusMapVariant.base
      ? baseAsset
      : (byVariant(v)?.assetPath ?? baseAsset);
}
