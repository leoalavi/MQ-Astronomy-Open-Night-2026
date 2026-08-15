import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:aon2026/widgets/map_config.dart';

/// The reskinned illustrated campus basemap as a `CrsSimple` `OverlayImage`,
/// pinned to the full map bounds. Phase M2 will swap the asset for the selected
/// thematic variant.
class CampusBasemapLayer extends StatelessWidget {
  const CampusBasemapLayer({super.key});

  @override
  Widget build(BuildContext context) => OverlayImageLayer(
        overlayImages: [
          OverlayImage(
            bounds: MapConfig.mapBounds,
            imageProvider: const AssetImage('assets/maps/mqcampus_dark.png'),
          ),
        ],
      );
}
