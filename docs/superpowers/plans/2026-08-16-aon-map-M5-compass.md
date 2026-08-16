# M5 — Compass / Radar Point-Me — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `MapMode.compass` — a night-vision compass/radar point-me finder in the Map tab that shows venue+building targets as blips around a heading-driven rose, locks any one for a big-arrow+distance, and degrades to a cardinal-bearing list when the magnetometer is unavailable.

**Architecture:** A third map mode reusing Phase B (`HeadingService`, `bearing_math`, `MapConfig` declination) and M3 (`searchIndexProvider`). A new `CompassController` owns an always-on-while-visible heading subscription; `nearbyTargetsProvider` computes venue-biased nearest targets from the unified index; `CompassModeView` wires it into `map_screen`. No camera, no AR framework, no new sensors, no new persistence.

**Tech Stack:** Flutter 3.44.7 / Dart ^3.11, Riverpod 3 (plain Notifier/Provider, no codegen), `latlong2`, existing `flutter_test`.

**Source of truth:** `docs/superpowers/specs/2026-08-16-aon-map-M5-compass-design.md`, **§0 (gauntlet amendments) supersedes the body.** This plan is generated from §0.

## Global Constraints (every task inherits these)

- **Riverpod 3:** no `StateProvider`; `Notifier<T>` with a **method** (never external `.state=` from outside); `AsyncValue` → `.asData?.value` (NOT `valueOrNull`); reads that shouldn't rebuild at 20 Hz use `.select`.
- **Provider mutation:** NEVER mutate a provider in widget `build()`/`dispose()` via `ref`. Capture `.notifier` in `initState`; set via `WidgetsBinding.instance.addPostFrameCallback`; release on captured notifiers in `dispose` inside `try/catch`. (Pattern: `point_me_screen.dart:50-88`, `app_shell.dart:76-82`.)
- **l10n:** every new EN key needs a real-Persian FA key (machine-fill forbidden); interpolations need an `@key` block in EN. Gate treats empty `untranslated_messages.json` as complete.
- **Data honesty:** null routing coords → no blip; non-null `DataConfidence.placeholder` → dimmed + "approximate", never crisp certainty; known-but-unlocatable venues → disabled "see printed map" row, never deleted.
- **A11y:** 320×568 @ textScale 2.0 no overflow AND last actionable row reachable+tappable (`scrollUntilVisible`+`ensureVisible`+`tap`); min tap target 56 (`AonSpacing.minTapTarget`); toggle segments assert via `find.bySemanticsLabel` (they use `Semantics(label:)`, **not** `Tooltip`).
- **Theme:** `context.aon.*` for chrome; compass red palette is compass-LOCAL tokens, never mutate `aon_palette`.
- **Commit gating (the one hard rule):** gate on `check.sh`'s own exit code, never through a pipe:
  ```bash
  ./scripts/check.sh > /tmp/gate.log 2>&1 && git add … && git commit … || { echo GATE FAILED; tail -40 /tmp/gate.log; }
  ```
- **Branch:** `feature/map-M5-compass` (already created, off `main@d20e9b3`; spec + gauntlet already committed there).

---

## 0. Plan gauntlet amendments (AUTHORITATIVE — supersede the task bodies where they conflict)

Applied 2026-08-16 after a 3-reviewer + self plan-gauntlet (compile/API · test-validity · §0-coverage/integration). **17 findings verified against the code, 0 rejected** (4 high, 7 medium, 6 low/minor); several plan tests were verified *sound* (subscribe-before-emit, T2 isolation, T8 dispose). Where a task below conflicts, **this section wins.**

### 0-A [HIGH, F1/F2] Rose and `NearbyList` COEXIST in every fix-acquired branch
The body made them mutually exclusive — violating §0.6 (list is the accessible tap path) and re-opening the §0.5 First-Aid safety gap on any working-magnetometer device. **`CompassModeView.build` (T8) renders, when `fix != null`:**
```dart
final avail = ref.watch(compassControllerProvider.select((s) => s.availability));
final body = switch (avail) {
  HeadingAvailability.available || HeadingAvailability.acquiring =>
    Column(children: [
      Expanded(flex: 3, child: CompassRadarView()),   // visual layer
      const Divider(height: 1),
      Expanded(flex: 2, child: NearbyList()),          // accessible 56px tap path + safety rows
    ]),
  HeadingAvailability.unavailable || HeadingAvailability.unsupported =>
    const NearbyList(),                                 // list only (no rose)
};
return Column(children: [_FilterField(...), Expanded(child: body)]);
```
- **T8 test:** in `available` mode assert `find.byType(NearbyList)` present AND `find.byType(CompassRadarView)` present.
- **T6 test:** the unlocatable First-Aid safety row is asserted in `NearbyList` regardless of heading (it already is; keep).

### 0-B [HIGH, F3] Locked-panel honesty — suppress crisp certainty for placeholder coords
`CompassController._compute` (T3) must consult the locked target's confidence. Change the `near` computation to:
```dart
reliable = !fix.isLowAccuracy && locked.confidence.isReliable; // isReliable => != placeholder
near = reliable && locked.distanceMeters <= MapConfig.pointMeNearTargetMeters;
```
`CompassState` gains `bool lockedApproximate` = `locked != null && !locked!.confidence.isReliable`. **T7** renders `l.compassApproximate` on the locked panel and **suppresses `l.compassYouAreHere`** when `lockedApproximate`. **T3 test:** lock a `DataConfidence.placeholder` target at ~0 m → assert `lockedNearTarget == false` and `lockedApproximate == true`.

### 0-C [HIGH, PT-7] Test the `acquiring` rose (null heading) + null-guard the painter
`acquiring` is the default first-paint (≤4 s) and routes to `CompassRadarView` with `trueHeadingDegrees == null`, `locked == null`. **The painter MUST null-guard** (`final h = state.trueHeadingDegrees; if (h != null) drawFacingWedge(h);`) and render a **static Icon+Text** acquiring hint (copy `point_me_screen.dart:159-161`), never a `CircularProgressIndicator`/`AnimationController`. **T7 test:** override the controller to `availability: acquiring, trueHeadingDegrees: null, locked: null`, non-null fix, render `CompassRadarView`, assert `find.byType(CircularProgressIndicator)` `findsNothing`, `takeException()` null, and no pending timers (test the frame with `pump()`).

### 0-D [HIGH, F6/PT-6] Toggle must not overflow at 320×568 / textScale 2.0
`_Segment` is a `mainAxisSize.min` Row with no `Flexible`; a 3rd "Compass"/FA "قطب‌نما" segment can RenderFlex-overflow the EXISTING test `panorama_responsive_test.dart:27` (renders `MapModeToggle` at 320/2.0, asserts `takeException() isNull`). **T5 fix (widget change, not a test edit):** wrap the toggle's `Row` in `FittedBox(fit: BoxFit.scaleDown)` inside the `GlassSurface` so it scales down only when it would overflow. **T5 test:** add a 320×568/2.0 `no-overflow` case for the 3-segment toggle; verify `panorama_responsive_test.dart` (its `'toggle @ 320x568 / 2.0'` case now exercises 3 segments) stays green.

### 0-E [MED, CA-2] `_Segment` Semantics = single labeled node
So `find.bySemanticsLabel(...)` `findsOneWidget` (T5) does not double-match the `Semantics(label:)` + descendant `Text(label)`. Set the `_Segment` Semantics to `Semantics(button: true, selected: selected, label: label, container: true, excludeSemantics: true, child: …)`. (Gesture + `find.text` still work; only the a11y tree collapses to one node.)

### 0-F [MED, CA-1] `nav_format` import path
T6 imports `package:aon2026/services/nav_format.dart` (it is in `lib/services/`, not `lib/widgets/`). Call site: `formatNavDistance(l, t.distanceMeters.round())`.

