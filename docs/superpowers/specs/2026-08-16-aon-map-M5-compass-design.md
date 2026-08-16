# M5 — Compass / Radar Point-Me (Map Parity Program) — Design

**Status:** design, awaiting user review. Milestone **M5** of the map-parity
program (`2026-08-15-aon-map-parity-program-design.md`). Forked from `main@d20e9b3`
(post-M4). Branch (at execution): `feature/map-M5-compass`.

**Goal:** Add a third Map-tab mode — a night-vision **compass/radar point-me
finder** — that shows nearby campus places as blips around a heading-driven rose,
lets the user lock any one as a "point me there" target (big arrow + distance),
and degrades honestly to a distance-sorted list when the compass sensor is
unavailable. Pure reuse of Phase B (heading + bearing math) and M3 (unified
venue+building index) over a new view; **no camera, no AR framework, no new
sensors.**

---

## 1. Context & the parity-matrix reconciliation (honesty first)

The umbrella spec's capability matrix lists two M5 rows as **"ported"** from MQ
Journey:

| Matrix row (umbrella §3) | Umbrella claim | Reality (verified 2026-08-16) |
|---|---|---|
| AR building picker | "ported (needs M3 + Phase B)" | **Phantom.** MQ Journey has **no AR** — no ARKit/ARCore/SceneView packages, no camera-AR code. Its only camera use is `mobile_scanner` for **Open Day QR codes** (`NSCameraUsageDescription`: *"…scan Open Day QR codes…"*). There is nothing to port. |
| Compass mode | "reuse Phase B heading" | **Real & grounded.** AON already ships the heading stack (`HeadingService`, `PointMeController`, `bearing_math`, WMM2025 declination). |

**Consequence:** "AR parity" cannot mean "match MQ's AR" because that artifact
does not exist. Per the program's own rule ("every deviation is a *documented*
row, not a silent gap"), M5 **supersedes** the phantom "AR building picker" row
with an honest, buildable capability: a sensor-driven **compass/radar finder**.
This is recorded as an **intentional deviation with evidence**, not a parity gap.

**The event constraint that makes this the *right* form, not merely the cheap
one:** AON is a **dark, outdoor** event (Sat 19 Sep 2026, 4–10pm). Classic
camera-passthrough AR renders labels over a **near-black** video frame at night —
the camera adds cost, a permission, and privacy surface for ~zero value. A
screen-rendered compass needs no camera, works in full dark, and — rendered in a
**red scotopic palette** — actively *preserves* the dark-adapted vision that a
star party depends on. The "reduced" option is the superior product here.

### Locked decisions (user, 2026-08-16)
1. **Form:** compass/radar point-me (not camera AR, not sky AR).
2. **Camera:** **none** — pure screen-rendered radar. No camera permission added.
3. **Targets:** **event venues + the full 170-building registry** (M3's unified
   index), proximity-culled and filterable.
4. **Naming honesty:** the mode enum value is **`MapMode.compass`** — no "AR"
   claim in code, copy, or l10n.

---

## 2. Non-goals (YAGNI / scope guard)

- **No camera** feed, no `NSCameraUsageDescription`/Android camera permission, no
  camera plugin.
- **No AR framework** (ARKit/ARCore/SceneView) and no 3D device-attitude tracking.
- **No sky/celestial** features (constellations/planets) — explicitly deferred as
  a possible future program, not M5.
- **No new sensor code** — `HeadingService`/`bearing_math` are consumed as-is.
- **No new persistence** — no stored state beyond what already exists (favorites
  from M3 are read-only here).
- **No changes to Phase B behavior** (`PointMeScreen`, `PointMeController` math)
  beyond additive reuse.

---

## 3. Architecture (Approach ① — compass-as-a-third-map-mode)

The compass is a **mode of the existing Map tab**, alongside `campusMap` and
`panorama`, selected by the existing `MapModeToggle` (gaining a third segment).
It reuses the Phase B lifecycle idiom: a visibility provider gates the heading
subscription so the magnetometer runs **only while the mode is on screen**.

```
MapScreen (_mode: MapMode)
 ├─ MapModeToggle { campusMap | panorama | compass }      (extend enum + widget)
 └─ if _mode == compass → CompassModeView
        ├─ compassVisibleProvider = true (while built)    (gates heading stream)
        ├─ nearbyTargetsProvider ──────┐ nearest-N blips (venues+buildings)
        ├─ compassControllerProvider ──┤ always-on heading + per-blip + locked geometry
        └─ CompassRadarView / NearbyList (degradation)  ← renders both
```

