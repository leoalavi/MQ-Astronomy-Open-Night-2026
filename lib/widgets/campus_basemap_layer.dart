import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/map_config.dart';

/// The reskinned illustrated campus basemap as a `CrsSimple` `OverlayImage`,
/// pinned to the full map bounds. M2: renders exactly one image — the base or
/// the selected thematic variant (design §0/§6). Only the ink changes; the
/// footprint ([MapConfig.mapBounds]) is fixed, so the campus never moves.
class CampusBasemapLayer extends ConsumerWidget {
  const CampusBasemapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(campusVariantProvider);
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: MapConfig.mapBounds,
          imageProvider: AssetImage(CampusVariantsData.assetFor(variant)),
        ),
      ],
    );
  }
}
