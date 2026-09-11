import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/google_routes_service.dart';

const _iosHeaders = {'X-Ios-Bundle-Identifier': 'au.edu.mq.astronomy.aon2026'};
const _androidHeaders = {
  'X-Android-Package': 'au.edu.mq.astronomy.aon2026',
  'X-Android-Cert': 'AB:CD:EF',
};

GoogleRoutesService _svc(http.Client c, {Map<String, String> headers = _iosHeaders}) =>
    GoogleRoutesService(client: c, apiKey: 'k', platformHeaders: headers);
http.Client _ok(String body) => MockClient((_) async => http.Response(body, 200));

void main() {
  test('REQUEST CONTRACT: POST, exact URL, field mask, api-key, WALK, nested origin/dest, BOTH android headers (#8/#10)',
      () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode({
            'routes': [
              {'distanceMeters': 1, 'duration': '1s', 'polyline': {'encodedPolyline': ''}, 'warnings': []}
            ]
          }),
          200);
    });
    await _svc(client, headers: _androidHeaders)
        .walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'https://routes.googleapis.com/directions/v2:computeRoutes');
    expect(seen.headers['content-type'], contains('application/json'));
    expect(seen.headers['x-goog-api-key'], 'k');
    expect(seen.headers['x-goog-fieldmask'],
        'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,'
        'routes.warnings,routes.legs.steps.navigationInstruction,'
        'routes.legs.steps.distanceMeters');
    expect(seen.headers['x-android-package'], 'au.edu.mq.astronomy.aon2026'); // BOTH android headers (#8)
    expect(seen.headers['x-android-cert'], 'AB:CD:EF');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['travelMode'], 'WALK');
    expect(body['origin']['location']['latLng']['latitude'], -33.77);
    expect(body['origin']['location']['latLng']['longitude'], 151.11);
    expect(body['destination']['location']['latLng']['latitude'], -33.78);
    expect(body['destination']['location']['latLng']['longitude'], 151.12);
  });

  test('success: fractional "3.5s" parses; distance + polyline + warnings surfaced', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {'distanceMeters': 412, 'duration': '3.5s', 'polyline': {'encodedPolyline': '_p~iF~ps|U'}, 'warnings': ['Use caution']}
      ]
    }))).walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
    expect(r, isA<RouteSuccess>());
    final nav = (r as RouteSuccess).route;
    expect(nav.distanceMeters, 412);
    expect(nav.eta, const Duration(milliseconds: 3500)); // NOT crash on "3.5s"
    expect(nav.warnings, ['Use caution']);
    expect(nav.polyline.length, 1);
  });

  test('MAP #10: legs.steps are parsed into ordered NavSteps (Google-supplied only)', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {
          'distanceMeters': 300,
          'duration': '240s',
          'polyline': {'encodedPolyline': '_p~iF~ps|U'},
          'legs': [
            {
              'steps': [
                {
                  'navigationInstruction': {'instructions': 'Head north on Wally-s Walk'},
                  'distanceMeters': 120,
                },
                {
                  'navigationInstruction': {'instructions': 'Turn right onto Central Ave'},
                  'distanceMeters': 180,
                },
              ]
            }
          ],
        }
      ]
    }))).walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
    final nav = (r as RouteSuccess).route;
    expect(nav.steps.map((s) => s.instruction).toList(),
        ['Head north on Wally-s Walk', 'Turn right onto Central Ave']);
    expect(nav.steps.map((s) => s.distanceMeters).toList(), [120, 180]);
  });

  test('MAP #10: a step with no instruction text is skipped, never fabricated', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {
          'distanceMeters': 50,
          'duration': '60s',
          'polyline': {'encodedPolyline': ''},
          'legs': [
            {
              'steps': [
                {'distanceMeters': 20}, // no navigationInstruction → skipped
                {
                  'navigationInstruction': {'instructions': 'Arrive at destination'},
                  'distanceMeters': 30,
                },
              ]
            }
          ],
        }
      ]
    }))).walkingRoute(origin: (0, 0), destination: (0, 0));
    final nav = (r as RouteSuccess).route;
    expect(nav.steps.length, 1);
    expect(nav.steps.single.instruction, 'Arrive at destination');
  });

  test('a route with no legs still succeeds with an empty step list', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {'distanceMeters': 10, 'duration': '10s', 'polyline': {'encodedPolyline': ''}}
      ]
    }))).walkingRoute(origin: (0, 0), destination: (0, 0));
    expect(r, isA<RouteSuccess>());
    expect((r as RouteSuccess).route.steps, isEmpty);
  });

  test('durations "351s" and "0.125s" parse; absent warnings → empty list', () async {
    for (final d in ['351s', '0.125s']) {
      final r = await _svc(_ok(jsonEncode({
        'routes': [
          {'distanceMeters': 1, 'duration': d, 'polyline': {'encodedPolyline': ''}}
        ]
      }))).walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteSuccess>());
      expect((r as RouteSuccess).route.warnings, isEmpty);
    }
  });

  test('200 + zero routes → RouteNoRoute', () async {
    expect(await _svc(_ok(jsonEncode({'routes': []}))).walkingRoute(origin: (0, 0), destination: (0, 0)),
        isA<RouteNoRoute>());
  });

  test('200 + `{}` (proto3 omits the empty routes key) → RouteNoRoute, NOT malformed (P1)',
      () async {
    // The real Google Routes v2 "no walkable route" response — proto3 JSON does
    // not emit empty repeated fields, so it is `{}`, never `{"routes":[]}`.
    expect(await _svc(_ok('{}')).walkingRoute(origin: (0, 0), destination: (0, 0)),
        isA<RouteNoRoute>());
  });

  test('200 + routes present but WRONG TYPE → RouteMalformed (not silently no-route)', () async {
    expect(await _svc(_ok('{"routes":"nonsense"}')).walkingRoute(origin: (0, 0), destination: (0, 0)),
        isA<RouteMalformed>());
  });

  test('duration without the `s` suffix parses as whole seconds (not off-by-one char)', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {'distanceMeters': 1, 'duration': '351', 'polyline': {'encodedPolyline': ''}}
      ]
    }))).walkingRoute(origin: (0, 0), destination: (0, 0));
    expect((r as RouteSuccess).route.eta, const Duration(seconds: 351)); // NOT 35s
  });

  test('non-string warning elements are filtered, never crash (defensive cast)', () async {
    final r = await _svc(_ok(jsonEncode({
      'routes': [
        {'distanceMeters': 1, 'duration': '1s', 'polyline': {'encodedPolyline': ''},
         'warnings': ['Use caution', 42, null]}
      ]
    }))).walkingRoute(origin: (0, 0), destination: (0, 0));
    expect((r as RouteSuccess).route.warnings, ['Use caution']); // 42/null dropped, no throw
  });

  test('401/403/429 → RouteApiFailure(status) (NOT no-route)', () async {
    for (final s in [401, 403, 429]) {
      final r = await _svc(MockClient((_) async => http.Response('{"error":"x"}', s)))
          .walkingRoute(origin: (0, 0), destination: (0, 0));
      expect(r, isA<RouteApiFailure>());
      expect((r as RouteApiFailure).status, s);
    }
  });

  test('network throw → RouteNetworkFailure (never throws out)', () async {
    expect(
        await _svc(MockClient((_) async => throw Exception('offline')))
            .walkingRoute(origin: (0, 0), destination: (0, 0)),
        isA<RouteNetworkFailure>());
  });

  test('STRICT: unparseable body AND route-present-but-missing-fields both → RouteMalformed, never RouteNoRoute (#11)',
      () async {
    expect(await _svc(_ok('not json')).walkingRoute(origin: (0, 0), destination: (0, 0)), isA<RouteMalformed>());
    // a route object exists but lacks distanceMeters/polyline → malformed, NOT "no route"
    expect(await _svc(_ok('{"routes":[{"duration":"5s"}]}')).walkingRoute(origin: (0, 0), destination: (0, 0)),
        isA<RouteMalformed>());
  });

  test('REQUEST CONTRACT: WALK carries NO routingPreference or other DRIVE-only option',
      () async {
    // The Routes API rejects `routingPreference` with `travelMode: WALK`
    // (TRAFFIC_AWARE* is a driving concept). Pin that the request stays the
    // minimal WALK shape so a future edit cannot reintroduce a driving option
    // that turns every walk into an HTTP 400 INVALID_ARGUMENT.
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode({
            'routes': [
              {'distanceMeters': 1, 'duration': '1s', 'polyline': {'encodedPolyline': ''}}
            ]
          }),
          200);
    });
    await _svc(client).walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['travelMode'], 'WALK');
    for (final drivingOnly in ['routingPreference', 'trafficModel', 'routeModifiers', 'extraComputations']) {
      expect(body.containsKey(drivingOnly), isFalse,
          reason: 'WALK must not send the DRIVE-only field "$drivingOnly"');
    }
  });

  test('HTTP 400 INVALID_ARGUMENT/API_KEY_INVALID → RouteApiFailure(400), and the reason is traced (never the body/key)',
      () async {
    // The real incident: an expired Routes key comes back as HTTP 400 (not
    // 401/403) with this exact envelope. The service must classify it as an API
    // failure AND surface Google's bounded reason so the cause is obvious.
    const googleBody =
        '{"error":{"code":400,"message":"API key expired. Please renew the API key.",'
        '"status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo",'
        '"reason":"API_KEY_INVALID","domain":"googleapis.com"}]}}';

    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    try {
      final r = await _svc(MockClient((_) async => http.Response(googleBody, 400)))
          .walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
      expect(r, isA<RouteApiFailure>());
      expect((r as RouteApiFailure).status, 400);
    } finally {
      debugPrint = original;
    }

    final trace = logs.join('\n');
    expect(trace, contains('status=INVALID_ARGUMENT'));
    expect(trace, contains('reason=API_KEY_INVALID'));
    // The no-secret contract: the free-form message and any key-like text never
    // reach the trace.
    expect(trace, isNot(contains('renew the API key')));
  });
}
