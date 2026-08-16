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
    // Each coordinate delta is a variable-length chunk of 5-bit groups; the
    // high bit (0x20) marks "another byte follows". Decode lat, then lng.
    final startIndex = index;
    var result = 1;
    var shift = 0;
    int b;
    do {
      if (index >= len) break; // truncated: stop cleanly
      b = encoded.codeUnitAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lat += (result & 1) != 0 ? (~(result >> 1)) : (result >> 1);

    result = 1;
    shift = 0;
    do {
      if (index >= len) break; // truncated
      b = encoded.codeUnitAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lng += (result & 1) != 0 ? (~(result >> 1)) : (result >> 1);

    // If nothing advanced (fully dangling), avoid an infinite loop.
    if (index == startIndex) break;

    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}