**Why a new `CompassController` instead of reusing `PointMeController`:**
`PointMeController` subscribes to heading **only when a target is locked**
(`pointMeTargetProvider != null`, `point_me_controller.dart:76`) — correct for
single-target guidance, but the compass needs live heading to show the *facing*
indicator and place blips **before** anything is locked. So the compass owns its
own always-on (while-visible) heading subscription and **reuses the pure math
`PointMeController` is built on** (`bearing_math` + `MapConfig` + `HeadingService`),
rather than the single-target controller. `PointMeController`/`pointMeTargetProvider`
are left untouched for `PointMeScreen`. This keeps each controller doing one job
and avoids a second, target-gated heading subscription.

**Reused verbatim (no edits):**
- `lib/services/heading_service.dart` — `HeadingService`, `HeadingSample`,
  `HeadingAvailability { acquiring, available, unavailable, unsupported }`
  (web → `unsupported` without subscribing). `headingServiceProvider` is already
  overridden in `main.dart` for Phase B — the compass consumes the same provider.
- `lib/widgets/bearing_math.dart` — `trueBearingDegrees(from,to)`,
  `distanceBetweenMeters(from,to)`, `relativeAngleDegrees(bearing,heading)`,
  `normalizeBearing`, `cardinalFor(trueBearing) → Cardinal { n,ne,e,se,s,sw,w,nw }`.
- `lib/widgets/map_config.dart` — `campusMagneticDeclinationDegrees = 12.752`,
  `pointMeNearTargetMeters = 20`.
- M3: `searchIndexProvider → List<SearchEntry>` (unified venue+building, deduped),
  `SearchEntry { placeKey, title, subtitle, kind }` with `VenueEntry(venue,…)` /
  `BuildingEntry(building)` carrying the model (and thus `routingLatitude/Longitude`).

**New files:**
- `lib/services/nearby_targets.dart` — the one new provider + pure helpers.
- `lib/widgets/compass_radar_view.dart` — the rose + blips + locked arrow.
- `lib/widgets/nearby_list.dart` — the degradation/list view (cardinal bearings).
- `lib/widgets/compass_mode_view.dart` — the mode container (wires visibility +
  chooses radar vs list by availability + hosts the filter).

**Modified files:**
- `lib/widgets/map_mode_toggle.dart` — `enum MapMode` gains `compass`; toggle
  renders 3 segments (glyph/label + tooltip).
- `lib/screens/map_screen.dart` — render `CompassModeView` when
  `_mode == MapMode.compass`; keep the FAB/overlay guards mode-aware.
- `lib/services/providers.dart` (or nearest home) — `compassVisibleProvider`.
- `lib/l10n/app_en.arb` + `app_fa.arb` — new strings (real Persian).
- `lib/main.dart` — none expected (no new store/override; `headingServiceProvider`
  is already overridden for Phase B).

---

## 4. Components & signatures

### 4.1 `nearby_targets.dart`

```dart
/// One findable place with its live geometry to the user's fix.
class NearbyTarget {
  const NearbyTarget({
    required this.placeKey,      // 'venue:<id>' | 'building:<id>'  (M3 key space)
    required this.title,
    required this.kind,          // PlaceKind.venue | .building
    required this.distanceMeters,
    required this.trueBearingDegrees, // geographic true bearing, [0,360)
    required this.lat,
    required this.lng,
  });
  final String placeKey;
  final String title;
  final PlaceKind kind;
  final double distanceMeters;
  final double trueBearingDegrees;
  final double lat, lng;
}

/// Pure: routing coords for a search entry (SAME choice placeResolverProvider
/// makes — venue/building `routingLatitude/Longitude`). Null ⇒ not locatable.
(double lat, double lng)? routingLatLngOf(SearchEntry e);

/// Nearest-N locatable places to [fix], sorted by distance asc, tie-break by
/// placeKey asc. Entries with null routing coords are EXCLUDED (no fake blip —
/// DataConfidence honesty). Cap = MapConfig.compassMaxTargets (propose 12).
List<NearbyTarget> nearestTargets(LatLng fix, List<SearchEntry> index, {int max});

/// Riverpod: watches searchIndexProvider + locationControllerProvider.fix.
/// fix == null ⇒ const []. Otherwise nearestTargets(...).
final nearbyTargetsProvider = Provider<List<NearbyTarget>>((ref) { … });
```

- **Coord source:** read the entry's model directly (`VenueEntry.venue`,
  `BuildingEntry.building`) via `routingLatLngOf` — mirrors `placeResolverProvider`'s
  `routingLatitude/Longitude` so there is ONE truth for "where is this place". No
  per-key family resolution (that would spin ~180 `AsyncValue`s per rebuild).
