import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show normalizeBearing;

/// A plain 3-axis sample. NOT `sensors_plus`'s event type — keeping this pure
/// lets the math run in VM-only unit tests. The service adapter maps events → this.
class Vector3 {
  const Vector3(this.x, this.y, this.z);
  final double x, y, z;
}

/// Tilt-compensated MAGNETIC heading in [0,360), or null if the inputs are
/// degenerate (free-fall, device at a magnetic pole, parallel vectors).
///
/// Computed in the device's NATURAL-orientation frame (sensor convention). This
/// is correct only when natural == display orientation — true on a portrait-
/// locked phone (which this app is). Landscape-natural/rotated displays (iPad)
/// need axis remapping first — IOU-B4; `PointMeScreen` locks portrait meanwhile.
///
/// Implements Android `SensorManager.getRotationMatrix` + `getOrientation`:
/// A = normalize(gravity) [up]; H = mag × A [east], if ‖H‖ too small → null;
/// normalize H; M = A × H [north]; azimuth = atan2(H.y, M.y)
/// (== getOrientation's atan2(R[1], R[4])).
double? tiltCompensatedHeadingDegrees(Vector3 mag, Vector3 accel) {
  final ax = accel.x, ay = accel.y, az = accel.z;
  final normA = math.sqrt(ax * ax + ay * ay + az * az);
  if (normA < 1e-6) return null;
  final aX = ax / normA, aY = ay / normA, aZ = az / normA;

  // H = mag × A  (east)
  var hX = mag.y * aZ - mag.z * aY;
  var hY = mag.z * aX - mag.x * aZ;
  var hZ = mag.x * aY - mag.y * aX;
  final normH = math.sqrt(hX * hX + hY * hY + hZ * hZ);
  if (normH < 1e-6) return null; // degenerate: mag ∥ gravity
  hX /= normH;
  hY /= normH;
  hZ /= normH;

  // M = A × H  (north)
  final mY = aZ * hX - aX * hZ;

  final azimuthRad = math.atan2(hY, mY);
  return normalizeBearing(azimuthRad * 180 / math.pi);
}

/// Exponential low-pass over the unit circle, so 359° and 1° average near 0°.
/// A fresh instance is created per heading session (see `SensorsHeadingService`).
class CircularSmoother {
  CircularSmoother(this.alpha) : assert(alpha > 0 && alpha <= 1);
  final double alpha;
  double _sin = 0, _cos = 0;
  bool _seeded = false;

  double add(double deg) {
    final r = deg * math.pi / 180;
    final s = math.sin(r), c = math.cos(r);
    if (!_seeded) {
      _sin = s;
      _cos = c;
      _seeded = true;
    } else {
      _sin = _sin + alpha * (s - _sin);
      _cos = _cos + alpha * (c - _cos);
    }
    return normalizeBearing(math.atan2(_sin, _cos) * 180 / math.pi);
  }
}
