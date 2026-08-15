# Map Parity Phase B — "Point me there" heading (design)

**Status:** design, pre-gauntlet. Forked from `main` after Phase A (live location) merged.

## 1. Goal

From a venue's detail sheet, a **"Point me there"** action opens a focused screen
with a large arrow that points toward that venue and rotates live as the visitor
turns, with the live walking distance. At ±15–20 m GPS accuracy between buildings
at night, the Phase-A dot tells you *where you are* but not *which way to turn* —
this closes that gap. Pays down **IOU-A2** (heading), on the web-safe sensor path
(no `flutter_compass`).

## 2. Scope

**In (Phase B — the minimum *trustworthy* compass):**
- New dep `sensors_plus` (7.x) — **web-safe** (unlike `flutter_compass`, it lists
  web as a supported platform and degrades rather than breaking the build).
- **Tilt-compensated** magnetic heading fused from accelerometer + magnetometer
  (the way Android `SensorManager.getRotationMatrix`/`getOrientation` and Apple
  CoreMotion both derive azimuth — raw `atan2(x,y)` alone is a flat-tray toy and
  is NOT shipped).
- **Preflight-verified** fixed campus magnetic declination (WMM2025 @ campus
  centre @ 2026-09-19) → magnetic heading + declination = true heading.
- Target **true bearing** + **distance** via `latlong2` `Distance` (no hand-rolled
  haversine).
- Live **relative-angle arrow**, **circular smoothing** (359↔1 safe), an explicit
  **availability state machine**, **sensor lifecycle** (stream only while visible),
  **web/sensorless fallback** (bearing + distance card), **near-target** state,
  **safe venue lookup**, EN/FA, 320×568 / 2.0, reduced-motion-safe, a11y.

**Out (IOUs):**
- **IOU-B2** — compass calibration assistance (figure-eight UX).
- **IOU-B3** — dynamic geomagnetic declination computed from location/date at
  runtime (WMM), replacing the frozen campus value.
- **IOU-B4** — display/natural-orientation axis remapping, so heading is correct
  on landscape-natural (tablet) or rotated displays. Phase B locks `PointMeScreen`
  to portrait instead; on a landscape-natural device the arrow isn't trusted.
- (IOU-B1 "tilt compensation" is **removed** — it belongs in the minimum
  trustworthy version and is in-scope here.)

## 3. Architecture (mirrors Phase A's seams)

Four decoupled units, each testable in isolation:

```
sensors_plus magnetometer stream ─┐
sensors_plus accelerometer stream ─┤→ SensorsHeadingService ─→ HeadingSample stream
                                   │   (real adapter; web → unsupported)   │
     heading_math (pure)  ─────────┘                                       │
                                                                           ▼
locationControllerProvider (Phase A) ──────────────→  PointMeController (Notifier)
     target venue (VenuesData.byId) ────────────────→  → PointMeState
     MapConfig.campusMagneticDeclinationDegrees ─────┘
                                                                           ▼
                                                              PointMeScreen(venueId)
```

**Files (create):**
- `lib/services/heading_math.dart` — **pure** tilt-compensation + circular
  smoothing helpers. Takes **plain value types** (a local `Vector3(x,y,z)` /
  raw doubles), **never** `sensors_plus`'s `MagnetometerEvent`/`AccelerometerEvent`
  — importing those pulls the plugin and breaks VM-only unit tests. The service
  adapter maps plugin events → these plain types.
- `lib/services/heading_service.dart` — `HeadingAvailability`, `HeadingSample`,
  `HeadingService` interface, `SensorsHeadingService` (real).
- `lib/services/point_me_controller.dart` — `PointMeState`, providers,
  `PointMeController`.
- `lib/widgets/bearing_math.dart` — pure `trueBearingDegrees`, `relativeAngle`,
  `distanceMeters` (thin wrappers over `latlong2`, one canonical place).
- `lib/screens/point_me_screen.dart` — the screen + arrow + fallback card.
- `test/support/fake_heading_service.dart` — shared fake.
- mirrored tests.

