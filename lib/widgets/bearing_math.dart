import 'package:latlong2/latlong.dart';

/// 8-point compass bucket. The UI localizes it (EN/FA) — this stays pure.
enum Cardinal { n, ne, e, se, s, sw, w, nw }

const Distance _distance = Distance();

/// True-north bearing from [from] to [to], normalized to [0,360).
/// `Distance.bearing` returns atan2 in [-180,180]; the normalize wrap is required.
double trueBearingDegrees(LatLng from, LatLng to) =>
    normalizeBearing(_distance.bearing(from, to));

/// Signed shortest delta `bearing - heading`, in [-180,180]. Positive = target
/// is clockwise (to the right) of where the device points. Wrap-safe (359↔1).
double relativeAngleDegrees(double bearing, double heading) =>
    ((bearing - heading + 540) % 360) - 180;

double distanceBetweenMeters(LatLng from, LatLng to) =>
    _distance.as(LengthUnit.Meter, from, to);

/// Nearest 8-point compass bucket for a true bearing in [0,360).
Cardinal cardinalFor(double trueBearing) {
  final i = ((normalizeBearing(trueBearing) + 22.5) ~/ 45) % 8;
  return Cardinal.values[i];
}
