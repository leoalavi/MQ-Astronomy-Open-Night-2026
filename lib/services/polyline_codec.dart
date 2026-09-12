/// Decodes Google's [Encoded Polyline Algorithm Format](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
/// into a list of `(latitude, longitude)` degree pairs.
///
/// Returns plain `(double, double)` tuples deliberately — no `google_maps_flutter`
/// `LatLng` (which would risk pulling the platform-interface package into the
/// declared deps) and no `latlong2` `LatLng` (used elsewhere for the CrsSimple
/// map, a different coordinate space). A malformed/truncated tail is tolerated:
/// whatever was fully decoded is returned rather than throwing.
List<(double lat, double lng)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  final len = encoded.length;
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < len) {
    // Decode the lat delta, then the lng delta. A coordinate is only emitted
    // when BOTH complete — a string truncated mid-longitude used to append a
    // spurious point at lng −0.00001 rather than dropping the incomplete pair
    // (map audit P2).
    final (dLat, i1, ok1) = _decodeDelta(encoded, index, len);
    if (!ok1) break; // truncated during latitude
    final (dLng, i2, ok2) = _decodeDelta(encoded, i1, len);
    if (!ok2) break; // truncated during longitude → drop the incomplete pair

    lat += dLat;
    lng += dLng;
    index = i2;
    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}

/// Decode one signed varint delta. Returns `(delta, newIndex, complete)`;
/// `complete` is false when the string ends mid-chunk (a continuation bit was
/// set but no byte followed), so the caller can drop an incomplete coordinate.
(int delta, int newIndex, bool complete) _decodeDelta(
  String s,
  int index,
  int len,
) {
  // Each delta is a variable-length chunk of 5-bit groups; the high bit (0x20)
  // marks "another byte follows".
  var result = 1;
  var shift = 0;
  int b;
  do {
    if (index >= len) return (0, index, false); // ran out mid-varint
    b = s.codeUnitAt(index++) - 63 - 1;
    result += b << shift;
    shift += 5;
  } while (b >= 0x1f);
  // Dart web bitwise complement produces an unsigned 32-bit value. Arithmetic
  // negation preserves the signed delta on both the VM and JavaScript.
  final magnitude = result >> 1;
  return ((result & 1) != 0 ? -magnitude - 1 : magnitude, index, true);
}
