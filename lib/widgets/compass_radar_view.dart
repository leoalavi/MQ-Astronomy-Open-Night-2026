import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show normalizeBearing;

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/map_config.dart';

// ── Night-vision (scotopic) palette — compass-LOCAL tokens, never aon_palette.
// State is ALSO encoded by icon/shape (§0R-13), never by hue alone.
const _bg = Color(0xFF1A0505);
const _ink = Color(0xFFFF5A4D);
const _dim = Color(0xFF7A2A25);

/// Distance → radius fraction on the rose: ≤ near ⇒ centre, ≥ far ⇒ rim,
/// clamped to [0,1] (§0R-7). Uses BOTH clamps.
double blipRadiusFraction(double meters) {
  const span = MapConfig.compassFarClampMeters - MapConfig.compassNearClampMeters;
  return ((meters - MapConfig.compassNearClampMeters) / span).clamp(0.0, 1.0);
}

/// A group of targets sharing (near-)one bearing, drawn as one marker (§0R-8).
class BlipCluster {
  const BlipCluster(this.bearingDegrees, this.members);
  final double bearingDegrees; // circular-mean true bearing (honest)
  final List<NearbyTarget> members;
  int get count => members.length;

  /// The distance the blip's radius represents: the NEAREST member, so a
  /// {30 m, 700 m} cluster reads as "something close in this direction" rather
  /// than borrowing whichever member happened to sort first by bearing
  /// (map audit P2).
  double get nearestMeters =>
      members.map((t) => t.distanceMeters).reduce(math.min);
}

double _meanBearing(List<NearbyTarget> m) {
  var sx = 0.0, sy = 0.0;
  for (final t in m) {
    final r = t.trueBearingDegrees * math.pi / 180;
    sx += math.cos(r);
    sy += math.sin(r);
  }
  return normalizeBearing(math.atan2(sy, sx) * 180 / math.pi);
}

/// Cluster targets whose true bearings fall within [minSepDeg] (circular/
/// wrap-aware) — NEVER displacing a blip's angle or radius (that would lie about
/// bearing/distance). Sorted by bearing; adjacent-within-gap merged; wrap seam
/// across 0/360 merged.
List<BlipCluster> clusterByBearing(List<NearbyTarget> targets, double minSepDeg) {
  if (targets.isEmpty) return const [];
  final sorted = [...targets]
    ..sort((a, b) => a.trueBearingDegrees.compareTo(b.trueBearingDegrees));
  final groups = <List<NearbyTarget>>[];
  for (final t in sorted) {
    if (groups.isEmpty ||
        (t.trueBearingDegrees - groups.last.last.trueBearingDegrees).abs() > minSepDeg) {
      groups.add([t]);
    } else {
      groups.last.add(t);
    }
  }
  if (groups.length > 1) {
    final wrapGap =
        (360 - groups.last.last.trueBearingDegrees) + groups.first.first.trueBearingDegrees;
    if (wrapGap <= minSepDeg) groups.first.addAll(groups.removeLast());
  }
  return [for (final g in groups) BlipCluster(_meanBearing(g), g)];
}

/// Screen offset for a point at [bearingDeg] (from north, clockwise) and radius
/// fraction [rFrac] on an N-up rose (north = up).
Offset _onRose(double bearingDeg, double rFrac, Offset center, double radius) {
  final a = bearingDeg * math.pi / 180;
  return center + Offset(math.sin(a), -math.cos(a)) * (radius * rFrac);
}

/// The N-up compass rose (§0R-1: everything on the same ABSOLUTE frame; only the
/// facing indicator moves with heading). No camera, no spinner.
class CompassRadarView extends ConsumerWidget {
  const CompassRadarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    // Watches that are heading-INDEPENDENT (do not rebuild at 20 Hz, §0R-12):
    final targets = ref.watch(nearbyTargetsProvider);
    final acquiring = ref.watch(compassControllerProvider
        .select((s) => s.availability == HeadingAvailability.acquiring));
    final clusters = clusterByBearing(targets, MapConfig.compassMinAngularSepDegrees);

