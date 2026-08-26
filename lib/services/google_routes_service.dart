import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:http/http.dart' as http;

import 'polyline_codec.dart';
import 'routes_service.dart';

/// Calls the Google Routes API `computeRoutes` for a WALK route and maps the
/// response into a typed [RouteResult].
///
/// Security headers are a MAP, not a single name/value pair: Android's
/// app-restricted key needs BOTH `X-Android-Package` AND `X-Android-Cert`
/// (iOS needs the one `X-Ios-Bundle-Identifier`). The caller supplies the map
/// via [platformHeaders] (assembled by `routesClientIdentityProvider`).
class GoogleRoutesService implements RoutesService {
  GoogleRoutesService({
    required this.client,
    required this.apiKey,
    required this.platformHeaders,
  });

  final http.Client client;
  final String apiKey;
  final Map<String, String> platformHeaders;

  static final Uri _endpoint =
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

  /// Includes `routes.warnings` — required so the mandated walking warning can
  /// be displayed when Google supplies one.
  static const String _fieldMask =
      'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,routes.warnings';

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    // Scope 1: the network call ONLY. A throw here is a network failure and
    // must never be confused with a parse failure below (#12).
    final sw = Stopwatch()..start();
    debugPrint('GoogleNavTrace: request_start');
    http.Response resp;
    try {
      resp = await client.post(
        _endpoint,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': _fieldMask,
          ...platformHeaders,
        },
        body: jsonEncode({
          'origin': {
            'location': {
              'latLng': {'latitude': origin.$1, 'longitude': origin.$2}
            }
          },
          'destination': {
            'location': {
              'latLng': {'latitude': destination.$1, 'longitude': destination.$2}
            }
          },
          'travelMode': 'WALK',
        }),
      );
    } catch (e) {
      debugPrint('GoogleNavTrace: http_threw after ${sw.elapsedMilliseconds}ms '
          '(${e.runtimeType})');
      return const RouteNetworkFailure();
    }
    debugPrint('GoogleNavTrace: http_post_returned status=${resp.statusCode} '
        'bytes=${resp.bodyBytes.length} elapsed=${sw.elapsedMilliseconds}ms');

    if (resp.statusCode != 200) {
      return RouteApiFailure(resp.statusCode);
    }

    // Scope 2: decode + validate. Any throw or missing required field here is
    // malformed, NOT a network failure and NOT "no route".
    try {
      debugPrint('GoogleNavTrace: route_parse_start');
      final decoded = jsonDecode(resp.body);
      debugPrint('GoogleNavTrace: json_decoded=true');
      if (decoded is! Map<String, dynamic>) return const RouteMalformed();
      final routes = decoded['routes'];
      // Routes v2 is proto3 JSON, which OMITS empty repeated fields — a genuine
      // "no walkable route" comes back as `{}` (no `routes` key), NEVER as
      // `{"routes":[]}`. Treat an absent key as no-route, so it degrades to the
      // external-Maps fallback instead of a generic, un-retryable error. A
      // present-but-wrong-type `routes` is still malformed (map audit P1).
      if (routes == null) return const RouteNoRoute();
      if (routes is! List) return const RouteMalformed();
      if (routes.isEmpty) return const RouteNoRoute();

      final route = routes.first;
      if (route is! Map<String, dynamic>) return const RouteMalformed();
      final distance = route['distanceMeters'];
      final durationStr = route['duration'];
      final encoded = (route['polyline'] as Map?)?['encodedPolyline'];
      if (distance is! int || durationStr is! String || encoded is! String) {
        return const RouteMalformed();
      }

      // Materialise eagerly and keep only real strings: a lazy `.cast<String>()`
      // would defer a bad element into an uncaught TypeError during widget build
      // (map audit P2). Google sends `repeated string`, so this only ever filters
      // anomalous output rather than dropping legitimate warnings.
      final warnings =
          (route['warnings'] as List?)?.whereType<String>().toList() ?? const <String>[];
      debugPrint('GoogleNavTrace: polyline_decode_start len=${encoded.length}');
      final pts = decodePolyline(encoded);
      debugPrint('GoogleNavTrace: polyline_decode_done points=${pts.length}');
      debugPrint('GoogleNavTrace: route_parse_done '
          'elapsed=${sw.elapsedMilliseconds}ms');
      return RouteSuccess(NavRoute(
        polyline: pts,
        distanceMeters: distance,
        eta: _parseDuration(durationStr),
        warnings: warnings,
      ));
    } catch (e) {
      debugPrint('GoogleNavTrace: parse_threw (${e.runtimeType})');
      return const RouteMalformed();
    }
  }

  /// Google durations are seconds with an `s` suffix and MAY be fractional,
  /// e.g. `"3.5s"`, `"351s"`, `"0.125s"`. Parse as double → milliseconds so a
  /// fractional value never crashes an int parse.
  Duration _parseDuration(String v) {
    // Strip the documented `s` suffix only when present — never blindly drop the
    // last char, which would turn an unsuffixed "351" into 35 s (map audit P2).
    // A non-numeric value throws here and is caught as RouteMalformed.
    final trimmed = v.endsWith('s') ? v.substring(0, v.length - 1) : v;
    final seconds = double.parse(trimmed);
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
