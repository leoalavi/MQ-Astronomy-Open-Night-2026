# Web directions geometry fix — 13 September 2026

**PASS: reproduced zoom 0 before; observed zoom 18 after, with native Google Maps and the blue route visible.** No commit, push, or deployment was performed.

## Evidence provenance

A fresh Google Routes WALK response for the app's preview origin (Central Courtyard) and its 11WW building coordinates returned **227 m, 182 seconds, six points**. The saved response is `test/fixtures/courtyard_11ww_route.json`; encoded polyline: `xlcmEwiiy[AcCrBANSDAEyD`.

Origin: `(-33.7737, 151.1134)`; destination: `(-33.7746267, 151.1151193)`.

These are exact values from replaying that fresh response, which matches the supplied production distance and point count. The original production network response was not attached, so this is a reproduced route, not a claim to have recovered a historical browser capture.

Both the old decoder (copied from HEAD before editing) and fixed decoder were compiled with `dart compile js -O2`. Each used the application payload builder and `jsify()`. A headless Chrome harness delivered each payload using actual same-origin iframe postMessage to the directions page. Test-only hooks recorded the received object and native map zoom. Local files were served through browser request interception under the app origin; Google Maps itself loaded live. Nothing was deployed.

## Before: compiled Dart → serialized object → actual iframe

| index | Dart lat | Dart lng | sent lat | sent lng | iframe lat | iframe lng |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 42915.89923 | 151.1134 | 42915.89923 | 151.1134 | 42915.89923 | 151.1134 |
| 1 | 42915.89924 | 151.11406 | 42915.89924 | 151.11406 | 42915.89924 | 151.11406 |
| 2 | 85865.57162 | 151.11407 | 85865.57162 | 151.11407 | 85865.57162 | 151.11407 |
| 3 | 128815.2445 | 151.11417 | 128815.2445 | 151.11417 | 128815.2445 | 151.11417 |
| 4 | 171764.91743 | 151.11418 | 171764.91743 | 151.11418 | 171764.91743 | 151.11418 |
| 5 | 171764.91746 | 151.11511 | 171764.91746 | 151.11511 | 171764.91746 | 151.11511 |

## After: compiled Dart → serialized object → actual iframe

| index | Dart lat | Dart lng | sent lat | sent lng | iframe lat | iframe lng |
|---|---:|---:|---:|---:|---:|---:|
| 0 | -33.77373 | 151.1134 | -33.77373 | 151.1134 | -33.77373 | 151.1134 |
| 1 | -33.77372 | 151.11406 | -33.77372 | 151.11406 | -33.77372 | 151.11406 |
| 2 | -33.7743 | 151.11407 | -33.7743 | 151.11407 | -33.7743 | 151.11407 |
| 3 | -33.77438 | 151.11417 | -33.77438 | 151.11417 | -33.77438 | 151.11417 |
| 4 | -33.77441 | 151.11418 | -33.77441 | 151.11418 | -33.77441 | 151.11418 |
| 5 | -33.77438 | 151.11511 | -33.77438 | 151.11511 | -33.77438 | 151.11511 |

## Cause and exact fix

Every latitude is already corrupt in decoded Dart running as JavaScript. All three representations remain numerically identical: neither field names nor postMessage introduce corruption. Longitudes are correct. This is not swapped coordinates, zero contamination, or NaN.

The old negative-delta expression `~(result >> 1)` returns an unsigned 32-bit integer on Dart web. The fix in `lib/services/polyline_codec.dart` is:

```dart
final magnitude = result >> 1;
return ((result & 1) != 0 ? -magnitude - 1 : magnitude, index, true);
```

The arithmetic expression preserves negative values on VM and web. The existing Google reference-vector test passed natively before, but the browser replay failed; the new regression runs in Chrome too. See [Dart bitwise platform differences](https://dart.dev/language/operators#bitwise-and-shift-operators).

The serializer explicitly converts tuple latitude/longitude to `{lat, lng}`. The Routes API request still correctly uses `{latitude, longitude}`. There is no JSON encoding step between the widget and iframe: `jsify()` converts to JavaScript objects, then postMessage structured-clones them.

## Validation and bounds

`web/maps/route_geometry.js` checks finite numeric coordinates, geographic ranges, missing values, alternate field names, potentially swapped values, and `(0,0)`. A generic walking envelope allows 1 km or three times endpoint separation, whichever is larger, around the supplied endpoints. Outliers trigger `WebMapFrame: INVALID_ROUTE_BOUNDS` and endpoint-only fitting. It does not use campus constants. A suspect path is dropped entirely so removing one middle point cannot fabricate a connecting segment. Invalid endpoints never enter markers or bounds; no usable bounds leaves the camera unchanged.

Only validated path points reach the existing native Polyline, with `#1A73E8`, opacity 1, weight 6 and z-index 1000. The iframe, handshake, readiness gate, map API and resize behavior remain intact.

| Geometry | Latitude range | Longitude range | Latitude span | Longitude span |
|---|---|---|---:|---:|
| Before, decoded route only | 42915.89923 to 171764.91746 | 151.1134 to 151.11511 | 128849.01823 | 0.00171 |
| After, route only | -33.77441 to -33.77372 | 151.1134 to 151.11511 | 0.00069 | 0.00171 |
| After, route + endpoints | -33.7746267 to -33.7737 | 151.1134 to 151.1151193 | 0.0009267 | 0.0017193 |

Expected zoom depends on viewport dimensions, approximately 16–18. In the 1550 × 600 iframe:

- Original iframe + old decoder: **zoom 0**.
- Original iframe + corrected decoder: **zoom 18**.
- Guarded iframe + old corrupt geometry: **zoom 18**, endpoints only.
- Guarded iframe + corrected geometry: **zoom 18**, blue walking path visible.

## Temporary diagnostics

Opt in with `--dart-define=ROUTE_GEOMETRY_DIAGNOSTICS=true` in an investigation build. This logs indexed decoded Dart coordinates, the converted setRoute payload immediately before postMessage, iframe receipt, numeric extrema and fitted bounds. It never logs init messages or keys. The requested standard release build leaves coordinate tracing disabled; rejection reason codes remain available.

## Verification

| Check | Result |
|---|---|
| `flutter analyze lib test` | PASS, no issues |
| `flutter test` | PASS, 1,750 tests |
| `flutter test --platform chrome test/unit/polyline_codec_test.dart test/unit/web_route_payload_test.dart test/web/route_transport_test.dart` | PASS, 6 tests |
| `node --test test/web/route_geometry_test.cjs` | PASS, 7 tests |
| `flutter build web --release --dart-define-from-file=.env.web --base-href / --no-web-resources-cdn` | PASS, build/web |
| Built iframe and geometry files match source | PASS |
| Real Google Maps iframe replay | PASS, zoom 0 → 18 |

Browser tests cover signed decoding, every payload value, jsify and real iframe round-tripping. JavaScript tests cover bad geometry, endpoint inclusion, campus span, a non-Sydney route, and execution of the actual iframe script with instrumented Maps constructors to ensure corrupt points never reach native Polyline/LatLngBounds.

The production deployment itself is unchanged. These results verify the local fix and release build, not a deployed update.
