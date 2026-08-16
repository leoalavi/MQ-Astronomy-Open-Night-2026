# M4 — Embedded Google Maps navigation (design)

**Status:** design, pre-gauntlet. Phase M4 of the map-parity program. On `feature/map-M4-google-nav` off `main` (post M0–M3).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` — M4 row + §P0 (Google Routes must NOT render on the CrsSimple illustrated map). This spec **discharges that P0 by not touching the illustrated map at all**: navigation renders on a *real embedded Google map* (Google route on Google's own tiles = ToS-compliant).

## 0. Gauntlet amendment — AUTHORITATIVE (self-gauntlet; supersedes the body where it conflicts)

Verified against the repo + installed patterns. Where this conflicts with §§2–11, this wins.

1. **THREE new dependencies, not one (§10 corrected).** None of `google_maps_flutter`, `http`, `url_launcher` are in `pubspec.yaml`. M4 needs: **`google_maps_flutter`** (embed), **`http`** (the Routes API call — package:http's `Client` is the clean injectable for TDD; a fake `Client` in tests), **`url_launcher`** (the "Open in Google Maps app" deep link — droppable if we cut that handoff). Honest count: **3**. The program's "no new dependency" rule never applied to M4 (it *is* the routing subsystem), but state it as 3.

2. **The SDK key is NATIVE — reuse AON's existing secrets scaffolding.** `google_maps_flutter`'s map key CANNOT come from `--dart-define`; it is set natively: Android `AndroidManifest.xml` `<meta-data android:name="com.google.android.geo.API_KEY" .../>` via a `manifestPlaceholder` sourced from **`android/secrets.properties`** (already git-ignored, `.gitignore:69`), and iOS `GMSServices.provideAPIKey(...)` in `AppDelegate.swift` sourced from **`ios/Flutter/Secrets.xcconfig`** (already git-ignored, `.gitignore:70`). MQ never did this (it never embedded a Google map — no native key in its repo), so there is no MQ pattern to copy; the AON secrets files are the mechanism. The **Dart-side Routes API** key is separate: `--dart-define=GOOGLE_MAPS_API_KEY` (`String.fromEnvironment`), same value, different delivery. `mapsNavEnabledProvider` keys off the dart-define value being non-empty.

3. **Feature flag must be web-SAFE (§4 corrected).** `dart:io Platform.isAndroid` throws `UnsupportedError` on web — AON already guards every `Platform.is*` with `kIsWeb` (`location_service.dart:24,33`). Use `flutter/foundation`: `mapsNavEnabledProvider = apiKey.isNotEmpty && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)` — **no `dart:io`**.

4. **🔴 Web-build gate is gauntlet-critical (Task 0).** Adding `google_maps_flutter` pulls the endorsed `google_maps_flutter_web` federated impl, which at runtime wants a `<script>` Maps-JS tag in `web/index.html`. The `check.sh full` **web build is a hard gate** — Task 0 MUST add the dep and immediately run `flutter build web` to confirm it stays green (compile-time should be fine; the JS lib is a runtime concern, and our feature is flag-gated off web). If the web build breaks, mitigate (omit the script tag / `dependency_overrides` / confirm the web impl compiles without a key) BEFORE building any feature on top. Do not assume it's green.

5. **Routes API response quirks (§5).** `computeRoutes` returns `routes[].duration` as a **string with a trailing `s`** (e.g. `"351s"`) — parse `int.parse(d.replaceAll('s','')) ` → `Duration(seconds:)`. `distanceMeters` is an int. `polyline.encodedPolyline` is Google's encoded format → the ported `decodePolyline`. Request body nests coords as `origin.location.latLng.{latitude,longitude}`. Field mask header is required or the response is empty.

## 0. Decisions (user, 2026-08-16)

1. **Approach: embedded Google Map** (`google_maps_flutter`) in-app — not an in-app browser, not a non-Google provider. Dissolves the P0.
2. **Augment, not replace.** AON's existing `WayfindingScreen` is a *deliberate* design (parking→venue, organiser-authored curated routes, written-instructions-primary, **no GPS**, offline — because ±20 m GPS between buildings is worse than useless and curated routes encode lit paths / open gates / marshals). M4 **keeps that primary** and adds Google nav as an *option*, chiefly for the M3 registry buildings (which have no curated route) and as a live alternative for venues.
3. **Walking route line (parity).** Fetch a walking route and draw the polyline + distance/ETA on the embedded map (not pins-only).

## 0b. External-review amendment — AUTHORITATIVE (supersedes §0 + body where they conflict)

An expert, Google-primary-source review found 40 issues (~12 blockers). Verified the repo-level ones directly; adopted **all 40**. The architecture survives (embedded Google map, augment, walking route); the credential/error/privacy/fallback models are hardened. **This section wins over §0 and §§2–13.** The dragon: *native Maps SDK auth and Routes REST auth look alike ("a Google API key") but are different security surfaces.*

### A. Credentials — separate restricted keys, extractable-key posture (findings #1–4, #38)
- **My "same key, different delivery" model was wrong.** A single key cannot be application-restricted for Android *and* iOS *and* web-service traffic. Secure model = **FOUR credentials**, each restricted in GCP:
  - **Android Maps SDK key** — restricted to the Android package + SHA-1, Maps SDK for Android only (native `AndroidManifest` meta-data, from `android/secrets.properties`).
  - **iOS Maps SDK key** — restricted to the iOS bundle id, Maps SDK for iOS only (native `GMSServices.provideAPIKey`, from `ios/Flutter/Secrets.xcconfig`).
  - **Android Routes key** — restricted to Android + Routes API; the Dart HTTP call sends `X-Android-Package` + `X-Android-Cert` headers.
  - **iOS Routes key** — restricted to iOS + Routes API; the call sends `X-Ios-Bundle-Identifier`.
- **Security posture (reframed):** an API key compiled into a client **is extractable** — `--dart-define`/native config is *configuration, not secrecy*. **Restrictions ARE the security boundary**, not "the key isn't committed."
- **Proxy vs direct:** DECISION — **direct-client with the restriction headers above** (AON has no backend; a Supabase-style proxy for a one-night event isn't worth standing up/maintaining). The proxy alternative (2 native SDK keys in-app + a server credential) is noted but declined. The §2 reasoning "no proxy needed because the SDK key is already client-side" is **deleted** — it conflated the two security surfaces.
- **Key restriction is a PRE-LIVE CLOSEOUT GATE, not an IOU** — an unrestricted billed key is direct abuse/billing exposure (developer is financially liable). Closeout verifies all four keys are restricted, on **both** platforms (their credential paths differ).

### B. Capability flag — both surfaces, injectable (findings #5, #6, #10, #31)
- The flag must not be "Routes key present ∧ mobile" — that shows the CTA while the **native Maps SDK** may be unconfigured (iOS needs `GMSServices.provideAPIKey` before any Maps object). Model TWO capabilities:
  ```
  embeddedMapConfigured  — native SDK key present (a compile/build-time contract surfaced to Dart)
  routesConfigured       — Routes Dart key present
  googleNavEnabled       — embeddedMapConfigured ∧ routesConfigured ∧ !kIsWeb ∧ mobile
  ```
- **Injectable platform:** `mapsNavPlatformProvider → enum {unsupported, android, ios}` (overridable in tests), instead of reading `defaultTargetPlatform` globally.
- **No-key builds must be provably safe (#6, #32):** Android manifest placeholder + iOS config must tolerate the secret files being **absent**; `AppDelegate` calls `provideAPIKey` only when non-empty. Task 0 gates `flutter build web|apk|ios` **with no secrets present** — "ships dark" becomes executable, not prose.

### C. Routes API correctness — typed outcome + fractional duration (findings #11, #14–17)
- **🔴 duration parse bug:** Routes `duration` is a protobuf Duration string with **up to 9 fractional digits** (e.g. `"3.5s"`, `"0.125s"`) — my `int.parse(d.replaceAll('s',''))` crashes. Use `Duration(milliseconds: (double.parse(v.substring(0, v.length-1)) * 1000).round())`. Test `"351s"`, `"3.5s"`, `"0.125s"`.
- **Headers:** add `Content-Type: application/json` (plus `X-Goog-Api-Key`, `X-Goog-FieldMask`, and the platform-restriction header from §A). Field mask + coord nesting from §5 are **confirmed correct** by the review.
- **🔴 `NavRoute?` cannot express the promised states.** Replace with a typed **`sealed class RouteResult { RouteSuccess(NavRoute) | RouteNoRoute | RouteNetworkFailure | RouteApiFailure(int status) | RouteMalformed }`**. Auth/quota (401/403/429) → `RouteApiFailure` (an operational incident, NOT "no pedestrian route"), with the status/body logged safely (never the key). 200-with-zero-routes → `RouteNoRoute`. Add malformed-parse tests (missing duration, fractional duration, missing/invalid polyline, wrong distance type, invalid JSON).

### D. Nav screen (findings #18–20, #28, #30)
- **Camera fit** must include **every decoded polyline point** (a walking route bends well outside the origin→dest box) + bottom padding for the panel.
- **Attribution:** Google's required attribution must stay visible (ToS) — the panel uses explicit map padding so it never covers route content or Google's attribution.
- **Contract = SNAPSHOT route** (name it): one route computed from the origin at open; the native blue dot keeps moving but the route does **not** auto-recalculate — "Retry" re-fetches. (No live rerouting; matches the "not turn-by-turn" scope + billing.)
- **Offline is NOT "Google map with pins"** — Google tiles are network-backed, so an outage yields a blank platform view. Failure → a **standalone AON error panel** (Retry + fallbacks), not a reliance on Google tiles.
- **🔴 Widget-test map seam:** do not assume `google_maps_flutter` auto-stubs. Abstract the map behind a thin `EmbeddedMap` widget seam (or inject a fake `GoogleMapsFlutterPlatform`) so `GoogleNavScreen` states are testable without a real platform view.

### E. Privacy — sequence, consent state machine, self-guarding (findings #21–24)
- **🔴 Deep-link/router guard:** UI CTAs are flag-gated, but `Routes.googleNav(placeKey)` can be entered directly. `GoogleNavScreen`/router MUST independently enforce: `googleNavEnabled? ∧ consent==accepted ∧ destination resolvable` — never rely on hiding a button.
- **🔴 Consent BEFORE location:** strict sequence — `tap → consent (or stored accepted) → THEN obtain location → THEN instantiate Google map / send Routes request`. (Google terms require prior, express, revocable consent for end-user location use.)
- **🔴 Consent state machine:** `MapsConsent { unknown, accepted, declined }` persisted (passport idiom); Settings gets a **"Revoke Google Maps location consent"** control. Not `dialogShown=true`.
- **ToS notices (#24):** Settings/Info must state Google Maps is included and reference Google's terms/privacy — a **closeout checklist** item, not "one dialog covers it."

### F. Fallbacks — corrected (findings #25, #26, #29, #37, #28)
- **🔴 BuildingSheet no-key fallback was invalid** — `WalkingRoute`s are curated **parking→venue** (verified: `wayfinding_screen.dart` → `WalkingRoute fromLabel→toLabel` + `EmptyState`), so pushing a building id shows an empty screen. Corrected no-key building path = **external Google Maps URL** (`/maps/dir/?api=1&destination=…&travelmode=walking` — **no API key required**, opens the Maps app or browser). This also gives *graceful degradation*: even with zero credentials, buildings get useful directions.
- **Point-Me is NOT a no-permission fallback** (verified: it imports `locationControllerProvider`, gates on `locationReliable`). No-permission/offline fallback = the **curated GPS-free `WayfindingScreen`** (for venues) or the **external Maps URL** (for buildings, which Maps resolves without an app-supplied origin).
- **Rename** "Open in Google Maps app" → **"Open in Google Maps"** (may open a browser). Consider `dir_action=navigate` for a nav handoff.

### G. Billing rule now, not IOU (finding #36)
`navRouteProvider` is a `.family.autoDispose`; **one in-flight request per (origin≈,destination)**; retry only on explicit user action; no re-fetch on rebuild/reopen within a session. A UI lifecycle bug must not become a billing feature.

### H. Housekeeping (findings #33, #34, #35)
- Delete the superseded §4 body text (`local.properties`/"same env") — §A is authoritative.
- Reconcile §10: **three** new deps (§0.1), not one.
- Task 0 re-runs `flutter build web` **again** after `GoogleNavScreen`+router imports exist (tests the real transitive graph, not just the bare dep).

### I. Re-score (findings #39, #40) — honest pre-build
Credential safety **7→4** (unrestricted extractable single-key model was the flaw; →9 after §A's separate restricted keys). Privacy **7→6** (consent state machine + ToS notices not yet built; →9 after §E). Testing **6→**stays until §D's map seam + §B's build gates land.

## 1. Goal

A "Navigate with Google Maps" experience embedded in the app: a real Google map showing the attendee's live location, the destination, and the **walking route** to it — for any M3 building or event venue. Renders Google data on Google's map (compliant), leaves the curated parking→venue wayfinding untouched, and **ships dark until a Google Maps API key is supplied**.

## 2. Scope

**In:**
- Add `google_maps_flutter`; a `--dart-define=GOOGLE_MAPS_API_KEY` credential slot + platform config; a `mapsNavEnabledProvider` feature flag (key present ∧ mobile) that gates every entry point.
- `GoogleRoutesService.walkingRoute({origin, destination})` — Routes API `computeRoutes` (WALK) over an injected `http.Client` → `NavRoute {polyline, distanceMeters, eta}`, pure polyline decode.
- `GoogleNavScreen` — embedded `GoogleMap` with user location + destination marker + route polyline + a distance/ETA panel + "Open in Google Maps app" handoff; loading / no-network / no-permission / no-route states.
- Wiring (augment): BuildingSheet "Walking directions" → GoogleNavScreen; VenueSheet adds "Navigate with Google Maps" alongside the curated CTA. Both gated by the flag.
- First-use **privacy disclosure** before the first Google nav.
- EN + FA; 320×568 / 2.0 for the panel; TDD; `./scripts/check.sh` gate (web build stays green).

**Out (logged):**
- **Replacing** the curated `WayfindingScreen` / any parking→venue or venue Directions default (stays curated).
- **Turn-by-turn voice/step guidance** in-app — the "Open in Google Maps app" deep link is the turn-by-turn handoff; AON does not reimplement navigation UI.
- **Web** Google nav — mobile-only (iOS/Android). Web BUILD must stay green (the entry points are flag-gated off on web); the web runtime already black-screens (pre-existing).
- **Driving/transit modes** — walking only (campus scale).
- **A Supabase/edge-function proxy** — unneeded: the key is already app-side for the embedded SDK, so the Directions call is client-side with the same restricted key. (MQ proxied because it never embedded a Google map; we do.)

## 3. Architecture

```
GOOGLE_MAPS_API_KEY (--dart-define, platform config)   geolocator (origin)
        │                                                    │
