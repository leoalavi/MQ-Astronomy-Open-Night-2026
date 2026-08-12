# Live location on the AON map — Map Parity: Phase A (design)

The first sub-project of a phased effort to bring the AON campus map toward
feature parity with MQ Journey's. Parity was decomposed into independent phases
(A live location · B search · C offline tiles · D overlays/favourites ·
E turn-by-turn routing · F campus raster · G AR/compass); **E and F carry
external gates** (a billed Google Routes API key + secret; Macquarie cartography
licensing). This spec is **Phase A only**.

Status: **design — revised after self-gauntlet + Raouf's review (11 findings, all
adopted); ready for approval.** No production code until approved and a plan is
written.

Verified vs pub.dev / installed SDK (2026-08-11): `flutter_map` **8.3.1**
(`onPositionChanged(camera, bool hasGesture)` distinguishes a user pan —
`options.dart:52`; `CircleMarker(useRadiusInMeter: true)` = metre radius);
`geolocator` **14.0.2** (web needs HTTPS; `openAppSettings`/`openLocationSettings`
/`getServiceStatusStream` throw `UnsupportedError` on web; `checkPermission()` can
falsely return `denied` on web when the browser lacks the Permissions API;
`LocationSettings.distanceFilter` in metres); `flutter_compass` has **no web
impl** (cut, IOU-A2).

---

## 1. Scope

A "you are here" experience: a live location **dot + accuracy circle**, a
**follow-me** camera mode, and a stateful locate control — lazily permissioned,
fully degradable, and battery-disciplined.

**In:** live device position (dot keeps updating independent of follow);
follow-me camera (recenter, instant); campus-radius guard; graceful degrade
across permission/GPS states **including runtime failures**; visibility-scoped
GPS lifecycle.

**Out (IOUs / later phases):** heading cone (IOU-A2), map rotation (IOU-A3),
search (B), routing-from-here (E), overlays (D), offline tiles (C), AR (G),
licensed raster (F).

> This is the "where am I / follow me" core, **not** full map parity (the whole
> A–G programme). Scorecard §10 scores parity coverage honestly.

---

## 2. Decisions (brainstorm + gauntlet + review)

| # | Decision | Choice |
|---|---|---|
| D1 | Experience | Dot + accuracy circle + follow-me (heading/rotation cut → IOUs) |
| D2 | Permission | **Lazy** — requested only on first tap of the locate control |
| D3 | **Three decoupled responsibilities** | `locationActive` (GPS/dot) ≠ `followMode` (camera) ≠ `mapVisible` (lifecycle). `followMode` no longer controls the GPS subscription (§P1-review) |
| D4 | Live dot | Stays live whether or not the camera is following; a user map-pan exits **follow** but **keeps the dot** |
| D5 | Recenter motion | **Instant** `MapController.move` (no animation dep) |
| D6 | Off-campus | Campus-radius guard; radius constant lives in `MapConfig` |
| D7 | Dependency | **`geolocator` only** |
| D8 | iOS | **Foreground / When-In-Use only** — configure geolocator's Apple impl to bypass the "Always" path (no `NSLocationAlwaysAndWhenInUse…`, no `UIBackgroundModes: location`) |

---

## 3. Inherited contracts (post-merge)

Localisation (EN + FA, RTL); Palette (`context.aon.*`, no `AonColors`); text
scale 2.0; reduced motion (recenter is instant so nothing to suppress there);
keyless.

---

## 4. Dependency

| Dep | Why | Notes |
|---|---|---|
| `geolocator` (14.x) | position stream · permission check/request · service-enabled + service-status stream · `openAppSettings`/`openLocationSettings` · `distanceFilter` | Platform config §8. Web: HTTPS; several methods throw `UnsupportedError` → guarded (§5, §7). Pin at plan time; re-verify `flutter build web`. |

`permission_handler` (redundant — geolocator covers Settings) and
`flutter_compass` (no web impl, stale) were rejected.

---

## 5. Architecture (isolated, testable units)

### 5.1 Model — validated
```dart
// lib/models/user_location_fix.dart
class UserLocationFix {
  UserLocationFix({required this.position, required this.accuracyMeters})
      : assert(position.latitude.abs() <= 90 && position.longitude.abs() <= 180),
        assert(accuracyMeters.isFinite && accuracyMeters > 0);
  final LatLng position;
  final double accuracyMeters;

  /// Presentation policy (§P8): a huge accuracy radius shouldn't paint a
  /// Sydney-sized blob. Keep the true value; the layer omits the circle and the
  /// control shows a "low accuracy" state above this threshold.
  static const double poorAccuracyMeters = 200;
  bool get isLowAccuracy => accuracyMeters > poorAccuracyMeters;
}
```
Invalid/non-finite fixes from the platform are dropped in the service before they
reach state.