**Files (modify):** `pubspec.yaml` (+`sensors_plus`), `lib/widgets/map_config.dart`
(declination + near-target constant), `lib/screens/map_screen.dart` (`VenueSheet`/
`ParkingSheet` gain a "Point me there" entry), `lib/app/router/app_router.dart`
(route), `lib/l10n/app_en.arb` + `app_fa.arb`. **No Android/iOS permission
changes** — motion sensors need no runtime permission on iOS/Android.

## 4. The frozen heading pipeline

```
magnetometer (µT, x/y/z)  +  accelerometer (m/s², x/y/z)
        ↓  heading_math.tiltCompensatedHeadingDegrees()  (Android rotation-matrix method)
tilt-compensated MAGNETIC heading (0–360, or null if degenerate)
        ↓  + MapConfig.campusMagneticDeclinationDegrees   (east-positive)
TRUE heading = normalizeBearing(magnetic + declination)
        ↓
target TRUE bearing = normalizeBearing(Distance().bearing(userPos, targetPos))
        ↓
relativeAngle = shortestSignedDelta(trueBearing − trueHeading)   ∈ [−180, 180]
        ↓  circular low-pass smoothing (unit-vector accumulate)
arrow rotation (clockwise-positive; 0 = target dead ahead)
```

`heading_math.tiltCompensatedHeadingDegrees(Vector3 mag, Vector3 accel)`
(plain-value args, see above) implements the Android `getRotationMatrix` +
`getOrientation` algorithm: normalize gravity `A` and geomagnetic `E`; `H = E × A`
(east), if `‖H‖` too small (free-fall / device at a magnetic pole / degenerate)
return `null`; normalize `H`; `M = A × H` (north); azimuth = `atan2(H.y, M.y)` →
degrees → `normalizeBearing`. This equals Android's `getOrientation` azimuth
`atan2(R[1], R[4])`. **Pure, no plugin import, unit-tested** with hand-computed
vectors incl. a flat phone (known azimuth), a tilted phone (same azimuth — the
point of tilt-compensation), and a degenerate case (→ null).

**Stream fusion (in `SensorsHeadingService`, not the pure math):** the
magnetometer and accelerometer are **separate streams at different rates** — do
**NOT** `zip` them 1:1 (that pairs Nth-with-Nth and drifts). Cache the latest
accelerometer sample and emit a heading on each **magnetometer** tick using that
latest accel (a combine-latest-with-latest-accel). Bounded `acquiring` window
before declaring `unavailable`.

## 5. Availability state machine

`HeadingService` classifies at the platform edge; `PointMeController` exposes it:

```
enum HeadingAvailability { acquiring, available, unavailable, unsupported }
```

- **unsupported** — no magnetometer on this platform. `SensorsHeadingService`
  short-circuits on `kIsWeb` to a single `unsupported` sample **without
  subscribing** (web has no Magnetometer API in any browser — this is a fact, not
  a timeout). Also emitted if a sensor stream throws `MissingPluginException` /
  unsupported error at subscribe.
- **acquiring** — subscribed, no valid tilt-compensated heading yet (or readings
  currently degenerate). UI shows a brief "finding north…".
- **available** — valid smoothed heading; arrow live.
- **unavailable** — the stream errored mid-session, or heading stayed degenerate
  past a bounded window. Degrades to the **static bearing card** (never a frozen
  arrow).

Bearing + distance are computed whenever there is a **location fix**, regardless
of heading availability — so the fallback card is useful even with no compass.

## 6. UX — `PointMeScreen`

**Entry:** `VenueSheet` and `ParkingSheet` (both already exist in
`map_screen.dart`) gain a **"Point me there"** button, peer to "Walking
directions", shown only when the target `hasCoordinates`. Route:
`Routes.pointMeTo(venueId)` (a pushed full screen).

**Layout (top → bottom):** venue name (header) · the **arrow** (or fallback card) ·
**distance** ("220 m" / "1.2 km") · **cardinal hint** ("head north-east") · a
one-line status note for the current availability state.