### 0-G [MED, PT-2/PT-3] T3 harness: override `searchIndexProvider` directly, use plain `test()`
T3's `_c` overrides **`searchIndexProvider.overrideWithValue([BuildingEntry(Building(id:'T', code:'T', name:'Tower', category: BuildingCategory.academic, latitude:-33.7700, longitude:151.1134, campusX:1, campusY:1))])`** — NOT `buildingsProvider` (avoids the async FutureProvider race; the locked target resolves synchronously). Convert the three T3 cases from `testWidgets`+`runAsync` to plain `test(...) async` with `await Future<void>.delayed(Duration.zero)` between emits (broadcast delivery drains on the microtask; no widget pumped).

### 0-H [MED, PT-4] Cover the real `nearbyTargetsProvider` end-to-end (T2)
Add a T2 test that does NOT override `nearbyTargetsProvider`: real `searchIndexProvider` (override with a small `[BuildingEntry, VenueEntry]`), `FakeLocationService` emits a fix, assert (a) with no fix → `[]`; (b) with fix → nearest target present; (c) setting `compassFilterProvider` narrows the result. Proves the null-fix-empty branch + filter passthrough the widget tests mock away.

### 0-I [MED, F4] "Nothing nearby" empty state
When `fix != null` and `nearbyTargetsProvider` is empty AND `unlocatableVenues` is empty, `NearbyList` renders `l.compassNothingNearby` (centered) instead of a blank `ListView`. **T6 test:** empty index → the message shows.

### 0-J [MED, F9] `_FilterField` is a real widget + tested
`_FilterField` is a `TextField` (hint `l.compassFilterHint`) whose `onChanged` calls `ref.read(compassFilterProvider.notifier).set(value)`. **T8 test:** type into it → `compassFilterProvider` updates → the visible target set narrows (pump a fix + a 2-entry index; type a query matching one; assert the other row is gone).

### 0-K [MED, F10] Compass a11y reachability proof
**T8 test** at 320×568 / textScale 2.0 (fix present, heading `available` so both rose and list render): `scrollUntilVisible` + `ensureVisible` + `tap` the LAST `NearbyList` row; assert it locks (`compassLockedProvider` set) and `takeException()` null. This is the "reachable+tappable, not just no-overflow" proof the global A11y constraint requires.

### 0-L [MED, §0.1 honesty] `_EnableLocation` distinguishes OFF from ACQUIRING; test denied retry
`CompassModeView.build`: show `_EnableLocation` only when location is **not active** (`ref.watch(locationControllerProvider.select((s) => !s.active))`); when active-but-no-fix-yet (granted, acquiring) show an acquiring affordance (spinner-free `l.compassFindingNorth`-style text), NOT `l.compassLocationNeeded`. **T8 test:** `FakeLocationService(grant: LocationStatus.denied)` → tapping `l.compassEnableLocation` calls `onLocateTapped` again (assert `svc` request count increments) — a working retry, not a dead end.

### 0-M [LOW, F5] Cap the filtered set to N
`nearestTargets`: the `if (q.isNotEmpty) return located;` branch becomes `return located.take(MapConfig.compassMaxTargets).toList();` (nearest-N of the filtered matches, per §0.2). The existing T1 filter test (single match `lib0`) still passes; add a case where >N match → capped to N.

### 0-N [LOW, F7] Guard the FAB invert
**T8 test:** pump `map_screen` (or assert on the mode) in `MapMode.compass` → `find.byType(FloatingActionButton)` `findsNothing` (the wayfinding FAB is `campusMap`-only). No existing test covers this, so the invert is otherwise silent.

### 0-O [LOW, F11] Radar test overrides a fake `CompassController`
`NotifierProvider` can't `overrideWithValue`. Define a `test/support/fake_compass_controller.dart` `class FakeCompassController extends CompassController { FakeCompassController(this._s); final CompassState _s; @override CompassState build() => _s; }` and use `compassControllerProvider.overrideWith(() => FakeCompassController(fixedState))` in T7's radar/acquiring/locked tests.

### 0-P [MINOR, CA-3/4/5/6] Tidy
- **Drop** the dead l10n key `compassDistanceAway` (EN+FA) — never consumed.
- `compassVisibleProvider` is defined ONCE, in `location_providers.dart` (T2); the File-Structure line grouping it under `compass_controller.dart` is descriptive of its *consumer*, not a second definition.
- Cite fix: `pointMeActiveProvider` is `location_providers.dart:58-67`.
- T6 helper: drop the misplaced `// ignore: prefer_const_constructors` (the fixture compiles without it).

### 0-Q Re-scored plan-readiness
The gauntlet converted "reuse" optimism into concrete work: the rose+list composition (0-A), locked-panel honesty (0-B), acquiring safety (0-C), and the overflow/semantics toggle fixes (0-D/0-E) are real additions. Task count unchanged (T1–T9); T7 and T8 grow. No blocker remains that would ship a green-but-broken feature.

---

## 0R. External design-review amendments (AUTHORITATIVE — supersede §0 and task bodies)

Applied 2026-08-16 after an external line-by-line design review (verdict: FAIL WITH BLOCKERS). 20 findings, **0 rejected**; ~9 were design-stale-vs-plan (already correct here), ~9 needed real changes. This block is the newest truth: it supersedes §0 and the task bodies. The single biggest catch — the **coordinate-frame mismatch (0R-1)** — slipped both prior gauntlets and is a genuine correctness bug.

### 0R-1 [BLOCKER] N-up coordinate coherence — locked marker uses ABSOLUTE bearing, not relative
On an N-up rose, blips sit at absolute `trueBearingDegrees`; the locked marker MUST use the **same frame** or the arrow and its own blip disagree. **Changes:**
- `CompassState` (T3): **remove `lockedRelativeAngle` from the rose contract.** Add `double? lockedTrueBearingDegrees` (= `locked.trueBearingDegrees`, absolute) and an OPTIONAL `double? lockedTurnDegrees` (= `relativeAngleDegrees(bearing, trueHeading)`) used ONLY for a textual "turn X° left/right" cue, never the rose arrow.
- `CompassRadarView` (T7): the locked target renders as a **highlighted blip + a center→bearing line at `lockedTrueBearingDegrees`** (same frame as every blip). The **facing indicator** sits at `trueHeadingDegrees`; the user rotates until the facing indicator overlaps the locked blip. No relative-angle arrow on the rose.
- Consequence for 0R-9/0R-12: with N-up, blips + locked marker are **heading-independent**; only the facing indicator moves with heading.

### 0R-2 [BLOCKER] Rename the cap + make the default set explicit
`MapConfig.compassMaxTargets` → **`compassMaxBuildingTargets` = 12** (bounds ONLY the building fill). `nearestTargets` param `maxBuildings` reads it. Explicit contract:
```
default (empty query)  = ALL locatable venues + nearest compassMaxBuildingTargets buildings
filtered (non-empty)   = nearest compassMaxBuildingTargets of the SCORED matches (0R-3)
```
Update every reference (T1 impl + tests, §0-M, scorecard). Expect ~17 venues + 12 buildings ≈ 29 default blips — intended (venues are the event); clutter handled by clustering (0R-8) + the list.

### 0R-3 [BLOCKER] Filter reuses M3 search vocabulary, not `title.contains`
`nearestTargets` filter predicate becomes `scoreEntry(e, normalizeMapSearch(q)) > 0` (import `scoreEntry` from `search_providers.dart:56`, `normalizeMapSearch` from `building_search.dart:4`) so building **codes/aliases/tokens** ("18WW", "LIB", "14SCO") match. Then distance-sort + cap. (T1)

### 0R-4 [BLOCKER] Unlocatable places are a SEPARATE representation (already in plan; pin it)
`NearbyTarget` requires coords, so unlocatable safety venues CANNOT be `NearbyTarget`s. They flow via `unlocatableVenues(index) → List<SearchEntry>` (T1) and render as **disabled** rows in `NearbyList` (T6) — a distinct code path from located targets. No T1/T6 code change; pins the contract the review flagged unclear.

### 0R-5 [BLOCKER] `NearbyTarget.confidence` (already in plan T1)
Confirmed present: `final DataConfidence confidence` + `confidenceOf` (venue→its confidence, building→confirmed). No change; the design body was stale, the plan is correct.