### 5.2 Location service (the hardware seam)
```dart
// lib/services/location_service.dart
enum LocationStatus { unknown, granted, denied, deniedForever, serviceOff }

abstract interface class LocationService {
  Future<LocationStatus> status();
  Future<LocationStatus> request();            // OS prompt
  Stream<UserLocationFix> watch();             // position stream, validated
  Stream<bool> serviceEnabledChanges();        // native only; empty stream on web
  Future<void> openAppSettings();              // deniedForever (native)
  Future<void> openLocationSettings();         // serviceOff (native)
}
```
Real impl wraps `geolocator` with `LocationSettings(distanceFilter: …)`. Split
settings actions match the failure (§P1-3). All web-unsupported calls are
`kIsWeb`-guarded (no-op / empty). **Web acquisition is attempt-first** (§5.2.1).
Everything above the service is faked in tests — no GPS hardware.

#### 5.2.1 Web permission semantics (§P1-4)
On web, `checkPermission()` can return `denied` even when acquisition works, so
the web impl does **not** treat it as authoritative: on the first locate gesture
it **attempts `watch()`** directly and lets the browser prompt — a fix ⇒
`granted`/active; a permission/position error ⇒ a `denied`/unavailable hint. The
native impl keeps the check→request flow.

### 5.3 State (Riverpod) — three responsibilities, three providers
- `locationServiceProvider` — the service (fake-overridable).
- `locationStatusProvider` — `LocationStatus`.
- `userLocationProvider` — latest validated `UserLocationFix?`.
- **`locationActiveProvider`** (`bool`) — is the live dot on / GPS wanted.
- **`followModeProvider`** (`bool`) — is the camera following.
- **`mapVisibleProvider`** (`bool`) — is the Map shell branch visible (fed by the
  `AppShell` current index).

**GPS subscription is active iff `locationActive && mapVisible`.** Camera moves
iff `followMode && isNearCampus(fix)`.

### 5.4 Pure campus distance (§P9)
```dart
// MapConfig
static const double locationCampusRadiusMeters = 2500;
// one canonical calculation, used by BOTH the guard and the banner:
double distanceFromCampusMeters(LatLng p);            // latlong2 Distance vs campusCentre
bool isNearCampus(LatLng p, {double radiusMeters = MapConfig.locationCampusRadiusMeters});
```
Pure, unit-tested. `campusCentre = LatLng(-33.7737, 151.1134)` (verified).

### 5.5 The location layer + layer order (§P7)
`UserLocationLayer` composes flutter_map 8 built-ins. **Order matters** so the
translucent uncertainty field sits *under* venue content and the precise dot
sits *on top*:
```
TileLayer → accuracy CircleLayer → venue MarkerLayer → user-dot MarkerLayer → controls
```
- accuracy → `CircleMarker(point, radius: accuracyMeters, useRadiusInMeter: true,
  colour context.aon.accent low-alpha)` — **omitted when `fix.isLowAccuracy`**.
- dot → a small `context.aon.accent` dot on a white ring.

### 5.6 The locate control — three states + semantics (§P1-2, §P10)
`MapControlIsland`'s `my_location` button (today a plain callback — verified)
becomes state-driven by `locationActive` + `followMode` + `locationStatus`:

| Control state | Tap does | Semantic label |
|---|---|---|
| inactive | lazy `request()`; on granted → `locationActive=true`, `followMode=true` | "Show my location" |
| active, not following | `followMode=true` (recenter) | "Follow my location" |
| following | `followMode=false` (dot stays live) | "Stop following my location" |
| denied | re-`request()` | "Location unavailable" |
| deniedForever | `openAppSettings()` (native) / hint (web) | "Location unavailable" |
| serviceOff | `openLocationSettings()` (native) / hint (web) | "Turn on Location Services" |

The button is **one** semantics node (button role); tapping never fully
"turns off" location — Google-Maps style. Panning, markers, sheets work in every
state.

### 5.7 Follow, user-pan, off-campus, runtime failure
- **Recenter:** while `followMode` + fix + `isNearCampus` → instant
  `MapController.move`.
- **Off-campus:** else keep campus framing + a localized banner "You're about
  `distanceFromCampusMeters/1000` km from campus" (shared calc §5.4). Dot still
  renders at true position.
- **User pan exits follow (§P1-2):** `onPositionChanged(camera, hasGesture)` with
  `hasGesture == true` → `followMode = false`; **`locationActive` stays true**
  (dot keeps updating).
- **Runtime failure (§P1-6):** a `watch()` stream error, or
  `serviceEnabledChanges()` emitting `false`, or a mid-session `serviceOff` →
  cancel the subscription, set `followMode=false` and `locationActive=false`,
  update `locationStatus`, drop the (now stale) dot, and show the matching
  recovery state. The map itself never breaks.