- **New constant:** `MapConfig.compassMaxTargets = 12` (nearest-N cap).

### 4.2 `compassVisibleProvider` + `CompassController`

```dart
/// True only while the compass mode is on-screen; gates CompassController's
/// heading subscription. Mirrors mapVisibleProvider. Set true on the mode
/// container's build, false on dispose.
final compassVisibleProvider =
    NotifierProvider<CompassVisible, bool>(CompassVisible.new);

/// Which target is locked (tap a blip). Compass-local; NOT pointMeTargetProvider.
final compassLockedProvider =
    NotifierProvider<CompassLocked, String?>(CompassLocked.new); // placeKey | null

/// Immutable render state for the rose.
class CompassState {
  const CompassState({
    required this.availability,        // HeadingAvailability (reused enum)
    this.trueHeadingDegrees,           // magnetic + declination, [0,360); null unless available
    this.locked,                       // the locked NearbyTarget, or null
    this.lockedRelativeAngle,          // relativeAngleDegrees(bearing, trueHeading)
    this.lockedNearTarget = false,     // <=20 m on a reliable fix
    this.locationReliable = false,     // !fix.isLowAccuracy
    this.hasFix = false,
  });
  final HeadingAvailability availability;
  final double? trueHeadingDegrees;
  final NearbyTarget? locked;
  final double? lockedRelativeAngle;
  final bool lockedNearTarget, locationReliable, hasFix;
}

/// Owns the always-on (while compassVisibleProvider) heading subscription and
/// composes CompassState. Reuses the SAME pure helpers PointMeController uses —
/// trueBearingDegrees / distanceBetweenMeters / relativeAngleDegrees /
/// normalizeBearing + MapConfig.campusMagneticDeclinationDegrees +
/// pointMeNearTargetMeters — re-deriving the near-target/low-accuracy honesty
/// locally (≈10 lines) rather than routing through the single-target controller.
final compassControllerProvider =
    NotifierProvider<CompassController, CompassState>(CompassController.new);
```

- Subscribes `headingServiceProvider.watch()` while visible; cancels on dispose /
  when `compassVisibleProvider` goes false — never runs in the background, and a
  terminal `unavailable`/timeout is **not** resurrected (Phase B rule), enforced
  with the same generation-token guard `PointMeController` uses.
- `trueHeadingDegrees = normalizeBearing(magnetic + campusMagneticDeclinationDegrees)`.
- Locked geometry recomputed from the current fix + locked target on each heading
  or fix tick; near-target short-circuit + low-accuracy honesty identical in spirit
  to `PointMeController._compute()`.

### 4.3 `CompassRadarView` (heading available)

- A **rose** (fixed viewport, ≤ min(width) diameter) with a heading-up or N-up
  orientation. Proposal: **N-up rose** (north fixed at top), user-heading shown as
  a highlighted sector; blips placed at each target's **true bearing**. (N-up is
  simpler to reason about + test than a counter-rotating rose and avoids motion
  sickness; heading-up is an IOU if user testing wants it.)
- Each `NearbyTarget` → a blip at angle `trueBearingDegrees`, radius scaled by
  distance (nearer = closer to center, clamped ring for very-near/very-far). A
  **facing indicator** marks `CompassState.trueHeadingDegrees` on the rose.
- **Locked target** (`compassLockedProvider` set): a bold arrow at
  `CompassState.lockedRelativeAngle`, with the locked target's `distanceMeters` and
  the `lockedNearTarget` ("You're here"/within 20 m) short-circuit — all from
  `CompassState`.
- **Red scotopic palette:** dark-red on near-black; no bright whites/blues.
  Defined as compass-local tokens (does not alter `context.aon.*` globals).
- Tap a blip → `compassLockedProvider.set(target.placeKey)`.
- Each blip carries a `Semantics(label: "<title>, <cardinal>, <distance>")`.

### 4.4 `NearbyList` (heading unavailable / degradation)

- Distance-sorted list of `NearbyTarget`s; each row shows `title`, `cardinalFor
  (trueBearing)` (e.g. "NE"), and formatted distance.
- A visible **note**: "Compass unavailable on this device" (heading `unsupported`
  on web/no-magnetometer, or `unavailable` after sensor failure/timeout).
- No live arrow, ever — the list never claims a real-time direction.
- Reuses M4's `formatNavDistance` for the distance string (one distance format
  app-wide).

### 4.5 `CompassModeView` (container)

- On build: `compassVisibleProvider = true`; on dispose: `false` +
  `compassLockedProvider.set(null)`.