### 0R-6 [BLOCKER] Near-target certainty requires CONFIRMED coords (tighten §0-B)
"You're here" is a strong claim, so tighten §0-B from `isReliable` to **`== DataConfidence.confirmed`** (also excludes `derived`):
```dart
final reliable = !fix.isLowAccuracy && locked.confidence == DataConfidence.confirmed;
near = reliable && locked.distanceMeters <= MapConfig.pointMeNearTargetMeters;
```
Buildings are all `confirmed` so unaffected; only non-confirmed venues lose the "you're here" flourish (they still show distance + `compassApproximate`). (T3)

### 0R-7 [BLOCKER] Radius formula uses nearClamp (already correct in plan T7)
`blipRadiusFraction` = `((meters - compassNearClampMeters) / (compassFarClampMeters - compassNearClampMeters)).clamp(0,1)`. Plan T7 already wrote this; the **design** §0.6 `lerp(..., distance/farClamp)` form was buggy. No plan change; noted for the design reconcile.

### 0R-8 [MAJOR] De-collision by CLUSTERING, not by falsifying angle or radius
Angular offset lies about bearing; radial offset lies about distance (radius encodes distance). Replace `deCollide` with **`clusterByBearing(List<NearbyTarget>, minSepDeg) → List<BlipCluster>`**: targets whose true bearings fall within `compassMinAngularSepDegrees` (circular/wrap-aware) merge into one cluster marker at the group's true bearing with a **count badge**; the list disambiguates. Preserves both bearing and distance truth. **T7 tests:** two near-collinear → one cluster; **wrap `[359, 1]` → clustered** (2° apart, not 358°); separated → distinct markers.

### 0R-9 [MAJOR] Blips `ExcludeSemantics`; the list is the canonical a11y path
Rose blip/cluster hitboxes are `ExcludeSemantics` (sighted tap convenience only) so screen readers don't get duplicate items. `NearbyList` rows are the semantic buttons (56px, labels). (T7 removes blip Semantics labels; §0-A/0-K unchanged.)

### 0R-10 [MAJOR] Explicit state precedence in `CompassModeView` (T8, supersedes §0-A/§0-L order)
```
1. location not active (off/denied)       → Locate/Retry (_EnableLocation)
2. active && fix == null (acquiring GPS)  → "finding your location" (spinner-free)
3. heading available/acquiring            → N-up radar + NearbyList
4. heading unavailable/unsupported        → NearbyList only
```
Location precedes heading, so `unsupported heading + null fix` shows Locate/Retry, not an empty list.

### 0R-11 [MAJOR] `ensureLocationActive()` — not `onLocateTapped()`
`onLocateTapped` toggles map-**follow** on a 2nd call (`location_providers.dart:106`) — wrong for compass re-entry. Add to `LocationController`:
```dart
/// Activate location for a consumer that needs the stream but NOT map-follow
/// semantics (compass). No-op if already active; requests permission if not.
Future<void> ensureLocationActive() async {
  if (state.active) return;
  final s = await _svc.request();
  state = state.copyWith(status: s);
  if (s == LocationStatus.granted) { state = state.copyWith(active: true); _sync(); }
}
```
Compass `initState` post-frame + `_EnableLocation` retry call this (no `following: true`). (T2 adds method + test; T8 uses it.)

### 0R-12 [MAJOR] Provider-watch split to avoid 20 Hz rebuilds
Only the facing-indicator sub-widget watches `compassControllerProvider.select((s) => s.trueHeadingDegrees)`. Blips/clusters + `NearbyList` watch `nearbyTargetsProvider` (fix/filter, not heading). Locked marker watches `select((s) => s.lockedTrueBearingDegrees)`. A 20 Hz tick repaints only the facing indicator, not 29 blips + list + semantics. (T7/T8)

### 0R-13 [MAJOR] Scotopic palette accessibility floor
State (venue vs building vs approximate vs unlocatable) encoded by **icon/shape/label**, never red hue alone; `NearbyList` text meets AA contrast on near-black. (T6/T7 note + keep list legibility in the 320/2.0 test.)

### 0R-14 [MED] Test-matrix expansion + named real-entry regression
- **T1** adds: empty-query venue-survival + building-cap; non-empty filters full index before cull; a match ranked 13th-overall survives when the query selects it; tie → distance then placeKey; **filtered set capped** to N; `scoreEntry` matches a building CODE not in the title; a `placeholder` venue returned but flagged approximate.
- **T8** names the regression `fresh state (Locate never tapped) → enter compass → Locate/Retry shows → tap → ensureLocationActive → fake fix → targets appear` (the exact B4 bug).

