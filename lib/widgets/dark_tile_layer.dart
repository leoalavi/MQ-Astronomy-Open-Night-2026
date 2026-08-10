import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:aon2026/widgets/map_config.dart';

/// The basemap tile layer, used by every map in the app.
///
/// Shared rather than configured per-screen so a map can never accidentally
/// render *light* tiles. That is not a cosmetic slip: a full-brightness white
/// rectangle on a phone at a telescope field destroys the dark adaptation of
/// everyone nearby, which is the one thing this app must not do.
class DarkTileLayer extends StatelessWidget {
  const DarkTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    // OSM raster tiles are designed for a light UI. In dark mode we invert
    // them; in light mode we must NOT — inverting there would produce a dark
    // basemap under light chrome, which is the worst of both.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TileLayer(
      urlTemplate: MapConfig.tileUrlTemplate,
      userAgentPackageName: MapConfig.userAgentPackageName,
      tileBuilder: isDark ? _darkTileBuilder : null,
      maxNativeZoom: 19,
    );
  }
}

/// Darkens the standard OSM raster tiles to fit the night theme.
///
/// A colour-matrix filter over the raster is a pragmatic middle ground: proper
/// dark basemaps (Carto Dark, Stadia) are lovely, but every one of them needs
/// an API key or has terms that would need reviewing before an event this
/// public. This keeps the repo key-free.
///
/// The transform is the well-known `invert(1) hue-rotate(180deg)` pair used for
/// dark Leaflet maps. Inverting alone would work but turns water orange and
/// parkland pink; rotating the hue a half-turn puts those back roughly where
/// the eye expects them. Crucially, inverting is also what makes OSM's *dark*
/// label text render *light* — a plain "darken" filter would leave the labels
/// black on near-black and destroy the map's legibility.
///
/// Applied as two nested filters rather than one hand-multiplied matrix: the
/// composed 4x5 matrix is unreadable and impossible to review, and Flutter
/// collapses the pair into a single GPU pass anyway.
Widget _darkTileBuilder(BuildContext context, Widget tile, TileImage image) {
  return ColorFiltered(
    colorFilter: _hueRotate180,
    child: ColorFiltered(
      colorFilter: _invert,
      child: tile,
    ),
  );
}

/// Flips luminance: light land becomes dark, dark labels become light.
const ColorFilter _invert = ColorFilter.matrix(<double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
]);

/// A half-turn around the hue wheel, undoing the colour shift that inverting
/// introduces (orange water becomes blue again).
const ColorFilter _hueRotate180 = ColorFilter.matrix(<double>[
  -0.574, 1.430, 0.144, 0, 0, //
  0.426, 0.430, 0.144, 0, 0, //
  0.426, 1.430, -0.856, 0, 0, //
  0, 0, 0, 1, 0, //
]);