mapsNavEnabledProvider (key≠'' ∧ mobile)                     │
        │ gates                                              ▼
BuildingSheet / VenueSheet  ──"Navigate with Google Maps"──► GoogleNavScreen(destinationKey)
                                                             │  resolve dest (M3 placeResolver → routing coords)
                                                             ▼
                                       GoogleRoutesService.walkingRoute(origin,dest)
                                            │ Routes API computeRoutes (WALK), injected http.Client
                                            ▼
                                       NavRoute {polyline, distanceMeters, eta}
                                            ▼
                              GoogleMap( myLocation + dest marker + Polyline ) + panel(distance/ETA) + "Open in Google Maps"
```

**Files (create):**
- `lib/services/google_routes_service.dart` — the route fetch + `NavRoute` + polyline decoder.
- `lib/services/maps_nav_providers.dart` — `mapsNavEnabledProvider`, `googleMapsApiKeyProvider`, `googleRoutesServiceProvider`, a `navRouteProvider` family.
- `lib/screens/google_nav_screen.dart` — the embedded map screen.
- `lib/widgets/maps_nav_disclosure.dart` — first-use privacy consent.
- mirrored tests.

**Files (modify):** `pubspec.yaml` (dep + no new asset), `lib/app/router/app_router.dart` (a `googleNav` route), `lib/widgets/building_sheet.dart` + `map_screen.dart`'s `VenueSheet` (the CTAs), `lib/l10n/app_en.arb` + `app_fa.arb`, platform config (`android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift` or `Info.plist`), `lib/config/*` (feature flag surface).

## 4. Credential safety + feature flag

- **Key delivery:** `--dart-define=GOOGLE_MAPS_API_KEY=…` at build. `googleMapsApiKeyProvider` reads `String.fromEnvironment('GOOGLE_MAPS_API_KEY')` (default `''`). The SDK's platform key: Android via a `manifestPlaceholders` / a `local.properties`-sourced meta-data value; iOS via a build-setting/plist entry sourced from the same env — **the key is NOT committed** (platform files reference a variable, not a literal; document the build command).
- **Feature flag:** `mapsNavEnabledProvider = googleMapsApiKeyProvider != '' ∧ (Platform.isAndroid || Platform.isIOS)`. Every Google-nav CTA is wrapped in `if (ref.watch(mapsNavEnabledProvider))`. **No key → the option never appears; the app is fully functional without it.**
- **Restriction (release IOU):** the key must be restricted by bundle id / package + SHA and to the Maps SDK + Routes API only — a release checklist item, not enforceable in code.

## 5. Route service

`GoogleRoutesService({required http.Client client, required String apiKey})`:
- `Future<NavRoute?> walkingRoute({required LatLng origin, required LatLng destination})` — POST `https://routes.googleapis.com/directions/v2:computeRoutes` with `X-Goog-Api-Key` + `X-Goog-FieldMask: routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration`, body `{origin, destination, travelMode: WALK}`. Parses the first route → `NavRoute`. Any non-200 / network error / empty routes → returns `null` (caller shows the no-route/offline state). Never throws to the UI.
- `NavRoute { List<LatLng> polyline; int distanceMeters; Duration eta; }`.
- **Polyline decode:** pure `List<LatLng> decodePolyline(String encoded)` (standard Google algorithm, ported/unit-tested against known vectors) — no new dependency.
- The service is pure/injectable: tests use a fake `http.Client` returning canned JSON; **no real network in tests.**

## 6. Nav screen

`GoogleNavScreen(String destinationKey)` (`ConsumerStatefulWidget`):
- Resolves the destination via `placeResolverProvider(destinationKey)` → routing coords (`routingLat/Lng`, entrance-aware; §0b.E). Unresolvable/no-coords → an error state (never a blank map).
- Origin: `geolocator` current position (reuses AON's location service). No permission / no fix → a state offering the curated wayfinding / Point-Me instead.
- Fetches `navRouteProvider((origin,dest))` → `NavRoute?`. Success → `GoogleMap` with `myLocationEnabled`, a destination `Marker`, a `Polyline(navRoute.polyline)`, camera fit to both; a bottom panel shows distance + ETA and an **"Open in Google Maps app"** button (`url_launcher` `https://www.google.com/maps/dir/?api=1&…&travelmode=walking` — the sanctioned deep link). Failure → no-network state (retry + Point-Me fallback).
- `context.aon` chrome around the map; the map itself is Google's.

## 7. Wiring (augment)

- **BuildingSheet** (M3): its "Walking directions" CTA → `context.push(Routes.googleNav(buildingKey))` **when `mapsNavEnabledProvider`**, else keep the current push to the existing wayfinding entry (unchanged) — so buildings still do *something* without the key.
- **VenueSheet** (map_screen): keep the curated "Walking directions" CTA; **add** a second "Navigate with Google Maps" CTA, shown only when the flag is on.
- **Parking sheets + `WayfindingScreen` + the wayfinding FAB: untouched.**
- Deep link `Routes.googleNav(placeKey)` added to `app_router.dart`.

## 8. Privacy

Google nav opts into location *and* sends it to Google — a boundary the rest of AON deliberately avoids. **First-use disclosure** (`MapsNavDisclosure`): before the first Google nav, a one-time dialog explaining that this opens Google Maps in-app and shares the current location with Google; proceed/cancel; the choice is remembered (`shared_preferences`, passport idiom). A short note also appears in Settings/Info. The curated wayfinding remains GPS-free.

## 9. Fallbacks (explicit)

| Condition | Behaviour |
|---|---|
| No key (`mapsNavEnabledProvider` false) | Google-nav CTAs absent; curated wayfinding / Point-Me unaffected |
| No network / Routes API error | Map shows pins (origin+dest) + "route unavailable" + retry + a Point-Me / curated-wayfinding link |
| No location permission / no fix | State offering Point-Me (offline) or curated wayfinding; no blank map |
| Destination off the calibrated footprint but has GPS | Still routable (Google uses real GPS, not the CrsSimple domain) |
| Web | Entry points flag-gated off; web BUILD green |

## 10. Global constraints

- **New dependency `google_maps_flutter`** (expected — the routing subsystem). No new asset. **Web build stays a hard gate** — verify the web impl compiles and the feature is gated off web.
- **EN + FA** for every new string (CTA, disclosure, panel labels, states) — `check.sh` l10n gate.
- **`context.aon`** for chrome; the embedded map is Google's own surface.
- **320×568 / 2.0** for the nav panel + disclosure.
- **TDD; never weaken a test.** Full suite green; live map render + real route are gated on the key + on-device (a `--dart-define` build), not in the CI gate.

## 11. Testing

- **Route service (pure):** fake `http.Client` → canned `computeRoutes` JSON → correct `NavRoute` (polyline points, distance, eta); non-200 → null; empty routes → null; network throw → null (never throws out). `decodePolyline` against known vectors.
- **Feature flag:** key `''` → `mapsNavEnabledProvider` false; non-empty + mobile → true; web/desktop → false.
- **Wiring:** with the flag ON, BuildingSheet "Walking directions" pushes `Routes.googleNav('building:…')`; VenueSheet shows BOTH CTAs; with flag OFF, the Google CTA is absent and the curated CTA still works. Parking/wayfinding CTAs unchanged (regression).
- **Nav screen (widget, no real map):** `google_maps_flutter` renders a stub platform view in tests — assert the screen builds with a fake route service (loading → route panel with distance/ETA; no-route → offline state; no-permission → fallback state), destination resolves via placeResolver. Do NOT assert real tiles.
- **Disclosure:** first-use dialog shows once, choice persists (fake store); EN + FA; 320×568/2.0.
- **Verification:** `check.sh full` (incl. web build gated-off); **on-device with a real key** (`flutter run --dart-define=GOOGLE_MAPS_API_KEY=…`): real Google map, live location, walking polyline + ETA to a building and a venue; the "Open in Google Maps app" handoff; no-network fallback.

## 12. Scorecard (M4, pre-build)

| Axis | Score | Raises it |
|---|---:|---|
| Parity coverage | 6/10 | Embedded Google walking nav closes routing; AR (M5) remains. |
| ToS / correctness | 9/10 | Google route on Google's own map — the P0 dissolved, not worked around. |
| Additive safety | 8/10 | Augments (curated wayfinding untouched); every entry flag-gated; ships dark without a key. |
| Credential safety | **4/10** (→9 after §0b.A) | Original single-extractable-key model was the flaw (review #1–4). §0b.A: FOUR separate GCP-restricted keys (Android/iOS × SDK/Routes) + restriction headers; restriction is a PRE-LIVE gate, not IOU. |
| Privacy | **6/10** (→9 after §0b.E) | GPS-free curated path preserved; but consent state machine (accepted/declined/revoked) + before-location sequencing + deep-link self-guard + ToS notices are §0b.E work, not yet built. |
| A11y / 2.0 / FA | 8/10 | Panel/disclosure labelled + 2.0 + EN/FA (the Google map itself is Google's a11y). |

## 13. Open questions / IOUs

1. **Key restriction** (bundle id/SHA + API scoping) — release checklist IOU.
2. **Directions API billing** — each route is a billed `computeRoutes` call; note expected event volume; cache a route for a (origin≈,dest) within a session to limit calls (IOU if needed).
3. **Physical-device verification** — simulator can't fully exercise the embedded Google map + live GPS; a physical iOS + Android run with a real key is the closeout gate (release IOU alongside M2/M3's).
4. **`buildings.json` / MQ artwork redistribution permission** — inherited program IOU, unaffected by M4.

## 14. Next step

On approval → **gauntlet this design** (verify `google_maps_flutter` current API + Routes API shape + geolocator/url_launcher against installed/pinned versions), then the M4 TDD plan (dep+key+flag → route service+decoder → nav providers → nav screen → disclosure → wiring → l10n → verification incl. on-device with key). No code before the plan is gauntletted. Everything is buildable/mergeable **without** the key; only the live on-device render waits for it.
