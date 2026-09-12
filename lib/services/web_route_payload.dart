/// Google Maps JS literals deliberately differ from Routes API request fields
/// (`latitude` / `longitude`). Keep this boundary explicit and lossless.
Map<String, double> routePointLiteral((double lat, double lng) point) => {
  'lat': point.$1,
  'lng': point.$2,
};

Map<String, Object?> webRoutePayload({
  required (double lat, double lng) origin,
  required (double lat, double lng) destination,
  required List<(double lat, double lng)> route,
  bool diagnostics = false,
}) => {
  'source': 'aon-host',
  'type': 'setRoute',
  'origin': routePointLiteral(origin),
  'destination': routePointLiteral(destination),
  'polyline': route.map(routePointLiteral).toList(),
  'diagnostics': diagnostics,
};