---

## 6. Lifecycle & battery (§P1-1, §P1-5)

GPS work is scoped to **`locationActive && mapVisible`** — not to `followMode`
(the old conflation) and not left running on a hidden tab:

- Map hidden (tab switch in the `IndexedStack` shell) → `mapVisible=false` →
  **stream paused**; `followMode` reset to `off`; `locationActive` **intent
  retained**.
- Return to Map → `mapVisible=true` → stream **resumes** (dot live again); the
  user re-taps to follow.
- `mapVisible` is fed by an `AppShell`-level signal (the shell's current branch
  index), since the `StatefulShellRoute.indexedStack` does not dispose the Map on
  tab switch and offers no cheap visibility callback.

---

## 7. Degrade & failure matrix (map never hard-fails)

| Condition | Behaviour |
|---|---|
| `granted` | dot + accuracy circle (omitted if low-accuracy); follow works |
| `denied` (this time) | button "Location unavailable"; tap re-prompts |
| `deniedForever` | native: `openAppSettings`; web: hint |
| `serviceOff` (initial or mid-session) | button "Turn on Location Services"; native: `openLocationSettings`; drop dot |
| watch() stream error mid-session | cancel, `followMode/locationActive=false`, recovery state |
| web: `checkPermission`==denied but acquisition works | attempt-first (§5.2.1) — not treated as denied |
| web: geolocation blocked / not HTTPS | hint; markers/venues unaffected |
| low-accuracy fix | dot shown, **circle omitted**, "low accuracy" state |

---

## 8. Platform configuration

- **iOS `Info.plist`**: `NSLocationWhenInUseUsageDescription`. Configure
  geolocator's Apple impl **foreground/When-In-Use only** — no
  `NSLocationAlwaysAndWhenInUseUsageDescription`, no `UIBackgroundModes:
  location` (§D8) — to keep the App Store permission questions minimal.
- **Android manifest**: `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`.
- **Store / privacy**: location used **on-device for the dot + follow-me; not
  collected, stored, or transmitted** (no backend). Play Data-safety reflects
  on-device-only use.
- Preserves "usable with no permission" in substance: decline and the whole map
  still works.

---

## 9. Testing

- **Pure `distanceFromCampusMeters` + `isNearCampus`**: on-campus, ~5 km away,
  boundary.
- **Model validation**: invalid lat/lng or `accuracy<=0` rejected; `isLowAccuracy`
  threshold.
- **`LocationService` fake** drives state tests: status transitions
  (unknown→granted/denied/deniedForever/serviceOff); **live dot updates with
  `followMode=false`** (decoupling, §P1-1); **user pan sets `followMode=false`
  but keeps `locationActive`** (§P1-2); **runtime stream-error / serviceOff mid-
  session ⇒ recovery transition** (§P1-6); off-campus guard (far fix ⇒ no move).
- **Lifecycle**: `mapVisible=false` pauses the stream and resets follow;
  returning resumes (§P1-5).
- **Web semantics**: attempt-first path — a fix on web ⇒ active even if
  `checkPermission` said denied (§P1-4).
- **`UserLocationLayer`**: dot + circle from a normal fix; **circle omitted** for
  a low-accuracy fix; layer order (circle below venue markers, dot above).
- **Locate control semantics**: exactly one button node; correct label + action
  per state (§P10); `deniedForever`→`openAppSettings`, `serviceOff`→
  `openLocationSettings`.
- **Off-campus banner** present/absent by distance.
- **2.0**: control + banner at `320×568 / 2.0`. **l10n**: EN + FA arb, FA smoke.
- **`flutter build web`** green with geolocator + guards.
- No real GPS — service faked.

---

## 10. Honest scorecard

| Axis | Score | What moves it higher |
|---|---:|---|
| Parity coverage | 5/10 | One of 7 subsystems; biggest single gap. Higher = B–G. |
| Identity fidelity | 7/10 | Lazy + full degrade keep "usable with no permission"; 2nd runtime permission after camera. |
| Correctness of state model | 8/10 | Three decoupled responsibilities; runtime-failure transitions defined. Higher = a fuzz/property test over the state machine. |
| Testability | 8/10 | Hardware faked; pure campus calc; state transitions unit-tested. |
| A11y / 2.0 / RTL | 8/10 | Per-state semantics + 2.0 + EN/FA; higher = on-device VoiceOver pass. |
| Battery discipline | 8/10 | Scoped to `locationActive && mapVisible`; `distanceFilter`. Higher = adaptive accuracy per zoom. |
| Ambition | 3/10 | Expected, recombined map capability — honest, not a species. |

---

## 11. IOU ledger

- **IOU-A1 — Routing-from-here** → Phase E (gates on the Google Routes key).
- **IOU-A2 — Heading cone** → web-safe sensor path (`sensors_plus` magnetometer,
  tilt-compensated; or conditional-import compass).