**States:**
| Condition | Shown |
|---|---|
| available, distance > near threshold | Rotating arrow at `relativeAngle` + distance + cardinal |
| available, distance ≤ near threshold | "You're basically there" near-target panel (no twitchy arrow) |
| acquiring | Dimmed arrow + "finding north…" |
| unsupported / unavailable | **Bearing card**: "{Venue} is ~{dist} {cardinal} of you" + honest note "the live arrow needs a phone with a compass sensor" |
| no location fix / permission | Reuse Phase A's enable-location affordance ("turn on location to point the way") |
| unknown/deleted venueId | Safe "We can't find that place" + Back — **never invent coordinates or fall back to campus centre** |

**Motion:** the arrow rotates because that motion *is* the essential live sensor
readout — so under reduced-motion we drop only the decorative easing/tween
(snap to the new angle) but the arrow still reorients. Pulses/glows are removed
under reduced-motion.

**a11y:** the arrow carries a semantic label — "{Venue} is to your
{left/right/ahead/behind}, {distance} away" — recomputed from `relativeAngle`
(e.g. |angle|<20 ahead; >160 behind; else left/right). The side words AND the
cardinals are **l10n keys** (EN/FA), not English literals. The label is **not** a
continuously-announcing `liveRegion` — a heading updates many times/second and
would flood VoiceOver/TalkBack; the label updates silently (read on focus) and
any spoken announcement is throttled to a **meaningful side change** only.
Distance + cardinal are in the tree as text. Never rely on colour/rotation alone.

## 7. Geo math (`bearing_math.dart`, pure)

- `double trueBearingDegrees(LatLng from, LatLng to)` =
  `normalizeBearing(Distance().bearing(from, to))` — `Distance.bearing` returns
  `atan2` in **[−180,180]**, so the `normalizeBearing` wrap to [0,360) is required
  (verified in latlong2 0.9.1).
- `double relativeAngle(double bearing, double heading)` =
  `((bearing − heading + 540) % 360) − 180` → signed shortest delta in [−180,180].
- `double distanceMeters(LatLng from, LatLng to)` =
  `Distance().as(LengthUnit.Meter, from, to)`.
- `String cardinal(double trueBearing)` → 8-point compass word (l10n keys).

All unit-tested, including the **359↔1 wrap** on `relativeAngle` and a due-south /
due-north bearing.

## 8. Circular smoothing (`heading_math.dart`, pure)

Naïve averaging of 359° and 1° yields 180° — wrong. Smooth on the unit circle:
keep an exponential low-pass over `(sin θ, cos θ)` and read back
`atan2(Σsin, Σcos)`. `CircularSmoother(alpha)` with `add(double deg) → double`.
Unit tests: 359→1 stays near 0; a steady input converges; a 90° step eases, not
jumps. Under reduced-motion the smoother is bypassed (snap) — live state still
shown.

## 9. Sensor lifecycle

Motion sensors must run **only while `PointMeScreen` is visible and the app is
foregrounded** (battery + privacy):
- Subscribe when the screen mounts; cancel in `dispose`.
- An `AppLifecycleListener` cancels on `paused`/`inactive` and re-subscribes on
  `resumed` while still mounted.
- Lifecycle uses **only the plain-`Notifier` patterns proven in Phase A** (the
  Riverpod 3.4.2 manual `autoDispose.family` API is not what the plan verified):
  a tiny `pointMeTargetProvider` (`Notifier<LatLng?>`) that `PointMeScreen` sets on
  open and clears (null) on dispose/background. `PointMeController` (a plain
  `Notifier`) subscribes to heading only while the target is non-null and cancels
  the stream the instant it clears — so leaving the screen tears the streams down.
- Never leave the magnetometer/accelerometer humming after the screen is gone.

## 10. Declination — preflight-verified, not guessed

