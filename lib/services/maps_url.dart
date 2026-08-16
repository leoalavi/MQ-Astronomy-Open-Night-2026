/// Builds the keyless Google Maps *directions* URL (Maps URLs scheme — no API
/// key required, officially supported). `origin` is intentionally OMITTED so
/// Google Maps uses the device's current location as the start. Built with
/// [Uri.https] (never string concatenation) so the destination is escaped.
Uri buildWalkingMapsUrl({required double destLat, required double destLng}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$destLat,$destLng',
    'travelmode': 'walking',
  });
}