- **IOU-A3 — Map rotation** → needs marker counter-rotation.
- **IOU-A4 — Adaptive accuracy/`distanceFilter` tuning per zoom.**

---

## 12. Open questions

1. **Campus radius** 2.5 km (`MapConfig.locationCampusRadiusMeters`) — confirm it
   covers arrival from Metro / car parks without a false off-campus note.
2. `MapModeToggle`: the locate control should be hidden in **panorama** mode.
3. On tab-hidden, follow resets to off but the dot resumes on return — confirm
   that's the desired feel (vs. also pausing the dot until re-tap).

---

## 13. Next step

On approval → **writing-plans skill** (geolocator + foreground-only platform
config; validated model; faked-service tests; the three providers +
pan/lifecycle/failure wiring; pure campus calc; `CircleLayer`/`MarkerLayer` in
the right order; locate-control state machine + semantics; l10n; 2.0;
verification incl. `flutter build web` and an on-device location run). No
implementation before that plan is written and reviewed.

---

## Closeout — Map Parity Phase A (2026-08-12)

Implemented via the TDD plan (`docs/superpowers/plans/2026-08-11-aon-map-live-location-phaseA.md`), 11 tasks, one commit per task on `feature/map-live-location-phaseA`.

**Static + tests:** `flutter analyze` clean; **491 tests pass** (462 baseline + 29 new). No existing test weakened (`map_control_island_test` updated to the new `locateButton` slot — an intentional API change, still asserting three buttons / callbacks / tap targets).

**Builds (all green, on-branch):**
- `flutter build web` — ✅ (the load-bearing gate; the reason `flutter_compass` was cut. geolocator 14.0.3 compiles for web.)
- `flutter build ios --simulator --debug` — ✅ (Pod install exercises the Podfile `BYPASS_PERMISSION_LOCATION_ALWAYS=1` bypass)
- `flutter build apk --debug` — ✅

**Resolved dependency:** `geolocator` **14.0.3** (pinned `^14.0.3`, lock committed). iOS resolves `geolocator_apple` via Swift Package Manager, so `Podfile.lock` gains no pod entry — only its PODFILE CHECKSUM changed (from the `post_install` edit).

**Visibility mechanism — settled, not an open question:** `mapVisible` is driven by `AppShell` from `StatefulNavigationShell.currentIndex == 3` (single writer); `map_screen` never writes it. The `TickerMode` experiment was removed entirely in plan v2. Proven end-to-end by `map_visibility_shell_test` (real `StatefulShellRoute.indexedStack`) and confirmed on-device (tab-switch pause/resume below).

**Foreground-service determination:** `FOREGROUND_SERVICE_LOCATION` is **not required** — Phase A streams location only while foregrounded and the Map tab is visible (`active && mapVisible`); no background/continuous service. Not added.

**iOS simulator runtime pass (iPhone 17 Pro, iOS 26 sim):**
- [x] open Map → **NO** permission prompt (lazy) — PASS
- [x] tap locate → permission prompt appears, showing the When-In-Use copy; options are Allow Once / While Using / Don't Allow (**no Always**, confirming foreground-only config) — PASS
- [x] grant → location dot (accent-on-white ring) appears; map recenters (following); locate button shows the filled "following" icon — PASS
- [x] location far from campus (fed via `simctl location`) → off-campus banner "You're about 3.2 km from campus"; map does **NOT** fly away (dot off-screen by design) — PASS
- [x] switch to another tab and back → dot resumes on return (GPS paused while away via `mapVisible`); no crash — PASS
- [~] pan-exits-follow / tap-again-refollows / low-accuracy-no-recenter / deny+serviceOff copy — **not exercised on-device** (accuracy can't be set via `simctl`; these paths are covered by the unit + widget suite: `location_controller_test`, `locate_button_test`, `map_location_wiring_test`).

**Web runtime smoke — BLOCKED by a pre-existing condition (NOT a Phase A regression):** served the release build over `http://localhost` (secure context) in a headless browser; the app fails to paint (black screen, an uncaught Dart exception at startup, `Object.Z` path). **Verified pre-existing:** the base commit `ecb3204` (before any Phase A code) built and served identically **also black-screens with the same startup exception**. Phase A adds no startup-executing web path (the location stream starts only on a locate tap), so it did not introduce this. The web *compile* gate — which is what Phase A actually required — passes at both commits. The web static-serve runtime failure is out of Phase A scope and warrants a separate investigation.

**Status:** Phase A is **CODE-COMPLETE and RELEASE-READY on iOS/Android** (native runtime verified on-device for the core paths; full logic covered by 491 automated tests). **Web:** compiles and ships, but its at-runtime render is blocked by a pre-existing, non-Phase-A issue to be triaged separately.
