import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:aon2026/widgets/map_config.dart';

/// The OFFICIAL AON 2026 campus map as a `CrsSimple` `OverlayImage`.
///
/// This is page 1 of the published "Astronomy Open Night 2026 Program and Map"
/// A3 PDF — the artwork Faculty of Science and Engineering hands out on the
/// night — extracted by `tools/aon_map/extract.py`. Using the real event map
/// means the pins the app draws and the map people are holding agree: the same
/// A–I lettering, the same registration and information points, the same
/// shuttle and pedestrian routes.
///
/// Pinned to [MapConfig.aonMapBounds], NOT [MapConfig.mapBounds]: the artwork
/// is a slightly different crop of the same MQ cartographic master, and its
/// bounds are derived from the projector so the ink and the GPS calibration can
/// never drift apart (see `CampusProjection.aonPixel`).
///
/// Shipped UNMODIFIED — no night-reskin. Brand fidelity was chosen over
/// scotopic dimming; if that is revisited, wrap this in a `ColorFiltered` at
/// runtime rather than baking a darker asset, so the official artwork stays
/// pristine.
class CampusBasemapLayer extends StatelessWidget {
  const CampusBasemapLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: MapConfig.aonMapBounds,
          imageProvider: const AssetImage('assets/maps/aon_event_map.png'),
        ),
      ],
    );
  }
}
