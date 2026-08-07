import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/data_confidence.dart';

/// One numbered step in a written walking instruction list.
@immutable
class RouteStep {
  const RouteStep({required this.instruction, this.landmark});

  /// Plain-language instruction. Written for someone walking in the dark, so
  /// it names things you can *see* ("the lit path", "the Library entrance")
  /// rather than compass bearings, which nobody can follow without a map.
  final String instruction;

  /// Optional landmark to confirm you are still on track.
  final String? landmark;
}

/// A predefined campus walking route between two fixed points.
///
/// **This is a rebuild, not a reuse.** MQ Journey has a routing stack
/// (`MapRoute`, `CampusRoutesRemoteSource`, `MapsRoutesRemoteSource`) but it is
/// a thin client over the **Google Routes / Directions API** — it needs a
/// billed API key, a network round-trip, and it returns generic turn-by-turn
/// text that has no idea which campus paths are lit or open at night. All three
/// of those are disqualifying for this MVP, so routes here are hand-authored,
/// bundled offline, and reviewable by the event organisers before the night.
///
/// See `docs/navigation-strategy.md` for the full rationale.
@immutable
class WalkingRoute {
  const WalkingRoute({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.fromLabel,
    required this.toLabel,
    required this.steps,
    this.points = const [],
    this.walkingMinutes,
    this.distanceMetres,
    this.pathConfidence = DataConfidence.placeholder,
    this.isAccessible,
    this.accessibilityNotes,
    this.lightingNotes,
  });

  final String id;

  /// Origin identifier — a [ParkingArea.id] or [Venue.id].
  final String fromId;

  /// Destination identifier — a [Venue.id].
  final String toId;

  /// Human-readable endpoints, denormalised so a route can render in a list
  /// without resolving both foreign keys.
  final String fromLabel;
  final String toLabel;

  /// Written instructions. This is the primary output of the feature — the
  /// polyline is a supporting visual, not the answer.
  final List<RouteStep> steps;

  /// Polyline drawn on the map. May be empty when only written directions
  /// exist; the UI degrades to text-only rather than drawing a fabricated line.
  final List<LatLng> points;

  final int? walkingMinutes;
  final int? distanceMetres;

  /// Provenance of [points]. Marked `placeholder` for any route whose geometry
  /// has not been walked and verified on the ground.
  final DataConfidence pathConfidence;

  /// Step-free for wheelchairs and prams. `null` means unknown — which the UI
  /// must render as "not yet confirmed", never as "no".
  final bool? isAccessible;

  final String? accessibilityNotes;

  /// Whether the path is lit after dark. Critical for a night event and the
  /// single most-requested piece of information from the organisers.
  final String? lightingNotes;

  bool get hasPolyline => points.length >= 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is WalkingRoute && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WalkingRoute($id, $fromLabel -> $toLabel)';
}
