import 'package:flutter/foundation.dart';

import 'package:aon2026/models/data_confidence.dart';

/// A car park offered to Astronomy Open Night attendees.
///
/// Kept separate from [Venue] rather than reusing MQ Journey's
/// `BuildingCategory.parking`, because a car park is the *origin* of a journey
/// in this product, never a destination you browse to. Giving it its own type
/// means the wayfinding start-point picker cannot accidentally offer a lecture
/// theatre as a starting car park.
@immutable
class ParkingArea {
  const ParkingArea({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.artworkX,
    this.artworkY,
    this.coordinateConfidence = DataConfidence.placeholder,
    this.isFree = true,
    this.accessibilityNotes,
    this.notes,
  });

  final String id;

  /// Official name as printed on the event map, e.g. 'West 6'.
  final String name;

  final double? latitude;
  final double? longitude;

  /// Pixel-exact placement on the official AON artwork (its 4680x3310 pixel
  /// space — see [CampusProjection.aonPixel]), the same mechanism venues use.
  /// Set only when a car park's real GPS sits off the printed map's western
  /// crop (West 6), so its pin is drawn where the map itself labels it. When
  /// present it wins for the in-app map pin; [latitude]/[longitude] still drive
  /// real-world Google directions. Never geographic — never write GPS here.
  final double? artworkX, artworkY;

  final DataConfidence coordinateConfidence;

  /// The official map marks event parking as free.
  final bool isFree;

  final String? accessibilityNotes;
  final String? notes;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether this car park is pinned to the artwork rather than by GPS.
  bool get hasArtworkPin => artworkX != null && artworkY != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ParkingArea && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ParkingArea($id, $name)';
}
