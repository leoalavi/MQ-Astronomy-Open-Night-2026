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
    final loc = context.aon.mapUserLocation;
    return CircleLayer(circles: [
      CircleMarker(
        point: center.value,
        radius: fix.accuracyMeters * accuracyRadiusScale(nPx, ePx),
        useRadiusInMeter: false, // radius is SCREEN PIXELS
        color: loc.withValues(alpha: 0.12),
        borderColor: loc.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ),
    ]);
  }
}

/// The "you are here" dot — a GPS-blue dot inside a white ring inside a small
/// translucent-blue halo — ON TOP of the pins. Modelled on Google Maps' live
/// location indicator so a visitor reads it as *you* at a glance.
///
/// The `Colors.white` ring + `Colors.black26` shadow are the one sanctioned
/// palette exception: a "you-are-here" dot must read as *you* against any map
/// independent of theme. The centre is `mapUserLocation` (blue), the universal
/// location colour — field testers read the old amber centre as a venue pin.
///
/// Sizing (field report, Leo Alavi 2026-08-28: the old 22px dot "is too small"):
///  - 30px translucent-blue halo — visible but small, and translucent so it
///    never obscures a nearby venue pin (which are 44–56px, solid);
///  - 18px white ring — the crisp separation from the map;
///  - 12px solid blue centre.
/// This is the whole marker; the LARGE, accuracy-scaled ring is the separate
/// [UserLocationCircle] beneath the pins, so the two are never confused.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({required this.center, super.key});
  final CampusMapPoint center;

  static const double _size = 30;

  @override
  Widget build(BuildContext context) {
    final loc = context.aon.mapUserLocation;
    return MarkerLayer(markers: [
      Marker(
        point: center.value,
        width: _size,
        height: _size,
        child: Center(
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The small "you" halo — a constant footprint, NOT the accuracy
              // circle. Kept translucent so venue pins stay visible under it.
              color: loc.withValues(alpha: 0.18),
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black26)],
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: loc, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