    return ColoredBox(
      color: _bg,
      child: LayoutBuilder(builder: (ctx, cons) {
        final d = math.min(cons.maxWidth, cons.maxHeight);
        final center = Offset(d / 2, d / 2);
        final radius = d / 2 - 16;
        return Center(
          child: SizedBox(
            width: d,
            height: d,
            child: Stack(children: [
              CustomPaint(size: Size(d, d), painter: _RosePainter(radius)),
              // Blips: sighted convenience only → ExcludeSemantics (§0R-9).
              for (final c in clusters)
                _positioned(
                  _onRose(c.bearingDegrees, blipRadiusFraction(c.nearestMeters),
                      center, radius),
                  ExcludeSemantics(child: _Blip(cluster: c)),
                ),
              // The rose is centred on YOU. Draw an explicit "you are here"
              // marker so the facing pin at the rim reads as "which way you're
              // facing", not "a person over there" (field report, Pouya
              // 2026-08-28). Painted AFTER the blips: on the night, every venue
              // is close, so the blips cluster near the centre — "you" must sit
              // on top of them, never be buried. Ringed to stand apart.
              Positioned(
                key: const ValueKey('compass-you-marker'),
                left: center.dx - 8,
                top: center.dy - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 3),
                  ),
                ),
              ),
              _FacingLayer(center: center, radius: radius),
              _LockedLayer(center: center, radius: radius),
              if (acquiring)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    // §0R-C: STATIC icon + text — never a CircularProgressIndicator.
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.explore_rounded, color: _dim),
                      Text(l.compassFindingNorth, style: const TextStyle(color: _dim)),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }

  static Widget _positioned(Offset at, Widget child) =>
      Positioned(left: at.dx - 12, top: at.dy - 12, width: 24, height: 24, child: child);
}

class _RosePainter extends CustomPainter {
  const _RosePainter(this.radius);
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _dim;
    canvas.drawCircle(c, radius, ring);
    // North tick.
    canvas.drawLine(Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy - radius + 12),
        ring..color = _ink);
  }

  @override
  bool shouldRepaint(_RosePainter old) => old.radius != radius;
}

class _Blip extends StatelessWidget {
  const _Blip({required this.cluster});
  final BlipCluster cluster;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
        child: cluster.count > 1
            ? Center(
                child: Text(TimeFormat.count(cluster.count),
                    style: const TextStyle(color: _bg, fontSize: 11, fontWeight: FontWeight.bold)))
            : const SizedBox.shrink(),
      );
}

/// Heading-dependent layer — the ONLY thing that repaints at 20 Hz (§0R-12).
class _FacingLayer extends ConsumerWidget {
  const _FacingLayer({required this.center, required this.radius});
  final Offset center;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(compassControllerProvider.select((s) => s.trueHeadingDegrees));
    if (heading == null) return const SizedBox.shrink(); // null-guard (§0R-C)
    final at = _onRose(heading, 1.0, center, radius);
    return Positioned(
      left: at.dx - 10,
      top: at.dy - 10,
      child: const Icon(Icons.person_pin_circle_rounded, color: _ink, size: 20),
    );
  }
}

/// Locked target — drawn at its ABSOLUTE bearing, same frame as its blip (§0R-1).
class _LockedLayer extends ConsumerWidget {
  const _LockedLayer({required this.center, required this.radius});
  final Offset center;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bearing =
        ref.watch(compassControllerProvider.select((s) => s.lockedTrueBearingDegrees));
    final near = ref.watch(compassControllerProvider.select((s) => s.lockedNearTarget));
    if (bearing == null) return const SizedBox.shrink();
    final at = _onRose(bearing, 0.92, center, radius);
    return Positioned(
      key: const ValueKey('compass-locked-marker'),
      left: at.dx - 14,
      top: at.dy - 14,
      child: Icon(near ? Icons.my_location_rounded : Icons.navigation_rounded,
          color: _ink, size: 28),
    );
  }
}
