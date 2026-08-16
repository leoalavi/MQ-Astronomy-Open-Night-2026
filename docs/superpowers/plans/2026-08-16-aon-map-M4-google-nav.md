# M4 — Embedded Google Maps Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** An embedded Google map showing the attendee's location, a destination, and the **walking route** to it — for M3 buildings and event venues — rendering Google data on Google's own map (ToS-clean), augmenting (not replacing) the curated wayfinding, and shipping **dark until API keys are supplied**.

**Architecture:** A capability flag (`googleNavEnabled` = native-map-configured ∧ Routes-key ∧ mobile) gates every entry point. A pure `GoogleRoutesService` returns a typed `RouteResult`; `GoogleNavScreen` sequences consent → location → route → embedded map (behind an `EmbeddedMap` seam so it's testable). Credentials are **four separate GCP-restricted keys**; the key is assumed extractable and restrictions are the security boundary.

**Tech Stack:** Flutter 3.44 · **new deps: `google_maps_flutter`, `http`, `url_launcher`** · Riverpod 3 · `geolocator` (existing) · `shared_preferences` (existing).

**Design:** `docs/superpowers/specs/2026-08-16-aon-map-M4-google-nav-design.md` — **read §0b (external-review amendment) then §0; both authoritative, supersede the body.**

## Global Constraints

- **Ships dark without keys.** No secret → `googleNavEnabled` false → no Google-nav CTA; the app builds and runs fully. No-key `build web|apk|ios` are gates (Task 0/Task 10).
- **Four restricted credentials** (design §0b.A): Android/iOS × {Maps SDK key, Routes key}. Native SDK keys via `android/secrets.properties` + `ios/Flutter/Secrets.xcconfig` (already git-ignored). Routes keys via `--dart-define`. **Key is extractable → restrictions ARE the boundary.** Restriction of all four = a **pre-live closeout gate**, not an IOU.
- **Typed errors:** `RouteResult` sealed — network / no-route / api-error(status) / malformed distinct. Auth/quota ≠ "no route".
- **Consent before location** (design §0b.E): `tap → consent → location → map/route`. Router + screen self-guard deep links. Consent state `{unknown, accepted, declined}` + Settings revoke.
- **Augment:** BuildingSheet + VenueSheet gain Google-nav (flag-gated); **parking sheets + `WayfindingScreen` + wayfinding FAB untouched.** No-key building fallback = keyless external Maps URL.
- **New deps expected; web build stays a hard gate; EN+FA every string; `context.aon` chrome (map is Google's); 320×568/2.0; TDD; `./scripts/check.sh` EXIT-gated before every commit** (`check.sh && git commit`, never `check.sh | tail && commit`).

---

### Task 0: Deps + no-key build safety + web gate (🔴 gauntlet-critical, do first)

**Files:** `pubspec.yaml`; `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle(.kts)`; `ios/Runner/AppDelegate.swift`, `ios/Flutter/Secrets.xcconfig` (sample) + `Info.plist`; `android/secrets.properties.sample`.

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
Expected: GREEN. `google_maps_flutter_web` is pulled transitively; the web build must still compile (the Maps-JS `<script>` is a runtime concern, and the feature is gated off web). If it FAILS: stop and mitigate (confirm the web impl compiles without a key; add the `<script>` guarded, or `dependency_overrides`) before proceeding.

- [ ] **Step 3: Native SDK key config that tolerates MISSING secrets**
- Android: `build.gradle` loads `android/secrets.properties` **if present** (else empty), exposes `MAPS_API_KEY` as a `manifestPlaceholder` defaulting to `""`; `AndroidManifest.xml` adds
  `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}"/>`.
- iOS: `AppDelegate.swift` reads the key from `Bundle.main` (an `Info.plist` entry substituted from `Secrets.xcconfig` build setting) and calls `GMSServices.provideAPIKey(key)` **only if non-empty**; a missing `Secrets.xcconfig` must not break the build (`#include?` optional include).
- Add `android/secrets.properties.sample` + document the build command with `--dart-define=GOOGLE_MAPS_ANDROID_ROUTES_KEY=…`/`…IOS…`. Real secrets stay git-ignored.

- [ ] **Step 4: No-key build gate + commit**
```bash
# with NO android/secrets.properties and NO ios/Flutter/Secrets.xcconfig present:
flutter build web && flutter build apk --debug   # iOS build if on macOS/Xcode
```
Expected: all GREEN ("ships dark" is now executable, #6/#32).
```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && git add pubspec.yaml pubspec.lock android/ ios/ && git commit -m "feat(map): M4 T0 — google_maps_flutter/http/url_launcher + no-key-safe native config + web gate" || { echo GATE FAILED; tail /tmp/gate.log; }
```

---

### Task 1: Capability providers (injectable platform, both surfaces)

**Files:** Create `lib/services/maps_nav_providers.dart`; Test `test/unit/maps_nav_capability_test.dart`.

**Interfaces:**
- `enum MapsNavPlatform { unsupported, android, ios }`; `mapsNavPlatformProvider` (default from `kIsWeb`/`defaultTargetPlatform`, overridable in tests).
- `androidRoutesKeyProvider`/`iosRoutesKeyProvider` (`String.fromEnvironment`), `routesConfiguredProvider`, `embeddedMapConfiguredProvider` (a `bool.fromEnvironment('MAPS_NATIVE_CONFIGURED')` build flag set by the native config, or a const surfaced from Task 0), `googleNavEnabledProvider`.

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

void main() {
  test('enabled only when native map AND routes AND mobile', () {
    expect(_c(platform: MapsNavPlatform.android, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.android, routes: false, nativeMap: true).read(googleNavEnabledProvider), isFalse); // no routes key
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: false).read(googleNavEnabledProvider), isFalse); // native map missing → the #5 trap
    expect(_c(platform: MapsNavPlatform.unsupported, routes: true, nativeMap: true).read(googleNavEnabledProvider), isFalse); // web/desktop
  });
}
```
- [ ] **Step 2–4:** Run → fail; implement (the base `googleNavEnabledProvider` = `routesConfigured ∧ embeddedMapConfigured ∧ platform != unsupported`; `mapsNavPlatformProvider` computed web-safe via `kIsWeb ? unsupported : switch(defaultTargetPlatform)`); run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T1 — capability flag (both surfaces, injectable platform)"`

---

### Task 2: Polyline decoder (pure)

**Files:** Create `lib/services/polyline_codec.dart`; Test `test/unit/polyline_codec_test.dart`.

**Interfaces:** `List<LatLng> decodePolyline(String encoded)` (Google's standard algorithm; `LatLng` from `google_maps_flutter` or a local pair — use `package:google_maps_flutter_platform_interface`'s `LatLng` to avoid latlong2 confusion, or return `(double,double)` tuples).

- [ ] **Step 1: Failing test with a known vector**
```dart
// test/unit/polyline_codec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/polyline_codec.dart';

void main() {
  test('decodes Google reference vector "_p~iF~ps|U_ulLnnqC_mqNvxq`@"', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].$1, closeTo(38.5, 1e-5));
    expect(pts[0].$2, closeTo(-120.2, 1e-5));
    expect(pts[2].$1, closeTo(43.252, 1e-3));
  });
  test('empty string → empty', () => expect(decodePolyline(''), isEmpty));
}
```
- [ ] **Step 2–4:** implement the standard decode (returns `List<(double lat, double lng)>`); run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T2 — pure polyline decoder"`

