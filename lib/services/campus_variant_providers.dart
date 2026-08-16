import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';

/// Single-select thematic-variant state. **Session-only, not persisted to
/// storage** — it resets on app restart (a persistence IOU if a need appears).
class CampusVariantController extends Notifier<CampusMapVariant> {
  @override
  CampusMapVariant build() => CampusMapVariant.base;

  /// Select a variant. A `null` argument is `RadioGroup`'s framework deselect
  /// sentinel (`radio_group.dart:159`); it maps to [CampusMapVariant.base] so
  /// the map is never left with no basemap.
  void select(CampusMapVariant? variant) =>
      state = variant ?? CampusMapVariant.base;
}

final campusVariantProvider =
    NotifierProvider<CampusVariantController, CampusMapVariant>(
        CampusVariantController.new);
