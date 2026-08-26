import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:aon2026/services/google_routes_service.dart';
import 'package:aon2026/services/routes_service.dart';

/// The Routes pipeline, pinned against a REAL API response.
///
/// ## The bug this file exists to prevent
///
/// The web Directions screen hung forever after a perfectly good HTTP 200. The
/// trace proved the parse succeeded (`provider_complete result=RouteSuccess`)
/// and the hang was downstream — but until that was known, the parser was a
/// prime suspect for hours. Pinning it against a captured live response makes
/// "did the parser handle the real shape?" a five-millisecond question instead
/// of a browser session.
void main() {
  /// A genuine `directions/v2:computeRoutes` WALK response, captured live
  /// (Central Courtyard → Astronomical Observatory). No key, no PII — just the
  /// route body Google actually returns for our field mask.
  final fixture =
      File('test/fixtures/routes_walk_response.json').readAsStringSync();

  GoogleRoutesService svc(http.Client c) =>
      GoogleRoutesService(client: c, apiKey: 'k', platformHeaders: const {});

  group('the real response shape parses', () {
    test('a captured live 200 becomes RouteSuccess with every field', () async {
      final result = await svc(MockClient((_) async => http.Response(fixture, 200)))
          .walkingRoute(origin: (-33.7738, 151.1146), destination: (-33.776, 151.112));

      expect(result, isA<RouteSuccess>());
      final route = (result as RouteSuccess).route;
      expect(route.distanceMeters, 395, reason: 'distanceMeters from the wire');
      expect(route.eta, const Duration(seconds: 345), reason: '"345s" parsed');
      expect(route.polyline, isNotEmpty, reason: 'encodedPolyline decoded');
      expect(route.warnings, isEmpty, reason: 'absent warnings default to []');
    });

    test('the fixture really is the shape our field mask requests', () {
      // Guards against the failure mode the brief called out: a parser reading
      // `geoJsonLinestring` while the API returns `encodedPolyline`.
      final json = jsonDecode(fixture) as Map<String, dynamic>;
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      expect(route.containsKey('distanceMeters'), isTrue);
      expect(route['duration'], isA<String>());
      expect((route['polyline'] as Map).containsKey('encodedPolyline'), isTrue);
    });

    test('the decoded polyline is a real multi-point path', () async {
      final result = await svc(MockClient((_) async => http.Response(fixture, 200)))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      final pts = (result as RouteSuccess).route.polyline;
      expect(pts.length, greaterThan(5));
      // Sanity: decoded points must land near Macquarie University, not at 0,0.
      expect(pts.first.$1, closeTo(-33.77, 0.05));
      expect(pts.first.$2, closeTo(151.11, 0.05));
    });
  });

  group('every async path ends in a typed result — never a hang', () {
    test('non-200 → RouteApiFailure carrying the status', () async {
      final r = await svc(MockClient((_) async => http.Response('{}', 401)))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteApiFailure>());
      expect((r as RouteApiFailure).status, 401);
    });

    test('a thrown request → RouteNetworkFailure', () async {
      final r = await svc(MockClient((_) async => throw const SocketException('down')))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteNetworkFailure>());
    });

    test('unparseable body → RouteMalformed, not an exception', () async {
      final r = await svc(MockClient((_) async => http.Response('not json', 200)))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteMalformed>());
    });

    test('proto3 omits empty repeated fields → RouteNoRoute', () async {
      final r = await svc(MockClient((_) async => http.Response('{}', 200)))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteNoRoute>());
    });

    test('RouteTimeout exists as its own typed outcome', () {
      // A stalled request must be distinguishable from an outage, so an
      // eternal-spinner regression is visible rather than disguised.
      expect(const RouteTimeout(), isA<RouteResult>());
      expect(const RouteTimeout(), isNot(isA<RouteNetworkFailure>()));
    });
  });
}
