import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';

/// Pixels-per-metre to use for the accuracy radius given the local north/east
/// screen-pixel-per-metre scales. ≤5% anisotropy → their average; otherwise the
/// larger (conservative) — a general affine turns a metric circle into an
/// ellipse, so we never under-state uncertainty. Pure + unit-tested.
double accuracyRadiusScale(double nPx, double ePx) {
  final larger = nPx > ePx ? nPx : ePx;
  final anisotropy = larger == 0 ? 0.0 : (nPx - ePx).abs() / larger;
  return anisotropy <= 0.05 ? (nPx + ePx) / 2 : larger;
}

/// Accuracy circle (screen-pixel radius) that sits UNDER the venue pins.
///
/// `CrsSimple` has no real metres, so the radius is computed in **screen
/// pixels** at the current zoom via [MapCamera.projectAtZoom] — keeping a
/// constant campus footprint as the user zooms. Renders nothing for a
/// low-accuracy fix so it never paints a suburb-sized blob (Phase A §5.1).
class UserLocationCircle extends StatelessWidget {
  const UserLocationCircle({required this.center, required this.fix, super.key});
  final CampusMapPoint center;
  final UserLocationFix fix;
  static const _proj = CampusProjection();

  @override
  Widget build(BuildContext context) {
    if (fix.isLowAccuracy) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final north =
        _proj.project(GpsPoint(const Distance().offset(fix.position, 25, 0)));
    final east =
        _proj.project(GpsPoint(const Distance().offset(fix.position, 25, 90)));
    if (north == null || east == null) return const SizedBox.shrink();
    final c = camera.projectAtZoom(center.value);
    final nPx = (camera.projectAtZoom(north.value) - c).distance / 25.0;
    final ePx = (camera.projectAtZoom(east.value) - c).distance / 25.0;
    final accent = context.aon.accent;
    return CircleLayer(circles: [
      CircleMarker(
        point: center.value,
        radius: fix.accuracyMeters * accuracyRadiusScale(nPx, ePx),
        useRadiusInMeter: false, // radius is SCREEN PIXELS
        color: accent.withValues(alpha: 0.12),
        borderColor: accent.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ),
    ]);
  }
}

/// The "you are here" dot — an accent dot on a white ring — ON TOP of the pins.
///
/// The `Colors.white` ring + `Colors.black26` shadow are the one sanctioned
/// palette exception: a "you-are-here" dot must read as *you* against any map
/// independent of theme. The dot's centre still reads from `context.aon`.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({required this.center, super.key});
  final CampusMapPoint center;

  @override
  Widget build(BuildContext context) => MarkerLayer(markers: [
        Marker(
          point: center.value,
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black26)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: context.aon.accent, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ]);
}
