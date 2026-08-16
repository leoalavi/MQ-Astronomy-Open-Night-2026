# M4 — Embedded Google Maps Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** An embedded Google map showing the attendee's location, a destination, and the **walking route** to it — for M3 buildings and event venues — rendering Google data on Google's own map (ToS-clean), augmenting (not replacing) the curated wayfinding, and shipping **dark until API keys are supplied**.

**Architecture:** A capability flag (`googleNavEnabled` = native-map-configured ∧ Routes-key ∧ mobile) gates every entry point. A pure `GoogleRoutesService` returns a typed `RouteResult`; `GoogleNavScreen` sequences consent → location → route → embedded map (behind an `EmbeddedMap` seam so it's testable). Credentials are **four separate GCP-restricted keys**; the key is assumed extractable and restrictions are the security boundary.

**Tech Stack:** Flutter 3.44 · **new deps: `google_maps_flutter`, `http`, `url_launcher`** · Riverpod 3 · `geolocator` (existing) · `shared_preferences` (existing).

**Design:** `docs/superpowers/specs/2026-08-16-aon-map-M4-google-nav-design.md` — **read §0b (external-review amendment) then §0; both authoritative, supersede the body.**

## Global Constraints

- **Ships dark without keys.** No secret → `googleNavEnabled` false → no Google-nav CTA; the app builds and runs fully. No-key `build web|apk|ios` are gates (Task 0/Task 10).
- **Four restricted credentials** (design §0b.A): Android/iOS × {Maps SDK key, Routes key}. Native SDK keys via `android/secrets.properties` + `ios/Flutter/Secrets.xcconfig` (already git-ignored). Routes keys via `--dart-define`. **Key is extractable → restrictions ARE the boundary.** Restriction of all four = a **pre-live closeout gate**, not an IOU.
- **🔴 Direct-mobile Routes security headers (Google-verified, api-security-best-practices):** an app-restricted key called directly from the device requires per-platform identity headers, and **Android requires TWO** — `X-Android-Package` (= `au.edu.mq.astronomy.aon2026`) **and** `X-Android-Cert` (the signing-cert SHA-1) — while **iOS requires one**, `X-Ios-Bundle-Identifier` (= `au.edu.mq.astronomy.aon2026`). The service takes a **header MAP**, and the SHA-1 has an explicit source (T3 `routesClientIdentityProvider`). Verify at closeout that wrong identity is REJECTED (T10) — the restriction is the boundary, so proving rejection is the evidence.
- **🔴 Mandatory walking warning (Google-verified, RouteTravelMode):** WALK/BICYCLE/TWO_WHEELER are beta and *"You must display this warning to the user for all walking … routes that you display in your app."* M4 is WALK-only → the route panel MUST show `routes.warnings[]` when present AND a baseline localized walking caution regardless (EN+FA). Field mask includes `routes.warnings`; `NavRoute` carries `warnings`.
- **Typed errors:** `RouteResult` sealed — network / no-route / api-error(status) / malformed distinct. Auth/quota ≠ "no route". A route object present but missing required fields is **malformed**, never "no route".
- **Consent before location** (design §0b.E): `tap → consent → location → map/route`. Router + screen self-guard deep links. Consent state `{unknown, accepted, declined}` + Settings revoke.
- **Augment:** BuildingSheet + VenueSheet gain Google-nav (flag-gated); **parking sheets + `WayfindingScreen` + wayfinding FAB untouched.** No-key building fallback = keyless external Maps URL.
- **New deps expected; web build stays a hard gate; EN+FA every string; `context.aon` chrome (map is Google's); 320×568/2.0; TDD; `./scripts/check.sh` EXIT-gated before every commit** (`check.sh && git commit`, never `check.sh | tail && commit`).

---

### Task 0: Deps + no-key build safety + web gate (🔴 gauntlet-critical, do first)

**Files:** `pubspec.yaml`; `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`; `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`; **committed samples** `ios/Flutter/Secrets.xcconfig.sample` + `android/secrets.properties.sample` (the real `ios/Flutter/Secrets.xcconfig` / `android/secrets.properties` stay git-ignored — the sample MUST have a distinct path, #1).

**Interfaces:** produces the three deps resolved, and a native config that builds green **with the secret files absent**.

- [ ] **Step 1: Add deps, resolve, record targets (#8)**
```bash
cd /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026
flutter pub add google_maps_flutter http url_launcher
flutter pub get
```
Record the resolved `google_maps_flutter` version + the min Android `compileSdk`/`minSdk` and iOS deployment target it requires (from `flutter pub deps` / build errors) into the plan's closeout notes. Do NOT guess versions.

- [ ] **Step 2: 🔴 Web-build gate BEFORE any feature code**
Run: `flutter build web`
Expected: GREEN. `google_maps_flutter_web` is pulled transitively; the web build must still compile. **Do NOT add the Maps-JS `<script>` to make this pass (#3):** that JS runtime is only needed to actually *render* a Google map on web, and M4 is gated OFF web (`mapsNavPlatform == unsupported`), so it renders nothing there. A web-compile failure is a plugin-compatibility problem — investigate the resolved plugin version, Flutter/platform minimums, and any upstream issue; use a scoped `dependency_overrides` only if a known-good version resolves it. Never light up an unused runtime to massage a compile gate.

- [ ] **Step 3: Native SDK key config that tolerates MISSING secrets**
- Android: `build.gradle` loads `android/secrets.properties` **if present** (else empty), exposes `MAPS_API_KEY` as a `manifestPlaceholder` defaulting to `""`; `AndroidManifest.xml` adds
  `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}"/>`.
- iOS: `AppDelegate.swift` reads the key from `Bundle.main` (an `Info.plist` entry substituted from `Secrets.xcconfig` build setting) and calls `GMSServices.provideAPIKey(key)` **only if non-empty**; a missing `Secrets.xcconfig` must not break the build (`#include?` optional include).
- Add `android/secrets.properties.sample` + `ios/Flutter/Secrets.xcconfig.sample` + document the build command with `--dart-define=GOOGLE_MAPS_ANDROID_ROUTES_KEY=…`/`…IOS…`. Real secrets stay git-ignored.

- [ ] **Step 4: No-key build gate (web + apk + iOS all EXECUTED) + commit**
This host is macOS, so the iOS build is a real gate, not a comment (#2):
```bash
# with NO android/secrets.properties and NO ios/Flutter/Secrets.xcconfig present:
flutter build web && \
flutter build apk --debug && \
flutter build ios --debug --no-codesign
```
Expected: all three GREEN ("ships dark" is now executable, #2/#6/#32). The iOS no-key build is the one that proves the optional `#include?` of the absent `Secrets.xcconfig` doesn't break the build.
```bash
# Stage explicit paths only — never `git add android/ ios/` wholesale for a secrets-sensitive task (#4):
./scripts/check.sh > /tmp/gate.log 2>&1 && git add pubspec.yaml pubspec.lock \
  android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/secrets.properties.sample \
  ios/Runner/AppDelegate.swift ios/Runner/Info.plist ios/Flutter/Secrets.xcconfig.sample && \
  git commit -m "feat(map): M4 T0 — google_maps_flutter/http/url_launcher + no-key-safe native config + web/apk/ios gates" || { echo GATE FAILED; tail /tmp/gate.log; }
# (verify `git status` shows no real secret file staged before committing)

---

### Task 1: Capability providers (injectable platform, both surfaces)

**Files:** Create `lib/services/maps_nav_providers.dart`; Test `test/unit/maps_nav_capability_test.dart`.

**Interfaces:**
- `enum MapsNavPlatform { unsupported, android, ios }`; `mapsNavPlatformProvider` (default from `kIsWeb`/`defaultTargetPlatform`, overridable in tests).
- `androidRoutesKeyProvider`/`iosRoutesKeyProvider` (`String.fromEnvironment`); **`activeRoutesKeyProvider`** = `switch(mapsNavPlatform){ android → androidRoutesKey, ios → iosRoutesKey, unsupported → '' }`; **`routesConfiguredProvider = activeRoutesKeyProvider.isNotEmpty`** — the ACTIVE platform's key, NOT "either key" (#5). An Android build carrying only the iOS Routes key must read `routesConfigured == false`. Then `embeddedMapConfiguredProvider`, `googleNavEnabledProvider`.
- **`embeddedMapConfigured` is a BUILD-TIME assertion, not runtime detection.** There is no clean way for Dart to query whether iOS `GMSServices.provideAPIKey` / the Android manifest key were actually set. So `embeddedMapConfiguredProvider = bool.fromEnvironment('MAPS_NATIVE_CONFIGURED', defaultValue: false)` — the build that provides the native secret files ALSO passes `--dart-define=MAPS_NATIVE_CONFIGURED=true`. Document this coupling; the two-flag split (vs one all-configured flag) is what lets the matrix test prove the #5 trap (routes-present-but-native-absent → disabled) is closed.

- [ ] **Step 1: Failing matrix test (#31)**
```dart
// test/unit/maps_nav_capability_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/maps_nav_providers.dart';

ProviderContainer _c({required MapsNavPlatform platform, bool routes = false, bool nativeMap = false}) {
  final c = ProviderContainer(overrides: [
    mapsNavPlatformProvider.overrideWithValue(platform),
    routesConfiguredProvider.overrideWithValue(routes),
    embeddedMapConfiguredProvider.overrideWithValue(nativeMap),
  ]);
  addTearDown(c.dispose);
  return c;
}

// Cross-key container: overrides the RAW keys (not routesConfigured) so the
// platform-selection logic itself is under test (#5).
ProviderContainer _cKeys({required MapsNavPlatform platform, String android = '', String ios = ''}) {
  final c = ProviderContainer(overrides: [
    mapsNavPlatformProvider.overrideWithValue(platform),
    androidRoutesKeyProvider.overrideWithValue(android),
    iosRoutesKeyProvider.overrideWithValue(ios),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('enabled only when native map AND routes AND mobile', () {
    expect(_c(platform: MapsNavPlatform.android, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.android, routes: false, nativeMap: true).read(googleNavEnabledProvider), isFalse); // no routes key
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: false).read(googleNavEnabledProvider), isFalse); // native map missing → the #5 trap
    expect(_c(platform: MapsNavPlatform.unsupported, routes: true, nativeMap: true).read(googleNavEnabledProvider), isFalse); // web/desktop
  });
  test('routesConfigured tracks the ACTIVE platform key, not "either key" (#5)', () {
    expect(_cKeys(platform: MapsNavPlatform.android, ios: 'iosKey').read(routesConfiguredProvider), isFalse); // Android build, only iOS key
    expect(_cKeys(platform: MapsNavPlatform.ios, android: 'androidKey').read(routesConfiguredProvider), isFalse); // iOS build, only Android key
    expect(_cKeys(platform: MapsNavPlatform.android, android: 'androidKey').read(routesConfiguredProvider), isTrue);
    expect(_cKeys(platform: MapsNavPlatform.ios, ios: 'iosKey').read(routesConfiguredProvider), isTrue);
  });
}
```
- [ ] **Step 2–4:** Run → fail; implement (`activeRoutesKeyProvider` platform-switched; `routesConfiguredProvider = activeRoutesKeyProvider.isNotEmpty`; base `googleNavEnabledProvider` = `routesConfigured ∧ embeddedMapConfigured ∧ platform != unsupported`; `mapsNavPlatformProvider` computed web-safe via `kIsWeb ? unsupported : switch(defaultTargetPlatform)`); run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T1 — capability flag (both surfaces, injectable platform)"`

---

### Task 2: Polyline decoder (pure)

**Files:** Create `lib/services/polyline_codec.dart`; Test `test/unit/polyline_codec_test.dart`.

**Interfaces:** **`List<(double lat, double lng)> decodePolyline(String encoded)`** — Google's standard algorithm, returning plain `(double,double)` tuples (DECIDED: no `google_maps_flutter_platform_interface` `LatLng`, which risks pulling that package into the dep story as a 4th declared dep, #19; and no `latlong2` confusion). Tuples flow unchanged through T3/T4/T6.

- [ ] **Step 1: Failing test — assert BOTH coords of ALL reference points + malformed (#7)**
```dart
// test/unit/polyline_codec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/polyline_codec.dart';

void main() {
  test('decodes Google reference vector "_p~iF~ps|U_ulLnnqC_mqNvxq`@" — all 3 points, lat AND lng', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].$1, closeTo(38.5, 1e-5));   expect(pts[0].$2, closeTo(-120.2, 1e-5));
    expect(pts[1].$1, closeTo(40.7, 1e-5));   expect(pts[1].$2, closeTo(-120.95, 1e-5));
    expect(pts[2].$1, closeTo(43.252, 1e-3)); expect(pts[2].$2, closeTo(-126.453, 1e-3)); // longitude decode covered
  });
  test('empty string → empty', () => expect(decodePolyline(''), isEmpty));
  test('truncated/dangling encoding does not throw (returns what it decoded)', () {
    // a trailing chunk with the continuation bit set but no following byte
    expect(() => decodePolyline('_p~iF~ps|U_ulL'), returnsNormally);
  });
}
```
- [ ] **Step 2–4:** implement the standard decode (returns `List<(double lat, double lng)>`); run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T2 — pure polyline decoder"`

---

### Task 3: `RouteResult` + `RoutesService` + client identity (typed, fake http)

**Files:** Create `lib/services/routes_service.dart` (interface + `NavRoute`/`RouteResult`), `lib/services/google_routes_service.dart` (impl), `lib/services/routes_client_identity.dart` (identity headers + provider), `android/app/src/main/kotlin/.../RoutesIdentityPlugin.kt` + `ios/Runner` MethodChannel handler (Android cert only); Test `test/unit/google_routes_service_test.dart`.

**Interfaces:**
- `class NavRoute { List<(double,double)> polyline; int distanceMeters; Duration eta; List<String> warnings; }` — **`warnings` carries Google's `routes.warnings[]`** (mandatory display, see Global Constraints / #13).
- `sealed class RouteResult` → `RouteSuccess(NavRoute)`, `RouteNoRoute`, `RouteNetworkFailure`, `RouteApiFailure(int status)`, `RouteMalformed`.
- **`abstract interface class RoutesService { Future<RouteResult> walkingRoute({required (double,double) origin, required (double,double) destination}); }`** (#14 — this is the seam T4's counting fake and T7's fakes implement; concrete class below is one implementation).
- `class GoogleRoutesService implements RoutesService` — ctor `({required http.Client client, required String apiKey, required Map<String,String> platformHeaders})`. **`platformHeaders` is a MAP (#8):** iOS `{'X-Ios-Bundle-Identifier': bundleId}`; **Android `{'X-Android-Package': pkg, 'X-Android-Cert': sha1}` — both required** (Google-verified). A single name/value pair cannot express Android's two headers.
- **`class RoutesClientIdentity { final Map<String,String> headers; }`** + `routesClientIdentityProvider` (#9 — the SOURCE of those headers):
  - iOS: `{'X-Ios-Bundle-Identifier': 'au.edu.mq.astronomy.aon2026'}` (bundle id is a build constant; verified in `project.pbxproj`).
  - Android: `{'X-Android-Package': 'au.edu.mq.astronomy.aon2026', 'X-Android-Cert': <sha1>}` where `<sha1>` is read at runtime via a tiny `MethodChannel` (`PackageManager.getPackageInfo(pkg, GET_SIGNING_CERTIFICATES)` → SHA-1 of the active signing cert) so it always matches the running APK. (Build-time `--dart-define` injection of the SHA-1 is an acceptable fallback, but the live-cert read cannot drift from the shipped signature.)
  - `unsupported`/web: `{}` — nav is disabled there anyway.

- [ ] **Step 1: Failing tests — request contract + fractional duration + error classification + strict malformed (#8/#10/#11/#12/#13)**
```dart
// test/unit/google_routes_service_test.dart  (uses package:http/testing MockClient)
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/google_routes_service.dart';

const _iosHeaders = {'X-Ios-Bundle-Identifier': 'au.edu.mq.astronomy.aon2026'};
const _androidHeaders = {'X-Android-Package': 'au.edu.mq.astronomy.aon2026', 'X-Android-Cert': 'AB:CD:EF'};

GoogleRoutesService _svc(http.Client c, {Map<String,String> headers = _iosHeaders}) =>
    GoogleRoutesService(client: c, apiKey: 'k', platformHeaders: headers);
http.Client _ok(String body) => MockClient((_) async => http.Response(body, 200));

void main() {
  test('REQUEST CONTRACT: POST, exact URL, field mask, api-key, WALK, nested origin/dest, BOTH android headers (#8/#10)', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode({'routes':[{'distanceMeters':1,'duration':'1s','polyline':{'encodedPolyline':''},'warnings':[]}]}), 200);
    });
    await _svc(client, headers: _androidHeaders).walkingRoute(origin: (-33.77, 151.11), destination: (-33.78, 151.12));
    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'https://routes.googleapis.com/directions/v2:computeRoutes');
    expect(seen.headers['content-type'], contains('application/json'));
    expect(seen.headers['x-goog-api-key'], 'k');
    expect(seen.headers['x-goog-fieldmask'],
        'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,routes.warnings'); // includes warnings (#13)
    expect(seen.headers['x-android-package'], 'au.edu.mq.astronomy.aon2026'); // BOTH android headers present (#8)
    expect(seen.headers['x-android-cert'], 'AB:CD:EF');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['travelMode'], 'WALK');
    expect(body['origin']['location']['latLng']['latitude'], -33.77);
    expect(body['origin']['location']['latLng']['longitude'], 151.11);
    expect(body['destination']['location']['latLng']['latitude'], -33.78);
    expect(body['destination']['location']['latLng']['longitude'], 151.12);
  });
  test('success: fractional "3.5s" parses; distance + polyline + warnings surfaced', () async {
    final r = await _svc(_ok(jsonEncode({'routes':[{'distanceMeters':412,'duration':'3.5s','polyline':{'encodedPolyline':'_p~iF~ps|U'},'warnings':['Use caution']}]}))).walkingRoute(origin: (-33.77,151.11), destination: (-33.78,151.12));
    expect(r, isA<RouteSuccess>());
    final nav = (r as RouteSuccess).route;
    expect(nav.distanceMeters, 412);
    expect(nav.eta, const Duration(milliseconds: 3500)); // NOT crash on "3.5s"
    expect(nav.warnings, ['Use caution']);
  });
  test('durations "351s" and "0.125s" parse; absent warnings → empty list', () async {
    for (final d in ['351s','0.125s']) {
      final r = await _svc(_ok(jsonEncode({'routes':[{'distanceMeters':1,'duration':d,'polyline':{'encodedPolyline':''}}]}))).walkingRoute(origin:(0,0),destination:(0,0));
      expect(r, isA<RouteSuccess>());
      expect((r as RouteSuccess).route.warnings, isEmpty);
    }
  });
  test('200 + zero routes → RouteNoRoute', () async {
    expect(await _svc(_ok(jsonEncode({'routes':[]}))).walkingRoute(origin:(0,0),destination:(0,0)), isA<RouteNoRoute>());
  });
  test('401/403/429 → RouteApiFailure(status) (NOT no-route)', () async {
    for (final s in [401,403,429]) {
      final r = await _svc(MockClient((_) async => http.Response('{"error":"x"}', s))).walkingRoute(origin:(0,0),destination:(0,0));
      expect(r, isA<RouteApiFailure>());
      expect((r as RouteApiFailure).status, s);
    }
  });
  test('network throw → RouteNetworkFailure (never throws out)', () async {
    expect(await _svc(MockClient((_) async => throw Exception('offline'))).walkingRoute(origin:(0,0),destination:(0,0)), isA<RouteNetworkFailure>());
  });
  test('STRICT: unparseable body AND route-present-but-missing-fields both → RouteMalformed, never RouteNoRoute (#11)', () async {
    expect(await _svc(_ok('not json')).walkingRoute(origin:(0,0),destination:(0,0)), isA<RouteMalformed>());
    // a route object exists but lacks distanceMeters/polyline → malformed, NOT "no route"
    expect(await _svc(_ok('{"routes":[{"duration":"5s"}]}')).walkingRoute(origin:(0,0),destination:(0,0)), isA<RouteMalformed>());
  });
}
```
- [ ] **Step 2–4:** implement. POST `https://routes.googleapis.com/directions/v2:computeRoutes`; headers = `{'Content-Type':'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': 'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,routes.warnings', ...platformHeaders}` (spread the identity map — #8/#13); body nests `origin.location.latLng.{latitude,longitude}`, `destination.location.latLng.*`, `travelMode:'WALK'`. **Scoped error handling (#12):** wrap ONLY the `client.post` in a try→`RouteNetworkFailure`; then check `statusCode != 200 → RouteApiFailure(status)`; then in a SEPARATE try, decode+validate (missing `routes` key OR route present without `distanceMeters`/`polyline.encodedPolyline`/`duration` → `RouteMalformed`; `routes` empty → `RouteNoRoute`) — a JSON/duration exception here is malformed, never mislabeled network. Duration: `Duration(milliseconds: (double.parse(v.substring(0,v.length-1))*1000).round())`. `warnings` = `(route['warnings'] as List?)?.cast<String>() ?? const []`. Log status/body safely (never the key). Run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T3 — RoutesService iface + GoogleRoutesService (header map, client identity, warnings, strict malformed)"`

---

### Task 4: `navRouteProvider` (autoDispose family, billing rule #36)

**Files:** add to `lib/services/maps_nav_providers.dart`; Test add to capability test or a new one.
- `routesServiceProvider` returns a **`RoutesService`** (T3 interface, #14) — production build wires `GoogleRoutesService(client: http.Client(), apiKey: activeRoutesKey, platformHeaders: routesClientIdentity.headers)`; tests override with a counting fake. `navRouteProvider = FutureProvider.autoDispose.family<RouteResult, ((double,double),(double,double))>` — one in-flight per (origin,dest); autoDispose so a closed screen frees it; retry = invalidate on user action only.
- [ ] Tests (#15): override `routesServiceProvider` with a `class _CountingService implements RoutesService { int calls = 0; ... }`. Keep the provider ALIVE with an explicit listener so autoDispose can't tear it down between reads — `final sub = container.listen(navRouteProvider(args), (_, __) {}); addTearDown(sub.close);` — then a SECOND `container.listen`/`read` of the SAME args asserts `calls == 1` (two simultaneous consumers → one HTTP op); different args → `calls == 2`. `./scripts/check.sh && git commit -m "feat(map): M4 T4 — navRouteProvider (autoDispose, one-in-flight billing rule)"`

---

### Task 5: Consent state machine + store + disclosure (#22,#23)

**Files:** Create `lib/services/maps_consent_store.dart` + `lib/services/maps_consent_providers.dart` + `lib/widgets/maps_nav_disclosure.dart`; Test mirrored. Modify `main.dart` (inject snapshot, passport idiom).

**Interfaces:** `enum MapsConsent { unknown, accepted, declined }`; `MapsConsentStore` (SharedPreferencesAsync, key `map_google_consent.v1`); `mapsConsentProvider` (Notifier, seeded from injected snapshot) with `accept()/decline()/revoke()`.

**🔴 Explicit state contract (#16) — the three states drive T7's guard:**
- `accepted` → proceed straight to location+route (no disclosure).
- `unknown` → show disclosure before ANY location read or Google call; Accept→`accepted`, Cancel→`declined`.
- `declined` → **NOT a permanent brick.** Nothing auto-accesses location or contacts Google. But an explicit Google-nav tap re-opens the disclosure (a `declined` user who taps again is asking to reconsider); the CTA still renders. Only `revoke()` from Settings resets to `unknown`. (So T7 treats BOTH `unknown` and `declined` as "show disclosure on explicit tap", and only `accepted` as "proceed".)

- [ ] Tests: default `unknown`; `accept` → `accepted` persists; `decline` → `declined` persists; `revoke` → `unknown`+persists; disclosure shows when `unknown`, shows again on explicit tap when `declined`, NOT shown when `accepted`; Cancel sets `declined` (no location touched); EN+FA; 320×568/2.0. Implement (passport idiom + dispose guard as in M3 favorites). `./scripts/check.sh && git commit -m "feat(map): M4 T5 — Google-nav consent state machine (declined defined) + disclosure"`

---

### Task 6: `EmbeddedMap` seam (#30)

**Files:** Create `lib/widgets/embedded_map.dart` (widget + pure `LatLngBounds boundsFor(origin, destination, route)` helper); Test `test/widget/embedded_map_test.dart` + `test/unit/embedded_map_bounds_test.dart`.
- **`EmbeddedMap({required (double,double) origin, required (double,double) destination, required List<(double,double)> route})`** — origin is EXPLICIT (#18): the camera fits **origin ∪ destination ∪ all route points**, because a returned polyline may not include the exact device origin/destination, and a bounds over only `route` could clip them.
- Wraps `GoogleMap` (markers for origin+destination + `Polyline` over route + panel padding for attribution). **Do NOT fake `google_maps_flutter`'s platform interface (#19)** — that risks pulling `google_maps_flutter_platform_interface` into the declared deps (breaks the "3 deps" story) and couples tests to Google's plugin internals. Instead the tile-rendering is behind a local **`EmbeddedMapSurface`** seam (production → the real `GoogleMap`; tests → a `FakeEmbeddedMapSurface` that renders a `SizedBox`). Widget tests build `EmbeddedMap` with the fake surface; **the bounds math is tested as a PURE function** (`boundsFor(...)`), no widget at all.
- [ ] Tests: `boundsFor` includes every extreme of origin/destination/route (unit); `EmbeddedMap` builds with the fake surface without a platform view. `./scripts/check.sh && git commit -m "feat(map): M4 T6 — EmbeddedMap (explicit origin, pure bounds, local surface seam)"`

---

### Task 7: `GoogleNavScreen` + router self-guard (#20,#21,#22,#28)

**Files:** Create `lib/screens/google_nav_screen.dart`; Modify `lib/app/router/app_router.dart` (add `Routes.googleNav(placeKey)` with a guard). Test `test/widget/google_nav_screen_test.dart`.
- **🔴 Coordinate space (gauntlet):** the destination MUST be `ResolvedPlace.routingLat/routingLng` (**geographic WGS84 GPS** — `entrance ?? latitude`). **NEVER `renderPoint`** — that is `CampusMapPoint` in **CrsSimple map-units** (e.g. `(36.6, 58.6)`); sent to Google Maps it's mid-ocean. Origin is the geolocator GPS. Both are geographic; the CrsSimple projection is not involved in M4 at all.
- **🔴 Sequence ordering fix (#20)** — you cannot test "dest resolvable" before resolving it, and consent must gate location, not resolution. Correct strict order:
  1. **Capability guard** — `googleNavEnabled` false → Google-nav-unavailable panel (no resolve, no consent).
  2. **Resolve the local M3 destination** via `placeResolverProvider(placeKey)` → take `routingLat/routingLng`. This touches NO location and contacts Google with NOTHING, so it precedes consent safely; unresolvable placeKey → local error/back (see deep-link cases).
  3. **Consent gate** — `accepted` → continue; `unknown`/`declined` → show disclosure (per T5 contract), and only on Accept continue.
  4. **Obtain location** (origin, captured ONCE = snapshot); no permission / no fix → offer curated wayfinding (venues) or external Maps URL (buildings), never a blank Google view.
  5. **`navRouteProvider((origin,dest))`** → route request.
  6. **Instantiate `EmbeddedMap(origin, destination, route)`** on success.
- States:
  - success → `EmbeddedMap` + panel (distance/ETA) + **🔴 walking warning (#13/#22): render `route.warnings` when present AND always a baseline `mapNavWalkingWarning` caution** (Google mandate — WALK routes must warn) + "Open in Google Maps" (url_launcher via the T9 `ExternalMapsLauncher` seam, #26) — **snapshot route** (#20).
  - `RouteNoRoute`/`RouteApiFailure`/`RouteNetworkFailure`/malformed → **standalone AON error panel** (Retry + curated/external fallback) — NOT a Google-tiles-dependent view (#28).
- **🔴 Deep-link failure cases, enumerated (#21)** — the router/screen guard for `Routes.googleNav(placeKey)` handles each explicitly; **never auto-launch an external app from a deep link** — external Maps is offered as an explicit button, tapped by the user:
  - feature disabled (`!googleNavEnabled`) → Google-nav-unavailable panel (optional "Open in Google Maps" button).
  - invalid/unresolvable `placeKey` → local error panel + back.
  - `consent == unknown|declined` → disclosure (Accept continues, Cancel → `declined` + back).
  - `consent == accepted` → continue the sequence.
- [ ] Tests (fake `RoutesService` + fake `EmbeddedMapSurface`, no real map): capability-off → unavailable panel; each route state renders the right panel; success shows distance/ETA **and the walking warning** (assert `find.text(mapNavWalkingWarning...)`); deep-link with `consent!=accepted` shows disclosure and touches no location (guard #21); invalid placeKey → error panel. `./scripts/check.sh && git commit -m "feat(map): M4 T7 — GoogleNavScreen (ordered guard, enumerated deep-links, walking warning, snapshot route)"`

---

### Task 8: l10n (EN + FA)

**Files:** `lib/l10n/app_en.arb`+`app_fa.arb`.
- Keys: `mapNavGoogle` ("Navigate with Google Maps"), `mapNavOpenExternal` ("Open in Google Maps"), `mapNavDistance(m)`, `mapNavEta(mins)`, `mapNavNoRoute`, `mapNavOffline`, `mapNavError`, `mapNavNeedLocation`, **`mapNavWalkingWarning`** ("Walking routes are in beta — sidewalks and paths may be missing; use caution.", Google-mandated baseline #13/#22), **`mapNavWarningsTitle`** ("Route notices", header for Google's `routes.warnings`), disclosure title/body/accept/decline, `settingsRevokeGoogleConsent`, `settingsGoogleMapsNotice` (ToS notice #24). Real Persian for every key.
- **🔴 Format contract (#23) — pin it so widgets don't each invent it:** `mapNavDistance(m)` renders `<1000 → "412 m"`, `≥1000 → "1.4 km"` (one decimal, `m/1000` rounded) — formatted in Dart then passed as a `{distance}` string placeholder, so the ARB carries only the surrounding words. `mapNavEta(mins)` takes integer minutes: `<60 → "6 min"`, `≥60 → "1 hr 4 min"` — minute/hour split computed in Dart, ARB carries the unit words. ETA source = `NavRoute.eta.inMinutes` (round `inSeconds/60`).
- [ ] gen-l10n green; `./scripts/check.sh && git commit -m "feat(map): M4 T8 — EN+FA strings (Google nav, consent, walking warning, ToS) + format contract"`

---

### Task 8A: Settings/Info Google-Maps privacy controls (🔴 was a silent gap, #17)

**Files:** Modify `lib/screens/settings_screen.dart` (revoke control + notice) and/or `lib/screens/info_screen.dart` (ToS/attribution notice); Test `test/widget/settings_google_consent_test.dart`.

The consent machine (T5) has `revoke()` and T10 requires "Settings revoke → next nav re-asks" + "ToS notices present in Settings/Info", but **no other task touches these screens** — so this is the task that makes those requirements real (the self-review's earlier "no silent gap" was false without it).

- **Settings:** show the Google-Maps privacy notice (`settingsGoogleMapsNotice`); when `mapsConsent == accepted`, show a **Revoke** control (`settingsRevokeGoogleConsent`) that calls `mapsConsentProvider.notifier.revoke()` → state `unknown`. When not accepted, the revoke control is hidden (nothing to revoke).
- **Info:** Google Maps/Routes attribution + ToS notice line (keyless-nav and embedded-map usage), consistent with the app-wide attribution cleanup IOU.
- [ ] Tests: notice string present (EN+FA); revoke visible only when `accepted`; tapping revoke → `mapsConsentProvider` reads `unknown` (⇒ next nav re-asks, satisfying the T10 check by construction); 320×568/2.0 reachability of the revoke row (`scrollUntilVisible`+`tap`). `./scripts/check.sh && git commit -m "feat(map): M4 T8A — Settings revoke + Google-Maps ToS notice (closes the #17 gap)"`

---

### Task 9: Wiring (augment) + keyless fallback (#25)

**Files:** Modify `lib/widgets/building_sheet.dart`, `lib/screens/map_screen.dart` (`VenueSheet`); add `lib/services/maps_url.dart` (keyless URL) + `lib/services/external_maps_launcher.dart` (launcher seam). Test `test/widget/map_m4_wiring_test.dart`.
- **`maps_url.dart` (#25):** build the keyless directions URL with **`Uri.https('www.google.com', '/maps/dir/', {...})`** — NOT string concatenation. Params `{'api':'1','destination':'$lat,$lng','travelmode':'walking'}`; **omit `origin`** so Google Maps picks the device's current location (officially supported, verified). Keyless is fine for the Maps *URL* scheme (no API key needed).
- **`ExternalMapsLauncher` seam (#24):** `abstract interface class ExternalMapsLauncher { Future<bool> open(Uri uri); }` + `externalMapsLauncherProvider` (production → `url_launcher`'s `launchUrl`); widget tests override with a fake that records the `Uri`. No mocking of plugin globals.
- **BuildingSheet:** `googleNavEnabled` → "Walking directions" pushes `Routes.googleNav('building:$id')`; **else → `mapNavOpenExternal` calling `externalMapsLauncher.open(mapsUrl)`** (never the empty curated screen). VenueSheet: keep curated "Walking directions"; **add** "Navigate with Google Maps" when `googleNavEnabled`. Parking + `WayfindingScreen` + FAB untouched (regression test).
- [ ] Tests: flag ON → building CTA pushes googleNav; flag OFF → building CTA calls the fake launcher with the expected `Uri` (assert host/path/query); venue shows both/one; parking unchanged. `./scripts/check.sh && git commit -m "feat(map): M4 T9 — augment wiring + keyless external-Maps fallback (launcher seam)"`

---

### Task 10: Verification & closeout

> **CLOSEOUT RECORD (2026-08-16).** T0–T9 + T8A executed on `feature/map-M4-google-nav`, 11 exit-gated commits (T0 `919c43d` · T1 `12b4bb5` · T2 `f233c14` · T3 `f4edee0` · T4 `c30cf2f` · T8 l10n `db25c53` · T5 `6d9c0c6` · T6 `dbc515a` · T7 `fc6b13b` · T8A `4f48b79` · T9 `a9aa488`). Resolved deps: **google_maps_flutter 2.18.0** (android 2.19.12 / ios 2.18.4 / web 0.6.3), http 1.6.0, url_launcher 6.3.2. iOS deployment target bumped **13.0 → 14.0** (google_maps_flutter_ios requirement, surfaced by pod install). Two deviations from plan order, both sound: **T8 (l10n) pulled before the UI tasks** (every UI task consumes the strings and each commit must compile); **maps_url + external_maps_launcher pulled into T7** (T7's success/error panels need them; T9 only wires them into the sheets). **CODE-COMPLETE, on-device BLOCKED on the user's 4 GCP keys.**

- [x] **check.sh full** — all gates green **with no secrets present** (no-key web/apk/iOS builds all executed, T0 Step 4). *(Verified at closeout.)*
- [ ] **On-device WITH real keys, BOTH platforms** (#38): provision the 4 GCP keys (restricted), put SDK keys in `secrets.properties`/`Secrets.xcconfig`, and build **WITH THE FEATURE FLAG ON (#26)** — the native-configured flag is required or `googleNavEnabled` stays false and NO CTA appears:
  ```bash
  # Android
  flutter run --dart-define=MAPS_NATIVE_CONFIGURED=true --dart-define=GOOGLE_MAPS_ANDROID_ROUTES_KEY=…
  # iOS
  flutter run --dart-define=MAPS_NATIVE_CONFIGURED=true --dart-define=GOOGLE_MAPS_IOS_ROUTES_KEY=…
  ```
  Verify: consent dialog → live location → walking polyline + ETA + **walking-warning text visible (#13)** to a **building** and a **venue**; "Open in Google Maps" handoff; airplane-mode → AON error panel (not blank Google view); Settings revoke (T8A) → next nav re-asks. iOS **and** Android (credential paths differ; Android sends both identity headers — T3).
- [ ] **🔴 Restriction-rejection proof (#27):** don't just read the Console restrictions — prove they bite. Confirm a request with the CORRECT identity is accepted and one with a WRONG identity is REJECTED: wrong `X-Android-Package`/`X-Android-Cert` → rejected; wrong `X-Ios-Bundle-Identifier` → rejected; correct → accepted. (Google explicitly recommends verifying incorrect identifiers are rejected.)
- [ ] **🔴 Pre-live gate (#4):** confirm all four keys are GCP-restricted (app + API). ToS notices present in Settings/Info (T8A/#24). Record in closeout.
- [x] Re-score design §12 → see design **§12b** (closeout re-score: Additive 9, A11y 9, Credential 8, Privacy 8 — the two 8s held pending on-device proofs). `superpowers:finishing-a-development-branch` → present merge/PR/keep for `feature/map-M4-google-nav`.

---

## Self-Review

**Coverage (§0b → tasks):** A credentials → T0 (4-key native config, no-key-safe) + T3 (**header MAP** + `routesClientIdentity` incl. Android package+cert) + T10 (restriction-rejection proof); B flag → T1 (both surfaces, injectable, **active-platform** routes key) + T0 no-key builds; C API → T2 decoder + T3 typed RouteResult/fractional duration/request-contract/strict-malformed/**warnings**; D screen → T6 EmbeddedMap (explicit origin, pure bounds, local surface seam) + T7 (ordered guard, camera-fit-all-points, snapshot, offline error panel, **walking warning**); E privacy → T5 consent machine (**declined defined**) + T7 enumerated deep-link guard + before-location sequence + **T8A Settings revoke/notice**; F fallbacks → T9 keyless external URL via launcher seam (curated is parking→venue only, Point-Me needs location — both verified); G billing → T4 autoDispose one-in-flight (keep-alive test); H housekeeping (3 deps, web re-gate) → T0/T8.

**Gauntlet-3 gaps now closed (external review, verified):** Android's two security headers (#8) + their source (#9), request-contract test (#10), mandatory walking warning (#13/#22, Google-verified), Settings revoke UI that T10 assumed but no task built (#17), and the with-key run command that forgot the native flag (#26). The earlier "No silent gap" claim was **false** without T8A/T3-identity — removed.

**Known limitation (stated):** live on-device verification (T10) is BLOCKED on the user's 4 GCP keys. Everything T0–T9+T8A builds/tests/merges without them (`googleNavEnabled` false → dark), **including the Android package+cert identity mechanism (T3) — it's implemented and unit-tested with fakes, so obtaining the keys is the ONLY remaining blocker**, not an unbuilt mechanism. This is by design, not a gap.

**Placeholder scan:** pure/testable cores (T1–T5) carry complete code + tests; native-config (T0), the T3 Android-cert MethodChannel, and UI (T6/T7/T8A) are concrete engineering steps against defined interfaces + the in-repo M2/M3 harness — not literal copy-paste, and honestly labelled as such.

**Type consistency:** `RoutesService` interface (T3) implemented by `GoogleRoutesService`, consumed by T4 (`routesServiceProvider`) + faked in T4/T7; `RouteResult` sealed classes (T3) consumed by T4/T7; `(double,double)` coord tuples through T2/T3/T4/T6; `googleNavEnabledProvider` (T1) gates T7/T9; `MapsConsent` (T5) gates T7 + revoked in T8A; `NavRoute` fields incl. `warnings` (T3) shown by T7.
