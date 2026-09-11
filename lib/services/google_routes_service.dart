import 'dart:convert';

import 'package:aon2026/services/nav_trace.dart';

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

  /// Includes `routes.warnings` — required so any Google-supplied route notice
  /// can be displayed — and `routes.legs.steps.*` so the in-app directions can
  /// show a compact, GOOGLE-SUPPLIED step list (never locally invented).
  static const String _fieldMask =
      'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,'
      'routes.warnings,routes.legs.steps.navigationInstruction,'
      'routes.legs.steps.distanceMeters';

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    // Scope 1: the network call ONLY. A throw here is a network failure and
    // must never be confused with a parse failure below (#12).
    final sw = Stopwatch()..start();
    navTrace('request_start');
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
      navTrace('http_threw after ${sw.elapsedMilliseconds}ms '
          '(${e.runtimeType})');
      return const RouteNetworkFailure();
    }
    navTrace('http_post_returned status=${resp.statusCode} '
        'bytes=${resp.bodyBytes.length} elapsed=${sw.elapsedMilliseconds}ms');

    if (resp.statusCode != 200) {
      // Surface Google's OWN error classification. This incident cost a
      // debugging session because a bare `status=400` hid the real cause: the
      // Routes API reports an expired/invalid key as HTTP 400 INVALID_ARGUMENT
      // / API_KEY_INVALID — NOT 401/403 — so the status code alone is
      // misleading. Trace only the two bounded, enum-like fields (the RPC
      // `status` and the first `error.details[].reason`); never the body, the
      // free-form message, or a key (see the nav_trace no-secret contract).
      navTrace('route_error status=${resp.statusCode} ${_errorClass(resp.body)}');
      return RouteApiFailure(resp.statusCode);
    }

    // Scope 2: decode + validate. Any throw or missing required field here is
    // malformed, NOT a network failure and NOT "no route".
    try {
      navTrace('route_parse_start');
      final decoded = jsonDecode(resp.body);
      navTrace('json_decoded=true');
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
      navTrace('polyline_decode_start len=${encoded.length}');
      final pts = decodePolyline(encoded);
      navTrace('polyline_decode_done points=${pts.length}');
      // Walking steps, verbatim from `routes.legs[].steps[]`. Every access is
      // defensive: a missing/oddly-typed field just skips that step (or all of
      // them) — the route still succeeds on distance + polyline alone, and the
      // UI shows whatever real steps came back, never a fabricated one.
      final steps = _parseSteps(route['legs']);
      navTrace('route_parse_done steps=${steps.length} '
          'elapsed=${sw.elapsedMilliseconds}ms');
      return RouteSuccess(NavRoute(
        polyline: pts,
        distanceMeters: distance,
        eta: _parseDuration(durationStr),
        warnings: warnings,
        steps: steps,
      ));
    } catch (e) {
      navTrace('parse_threw (${e.runtimeType})');
      return const RouteMalformed();
    }
  }

  /// Extracts Google's bounded error classification from a non-200 body, for
  /// tracing only. Returns e.g. `status=INVALID_ARGUMENT reason=API_KEY_INVALID`.
  ///
  /// SAFE under the nav_trace no-secret contract: it returns ONLY the two
  /// enum-like fields Google supplies (`error.status` and the first
  /// `error.details[].reason`) — never the free-form `error.message`, never the
  /// raw body, never any request echo. A missing/oddly-typed field or a
  /// non-JSON body degrades to `?` instead of throwing.
  static String _errorClass(String body) {
    try {
      final err = (jsonDecode(body) as Map<String, dynamic>)['error'];
      if (err is! Map<String, dynamic>) return 'status=? reason=?';
      final status = err['status'];
      String? reason;
      final details = err['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map && d['reason'] is String) {
            reason = d['reason'] as String;
            break;
          }
        }
      }
      return 'status=${status is String ? status : '?'} reason=${reason ?? '?'}';
    } catch (_) {
      return 'status=? reason=?';
    }
  }

  /// Flatten `routes.legs[].steps[]` into ordered [NavStep]s. Defensive at every
  /// hop: a leg or step of the wrong shape, or a step with no instruction text,
  /// is skipped rather than throwing — a walk route may legitimately arrive with
  /// no steps, and that must never turn a good route into `RouteMalformed`.
  List<NavStep> _parseSteps(Object? legs) {
    if (legs is! List) return const [];
    final out = <NavStep>[];
    for (final leg in legs) {
      final ls = (leg is Map) ? leg['steps'] : null;
      if (ls is! List) continue;
      for (final s in ls) {
        if (s is! Map) continue;
        final instr = (s['navigationInstruction'] as Map?)?['instructions'];
        if (instr is! String || instr.isEmpty) continue; // no text → skip
        final d = s['distanceMeters'];
        out.add(NavStep(instruction: instr, distanceMeters: d is int ? d : 0));
      }
    }
    return out;
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