`MapConfig.campusMagneticDeclinationDegrees` (east-positive `double`). Its value is
**derived during plan Task 0 preflight** from **WMM2025** at **campus centre
(−33.7737, 151.1134)** on **2026-09-19**, via the NOAA geomag calculator, and the
receipt recorded in the plan/closeout:
```
model:        WMM2025
coordinate:   -33.7737, 151.1134
date:         2026-09-19
declination:  <computed>° E
source:       NOAA NCEI geomag calculator (URL + retrieval date)
```
Do **not** freeze an approximate "~12.7°E" lookup. Dynamic runtime WMM = IOU-B3.

## 11. Global constraints (carried from Phase A)

- **One new dependency: `sensors_plus`.** No `flutter_compass`.
- **Web build is a hard gate, checked the instant the dep lands.** `sensors_plus`
  *lists* web support, but that is the exact class of claim that bit
  `flutter_compass` — so the plan's dep-add task MUST run `flutter build web`
  immediately after `flutter pub add sensors_plus` and STOP if it fails, isolating
  any web break to the dep before any feature code exists. Magnetometer is
  classified `unsupported` at the platform edge (`kIsWeb`).
- **`context.aon` colours only**; the arrow is a themed shape (accent), no hex.
- **EN + FA** for every new string (build fails if FA misses a key).
- **Every new surface passes 320×568 / 2.0**; **reduced-motion-safe** (arrow
  reorients as essential info; decorative easing/pulse removed).
- **TDD** with a faked `HeadingService` + Phase A's faked `LocationService`.
- **No invented coordinates**; unknown venue → safe unavailable + Back.
- **Per-task gate:** `flutter analyze && flutter test`; web build re-verified.

## 12. Testing

- `heading_math`: tilt-compensation with hand-computed vectors (flat, tilted,
  degenerate→null); circular smoother (359↔1, convergence, step).
- `bearing_math`: bearing normalization, relative-angle wrap, distance, cardinal.
- `HeadingService` fake contract; `SensorsHeadingService` web→`unsupported`
  (guarded by `kIsWeb`).
- `PointMeController`: acquiring→available; stream error→unavailable; web→
  unsupported; no-fix→no bearing; near-target threshold; declination applied
  (true = magnetic + declination); relativeAngle sign.
- `PointMeScreen` widget: arrow present when available; bearing card when
  unsupported/unavailable; near-target panel; unknown-venue safe state; a11y
  label reflects side; **320×568 / 2.0** no overflow; **FA** render; reduced-motion
  snaps (no tween) but still reorients.
- Gate: `flutter build web`; on-device compass pass (point at a known landmark,
  verify the arrow tracks and the bearing/cardinal are right; verify streams stop
  on leaving the screen).

## 13. Scorecard (self, pre-build)

| Axis | Score | What moves it up |
|---|---:|---|
| Parity coverage | 6/10 | 2nd of ~7 subsystems closed (heading). |
| Night-navigation utility | 8/10 | Points the way, not just the spot. Higher = arrival haptic + street-name hints. |
| Degradation honesty | 9/10 | Explicit `unsupported` on web; never a fake/frozen compass. |
| Sensor correctness | 7/10 | Tilt-compensated + verified declination; bounded by fixed declination + no calibration. Higher = IOU-B2/B3. |
| Testability | 8/10 | Pure math + faked sensor seam; state machine unit-tested. |
| A11y / 2.0 / RTL | 8/10 | Live side/distance semantics + 2.0 + EN/FA; higher = on-device VoiceOver pass. |
| Battery/privacy | 8/10 | Streams scoped to visible+foreground. |

## 14. IOU ledger

- **IOU-B2** — compass calibration assistance (figure-eight UX + quality meter).
- **IOU-B3** — dynamic geomagnetic declination from location/date (runtime WMM),
  replacing the frozen campus value.

## 15. Open questions

1. Near-target threshold (`pointMeNearTargetMeters`) — start at **20 m**; confirm
   it isn't so large that a real approach flips to "you're here" too early, nor so
   small the arrow twitches when accuracy > remaining distance.
2. "Point me there" on the **parking** sheet too, or venues only? (Proposed: both —
   both sheets exist and carry coordinates.)