- Watches `compassControllerProvider.availability`:
  - `available` → `CompassRadarView` (+ the locked arrow when a target is set).
  - `acquiring` → a brief "finding north…" affordance (bounded; Phase B's
    4 s acquire timeout then flips to `unavailable`).
  - `unavailable | unsupported` → `NearbyList`.
- Hosts the **filter**: a text field / chip row narrowing `nearbyTargetsProvider`
  output by title match (keeps the "everything" target set usable). Empty filter =
  nearest-12; filter narrows within the located set.
- Low-accuracy fix (`fix.isLowAccuracy`, >200 m) → surfaces the same honesty as
  PointMe (no "you're here"); blips still show relative to a coarse fix with a
  reliability note.

---

## 5. Data flow

```
locationControllerProvider.fix  ─┬─→ nearbyTargetsProvider ─→ blips (bearing+dist)
                                 └─→ CompassController ─────┐
headingServiceProvider.watch() ───→ CompassController ──────┴─→ CompassState
searchIndexProvider (venues+bldgs) → nearbyTargetsProvider     (heading + locked geom)
compassLockedProvider (tap blip) ──→ CompassController (which target is locked)
```

All coordinates are **geographic WGS84** — the same space Phase B bearing math
already uses (`fix.position`, `trueBearingDegrees`). `renderPoint`
(`CampusMapPoint`, CrsSimple map-units) is **never** used here (mid-ocean if fed to
bearing math). This mirrors M4's routing-coord discipline.

---

## 6. Degradation & honesty matrix

| Condition | Behavior |
|---|---|
| Web / no magnetometer (`unsupported`) | `NearbyList` + "compass unavailable" note. Mode still reachable. |
| Sensor failure/stall/timeout (`unavailable`) | Same `NearbyList` fallback (Phase B: terminal, never resurrect arrow). |
| Acquiring | Bounded "finding north…" (≤4 s) then resolves to available/unavailable. |
| No location fix (`fix == null`) | `nearbyTargetsProvider → []`; show "location needed" affordance (reuse Phase A messaging). |
| Low-accuracy fix (>200 m) | No "you're here"; reliability note; near-target short-circuit suppressed (PointMe rule). |
| Place has null routing coords | Excluded from targets entirely (no fake blip). |
| Empty index / all excluded | Empty-state ("nothing nearby to point to"). |

---

## 7. Accessibility

- 320×568 @ `textScale 2.0`: radar + filter + (fallback) list must not overflow;
  prove the last actionable row (a blip / list row / filter) is reachable+tappable
  (`scrollUntilVisible` + `ensureVisible` + `tap`), not merely "no overflow".
- Toggle segments: the **tooltip is the accessible name** → assert with
  `find.byTooltip`; third segment carries `Semantics(button, selected)`.
- Blips/rows: semantic label = "<title>, <cardinal>, <distance>".
- Reduced-motion: the rose must not spin continuously; blip placement updates
  without a jarring animation (respect `MediaQuery.disableAnimations`).
- Minimum tap target 56 px (`AonSpacing.minTapTarget`) for blips + segments.

---

## 8. l10n (EN + FA, real Persian)

New keys (names indicative): `mapModeCompass` (toggle label/tooltip),
`compassFindingNorth`, `compassUnavailable`, `compassUnavailableBody`,
`compassNearbyTitle`, `compassFilterHint`, `compassNothingNearby`,
`compassLocationNeeded`, `compassYouAreHere`, `compassReliabilityNote`, plus
cardinal short forms if not already localized (`cardinalN…cardinalNw`). Distances
reuse M4's `formatNavDistance`. Every EN key gets a real FA counterpart; placeholder
metadata (`@key`) for any interpolation.

---

## 9. Testing (the gate proves it, not paper review)

**Unit (`test/unit/`):**
- `nearby_targets_test.dart` — `routingLatLngOf` for venue/building/null;
  `nearestTargets` sort (distance asc, placeKey tiebreak), N-cap, null-coord
  exclusion, bearing correctness against known vectors.
- Cardinal mapping already covered by Phase B `bearing_math` tests (reuse; add a
  spot-check if a boundary is new).

**Widget (`test/widget/`):**
- `map_mode_toggle_test.dart` — 3 segments, tooltip = name, selected semantics,
  onChanged fires `MapMode.compass`.
- `compass_mode_view_test.dart` — availability routing: `available` → radar;
  `unsupported`/`unavailable` → `NearbyList` with note; `acquiring` → bounded
  affordance (no infinite spinner blocking `pumpAndSettle` — the M4 lesson).
- `compass_radar_view_test.dart` — blip present per target; tap blip sets
  `compassLockedProvider`; locked arrow renders from `CompassState`; facing
  indicator tracks `trueHeadingDegrees`; 320×568/2.0 no-overflow + reachable.