### 0R-15 [MED, doc] Body reconcile (design)
The design body (§4.1 NearbyTarget, §4.2 CompassState, §4.3 rose, §0.6 radius/tooltip/56px-blips, §6 null-only exclusion) is revised to match this block so no stale sentence survives (review #20). Executor follows THIS plan's §0R/§0; the design edit is the human record.

### 0R-16 Readiness
Blockers 0R-1 (coord frame), 0R-8 (honest de-collision), 0R-11 (activation semantics), 0R-3 (filter vocabulary) are real behavior changes; the rest reconcile documents already ahead in the plan. Task count still T1–T9; T1/T3/T7/T8 grow. Geometry axis 6.5 → target 8 once clustering + coord-frame land with tests.

---

## File Structure

**Create:**
- `lib/services/nearby_targets.dart` — `NearbyTarget`, `routingLatLngOf`, `confidenceOf`, `nearestTargets`, `unlocatableVenues`, `nearbyTargetsProvider`, `compassFilterProvider`.
- `lib/services/compass_controller.dart` — `compassVisibleProvider`, `compassLockedProvider`, `CompassState`, `CompassController`, `compassControllerProvider`.
- `lib/widgets/nearby_list.dart` — `NearbyList` (targets + disabled unlocatable rows).
- `lib/widgets/compass_radar_view.dart` — `CompassRadarView` (rose, blips, locked arrow) + pure layout helpers `blipRadiusFraction`, `deCollide`.
- `lib/widgets/compass_mode_view.dart` — `CompassModeView` (visibility + locate + availability routing + filter host).
- Tests: `test/unit/nearby_targets_test.dart`, `test/unit/compass_controller_test.dart`, `test/widget/map_mode_toggle_test.dart`, `test/widget/nearby_list_test.dart`, `test/widget/compass_radar_view_test.dart`, `test/widget/compass_mode_view_test.dart`.

**Modify:**
- `lib/widgets/map_config.dart` — compass constants.
- `lib/services/location_providers.dart` — add `compassVisibleProvider` to the gate (B4).
- `lib/widgets/map_mode_toggle.dart` — `enum MapMode` gains `compass`; per-mode l10n labels.
- `lib/screens/map_screen.dart` — 3-way mode branch + FAB `campusMap`-only.
- `lib/l10n/app_en.arb` + `app_fa.arb` — new keys.

---

## Task 1: Pure target selection (`nearby_targets.dart` — model + helpers)

**Files:**
- Create: `lib/services/nearby_targets.dart`
- Modify: `lib/widgets/map_config.dart`
- Test: `test/unit/nearby_targets_test.dart`

**Interfaces:**
- Consumes: `SearchEntry`/`VenueEntry`/`BuildingEntry`/`PlaceKind` (`lib/models/search_entry.dart`); `Venue.routingLatitude/Longitude` + `Venue.coordinateConfidence` (`venue.dart:104,70`); `Building.routingLatitude/Longitude` (`building.dart:45`); `DataConfidence` (`data_confidence.dart`); `trueBearingDegrees`/`distanceBetweenMeters` (`bearing_math.dart`); `LatLng` (`latlong2`).
- Produces: `NearbyTarget`, `(double,double)? routingLatLngOf(SearchEntry)`, `DataConfidence confidenceOf(SearchEntry)`, `List<NearbyTarget> nearestTargets(LatLng fix, List<SearchEntry> index, {String filter, int maxBuildings})`, `List<SearchEntry> unlocatableVenues(List<SearchEntry> index)`.

- [ ] **Step 1: Add MapConfig constants.** In `lib/widgets/map_config.dart`, after `pointMeNearTargetMeters`:
```dart
  /// Compass mode — max NEAREST buildings shown in the default (unfiltered) rose.
  /// Venues are never culled by this; it bounds only the building fill (§0.2).
  static const int compassMaxTargets = 12;
  /// Blip radius transfer clamps (metres) — nearer→center, farther→rim (§0.6).
  static const double compassNearClampMeters = 25;
  static const double compassFarClampMeters = 800;
  /// Two blips within this angular gap (deg) are de-collided by stacking (§0.6).
  static const double compassMinAngularSepDegrees = 8;
```

- [ ] **Step 2: Write the failing test** `test/unit/nearby_targets_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/nearby_targets.dart';

// Campus-ish anchor.
const _fix = LatLng(-33.7737, 151.1134);
Venue _v(String id, {double? lat, double? lng, DataConfidence c = DataConfidence.confirmed}) =>
    Venue(id: id, name: id, category: VenueCategory.other,
        latitude: lat, longitude: lng, coordinateConfidence: c);
Building _b(String id, {required double lat, required double lng}) =>
    Building(id: id, code: id, name: id, category: BuildingCategory.academic,
        latitude: lat, longitude: lng, campusX: 1, campusY: 1);

void main() {
  test('routingLatLngOf: venue/building present, null when no coords', () {
    expect(routingLatLngOf(VenueEntry(_v('a', lat: -33.77, lng: 151.11))), isNotNull);
    expect(routingLatLngOf(VenueEntry(_v('b'))), isNull); // null coords
    expect(routingLatLngOf(BuildingEntry(_b('c', lat: -33.77, lng: 151.11))), isNotNull);
  });

  test('confidenceOf: venue carries its confidence; building = confirmed', () {
    expect(confidenceOf(VenueEntry(_v('a', lat: -33.77, lng: 151.11,
        c: DataConfidence.placeholder))), DataConfidence.placeholder);
    expect(confidenceOf(BuildingEntry(_b('c', lat: -33.77, lng: 151.11))),
        DataConfidence.confirmed);
  });

  test('default set: ALL locatable venues + nearest maxBuildings buildings (venue-bias)', () {
    final index = <SearchEntry>[
      VenueEntry(_v('vFar', lat: -33.80, lng: 151.14)),   // far venue: still kept
      for (var i = 0; i < 20; i++)
        BuildingEntry(_b('b$i', lat: -33.7737 + i * 0.0005, lng: 151.1134)),
    ];
    final out = nearestTargets(_fix, index, maxBuildings: 12);
    expect(out.where((t) => t.kind == PlaceKind.venue).length, 1); // far venue survives
    expect(out.where((t) => t.kind == PlaceKind.building).length, 12); // capped
  });

  test('filter searches the FULL index, not the culled set (13th-nearest findable)', () {
    final index = <SearchEntry>[
      for (var i = 0; i < 20; i++)
        BuildingEntry(_b('Lib$i', lat: -33.7737 + (20 - i) * 0.001, lng: 151.1134)),
    ]; // Lib19 is nearest, Lib0 farthest
    final filtered = nearestTargets(_fix, index, filter: 'lib0');
    expect(filtered.map((t) => t.placeKey), contains('building:Lib0')); // far, but matched
  });

  test('null-coord entries excluded from targets; sorted by distance then key', () {
    final index = <SearchEntry>[
      VenueEntry(_v('noCoord')),
      BuildingEntry(_b('near', lat: -33.7738, lng: 151.1134)),
      BuildingEntry(_b('far', lat: -33.79, lng: 151.14)),
    ];
    final out = nearestTargets(_fix, index);
    expect(out.map((t) => t.placeKey), ['building:near', 'building:far']);
  });

  test('unlocatableVenues: venues with null coords surfaced (safety rows)', () {
    final index = <SearchEntry>[
      VenueEntry(_v('first-aid')),
      VenueEntry(_v('ok', lat: -33.77, lng: 151.11)),
      BuildingEntry(_b('b', lat: -33.77, lng: 151.11)),
    ];
    expect(unlocatableVenues(index).map((e) => e.placeKey), ['venue:first-aid']);
  });
}
```

- [ ] **Step 3: Run it, verify it fails** — `flutter test test/unit/nearby_targets_test.dart` → FAIL (`nearby_targets.dart` missing). (First run after touching pubspec is cold; here no pubspec change so fast.)

- [ ] **Step 4: Implement** `lib/services/nearby_targets.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

/// One findable place with live geometry to the user's fix. Geographic WGS84.
class NearbyTarget {
  const NearbyTarget({
    required this.placeKey,
    required this.title,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.trueBearingDegrees,
    required this.confidence,
  });
  final String placeKey;
  final String title;
  final PlaceKind kind;
  final double lat, lng;
  final double distanceMeters;
  final double trueBearingDegrees;
  final DataConfidence confidence;
}

/// Routing coords for an entry — SAME rule placeResolverProvider uses
/// (entrance pair else centre). Null ⇒ not locatable.
(double, double)? routingLatLngOf(SearchEntry e) {
  final (lat, lng) = switch (e) {
    VenueEntry(:final venue) => (venue.routingLatitude, venue.routingLongitude),
    BuildingEntry(:final building) => (building.routingLatitude, building.routingLongitude),
  };
  if (lat == null || lng == null) return null;
  return (lat, lng);
}

/// Venues carry provenance; buildings come from the survey registry (no field).
DataConfidence confidenceOf(SearchEntry e) => switch (e) {
      VenueEntry(:final venue) => venue.coordinateConfidence,
      BuildingEntry() => DataConfidence.confirmed,
    };

NearbyTarget _target(SearchEntry e, LatLng fix, double lat, double lng) {
  final to = LatLng(lat, lng);
  return NearbyTarget(
    placeKey: e.placeKey, title: e.title, kind: e.kind, lat: lat, lng: lng,
    distanceMeters: distanceBetweenMeters(fix, to),
    trueBearingDegrees: trueBearingDegrees(fix, to),
    confidence: confidenceOf(e),
  );
}

int _byDistance(NearbyTarget a, NearbyTarget b) {
  final d = a.distanceMeters.compareTo(b.distanceMeters);
  return d != 0 ? d : a.placeKey.compareTo(b.placeKey);
}

/// Venue-biased nearest targets (§0.2). Filter applies to the FULL index first;
/// empty filter → all locatable venues + nearest [maxBuildings] buildings.
List<NearbyTarget> nearestTargets(
  LatLng fix,
  List<SearchEntry> index, {
  String filter = '',
  int maxBuildings = MapConfig.compassMaxTargets,
}) {
  final q = filter.trim().toLowerCase();
  final located = <NearbyTarget>[];
  for (final e in index) {
    final ll = routingLatLngOf(e);
    if (ll == null) continue;
    if (q.isNotEmpty && !e.title.toLowerCase().contains(q)) continue;
    located.add(_target(e, fix, ll.$1, ll.$2));
  }
  located.sort(_byDistance);
  if (q.isNotEmpty) return located; // filtered: all matches, nearest-first
  final venues = located.where((t) => t.kind == PlaceKind.venue);
  final buildings =
      located.where((t) => t.kind == PlaceKind.building).take(maxBuildings);
  return [...venues, ...buildings]..sort(_byDistance);
}

/// Known-but-unlocatable venues (null coords) — surfaced as disabled rows so a
/// safety venue like First Aid is never silently dropped (§0.5).
List<SearchEntry> unlocatableVenues(List<SearchEntry> index) => index
    .where((e) => e.kind == PlaceKind.venue && routingLatLngOf(e) == null)
    .toList();
```
(Providers are added in Task 2; this file stays pure-testable now.)

- [ ] **Step 5: Run test, verify PASS** — `flutter test test/unit/nearby_targets_test.dart`.

- [ ] **Step 6: Commit** (docs/logic only; run the quick gate):
```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && git add lib/widgets/map_config.dart lib/services/nearby_targets.dart test/unit/nearby_targets_test.dart && git commit -m "feat(map): M5 T1 — pure venue-biased nearest-targets + honest coord/confidence helpers" || { echo GATE FAILED; tail -40 /tmp/gate.log; }
```

---

## Task 2: Providers + location gate (B4)

**Files:**
- Modify: `lib/services/nearby_targets.dart` (add providers), `lib/services/location_providers.dart`
- Test: `test/unit/nearby_targets_test.dart` (extend), `test/unit/compass_location_gate_test.dart` (new)

**Interfaces:**
- Consumes: `searchIndexProvider` (`search_providers.dart:41`), `locationControllerProvider` (`location_providers.dart:69`), `mapVisibleProvider`, `pointMeActiveProvider`.
- Produces: `compassVisibleProvider` (`NotifierProvider<CompassVisible,bool>`), `compassFilterProvider` (`NotifierProvider<CompassFilter,String>`), `nearbyTargetsProvider` (`Provider<List<NearbyTarget>>`).

- [ ] **Step 1: Add `compassVisibleProvider` to `location_providers.dart`.** After `pointMeActiveProvider` (`:59-67`) add:
```dart
/// True while the compass mode is on-screen. OR'd into the location gate so the
/// GPS stream stays alive in compass mode (Map Parity M5, §0.1/B4).
final compassVisibleProvider =
    NotifierProvider<CompassVisibleNotifier, bool>(CompassVisibleNotifier.new);

class CompassVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool visible) {
    if (state != visible) state = visible;
  }
}
```
Then wire it into the controller: in `LocationController.build()` after `:83` add `ref.listen(compassVisibleProvider, (_, _) => _sync());` and in `_sync()` change `:115-116` to:
```dart
    final wantStream = state.active &&
        (ref.read(mapVisibleProvider) ||
            ref.read(pointMeActiveProvider) ||
            ref.read(compassVisibleProvider));
```
Also in `_sync()`'s hidden-drop-follow guard (`:124`) leave as-is (map-specific).

- [ ] **Step 2: Write failing gate test** `test/unit/compass_location_gate_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import '../support/fake_location_service.dart';

void main() {
  test('compassVisible + active keeps the location stream alive (B4)', () async {
    final svc = FakeLocationService(grant: LocationStatus.granted);
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(svc),
    ]);
    addTearDown(c.dispose);
    c.read(locationControllerProvider); // instantiate
    // Simulate compass entry: activate location, mark compass visible.
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(compassVisibleProvider.notifier).set(true);
    svc.emit(UserLocationFix(position: const LatLng(-33.77, 151.11), accuracyMeters: 8));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix, isNotNull); // streamed while compass-only
  });
}
```

- [ ] **Step 3: Run, verify FAIL** (compass not yet in the gate if Step 1 skipped, or provider missing). `flutter test test/unit/compass_location_gate_test.dart`.

- [ ] **Step 4: Add the providers to `nearby_targets.dart`** (append):
```dart
/// The compass filter string (title contains). Notifier method, no external set.
final compassFilterProvider =
    NotifierProvider<CompassFilter, String>(CompassFilter.new);

class CompassFilter extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

/// Venue-biased nearest targets for the current fix + filter. Empty when no fix.
final nearbyTargetsProvider = Provider<List<NearbyTarget>>((ref) {
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  if (fix == null) return const <NearbyTarget>[];
  final index = ref.watch(searchIndexProvider);
  final filter = ref.watch(compassFilterProvider);
  return nearestTargets(fix.position, index, filter: filter);
});
```

- [ ] **Step 5: Run, verify PASS** — `flutter test test/unit/compass_location_gate_test.dart test/unit/nearby_targets_test.dart`.

- [ ] **Step 6: Commit:**
```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && git add lib/services/nearby_targets.dart lib/services/location_providers.dart test/unit/compass_location_gate_test.dart && git commit -m "feat(map): M5 T2 — compassVisible in location gate (B4) + nearby/filter providers" || { echo GATE FAILED; tail -40 /tmp/gate.log; }
```

---

## Task 3: `CompassController` (heading, terminal latch, locked-survives-cull)

**Files:**
- Create: `lib/services/compass_controller.dart`
- Test: `test/unit/compass_controller_test.dart`

**Interfaces:**
- Consumes: `headingServiceProvider`/`HeadingSample`/`HeadingAvailability` (`heading_service.dart`, `point_me_controller.dart:30`), `compassVisibleProvider`, `compassLockedProvider` (produced here), `locationControllerProvider`, `searchIndexProvider`, `NearbyTarget`/`routingLatLngOf`/`confidenceOf`, `bearing_math` (`relativeAngleDegrees`, `normalizeBearing` from `latlong2`), `MapConfig`.
- Produces: `compassLockedProvider` (`NotifierProvider<CompassLocked,String?>`), `CompassState`, `compassControllerProvider`.

- [ ] **Step 1: Write failing test** `test/unit/compass_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/point_me_controller.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeHeadingService h, FakeLocationService l) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(l),
    buildingsProvider.overrideWith((ref) async =>
        const [Building(id: 'T', code: 'T', name: 'Tower', category: BuildingCategory.academic,
            latitude: -33.7700, longitude: 151.1134, campusX: 1, campusY: 1)]),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  testWidgets('unavailable is TERMINAL — a later available does NOT resurrect', (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService();
    final c = _c(h, l);
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider); // subscribe
    await t.runAsync(() async {
      await _settle();
      h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 10));
      await _settle();
      h.emit(const HeadingSample(availability: HeadingAvailability.unavailable));
      await _settle();
      h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 90));
      await _settle();
    });
    expect(c.read(compassControllerProvider).availability, HeadingAvailability.unavailable);
  });

  testWidgets('declination applied to true heading', (t) async {
    final h = FakeHeadingService();
    final c = _c(h, FakeLocationService());
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider);
    await t.runAsync(() async {
      await _settle();
      h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
      await _settle();
    });
    // 0 magnetic + 12.752 E declination = 12.752 true.
    expect(c.read(compassControllerProvider).trueHeadingDegrees, closeTo(12.752, 0.01));
  });

  testWidgets('locked target resolves against the FULL index (survives the cull)', (t) async {
    final h = FakeHeadingService();
    final l = FakeLocationService();
    final c = _c(h, l);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(compassVisibleProvider.notifier).set(true);
    c.read(compassControllerProvider);
    await t.runAsync(() async {
      l.emit(UserLocationFix(position: const LatLng(-33.7737, 151.1134), accuracyMeters: 8));
      await _settle();
      c.read(compassLockedProvider.notifier).set('building:T');
      h.emit(const HeadingSample(availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
      await _settle();
    });
    final s = c.read(compassControllerProvider);
    expect(s.locked?.placeKey, 'building:T');
    expect(s.locked!.distanceMeters, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run, verify FAIL** — `flutter test test/unit/compass_controller_test.dart` (missing file).

- [ ] **Step 3: Implement** `lib/services/compass_controller.dart`:
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/point_me_controller.dart' show headingServiceProvider;
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

/// Locked target key (tap a blip/row). Compass-local; NOT pointMeTargetProvider.
final compassLockedProvider =
    NotifierProvider<CompassLocked, String?>(CompassLocked.new);

class CompassLocked extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? placeKey) => state = placeKey;
}

class CompassState {
  const CompassState({
    required this.availability,
    this.trueHeadingDegrees,
    this.locked,
    this.lockedRelativeAngle,
    this.lockedNearTarget = false,
    this.locationReliable = false,
    this.hasFix = false,
  });
  final HeadingAvailability availability;
  final double? trueHeadingDegrees;
  final NearbyTarget? locked;
  final double? lockedRelativeAngle;
  final bool lockedNearTarget, locationReliable, hasFix;
}

final compassControllerProvider =
    NotifierProvider<CompassController, CompassState>(CompassController.new);

class CompassController extends Notifier<CompassState> {
  StreamSubscription<HeadingSample>? _sub;
  int _gen = 0;
  bool _terminal = false; // §0.3/M8: once unavailable in a session, latched
  HeadingAvailability _avail = HeadingAvailability.acquiring;
  double? _magnetic;

  @override
  CompassState build() {
    ref.onDispose(_cancelSub);
    ref.listen(compassVisibleProvider, (_, v) => v ? _subscribe() : _cancelSub());
    ref.listen(compassLockedProvider, (_, _) => _recompute());
    ref.listen(locationControllerProvider, (_, _) => _recompute());
    if (ref.read(compassVisibleProvider)) _subscribe(); // subscribe only
    return _compute();
  }

  void _subscribe() {
    _cancelSub();
    final gen = ++_gen;
    _terminal = false;
    _avail = HeadingAvailability.acquiring;
    _magnetic = null;
    _sub = ref.read(headingServiceProvider).watch().listen((s) {
      if (gen != _gen || _terminal) return; // stale session OR latched
      if (s.availability == HeadingAvailability.unavailable ||
          s.availability == HeadingAvailability.unsupported) {
        _terminal = true;
      }
      _avail = s.availability;
      _magnetic = s.magneticHeadingDegrees;
      _recompute();
    }, onError: (_) {
      if (gen != _gen) return;
      _terminal = true;
      _avail = HeadingAvailability.unavailable;
      _magnetic = null;
      _recompute();
    });
  }

  void _cancelSub() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void _recompute() => state = _compute();

  CompassState _compute() {
    final trueHeading = _magnetic == null
        ? null
        : normalizeBearing(_magnetic! + MapConfig.campusMagneticDeclinationDegrees);
    final fix = ref.read(locationControllerProvider).fix;
    final lockedKey = ref.read(compassLockedProvider);
    NearbyTarget? locked;
    double? rel;
    var near = false, reliable = false;
    if (lockedKey != null && fix != null) {
      locked = _resolveLocked(lockedKey, fix.position);
      if (locked != null) {
        reliable = !fix.isLowAccuracy;
        near = reliable && locked.distanceMeters <= MapConfig.pointMeNearTargetMeters;
        if (trueHeading != null && !near) {
          rel = relativeAngleDegrees(locked.trueBearingDegrees, trueHeading);
        }
      }
    }
    return CompassState(
      availability: _avail,
      trueHeadingDegrees: trueHeading,
      locked: locked,
      lockedRelativeAngle: rel,
      lockedNearTarget: near,
      locationReliable: reliable,
      hasFix: fix != null,
    );
  }

  /// Resolve the locked key against the FULL index (not the culled/filtered set).
  NearbyTarget? _resolveLocked(String key, LatLng fix) {
    for (final e in ref.read(searchIndexProvider)) {
      if (e.placeKey != key) continue;
      final ll = routingLatLngOf(e);
      if (ll == null) return null;
      final to = LatLng(ll.$1, ll.$2);
      return NearbyTarget(
        placeKey: key, title: e.title, kind: e.kind, lat: ll.$1, lng: ll.$2,
        distanceMeters: distanceBetweenMeters(fix, to),
        trueBearingDegrees: trueBearingDegrees(fix, to),
        confidence: confidenceOf(e),
      );
    }
    return null;
  }
}
```

- [ ] **Step 4: Run, verify PASS** — `flutter test test/unit/compass_controller_test.dart`. (If `headingServiceProvider` import path differs, it lives at `point_me_controller.dart:30` — verified.)

- [ ] **Step 5: Commit:**
```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && git add lib/services/compass_controller.dart test/unit/compass_controller_test.dart && git commit -m "feat(map): M5 T3 — CompassController (terminal latch, sole-cancel, locked-survives-cull, declination)" || { echo GATE FAILED; tail -40 /tmp/gate.log; }
```

---

## Task 4: l10n keys (EN + FA)

**Files:** Modify `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`. Test: the gate's l10n completeness.

**Interfaces:** Produces l10n getters used by T5–T8. Cardinals REUSE existing long-form `cardinalN…cardinalNW` (§0.7/m4) — no new cardinal keys.

- [ ] **Step 1: Add EN keys** to `app_en.arb` (values chosen so existing `find.text('Map')`/`find.text('360°')` taps survive — §0.4):
```json
  "mapModeMap": "Map",
  "mapModePanorama": "360°",
  "mapModeCompass": "Compass",
  "compassFindingNorth": "Finding north…",
  "compassUnavailable": "Compass unavailable on this device",
  "compassUnavailableBody": "Showing what's nearby with directions instead.",
  "compassNearbyTitle": "Nearby",
  "compassFilterHint": "Filter places",
  "compassNothingNearby": "Nothing nearby to point to yet.",
  "compassLocationNeeded": "Turn on location to find your way",
  "compassEnableLocation": "Enable location",
  "compassYouAreHere": "You're basically there",
  "compassApproximate": "Approximate location",
  "compassUnlocatable": "Location unknown — see the printed map",
```

- [ ] **Step 2: Add FA keys** (real Persian) to `app_fa.arb`:
```json
  "mapModeMap": "نقشه",
  "mapModePanorama": "۳۶۰°",
  "mapModeCompass": "قطب‌نما",
  "compassFindingNorth": "در حال یافتن شمال…",
  "compassUnavailable": "قطب‌نما روی این دستگاه در دسترس نیست",
  "compassUnavailableBody": "در عوض مکان‌های نزدیک به همراه جهت نشان داده می‌شود.",
  "compassNearbyTitle": "نزدیک شما",
  "compassFilterHint": "فیلتر مکان‌ها",
  "compassNothingNearby": "هنوز جایی برای نشان‌دادن نزدیک نیست.",
  "compassLocationNeeded": "برای مسیریابی، موقعیت مکانی را روشن کنید",
  "compassEnableLocation": "روشن‌کردن موقعیت مکانی",
  "compassYouAreHere": "تقریباً رسیده‌اید",
  "compassApproximate": "موقعیت تقریبی",
  "compassUnlocatable": "موقعیت نامشخص — نقشهٔ چاپی را ببینید",
```

- [ ] **Step 3: Regenerate + verify completeness:**
```bash
flutter gen-l10n && test -s .dart_tool/untranslated_messages.json && cat .dart_tool/untranslated_messages.json || echo "l10n complete"
```
Expected: `{}`/empty → "l10n complete".

- [ ] **Step 4: Commit:**
```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && git add lib/l10n/app_en.arb lib/l10n/app_fa.arb && git commit -m "feat(map): M5 T4 — compass l10n EN+FA (reuse long-form cardinals)" || { echo GATE FAILED; tail -40 /tmp/gate.log; }
```

---

## Task 5: `MapMode.compass` + 3-segment toggle

**Files:** Modify `lib/widgets/map_mode_toggle.dart`. Test: `test/widget/map_mode_toggle_test.dart`; re-run `map_platform_wiring_test.dart`, `map_variant_wiring_test.dart`, `panorama_responsive_test.dart`.

**Interfaces:** Produces `MapMode { campusMap, panorama, compass }`; toggle renders 3 l10n'd segments with `Semantics(button, selected, label)`.

- [ ] **Step 1: Write failing test** `test/widget/map_mode_toggle_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/map_mode_toggle.dart';

Widget _app(MapMode v, ValueChanged<MapMode> onCh) => MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: Center(child: MapModeToggle(value: v, onChanged: onCh))),
    );

void main() {
  testWidgets('renders 3 segments; compass selectable via Semantics label', (t) async {
    MapMode? picked;
    await t.pumpWidget(_app(MapMode.campusMap, (m) => picked = m));
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.bySemanticsLabel(l.mapModeMap), findsOneWidget);
    expect(find.bySemanticsLabel(l.mapModePanorama), findsOneWidget);
    expect(find.bySemanticsLabel(l.mapModeCompass), findsOneWidget);
    await t.tap(find.bySemanticsLabel(l.mapModeCompass));
    expect(picked, MapMode.compass);
  });
}
```

- [ ] **Step 2: Run, verify FAIL** (enum has no `compass`, labels not l10n'd).

- [ ] **Step 3: Implement.** In `map_mode_toggle.dart`: extend the enum and l10n the label. Replace `enum MapMode { campusMap, panorama }` with `enum MapMode { campusMap, panorama, compass }`. Make `MapModeToggle.build` obtain `final l = AonL10n.of(context);` and replace the `_Segment` label ternary (`:29`) with:
```dart
            _Segment(
              label: switch (mode) {
                MapMode.campusMap => l.mapModeMap,
                MapMode.panorama => l.mapModePanorama,
                MapMode.compass => l.mapModeCompass,
              },
              selected: value == mode,
              onTap: () => onChanged(mode),
            ),
```
(Add `import 'package:aon2026/l10n/generated/app_localizations.dart';`.)

- [ ] **Step 4: Run new test, verify PASS.** Then run the three at-risk tests:
```bash
flutter test test/widget/map_mode_toggle_test.dart test/widget/map_platform_wiring_test.dart test/widget/map_variant_wiring_test.dart test/widget/panorama_responsive_test.dart
```
Expected: PASS (EN values preserved). **If any is red** because it asserts exactly 2 segments (e.g. `findsNWidgets(2)`) or taps a now-Semantics-only label, fix that test to the 3-segment reality (update the count / use `find.bySemanticsLabel`) — that is the correct fix, not reverting the widget.

- [ ] **Step 5: Commit** (`git add` the toggle + the new test + any of the three tests you had to update).

---

## Task 6: `NearbyList` (fallback + disabled unlocatable rows)

**Files:** Create `lib/widgets/nearby_list.dart`. Test: `test/widget/nearby_list_test.dart`.

**Interfaces:**
- Consumes: `nearbyTargetsProvider`, `unlocatableVenues`+`searchIndexProvider`, `NearbyTarget`, `cardinalFor`+`Cardinal` (`bearing_math.dart`), `formatNavDistance` (`nav_format.dart:5`, takes `int`), `DataConfidence`, l10n.
- Produces: `NearbyList` (`ConsumerWidget`). Row tap → `compassLockedProvider.set(placeKey)`.

- [ ] **Step 1: Write failing test** `test/widget/nearby_list_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/nearby_list.dart';

NearbyTarget _t(String k, {double d = 100, DataConfidence c = DataConfidence.confirmed}) =>
    NearbyTarget(placeKey: k, title: k, kind: PlaceKind.building, lat: -33.77, lng: 151.11,
        distanceMeters: d, trueBearingDegrees: 45, confidence: c);

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: NearbyList()),
      ),
    );

void main() {
  testWidgets('tapping a row locks that target; distance + cardinal shown', (t) async {
    final c = ProviderContainer(overrides: [
      nearbyTargetsProvider.overrideWithValue([_t('building:A', d: 412)]),
      searchIndexProvider.overrideWithValue(const []),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.textContaining('412'), findsOneWidget); // formatNavDistance rounded
    await t.tap(find.text('building:A'));
    await t.pumpAndSettle();
    expect(c.read(compassLockedProvider), 'building:A');
  });

  testWidgets('unlocatable venue shows a DISABLED "see printed map" row (safety)', (t) async {
    final c = ProviderContainer(overrides: [
      nearbyTargetsProvider.overrideWithValue(const []),
      searchIndexProvider.overrideWithValue([VenueEntry(_venue('first-aid'))]),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(_app(c));
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.pumpAndSettle();
    expect(find.text('first-aid'), findsOneWidget);
    expect(find.text(l.compassUnlocatable), findsOneWidget);
  });
}

// Helper: a venue with no coords.
VenueEntry _venue(String id) => VenueEntry(
    // ignore: prefer_const_constructors
    Venue(id: id, name: id, category: VenueCategory.other));
```
(Add the needed `import 'package:aon2026/models/venue.dart';`.)

- [ ] **Step 2: Run, verify FAIL** (missing widget).

- [ ] **Step 3: Implement** `lib/widgets/nearby_list.dart` — a `ConsumerWidget` returning a `ListView` (scrollable, so 320×568/2.0 can't overflow): map `nearbyTargetsProvider` to `ListTile`s (`title: Text(t.title)`, `subtitle: '${cardinal} · ${formatNavDistance(l, t.distanceMeters.round())}'`, `onTap: () => ref.read(compassLockedProvider.notifier).set(t.placeKey)`, dimmed + `l.compassApproximate` when `!t.confidence.isReliable`), then append `unlocatableVenues(ref.watch(searchIndexProvider))` as **disabled** `ListTile`s (`enabled: false`, `subtitle: Text(l.compassUnlocatable)`). Cardinal via `cardinalFor(t.trueBearingDegrees)` mapped to the long-form l10n key (switch on `Cardinal`). Min row height `AonSpacing.minTapTarget`.

- [ ] **Step 4: Run, verify PASS.**

- [ ] **Step 5: Commit.**

---

## Task 7: `CompassRadarView` (rose, radius fn, de-collision, locked arrow)

**Files:** Create `lib/widgets/compass_radar_view.dart`. Test: `test/widget/compass_radar_view_test.dart`.

**Interfaces:**
- Consumes: `nearbyTargetsProvider`, `compassControllerProvider` (`.select`), `compassLockedProvider`, `NearbyTarget`, `MapConfig` (clamps, min-sep), `context.aon` (background only).
- Produces: `CompassRadarView` (`ConsumerWidget`); pure `double blipRadiusFraction(double meters)`; pure `List<double> deCollide(List<double> bearingsDeg)`.

- [ ] **Step 1: Write failing test** `test/widget/compass_radar_view_test.dart` (pure helpers first, they carry the load-bearing math):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('blipRadiusFraction: near→center, far→rim, clamped to [0,1]', () {
    expect(blipRadiusFraction(0), lessThan(0.15));
    expect(blipRadiusFraction(MapConfig.compassFarClampMeters * 2), 1.0); // clamped
    expect(blipRadiusFraction(MapConfig.compassNearClampMeters), inInclusiveRange(0.0, 1.0));
    final a = blipRadiusFraction(50), b = blipRadiusFraction(400);
    expect(a, lessThan(b)); // monotonic
  });

  test('deCollide: two near-collinear bearings pushed >= min separation apart', () {
    final out = deCollide([45, 47]); // within compassMinAngularSepDegrees (8)
    final gap = (out[0] - out[1]).abs();
    expect(gap, greaterThanOrEqualTo(MapConfig.compassMinAngularSepDegrees - 0.001));
  });

  test('deCollide: already-separated bearings unchanged', () {
    expect(deCollide([0, 90, 180]), [0, 90, 180]);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement the pure helpers + the view.** In `compass_radar_view.dart`:
```dart
double blipRadiusFraction(double meters) {
  final span = MapConfig.compassFarClampMeters - MapConfig.compassNearClampMeters;
  final t = ((meters - MapConfig.compassNearClampMeters) / span).clamp(0.0, 1.0);
  return t; // near→0 (center), far→1 (rim)
}

/// Spread near-collinear bearings so blips don't overlap. Deterministic: sort,
/// then push each within min-sep of its predecessor outward by the deficit.
List<double> deCollide(List<double> bearingsDeg) {
  final idx = List.generate(bearingsDeg.length, (i) => i)
    ..sort((a, b) => bearingsDeg[a].compareTo(bearingsDeg[b]));
  final out = List<double>.from(bearingsDeg);
  for (var k = 1; k < idx.length; k++) {
    final prev = out[idx[k - 1]], cur = out[idx[k]];
    final need = MapConfig.compassMinAngularSepDegrees - (cur - prev);
    if (need > 0) out[idx[k]] = cur + need;
  }
  return out;
}
```
Then the `CompassRadarView` `ConsumerWidget`: a `LayoutBuilder` → square `CustomPaint` of diameter `min(w, h)` with a `CompassRosePainter` that draws the red rose ring, cardinal ticks, a facing wedge at `state.trueHeadingDegrees`, and blips positioned by `blipRadiusFraction(distance)` × unit-vector at `deCollide(bearings)` angle. A `Stack` overlays tappable `Semantics(button, label: "<title>, <cardinal>, <distance>")` hit-boxes (falling through to the list for a11y — the list is the accessible tap path per §0.6). The locked target (`state.locked`) draws the bold arrow at `state.lockedRelativeAngle`, or `l.compassYouAreHere` when `state.lockedNearTarget`. **`acquiring` and reduced-motion:** never a `CircularProgressIndicator`; honor `MediaQuery.disableAnimationsOf(context)` by skipping any rose spin (static frame). Red palette = local `const` tokens (e.g. `Color(0xFF3A0A0A)` bg, `Color(0xFFFF5A4D)` ink) — NOT `aon_palette`.

- [ ] **Step 4: Add a widget test** for the locked arrow + no-overflow at 320×568/2.0 (append to the same file):
```dart
// (widget-level) pump CompassRadarView with an overridden compassControllerProvider
// exposing a locked target; assert the arrow Semantics renders and takeException() is null.
```
Implement it mirroring `point_me_screen_test.dart` sizing (set `t.view.physicalSize`, `MediaQuery(textScaler: 2.0)`), pump with `pump()` for the acquiring branch (not `pumpAndSettle`).

- [ ] **Step 5: Run, verify PASS. Commit.**

---

## Task 8: `CompassModeView` + `map_screen` integration (B1, B2)

**Files:** Create `lib/widgets/compass_mode_view.dart`. Modify `lib/screens/map_screen.dart`. Test: `test/widget/compass_mode_view_test.dart`.

**Interfaces:**
- Consumes: `compassVisibleProvider`+`.notifier`, `compassLockedProvider`+`.notifier`, `compassFilterProvider`, `compassControllerProvider` (`.select availability`), `locationControllerProvider` (`.select fix` + `.notifier.onLocateTapped`), `CompassRadarView`, `NearbyList`, l10n.
- Produces: `CompassModeView` (`ConsumerStatefulWidget`).

- [ ] **Step 1: Write failing test** `test/widget/compass_mode_view_test.dart` — the critical one is the **no-preseeded-location** path (B4) and availability routing:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/compass_mode_view.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/nearby_list.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeHeadingService h, FakeLocationService l) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(l),
    buildingsProvider.overrideWith((ref) async => const []),
  ]);
  addTearDown(c.dispose);
  return c;
}
Widget _app(ProviderContainer c) => UncontrolledProviderScope(
    container: c, child: MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: const Scaffold(body: CompassModeView())));