3. Should the arrow also show when the app estimates the compass is uncalibrated
   (a soft "hold flat / calibrate" hint), or defer all calibration to IOU-B2?
   (Proposed: a passive one-line hint only; interactive calibration is IOU-B2.)

## 16. Next step

On approval → **writing-plans**. Plan Task 0 preflight computes + records the
WMM2025 declination. TDD order: dep → pure heading_math → pure bearing_math →
HeadingService + fake → PointMeController → PointMeScreen → sheet entry + route →
l10n → verification (web build + on-device compass). No implementation before the
plan is written and gauntletted.

---

## Closeout — Map Parity Phase B (2026-08-13)

Implemented via the TDD plan (`docs/superpowers/plans/2026-08-13-aon-map-heading-phaseB.md`), 10 tasks, one commit each on `feature/map-heading-phaseB`.

**Static + tests:** `flutter analyze` clean; **527 tests pass** (491 baseline + 36 new). Phase A's `location_providers` gate was widened (`active && (mapVisible || pointMeActive)`) with no Phase A regression. The data-seam guard (`integration_seams_test`) holds — `PointMeScreen` resolves the target via `venueByIdProvider`/`parkingByIdProvider`, not `VenuesData`/`ParkingData`.

**Builds (all green, on-branch):**
- `flutter build web` — ✅ (`sensors_plus` web support; the reason `flutter_compass` was cut)
- `flutter build ios --simulator --debug` — ✅ (Pod install fine with the motion key)
- `flutter build apk --debug` — ✅ (**AGP 8.11.1 → 8.12.1** for the `sensors_plus` 7.x floor)

**Resolved dependency:** `sensors_plus` **7.1.0** (`magnetometerEventStream`/`accelerometerEventStream({samplingPeriod})` API confirmed against the installed package). AGP bumped to **8.12.1**; Gradle 9.1.0 / Kotlin 2.3.20 / Java 17 already met the floor.

**Declination receipt (preflight, Task 0):**
```
model:        WMM2025
coordinate:   -33.7737, 151.1134
date:         2026-09-19
declination:  12.752° E
source:       BGS geomagnetic web service
              https://geomag.bgs.ac.uk/web_service/GMModels/wmm/2025/ (retrieved 2026-08-13)
```

**iOS simulator runtime pass (iPhone 17 Pro).** The simulator has no magnetometer, so it exercises the degradation path deterministically:
- [x] open venue sheet → **"Point me there"** present → tap → screen opens — PASS
- [x] no location fix → **"Turn on location"** + a working **Show my location** button that activates GPS (finding #7) — PASS
- [x] location active on the PointMe route even though Map isn't the front tab (finding #6, `pointMeActive` demand) — PASS
- [x] no magnetometer → after the acquisition timeout, degrades to the **bearing + distance card** ("Macquarie Theatre is about 269 m south-west of you"), **no frozen arrow** — PASS
- [x] bearing is geometrically correct (sim set north of campus; venue is genuinely SW) — PASS
- [x] no crash on motion access (`NSMotionUsageDescription` present) (finding #1) — PASS
- [~] live arrow tracks phone rotation / walk-in near-target — **NOT testable on a simulator** (no magnetometer); needs a real compass device. Logic is covered by `point_me_screen_test` / `point_me_controller_test` (arrow render, side-follows-heading, near-target, declination applied).

**Orientation (IOU-B4):** `PointMeScreen` locks portrait; heading is trusted on portrait-natural phones only. Landscape-natural/rotated (iPad) axis remap is deferred.

**Status — split, honest:**
- **IMPLEMENTATION COMPLETE (iOS/Android):** analyze/tests green, all three builds green, on-device runtime verified for every simulator-testable path; the live-compass path is unit/widget-covered and awaits a real-device pass.
- **WEB RELEASE READY — NOT claimed.** The web *build* is green, but the web bearing/distance *fallback* is not runtime-verified: the app's pre-existing web black-screen (Phase A closeout) means `PointMeScreen` is unreachable on web today. Blocked on the separate web-black-screen triage.