- `compass_controller_test.dart` — heading subscription starts on visible /
  cancels on dispose; `unavailable` is terminal (no resurrection); declination
  applied to `trueHeadingDegrees`; locked near-target + low-accuracy honesty.
- `nearby_list_test.dart` — distance order, cardinal labels, "unavailable" note,
  no arrow.
- Harness reuses `map_platform_wiring` patterns: override `headingServiceProvider`
  with a fake stream, `locationServiceProvider` with `FakeLocationService`,
  `buildingsProvider`/`venuesProvider` with small deterministic lists.
- **Gotchas to pre-empt:** fake heading via a `StreamController` (no real
  sensors); any `rootBundle`/decode in the map path wrapped in `t.runAsync`;
  `AsyncValue` via `.asData?.value`; icon buttons asserted by tooltip.

**Full gate:** `./scripts/check.sh full` — analyze clean, full `flutter test`,
buildings.json provenance SHA, l10n EN+FA complete, reskin py tests, **and**
web + apk + iOS-simulator builds green. Exit-gated commits (never `| tail`).

**On-device (release IOU, not code-blocking):** verify live heading on a physical
Android + iOS device (arrow tracks true bearing; declination applied; list
fallback on a device with the magnetometer disabled). Simulator has no
magnetometer → exercises the `unavailable` path, which is itself a valuable proof.

---

## 10. Interfaces consumed / produced (for the plan)

- **Consumes:** `headingServiceProvider`/`HeadingService`/`HeadingSample`/
  `HeadingAvailability`; `bearing_math` (`trueBearingDegrees`,
  `distanceBetweenMeters`, `relativeAngleDegrees`, `cardinalFor`,
  `normalizeBearing`); `MapConfig` (`campusMagneticDeclinationDegrees`,
  `pointMeNearTargetMeters`, **+new** `compassMaxTargets`);
  `searchIndexProvider`/`SearchEntry`/`PlaceKind`;
  `locationControllerProvider.fix` (`isLowAccuracy`, `position`);
  `formatNavDistance` (M4). **Does NOT touch** `PointMeController`/
  `pointMeTargetProvider` (left for `PointMeScreen`).
- **Produces:** `MapMode.compass`; `NearbyTarget`, `routingLatLngOf`,
  `nearestTargets`, `nearbyTargetsProvider`; `compassVisibleProvider`,
  `compassLockedProvider`, `CompassState`, `compassControllerProvider`;
  `CompassRadarView`, `NearbyList`, `CompassModeView`.

---

## 11. Scorecard (honest, 0–10; re-scored at closeout)

| Axis | Score | What raises it (named buildable) |
|---|---|---|
| Event fit (dark-adapted, on-theme) | 8 | On-device night trial in a dark field confirming red palette preserves scotopic vision + rose readable. |
| Reuse / low-risk | 9 | Already near-max: Phase B + M3 consumed, ~3 new widgets + 1 provider. |
| Honesty (parity + degradation) | 8 | Phantom-AR row reconciled in the matrix; degradation matrix implemented. Live proof of the `unavailable`→list path on a real no-mag device raises it. |
| A11y | 7 | 320×568/2.0 reachable + tooltip names + reduced-motion, proven by widget tests + one on-device VoiceOver/TalkBack pass. |
| Clutter control (170+ targets) | 7 | nearest-12 + filter shipped; user-tested that "everything" stays legible on the rose raises it. |

Deliberately **no 9s beyond reuse** pre-implementation — event-fit, honesty, and
a11y each owe a live proof, mirroring M4's held Credential/Privacy axes.

---

## 12. IOUs

- **On-device heading proof** (physical Android + iOS): arrow tracks true bearing,
  declination correct, list-fallback on magnetometer-off. (Shares the standing
  physical-smoke IOU.)
- **Heading-up rose variant** — if user testing prefers a counter-rotating
  (heading-up) rose over N-up. Deferred; N-up ships first.
- **Favorites filter** — the user chose the full venue+building set; a
  "favorites-only" filter toggle is a cheap future add, not in M5 scope.
- **buildings.json redistribution permission** — unchanged standing release gate;
  M5 surfaces building names in a new view but adds no new redistribution.

---

## 13. Open questions from the umbrella spec — resolved by this design

- **§Open-4 AR scope** → resolved: reduced compass/radar, not full/camera AR
  (phantom target; dark-event constraint).
- **§Open-6 Toggle target** → resolved: `{ campusMap, panorama, compass }` — keep
  panorama, add compass (honest naming, not `ar`).
- **§148 Camera permission (M5)** → resolved: **not added** (no camera).