void main() {
  testWidgets('entering compass with NO pre-seeded fix shows an enable-location affordance (B4)', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump(); // post-frame: visible=true + locate attempt
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.compassEnableLocation), findsOneWidget); // NOT a silent dead compass
  });

  testWidgets('heading unavailable → NearbyList; available → radar', (t) async {
    final h = FakeHeadingService();
    final c = _c(h, FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      h.emit(const HeadingSample(availability: HeadingAvailability.unavailable));
      await Future<void>.delayed(Duration.zero);
    });
    await t.pump();
    expect(find.byType(NearbyList), findsOneWidget);
  });

  testWidgets('sets compassVisible=false on dispose (no crash, captured notifier)', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    expect(c.read(compassVisibleProvider), isTrue);
    await t.pumpWidget(const SizedBox()); // dispose the view
    await t.pump();
    expect(c.read(compassVisibleProvider), isFalse);
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement** `CompassModeView` (`ConsumerStatefulWidget`) per §0.1/§0.3:
```dart
class _CompassModeViewState extends ConsumerState<CompassModeView> {
  late final CompassVisibleNotifier _visible;
  late final CompassLocked _locked;

  @override
  void initState() {
    super.initState();
    _visible = ref.read(compassVisibleProvider.notifier);
    _locked = ref.read(compassLockedProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visible.set(true);
      // Kick location activation through the permission-aware path (B4).
      if (ref.read(locationControllerProvider).fix == null) {
        ref.read(locationControllerProvider.notifier).onLocateTapped();
      }
    });
  }

  @override
  void dispose() {
    try {
      _visible.set(false);
      _locked.set(null);
    } catch (_) {/* container torn down first (tests) */}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avail = ref.watch(compassControllerProvider.select((s) => s.availability));
    final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
    final l = AonL10n.of(context);
    if (fix == null) {
      return _EnableLocation(onEnable: () =>
          ref.read(locationControllerProvider.notifier).onLocateTapped(), l: l);
    }
    final body = switch (avail) {
      HeadingAvailability.available => const CompassRadarView(),
      HeadingAvailability.acquiring => const CompassRadarView(), // static acquiring frame
      HeadingAvailability.unavailable || HeadingAvailability.unsupported => const NearbyList(),
    };
    return Column(children: [ _FilterField(...), Expanded(child: body) ]);
  }
}
```
`_EnableLocation` renders `Text(l.compassLocationNeeded)` + a button `Text(l.compassEnableLocation)`. `_FilterField` sets `compassFilterProvider`.

- [ ] **Step 4: Wire `map_screen.dart`** (§0.4). Change the body branch (`:173`) from binary to 3-way:
```dart
          if (_mode == MapMode.panorama)
            Expanded(child: PanoramaBuildingPicker(onOpen: (id) => context.push(Routes.panoramaFor(id))))
          else if (_mode == MapMode.compass)
            const Expanded(child: CompassModeView())
          else ...[
            MapCategoryFilterBar(/* …unchanged campus map branch… */),
            // …existing Stack…
          ],
```
Change the FAB guard (`:355`) from `_mode == MapMode.panorama ? null : <FAB>` to:
```dart
      floatingActionButton: _mode == MapMode.campusMap ? Padding(/* …existing FAB… */) : null,
```
Add `import 'package:aon2026/widgets/compass_mode_view.dart';`.

- [ ] **Step 5: Run the new test + existing map_screen wiring tests:**
```bash
flutter test test/widget/compass_mode_view_test.dart test/widget/map_platform_wiring_test.dart
```
Verify PASS; fix any map_screen wiring test that assumed 2 modes.

- [ ] **Step 6: Commit.**

---

## Task 9: Full gate + honest closeout

**Files:** Modify the design spec's scorecard closeout note if needed; no code.

- [ ] **Step 1: Run the full gate:**
```bash
./scripts/check.sh full > /tmp/gate.log 2>&1 && echo "FULL GATE GREEN" || { echo GATE FAILED; tail -60 /tmp/gate.log; }
```
Expected: analyze clean, full `flutter test` green, provenance SHA ok, l10n EN+FA complete, reskin py green, **web + apk + iOS-simulator builds green**.

- [ ] **Step 2: On-device IOU verification** (BLOCKED on physical hardware — the standing smoke IOU). Record what a real device must prove: arrow tracks true bearing with declination; list-fallback on a magnetometer-off device; red palette legible in the dark; locate affordance on a denied-permission device. iOS Simulator has no magnetometer → it exercises the `unavailable`→`NearbyList` path (a real proof of the honest degradation). Capture the simulator run.

- [ ] **Step 3: Re-score the §0.8 scorecard** against the shipped artifact (scores may move; explain any that don't reach 9). Append a closeout record to this plan: commit SHAs T1–T9, the on-device IOU, and CODE-COMPLETE vs RELEASE-READY status.

- [ ] **Step 4: Update memory** (`map-parity-program.md`, `MEMORY.md`, `.remember/recent.md`) and hand off with `finishing-a-development-branch` (present merge options; user drives integration).

---

## Self-Review (writing-plans)

- **Spec coverage:** §0.1→T2/T8 (B4 gate+affordance); §0.2→T1 (venue-bias/filter-first); §0.3→T3/T8 (post-frame, captured notifier, `.select`, sole-cancel, locked-survives-cull, terminal latch); §0.4→T5/T8 (3-way + FAB + Semantics + fixed tests); §0.5→T1/T6 (confidence + unlocatable rows); §0.6→T7 (radius fn, de-collision, list-as-tap-path, acquiring static, reduced-motion); §0.7→T1/T3/T4/T6 (round, latlong2 import, long cardinals, headingService override). All covered.
- **Placeholder scan:** the T6/T7/T8 widget bodies are described-with-real-signatures rather than full pixel code; every load-bearing contract (providers, math, lifecycle, tests) is concrete. No `TBD`/`TODO`.
- **Type consistency:** `NearbyTarget.distanceMeters` double → `formatNavDistance(..., .round())`; `routingLatLngOf` returns `(double,double)?`; `compassLockedProvider` is `String?`; `CompassController.build` returns `_compute()` (never assigns state in build); `headingServiceProvider` imported from `point_me_controller.dart:30`.
- **Order:** each task compiles+tests independently; l10n (T4) precedes UI (T5–T8); enum change (T5) precedes `map_screen` wiring (T8).
