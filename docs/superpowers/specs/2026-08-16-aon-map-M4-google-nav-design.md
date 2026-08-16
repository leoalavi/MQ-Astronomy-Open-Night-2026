# M4 — Embedded Google Maps navigation (design)

**Status:** design, pre-gauntlet. Phase M4 of the map-parity program. On `feature/map-M4-google-nav` off `main` (post M0–M3).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` — M4 row + §P0 (Google Routes must NOT render on the CrsSimple illustrated map). This spec **discharges that P0 by not touching the illustrated map at all**: navigation renders on a *real embedded Google map* (Google route on Google's own tiles = ToS-compliant).

## 0. Decisions (user, 2026-08-16)

1. **Approach: embedded Google Map** (`google_maps_flutter`) in-app — not an in-app browser, not a non-Google provider. Dissolves the P0.
2. **Augment, not replace.** AON's existing `WayfindingScreen` is a *deliberate* design (parking→venue, organiser-authored curated routes, written-instructions-primary, **no GPS**, offline — because ±20 m GPS between buildings is worse than useless and curated routes encode lit paths / open gates / marshals). M4 **keeps that primary** and adds Google nav as an *option*, chiefly for the M3 registry buildings (which have no curated route) and as a live alternative for venues.
3. **Walking route line (parity).** Fetch a walking route and draw the polyline + distance/ETA on the embedded map (not pins-only).

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
| Credential safety | 7/10 | dart-define + platform config, not committed; key restriction is a release IOU. |
| Privacy | 7/10 | First-use disclosure + GPS-free curated path preserved; Google receives location (disclosed). |
| A11y / 2.0 / FA | 8/10 | Panel/disclosure labelled + 2.0 + EN/FA (the Google map itself is Google's a11y). |

## 13. Open questions / IOUs

1. **Key restriction** (bundle id/SHA + API scoping) — release checklist IOU.
2. **Directions API billing** — each route is a billed `computeRoutes` call; note expected event volume; cache a route for a (origin≈,dest) within a session to limit calls (IOU if needed).
3. **Physical-device verification** — simulator can't fully exercise the embedded Google map + live GPS; a physical iOS + Android run with a real key is the closeout gate (release IOU alongside M2/M3's).
4. **`buildings.json` / MQ artwork redistribution permission** — inherited program IOU, unaffected by M4.

## 14. Next step

On approval → **gauntlet this design** (verify `google_maps_flutter` current API + Routes API shape + geolocator/url_launcher against installed/pinned versions), then the M4 TDD plan (dep+key+flag → route service+decoder → nav providers → nav screen → disclosure → wiring → l10n → verification incl. on-device with key). No code before the plan is gauntletted. Everything is buildable/mergeable **without** the key; only the live on-device render waits for it.