---

### Task 3: `RouteResult` + `GoogleRoutesService` (typed, fake http)

**Files:** Create `lib/services/google_routes_service.dart`; Test `test/unit/google_routes_service_test.dart`.

**Interfaces:**
- `class NavRoute { List<(double,double)> polyline; int distanceMeters; Duration eta; }`.
- `sealed class RouteResult` → `RouteSuccess(NavRoute)`, `RouteNoRoute`, `RouteNetworkFailure`, `RouteApiFailure(int status)`, `RouteMalformed`.
- `class GoogleRoutesService({required http.Client client, required String apiKey, required String platformHeaderName, required String platformHeaderValue})` with `Future<RouteResult> walkingRoute({required (double,double) origin, required (double,double) destination})`.

- [ ] **Step 1: Failing tests (fractional duration + error classification + malformed, #11/#15/#16/#17)**
```dart
// test/unit/google_routes_service_test.dart  (uses package:http/testing MockClient)
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:aon2026/services/google_routes_service.dart';

GoogleRoutesService _svc(http.Client c) => GoogleRoutesService(
    client: c, apiKey: 'k', platformHeaderName: 'X-Ios-Bundle-Identifier', platformHeaderValue: 'au.edu.mq.astronomy.aon2026');

http.Client _ok(String body) => MockClient((_) async => http.Response(body, 200));

void main() {
  test('success: fractional duration "3.5s" parses; distance + polyline', () async {
    final r = await _svc(_ok(jsonEncode({'routes':[{'distanceMeters':412,'duration':'3.5s','polyline':{'encodedPolyline':'_p~iF~ps|U'}}]}))).walkingRoute(origin: (-33.77,151.11), destination: (-33.78,151.12));
    expect(r, isA<RouteSuccess>());
    final nav = (r as RouteSuccess).route;
    expect(nav.distanceMeters, 412);
    expect(nav.eta, const Duration(milliseconds: 3500)); // NOT crash on "3.5s"
  });
  test('durations "351s" and "0.125s" parse', () async {
    for (final d in ['351s','0.125s']) {
      final r = await _svc(_ok(jsonEncode({'routes':[{'distanceMeters':1,'duration':d,'polyline':{'encodedPolyline':''}}]}))).walkingRoute(origin:(0,0),destination:(0,0));
      expect(r, isA<RouteSuccess>());
    }
  });
  test('200 + zero routes → RouteNoRoute', () async {
    final r = await _svc(_ok(jsonEncode({'routes':[]}))).walkingRoute(origin:(0,0),destination:(0,0));
    expect(r, isA<RouteNoRoute>());
  });
  test('401/403/429 → RouteApiFailure (NOT no-route)', () async {
    for (final s in [401,403,429]) {
      final r = await _svc(MockClient((_) async => http.Response('{"error":"x"}', s))).walkingRoute(origin:(0,0),destination:(0,0));
      expect(r, isA<RouteApiFailure>());
      expect((r as RouteApiFailure).status, s);
    }
  });
  test('network throw → RouteNetworkFailure (never throws out)', () async {
    final r = await _svc(MockClient((_) async => throw Exception('offline'))).walkingRoute(origin:(0,0),destination:(0,0));
    expect(r, isA<RouteNetworkFailure>());
  });
  test('malformed JSON / missing fields → RouteMalformed', () async {
    for (final b in ['not json', '{"routes":[{"duration":"5s"}]}' /* no distance/polyline */]) {
      final r = await _svc(_ok(b)).walkingRoute(origin:(0,0),destination:(0,0));
      expect(r, anyOf(isA<RouteMalformed>(), isA<RouteNoRoute>()));
    }
  });
}
```
- [ ] **Step 2–4:** implement. POST `https://routes.googleapis.com/directions/v2:computeRoutes`, headers `Content-Type: application/json`, `X-Goog-Api-Key`, `X-Goog-FieldMask: routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration`, `<platformHeaderName>: <value>`; body nests `origin.location.latLng.{latitude,longitude}` + `travelMode:'WALK'`. Classify: non-200 → `RouteApiFailure(status)`; catch → `RouteNetworkFailure`; empty routes → `RouteNoRoute`; parse failure → `RouteMalformed`. Duration: `Duration(milliseconds: (double.parse(v.substring(0,v.length-1))*1000).round())`. Log status/body safely (never the key). Run → pass.
- [ ] **Step 5:** `./scripts/check.sh && git commit -m "feat(map): M4 T3 — GoogleRoutesService typed RouteResult (fractional duration, error classes)"`

---

### Task 4: `navRouteProvider` (autoDispose family, billing rule #36)

**Files:** add to `lib/services/maps_nav_providers.dart`; Test add to capability test or a new one.
- `googleRoutesServiceProvider` builds the service from the platform's Routes key + header. `navRouteProvider = FutureProvider.autoDispose.family<RouteResult, ((double,double),(double,double))>` — one in-flight per (origin,dest); autoDispose so a closed screen frees it; retry = invalidate on user action only.
- [ ] Tests: same (origin,dest) read twice → the service's `walkingRoute` called once (inject a counting fake service); different args → separate calls. `./scripts/check.sh && git commit -m "feat(map): M4 T4 — navRouteProvider (autoDispose, one-in-flight billing rule)"`

---

### Task 5: Consent state machine + store + disclosure (#22,#23)

**Files:** Create `lib/services/maps_consent_store.dart` + `lib/services/maps_consent_providers.dart` + `lib/widgets/maps_nav_disclosure.dart`; Test mirrored. Modify `main.dart` (inject snapshot, passport idiom).

**Interfaces:** `enum MapsConsent { unknown, accepted, declined }`; `MapsConsentStore` (SharedPreferencesAsync, key `map_google_consent.v1`); `mapsConsentProvider` (Notifier, seeded from injected snapshot) with `accept()/decline()/revoke()`.

- [ ] Tests: default `unknown`; `accept` → `accepted` persists; `revoke` → `unknown`+persists; disclosure dialog shows once when `unknown`, not when `accepted`; EN+FA; 320×568/2.0. Implement (passport idiom + dispose guard as in M3 favorites). `./scripts/check.sh && git commit -m "feat(map): M4 T5 — Google-nav consent state machine + disclosure"`

---

### Task 6: `EmbeddedMap` seam (#30)

**Files:** Create `lib/widgets/embedded_map.dart`; Test `test/widget/embedded_map_test.dart`.
- `EmbeddedMap({required (double,double) destination, required List<(double,double)> route, ...})` wraps `GoogleMap` (markers + `Polyline` + camera fit to **all route points** + panel padding for attribution, #18/#19). A `@visibleForTesting` seam / a `GoogleMapsFlutterPlatform` fake lets widget tests build it without a real platform view. Tests assert the widget builds + camera bounds include route extremes (test the pure bounds helper directly, not the tiles).
- [ ] `./scripts/check.sh && git commit -m "feat(map): M4 T6 — EmbeddedMap seam (camera fits full route, testable)"`

---

### Task 7: `GoogleNavScreen` + router self-guard (#20,#21,#22,#28)

**Files:** Create `lib/screens/google_nav_screen.dart`; Modify `lib/app/router/app_router.dart` (add `Routes.googleNav(placeKey)` with a guard). Test `test/widget/google_nav_screen_test.dart`.
- Sequence (strict): guard (`googleNavEnabled ∧ consent==accepted ∧ dest resolvable`, else redirect/handoff) → resolve dest via `placeResolverProvider` (routing coords) → obtain location → `navRouteProvider` → states:
  - success → `EmbeddedMap` + panel (distance/ETA) + "Open in Google Maps" (url_launcher, #26) — **snapshot route** (#20).
  - `RouteNoRoute`/`RouteApiFailure`/`RouteNetworkFailure`/malformed → **standalone AON error panel** (Retry + curated/external fallback) — NOT a Google-tiles-dependent view (#28).
  - no permission / no fix → offer curated wayfinding (venues) / external Maps URL (buildings).
- [ ] Tests (fake service + `EmbeddedMap` seam, no real map): each state renders the right panel; a direct nav with consent!=accepted redirects to disclosure (deep-link guard #21); success shows distance/ETA. `./scripts/check.sh && git commit -m "feat(map): M4 T7 — GoogleNavScreen (guarded, typed states, snapshot route)"`

---

### Task 8: l10n (EN + FA)

**Files:** `lib/l10n/app_en.arb`+`app_fa.arb`.
- Keys: `mapNavGoogle` ("Navigate with Google Maps"), `mapNavOpenExternal` ("Open in Google Maps"), `mapNavDistance(m)`, `mapNavEta`, `mapNavNoRoute`, `mapNavOffline`, `mapNavError`, `mapNavNeedLocation`, disclosure title/body/accept/decline, `settingsRevokeGoogleConsent`, `settingsGoogleMapsNotice` (ToS notice #24). Real Persian.
- [ ] gen-l10n green; `./scripts/check.sh && git commit -m "feat(map): M4 T8 — EN+FA strings for Google nav + consent + ToS notice"`

---

### Task 9: Wiring (augment) + keyless fallback (#25)

**Files:** Modify `lib/widgets/building_sheet.dart`, `lib/screens/map_screen.dart` (`VenueSheet`), add a small `lib/services/maps_url.dart` (build the keyless `/maps/dir/?api=1…walking` URL). Test `test/widget/map_m4_wiring_test.dart`.
- **BuildingSheet:** `googleNavEnabled` → "Walking directions" pushes `Routes.googleNav('building:$id')`; **else → `mapNavOpenExternal` launching the keyless external Maps URL** (never the empty curated screen). VenueSheet: keep curated "Walking directions"; **add** "Navigate with Google Maps" when `googleNavEnabled`. Parking + `WayfindingScreen` + FAB untouched (regression test).
- [ ] Tests: flag ON → building CTA pushes googleNav; flag OFF → building CTA launches external URL (assert the url via a fake launcher); venue shows both/one; parking unchanged. `./scripts/check.sh && git commit -m "feat(map): M4 T9 — augment wiring + keyless external-Maps fallback"`

---

### Task 10: Verification & closeout

- [ ] **check.sh full** — all gates green **with no secrets present** (no-key web/apk/iOS builds).
- [ ] **On-device WITH real keys, BOTH platforms** (#38): provision the 4 GCP keys (restricted), put SDK keys in `secrets.properties`/`Secrets.xcconfig`, build `flutter run --dart-define=…ROUTES_KEY=…`. Verify: consent dialog → live location → walking polyline + ETA to a **building** and a **venue**; "Open in Google Maps" handoff; airplane-mode → AON error panel (not blank Google view); Settings revoke → next nav re-asks. iOS **and** Android (credential paths differ).
- [ ] **🔴 Pre-live gate (#4):** confirm all four keys are GCP-restricted (app + API). ToS notices present in Settings/Info (#24). Record in closeout.
- [ ] Re-score design §12; `superpowers:finishing-a-development-branch` → present merge/PR/keep for `feature/map-M4-google-nav`.

---

## Self-Review

**Coverage (§0b → tasks):** A credentials → T0 (4-key native config, no-key-safe) + T3 (platform header) + T10 (restriction gate); B flag → T1 (both surfaces, injectable) + T0 no-key builds; C API → T2 decoder + T3 typed RouteResult/fractional duration/Content-Type; D screen → T6 EmbeddedMap seam + T7 (camera-fit-all-points, snapshot, offline error panel); E privacy → T5 consent machine + T7 router/screen self-guard + before-location sequence; F fallbacks → T9 keyless external URL (curated is parking→venue only, Point-Me needs location — both verified) ; G billing → T4 autoDispose one-in-flight; H housekeeping (3 deps, web re-gate) → T0/T8. **No silent gap.**

**Known limitation (stated):** live on-device verification (T10) is BLOCKED on the user's 4 GCP keys — everything T0–T9 builds/tests/merges without them (`googleNavEnabled` false → dark). This is by design, not a gap.

**Placeholder scan:** pure/testable cores (T1–T5) carry complete code + tests; native-config (T0) and UI (T6/T7) are concrete engineering steps against defined interfaces + the in-repo M2/M3 harness — not literal copy-paste, and honestly labelled as such.

**Type consistency:** `RouteResult` sealed classes (T3) consumed by T4/T7; `(double,double)` coord tuples through T2/T3/T4/T6; `googleNavEnabledProvider` (T1) gates T7/T9; `MapsConsent` (T5) gates T7; `NavRoute` fields (T3) shown by T7.
