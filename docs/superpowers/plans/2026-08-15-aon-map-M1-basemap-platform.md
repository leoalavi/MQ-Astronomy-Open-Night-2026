# M1 — Basemap Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) or subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace AON's WGS84 OSM map with the `CrsSimple` reskinned illustrated basemap, under a hardened non-clamping projection, re-seating the Phase A dot/circle + venue/parking markers + follow-me — no Phase A/B regression, web-runtime render verified.

**Architecture:** const `CampusProjection` (`GpsPoint → CampusPixelPoint → CampusMapPoint?`, validated, non-clamping, frozen domain); `CrsSimple` `FlutterMap` with `initialCameraFit`; reskinned `OverlayImage` basemap; zoom-aware accuracy circle via `MapCamera.projectAtZoom`.

**Design:** `2026-08-15-aon-map-M1-basemap-platform-design.md` (gauntlet-clean). **All flutter_map 8.3.1 APIs verified against installed source.**

## Global Constraints (from the design + program spec)

- **Corrected map constants (frozen, Task 0 receipt):** `scale = 38.905882`; `mapNorth(lat)=85.0`, `mapEast(lng)=120.2389`; `mapBounds=(0,0)..(85.0,120.2389)`; `mapMinZoom=-4.0`, `mapMaxZoom=-2.2`.
- **Calibration (verified vs MQ):** pixel `0..4678 × 0..3307`; `affine.x=[880.374832,3889.927306,12.547607]`, `affine.y=[2862.069113,-64.093654,-2349.078357]`; norm `minLat -33.7772506 maxLat -33.7703261 minLng 151.1080508 maxLng 151.1211352`.
- **Projection is non-clamping** (`null` outside the frozen domain = normbox ∧ pixel, ε=1e-9), **GPS-validated**, **fail-closed** (no silent linear fallback in production).
- **Strong types** at the projection↔layer boundary; unwrap `.value` only at the flutter_map call. `CampusMapPoint.value` is never fed to geographic math.
- **Preserve Phase A** low-accuracy circle suppression; the `LocationController` seam + providers unchanged; Phase B bearing math untouched.
- **Never weaken an existing test.** Re-baseline the suite count at Task 0. EN+FA for new copy. New surfaces pass 320×568/2.0.
- **Per-task gate:** `flutter analyze && flutter test`. Web build + **web-runtime render** where the map changes.

## File Structure

**Create:** `lib/models/campus_geometry.dart`, `lib/services/campus_projection.dart`, `lib/widgets/campus_basemap_layer.dart`, `docs/fixtures/campus_overlay_meta.json`, and tests `test/unit/campus_projection_test.dart`, `test/unit/campus_calibration_drift_test.dart`, `test/unit/venue_projection_integrity_test.dart`, `test/widget/campus_basemap_layer_test.dart`, `test/widget/user_location_layer_test.dart`, `test/widget/map_platform_wiring_test.dart`.
**Modify:** `lib/widgets/map_config.dart`, `lib/screens/map_screen.dart`, `lib/widgets/user_location_layer.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`.

**Task order:** 0 preflight+receipt → 1 geometry types → 2 projection → 3 drift test → 4 venue integrity → 5 MapConfig map-units → 6 basemap layer → 7 user-location re-seat → 8 l10n note → 9 map_screen wiring → 10 viewport/2.0 → 11 verification.

---

## Task 0: Preflight + calibration receipt

- [ ] **Step 1: Branch + clean** — `git branch --show-current` (feature/map-parity-program); `git status --short` clean.
- [ ] **Step 2: Baseline** — `flutter analyze && flutter test`; **record the passing count** (this is the M1 floor; do not trust "527" — measure).
- [ ] **Step 3: Calibration receipt** — Run and paste into the Task 11 closeout:
```bash
python3 -c "
pw,ph=4678,3307
s=max(1,max(pw/170,ph/85))
print('scale',s,'mapNorth(lat)',ph/s,'mapEast(lng)',pw/s,'center',ph/s/2,pw/s/2)"
```
Expected: `scale 38.905882 mapNorth 85.0 mapEast 120.2389 center 42.5 60.1194`. The Task 5 constants are copied from THIS receipt.
- [ ] **Step 4: Copy calibration source** — `mkdir -p docs/fixtures && cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/data/campus_overlay_meta.json docs/fixtures/` (source-of-truth for the drift test; NOT bundled in `assets:`).
- [ ] **Step 5: Commit** — `git add docs/fixtures/campus_overlay_meta.json && git commit -m "chore(map): vendor MQ calibration meta as docs/fixtures source-of-truth (M1 T0)"`

---

## Task 1: Geometry types

**Files:** Create `lib/models/campus_geometry.dart`, `test/unit/campus_projection_test.dart` (start it here).

- [ ] **Step 1: Failing test** — in `test/unit/campus_projection_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';

void main() {
  test('geometry wrappers hold their value without conflation', () {
    expect(GpsPoint(const LatLng(-33.77, 151.11)).value.latitude, -33.77);
    expect(CampusMapPoint(const LatLng(42.5, 60.1)).value.longitude, 60.1);
  });
}
```
- [ ] **Step 2: Run → FAIL** (undefined). `flutter test test/unit/campus_projection_test.dart`.
- [ ] **Step 3: Implement** — `lib/models/campus_geometry.dart`. (No `CampusPixelPoint` — the pixel stage is internal `double` math in the projection; an unused wrapper is YAGNI.)
```dart
import 'package:latlong2/latlong.dart';

/// WGS84 degrees (projection INPUT). A wrapper so a GPS LatLng cannot be passed
/// to a map layer un-projected. Does not validate range — the projection
/// validates (extension types guard semantics, not data).
extension type const GpsPoint(LatLng value) {}

/// CrsSimple map-units (projection OUTPUT, for flutter_map). NOT a geographic
/// lat/lng — never feed `.value` to latlong2 Distance/bearing/Phase B maths.
extension type const CampusMapPoint(LatLng value) {}
```
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(map): typed GPS/pixel/map-unit geometry (extension types) (M1 T1)`

---

## Task 2: `CampusProjection` (pure, TDD)

**Files:** Create `lib/services/campus_projection.dart`; extend `test/unit/campus_projection_test.dart`.

**Interfaces:** `CampusProjection.project(GpsPoint) → CampusMapPoint?` (null off-domain, never clamps); `.canProject(GpsPoint) → bool`; static `mapNorth`, `mapEast`.

- [ ] **Step 1: Failing tests** — add:
```dart
import 'package:aon2026/services/campus_projection.dart';

const _proj = CampusProjection();
// campus centre (Central Courtyard) — inside the calibrated footprint
const _centre = GpsPoint(LatLng(-33.7737, 151.1134));

test('a campus point projects inside the map bounds', () {
  final p = _proj.project(_centre)!;
  expect(p.value.latitude, inInclusiveRange(0, CampusProjection.mapNorth));
  expect(p.value.longitude, inInclusiveRange(0, CampusProjection.mapEast));
});

test('reference vector: affine matches MQ published coefficients', () {
  // normLng/normLat of the centre, hand-applied to the affine, Y-flipped
  final p = _proj.project(_centre)!;
  // recompute expected from the frozen constants (guards accidental edits)
  const minLat = -33.7772506, maxLat = -33.7703261;
  const minLng = 151.1080508, maxLng = 151.1211352;
  final nLng = (151.1134 - minLng) / (maxLng - minLng);
  final nLat = (-33.7737 - minLat) / (maxLat - minLat);
  final x = 880.374832 + 3889.927306 * nLng + 12.547607 * nLat;
  final y = 2862.069113 - 64.093654 * nLng - 2349.078357 * nLat;
  expect(p.value.longitude, closeTo(x / 38.905882, 1e-6));
  expect(p.value.latitude, closeTo((3307 - y) / 38.905882, 1e-6));
});

test('OFF the footprint → null (never clamps to an edge)', () {
  expect(_proj.project(const GpsPoint(LatLng(-33.90, 151.30))), isNull); // km away
  expect(_proj.canProject(const GpsPoint(LatLng(-33.90, 151.30))), isFalse);
});

test('invalid GPS → null (NaN / out of range)', () {
  expect(_proj.project(GpsPoint(LatLng(double.nan, 151.11))), isNull);
  expect(_proj.project(const GpsPoint(LatLng(200, 151.11))), isNull);
});

test('deterministic', () {
  expect(_proj.project(_centre)!.value, _proj.project(_centre)!.value);
});
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — `lib/services/campus_projection.dart`:
```dart
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';

/// GPS → CrsSimple map-units via MQ's gcp_affine calibration. Compile-time
/// constants (validity is a build/test invariant — see the drift test). NEVER
/// clamps: returns null outside the frozen domain (normalization box ∧ raster
/// footprint). Fail-closed — no linear fallback in production.
class CampusProjection {
  const CampusProjection();

  static const double _pw = 4678, _ph = 3307;
  // EXACT (no truncation): scale = max(1, max(pw/170, ph/85)); ph/85 is the max,
  // so scale == 3307/85 exactly and mapNorth == 85.0 exactly. One geometry,
  // one source of truth — MapConfig consumes these, does not re-hardcode them.
  static const double _scale = _ph / 85.0;              // 3307/85 = 38.905882…
  static const List<double> _ax = [880.374832, 3889.927306, 12.547607];
  static const List<double> _ay = [2862.069113, -64.093654, -2349.078357];
  static const double _minLat = -33.7772506, _maxLat = -33.7703261;
  static const double _minLng = 151.1080508, _maxLng = 151.1211352;
  static const double _eps = 1e-9;

  static const double mapNorth = _ph / _scale;          // == 85.0 exactly
  static const double mapEast = _pw / _scale;           // 4678*85/3307 = 120.2389…

  CampusMapPoint? project(GpsPoint gps) {
    final lat = gps.value.latitude, lng = gps.value.longitude;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    final nLng = (lng - _minLng) / (_maxLng - _minLng);
    final nLat = (lat - _minLat) / (_maxLat - _minLat);
    if (nLng < -_eps || nLng > 1 + _eps || nLat < -_eps || nLat > 1 + _eps) {
      return null;                                       // outside calibration domain
    }
    final x = _ax[0] + _ax[1] * nLng + _ax[2] * nLat;
    final y = _ay[0] + _ay[1] * nLng + _ay[2] * nLat;
    if (x < -_eps || x > _pw + _eps || y < -_eps || y > _ph + _eps) {
      return null;                                       // outside raster footprint
    }
    return CampusMapPoint(LatLng((_ph - y) / _scale, x / _scale)); // Y-flip → map units
  }

  bool canProject(GpsPoint gps) => project(gps) != null;
}
```
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(map): CampusProjection — validated non-clamping gcp_affine (M1 T2)`

---

## Task 3: Calibration drift test (JSON ↔ constants)

**Files:** Create `test/unit/campus_calibration_drift_test.dart`.

- [ ] **Step 1: Write the test** — it must exercise **`CampusProjection` itself**, not just compare JSON to literals. It recomputes expected map-units **independently from the vendored JSON** and asserts the compiled projector agrees, for several reference vectors. This proves the real chain `vendored JSON → independent calc → CampusProjection` (a silent edit to the private `_ax`/`_scale` now fails here):
```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

void main() {
  test('CampusProjection agrees with the vendored MQ calibration JSON', () {
    final j = jsonDecode(
        File('docs/fixtures/campus_overlay_meta.json').readAsStringSync());
    final pb = j['pixelBounds'];
    final pw = (pb['east'] as num).toDouble();
    final ph = (pb['north'] as num).toDouble();
    final aff = j['gpsProjection']['affine'];
    final ax = (aff['x'] as List).map((e) => (e as num).toDouble()).toList();
    final ay = (aff['y'] as List).map((e) => (e as num).toDouble()).toList();
    final n = aff['normalization'];
    final minLat = n['minLat'] as double, maxLat = n['maxLat'] as double;
    final minLng = n['minLng'] as double, maxLng = n['maxLng'] as double;
    final scale = [1.0, pw / 170, ph / 85].reduce((a, b) => a > b ? a : b);

    // independent expectation straight from the JSON
    LatLng expected(double lat, double lng) {
      final nLng = (lng - minLng) / (maxLng - minLng);
      final nLat = (lat - minLat) / (maxLat - minLat);
      final x = ax[0] + ax[1] * nLng + ax[2] * nLat;
      final y = ay[0] + ay[1] * nLng + ay[2] * nLat;
      return LatLng((ph - y) / scale, x / scale);
    }

    const proj = CampusProjection();
    for (final gps in const [
      LatLng(-33.7737, 151.1134),   // centre
      LatLng(-33.7726489, 151.1105693), // sport/aquatic
      LatLng(-33.7768086, 151.1175848), // metro
    ]) {
      final got = proj.project(GpsPoint(gps))!;
      final exp = expected(gps.latitude, gps.longitude);
      expect(got.value.latitude, closeTo(exp.latitude, 1e-9), reason: '$gps');
      expect(got.value.longitude, closeTo(exp.longitude, 1e-9), reason: '$gps');
    }
    // and the compiled map bounds agree with the JSON-derived scale
    expect(CampusProjection.mapNorth, closeTo(ph / scale, 1e-9));
    expect(CampusProjection.mapEast, closeTo(pw / scale, 1e-9));
  });
}
```
- [ ] **Step 2: Run → PASS** (fails loudly if `CampusProjection`'s constants ever drift from the vendored JSON).
- [ ] **Step 3: Commit** — `test(map): calibration drift guard — constants == vendored meta (M1 T3)`

---

## Task 4: Venue/parking projection integrity

**Files:** Create `test/unit/venue_projection_integrity_test.dart`.

- [ ] **Step 1: Write the test** (PASSES — verified: all 19 coords are inside the domain):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

void main() {
  const proj = CampusProjection();
  test('every venue/parking coordinate projects onto the campus map', () {
    final coords = <(String, double, double)>[
      for (final v in VenuesData.all)
        if (v.latitude != null && v.longitude != null)
          (v.id, v.latitude!, v.longitude!),
      for (final p in ParkingData.all)
        if (p.latitude != null && p.longitude != null)
          (p.id, p.latitude!, p.longitude!),
    ];
    expect(coords, isNotEmpty);
    final unprojectable = [
      for (final (id, lat, lng) in coords)
        if (!proj.canProject(GpsPoint(LatLng(lat, lng)))) id,
    ];
    // Deliberately-null records (e.g. west-6) carry no coords and are excluded
    // above. Any coordinate that FAILS to project must be triaged, not skipped.
    expect(unprojectable, isEmpty, reason: 'unprojectable: $unprojectable');
  });
}
```
(Confirms curated event markers can never silently vanish under the new map.)
- [ ] **Step 2: Run → PASS** (verified: all 19 coords are inside the domain). **If it fails: STOP M1.** Do **not** loosen the projection domain or allowlist a legitimate venue inside this implementation task — that would change a load-bearing coordinate policy to make a test green. Return to the design gate with the failing IDs + coordinates; the domain change (if any) is decided and re-gauntletted there, then this task resumes.
- [ ] **Step 3: Commit** — `test(map): venue/parking projection integrity gate (M1 T4)`

---

## Task 5: `MapConfig` map-unit constants

**Files:** Modify `lib/widgets/map_config.dart`; extend a small test.

- [ ] **Step 1: Failing test** — `test/unit/map_config_mapunits_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('map-unit bounds match the frozen receipt', () {
    expect(MapConfig.mapBounds.north, closeTo(85.0, 1e-3));
    expect(MapConfig.mapBounds.east, closeTo(120.2389, 1e-3));
    expect(MapConfig.mapBounds.south, 0);
    expect(MapConfig.mapBounds.west, 0);
    expect(MapConfig.mapMinZoom, -4.0);
    expect(MapConfig.mapMaxZoom, -2.2);
  });
}
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — add to `map_config.dart` (keep the WGS84 constants; they stay for Phase B/wayfinding). **Consume `CampusProjection.mapNorth/mapEast` — do NOT re-hardcode the numbers (one geometry, one source of truth):**
```dart
import 'package:aon2026/services/campus_projection.dart';
  // ...
  // ── CrsSimple campus-map units (Map Parity M1). Bounds come straight from
  //    CampusProjection so they can never drift from the projector.
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(0, 0),
    LatLng(CampusProjection.mapNorth, CampusProjection.mapEast),
  );
  static const double mapMinZoom = -4.0;
  static const double mapMaxZoom = -2.2;
```
(The Task 5 test's `closeTo(85.0, …)` / `closeTo(120.2389, …)` still hold, now sourced from the projector.)
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(map): CrsSimple map-unit bounds/zooms in MapConfig (M1 T5)`

---

## Task 6: `CampusBasemapLayer`

**Files:** Create `lib/widgets/campus_basemap_layer.dart`, `test/widget/campus_basemap_layer_test.dart`.

- [ ] **Step 1: Failing test** — renders one `OverlayImage` at `mapBounds` under `CrsSimple`, no exception:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';

void main() {
  testWidgets('basemap renders one overlay image, no exception', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: FlutterMap(
        options: MapOptions(
          crs: const CrsSimple(),
          initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds),
        ),
        children: const [CampusBasemapLayer()],
      )),
    ));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1);
    expect(t.takeException(), isNull);
  });
}
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — `lib/widgets/campus_basemap_layer.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:aon2026/widgets/map_config.dart';

/// The reskinned illustrated campus basemap as a CrsSimple OverlayImage. M2 will
/// swap the asset for the selected thematic variant.
class CampusBasemapLayer extends StatelessWidget {
  const CampusBasemapLayer({super.key});
  @override
  Widget build(BuildContext context) => OverlayImageLayer(
        overlayImages: [
          OverlayImage(
            bounds: MapConfig.mapBounds,
            imageProvider: const AssetImage('assets/maps/mqcampus_dark.png'),
          ),
        ],
      );
}
```
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(map): CampusBasemapLayer — reskinned CrsSimple basemap (M1 T6)`

---

## Task 7: Re-seat the user-location layer (dot + zoom-aware circle)

**Files:** Modify `lib/widgets/user_location_layer.dart`; **MIGRATE** the existing `test/widget/user_location_layer_test.dart` (it tests the old `UserLocationCircle(fix:)` signature + a WGS84 `MapOptions`) — update it to the new signature and CrsSimple, **preserving** its two behaviours (normal → circle+marker; low-accuracy → no circle); do not delete them. Also extend `test/unit/campus_projection_test.dart` for the pure anisotropy rule.

**Interfaces:** `UserLocationCircle({required CampusMapPoint center, required UserLocationFix fix})`, `UserLocationDot({required CampusMapPoint center})`, and a pure top-level `double accuracyRadiusScale(double nPx, double ePx)`.

- [ ] **Step 1a: Pure anisotropy test** (unit) — add to `campus_projection_test.dart`:
```dart
import 'package:aon2026/widgets/user_location_layer.dart' show accuracyRadiusScale;

test('anisotropy ≤5% → average scale; >5% → conservative (larger)', () {
  expect(accuracyRadiusScale(10.0, 10.2), closeTo(10.1, 1e-9));   // ~2% → average
  expect(accuracyRadiusScale(10.0, 12.0), 12.0);                  // 20% → larger
});
```
- [ ] **Step 1b: Migrate + zoom the widget test** — rewrite `user_location_layer_test.dart`. The host uses **explicit `initialCenter` + `initialZoom`** (not `initialCameraFit`) so zoom is controllable; it reads the rendered `CircleMarker.radius`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

const _proj = CampusProjection();
const _gps = LatLng(-33.7737, 151.1134);
final _centre = _proj.project(const GpsPoint(_gps))!;

Widget _host(Widget child, {required double zoom}) => MaterialApp(
      home: Scaffold(body: FlutterMap(
        options: MapOptions(
          crs: const CrsSimple(),
          initialCenter: _centre.value,   // map-units
          initialZoom: zoom,
        ),
        children: [child],
      )),
    );

double _radius(WidgetTester t) =>
    t.widget<CircleLayer>(find.byType(CircleLayer)).circles.single.radius;

void main() {
  testWidgets('normal fix renders a circle + dot (migrated)', (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 15);
    await t.pumpWidget(_host(
        Column(children: [UserLocationCircle(center: _centre, fix: fix)]),
        zoom: -3.4));
    await t.pump();
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('low-accuracy fix omits the circle (migrated, Phase A §5.1)',
      (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 500);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -3.4));
    await t.pump();
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('circle radius GROWS with zoom, same footprint (the P0 fix)',
      (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 20);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -3.8));
    await t.pump();
    final rLow = _radius(t);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -2.8));
    await t.pump();
    final rHigh = _radius(t);
    expect(rHigh, greaterThan(rLow));         // more screen px when zoomed in
    expect(rLow, greaterThan(0));
  });
}
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — rewrite `user_location_layer.dart`. Circle is camera-aware (screen-pixel radius via `MapCamera.projectAtZoom`), keeps the `isLowAccuracy` short-circuit, and uses the **pure** `accuracyRadiusScale` (so the anisotropy rule is unit-testable):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';

/// Pixels-per-metre to use for the accuracy radius given the local north/east
/// screen-pixel-per-metre scales. ≤5% anisotropy → their average; otherwise the
/// larger (conservative) — a general affine turns a metric circle into an
/// ellipse, so we never under-state uncertainty. Pure + unit-tested.
double accuracyRadiusScale(double nPx, double ePx) {
  final larger = nPx > ePx ? nPx : ePx;
  final anisotropy = larger == 0 ? 0 : (nPx - ePx).abs() / larger;
  return anisotropy <= 0.05 ? (nPx + ePx) / 2 : larger;
}

/// Accuracy circle — sized in SCREEN PIXELS at the current zoom (CrsSimple has
/// no real metres), so it keeps a constant campus footprint as you zoom. Renders
/// nothing for a low-accuracy fix (Phase A §5.1 — no suburb-sized blob).
class UserLocationCircle extends StatelessWidget {
  const UserLocationCircle({required this.center, required this.fix, super.key});
  final CampusMapPoint center;
  final UserLocationFix fix;
  static const _proj = CampusProjection();

  @override
  Widget build(BuildContext context) {
    if (fix.isLowAccuracy) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    final north = _proj.project(GpsPoint(
        const Distance().offset(fix.position, 25, 0)));   // 25 m north
    final east = _proj.project(GpsPoint(
        const Distance().offset(fix.position, 25, 90)));  // 25 m east
    if (north == null || east == null) return const SizedBox.shrink();
    final c = camera.projectAtZoom(center.value);
    final nPx = (camera.projectAtZoom(north.value) - c).distance / 25.0;
    final ePx = (camera.projectAtZoom(east.value) - c).distance / 25.0;
    final accent = context.aon.accent;
    return CircleLayer(circles: [
      CircleMarker(
        point: center.value,
        radius: fix.accuracyMeters * accuracyRadiusScale(nPx, ePx),
        useRadiusInMeter: false,   // radius is SCREEN PIXELS
        color: accent.withValues(alpha: 0.12),
        borderColor: accent.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ),
    ]);
  }
}

/// "You are here" dot — projected map-unit point.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({required this.center, super.key});
  final CampusMapPoint center;
  @override
  Widget build(BuildContext context) => MarkerLayer(markers: [
        Marker(
          point: center.value,
          width: 22, height: 22,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black26)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(decoration: BoxDecoration(
                  color: context.aon.accent, shape: BoxShape.circle)),
            ),
          ),
        ),
      ]);
}
```
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(map): re-seat user-location dot + zoom-aware accuracy circle on CrsSimple (M1 T7)`

---

## Task 8: l10n — off-illustration note

**Files:** Modify `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`; regenerate.

- [ ] **Step 1: EN** — add `"mapLocatingOnCampus": "Locating you on the campus map…", "@mapLocatingOnCampus": {"description": "Shown when a near-campus GPS fix can't be placed on the illustrated map yet"}`.
- [ ] **Step 2: FA** — add `"mapLocatingOnCampus": "در حال یافتن موقعیت شما روی نقشه…"`.
- [ ] **Step 3: Regenerate + analyze** — `flutter gen-l10n && flutter analyze` (build fails if FA misses a key).
- [ ] **Step 4: Commit** — `feat(map): l10n for off-illustration locating note (EN/FA) (M1 T8)`

---

## Task 9: Wire the map + follow-me + regression

**Files:** Modify `lib/screens/map_screen.dart`; Create `test/widget/map_platform_wiring_test.dart`.

- [ ] **Step 1: Failing wiring test** — reuse the Phase A `FakeLocationService` container pattern (`map_location_wiring_test.dart`). Cases:
  - (a) projectable fix + active parking category → `CampusBasemapLayer`, `UserLocationDot`, parking `MarkerLayer` all present, `takeException()` null.
  - (b) **PIN the marker position** (not just "a MarkerLayer exists" — that passes even if a marker is left at raw WGS84 and stranded off-map): for a known venue, find its `Marker` and assert `marker.point == CampusProjection().project(GpsPoint(venueGps))!.value` **and** `MapConfig.mapBounds.contains(marker.point)`. (Locate it by a `Key` added to `_MarkerPin`, or by matching the projected point among `MarkerLayer.markers`.)
  - (c) **active + null fix → no crash, no dot.**
  - (d) **off-footprint fix** (`LatLng(-33.90,151.30)`) → **no `UserLocationDot`** (not a clamped edge dot); and the `mapLocatingOnCampus` note is absent (that fix isn't near campus either).
  - (e) **follow-me camera**: with `following:true` + a projectable fix, after the `ref.listen` fires, `_controller.camera.center` is **near the projected campus point** (within the map bounds, close to `project(fix).value`), **never** raw `(-33,151)`; with an off-footprint fix, the camera does **not** move. (Drive via the fake controller state; read `mapController.camera.center`.)
  - (f) panorama toggle still switches to `PanoramaBuildingPicker`. (Do not assert z-order.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Wire `map_screen.dart`:**
  1. Add `final _proj = const CampusProjection();` and, in `build`, after `loc` is read:
     ```dart
     final fix = loc.fix;
     final projected = fix == null ? null : _proj.project(GpsPoint(fix.position));
     ```
  2. **MapOptions** → replace initialCenter/zoom/min/max/cameraConstraint with:
     ```dart
     crs: const CrsSimple(),
     initialCameraFit: CameraFit.bounds(
         bounds: MapConfig.mapBounds, padding: const EdgeInsets.all(12)),
     minZoom: MapConfig.mapMinZoom,
     maxZoom: MapConfig.mapMaxZoom,
     cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
     ```
     (Keep `backgroundColor` + `onPositionChanged` as-is.)
  3. **children** → `DarkTileLayer` becomes `const CampusBasemapLayer()`; gate + project the location layers with `projected`; project each marker.
     ```dart
     const CampusBasemapLayer(),
     if (loc.active && projected != null)
       UserLocationCircle(center: projected, fix: fix!),
     MarkerLayer(markers: markers),           // markers built via _proj (below)
     if (loc.active && projected != null)
       UserLocationDot(center: projected),
     ```
  4. **Markers** — project each; skip null. Parking marker `point:` and `_venueMarker` `point:` become the projected value:
     ```dart
     final pt = _proj.project(GpsPoint(LatLng(p.latitude!, p.longitude!)));
     if (pt == null) continue;   // (integrity test guarantees this won't drop real venues)
     … Marker(point: pt.value, …)
     ```
     (Refactor `_venueMarker(Venue)` to take/compute the projected point; return `null` and filter if unprojectable.)
  5. **Follow-me** (`ref.listen`, ~:67-72): project before moving. **Preserve Phase A's inherited `!isLowAccuracy` gate** (verified `map_screen.dart:68` — Phase A already suppresses follow on a fuzzy fix, §5.1; M1 does NOT change that). The old `isNearCampus` check is **subsumed** by `mp != null` (on-footprint ⊂ near-campus), so it's replaced, not dropped:
     ```dart
     if (s.following && s.fix != null && !s.fix!.isLowAccuracy) {  // !isLowAccuracy inherited
       final mp = _proj.project(GpsPoint(s.fix!.position));
       if (mp != null) _controller.move(mp.value, _controller.camera.zoom); // mp!=null ⊃ isNearCampus
     }
     ```
  6. **Off-illustration note** — where the off-campus/low-accuracy notes are chosen, add: if `loc.active && fix != null && MapConfig.isNearCampus(fix.position) && projected == null` → show `_MapNote(text: l.mapLocatingOnCampus)`.
  7. **Zoom buttons** (`MapControlIsland`) — `clampZoom(..., min: MapConfig.mapMinZoom, max: MapConfig.mapMaxZoom)`.
- [ ] **Step 4: Run tests + build** — `flutter test test/widget/map_platform_wiring_test.dart && flutter analyze && flutter build web` — PASS/clean/green.
- [ ] **Step 5: Commit** — `feat(map): replace WGS84 map with CrsSimple basemap; project dot/markers/follow-me (M1 T9)`

---

## Task 10: 320×568 / 2.0 + camera viewport matrix

**Files:** extend `test/widget/map_platform_wiring_test.dart`.

- [ ] **Step 1: Tests** —
  - (a) MapScreen at `view.physicalSize = Size(320,568)` + `textScaleFactorTestValue = 2.0`, projectable fix, `pumpAndSettle`, `takeException()` null (base + markers + controls + panorama toggle).
  - (b) **The off-illustration note specifically** (the projectable-fix case in (a) can NOT reach it — it needs `projected == null`): a **near-campus but off-footprint** fix (within 2.5 km of campus yet outside the raster, e.g. a point ~1 km from centre but off the illustration) at 320×568 / 2.0, in **EN and FA** → `find.text(l.mapLocatingOnCampus)` (and its FA string) `findsOneWidget`, `takeException()` null (no overflow; RTL renders). Pick the off-footprint coordinate by construction: a `LatLng` with `isNearCampus == true` && `CampusProjection().canProject() == false` (assert both in the test setup so the fixture can't silently stop exercising the note).
  - (c) camera viewport matrix at 320×568, wide (1280×800), iPhone (390×844): each pumps without exception **and** assert the real invariants — `_controller.camera.zoom` is within `[mapMinZoom, mapMaxZoom]`, and the visible/fitted region intersects `MapConfig.mapBounds` (map is actually framed, not an empty gutter).
- [ ] **Step 2: Run → PASS** (fix overflows / wrong framing if any).
- [ ] **Step 3: Commit** — `test(map): 320x568/2.0 + camera viewport matrix (M1 T10)`

---

## Task 11: Verification gate + closeout

**Files:** Append a closeout to the M1 design spec.

- [ ] **Step 1: Full static + test** — `flutter analyze && flutter test` — clean; suite = Task 0 floor + new; **Phase A/B tests green** (heading math untouched; location seam unchanged).
- [ ] **Step 2: Builds** — `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — all succeed.
- [ ] **Step 3: Web-runtime render (gate, NOT just build)** — serve `build/web`, open the Map tab: dark illustrated base paints, venue/parking pins in place, pan/zoom works within the negative-zoom clamp, panorama toggle switches, **no black screen**. Record PASS/FAIL + a screenshot.
- [ ] **Step 4: iOS Impeller render** — launch the simulator, open Map: confirm the `OverlayImage` basemap actually paints (not blank/garbled); the dot sits on campus. Record PASS/FAIL.
- [ ] **Step 5: On-device alignment sanity** — with a fix (or a simulated position), the dot lands on the correct campus location; ≥3 venue pins visually match their buildings on the illustration.
- [ ] **Step 5b: Raster memory/perf + sharpness gate** — the basemap M1 renders is the **M0-reskinned `assets/maps/mqcampus_dark.png` = 2048×1448 ≈ 11.3 MiB decoded** (NOT the 4678×3307 / ~59 MiB source — M0 already downscaled it). Exercise on device: open Map → pan → max zoom → switch to panorama → back to Map → repeat. Record: no OOM/memory-pressure, no major jank, **and the real open question — is 2048px still sharp at max campus zoom, or does it read soft?** If soft, that's an **M0 revisit** (regenerate the reskin at a higher target width and re-run M0's memory gate), not an M1 hack. Record decoded footprint + the sharpness verdict.
- [ ] **Step 6: Closeout** — append: the Task 0 calibration receipt, the re-baselined test count, all build + render results, the alignment note, and the split: **M1 CODE COMPLETE** (analyze/tests green, 3 builds green, base renders on web + iOS, dot/markers projected, no Phase A/B regression) vs **release** (rolls up with the program).
- [ ] **Step 7: Final re-gate** — `flutter analyze && flutter test && git diff --check && git status --short`, then a hostile read of `git diff` for the phase. **If the web-runtime/iOS checks required any code fix, re-run all three builds (web/iOS/apk) AND the full test suite before declaring code-complete** — a fix invalidates the earlier green.
- [ ] **Step 8: Commit** — `docs(map): M1 verification + closeout (basemap platform code-complete)`

---

## Self-Review

**Spec coverage:** §3.1 types (T1) · §3.2 projection incl. validation/domain/fail-closed (T2) · drift (T3) · venue integrity (T4) · §4.1 camera/constants (T5, T9) · basemap (T6) · §4.3 zoom-aware circle + low-accuracy preserved + anisotropy (T7) · §4.2 projected-once null-safety + §4.4 markers/follow-me (T9) · off-illustration l10n (T8) · 2.0 + viewport (T10) · web-runtime + iOS + no-regression (T11). Covered.

**Placeholder scan:** projection, geometry, drift, integrity, basemap, circle are complete code; the map_screen wiring (T9) is exact edits against real line refs + a fully-pinning test. No TBD.

**Type consistency:** `GpsPoint`/`CampusPixelPoint`/`CampusMapPoint`; `CampusProjection.{project→CampusMapPoint?, canProject, mapNorth, mapEast}`; `UserLocationCircle({center,fix})`/`UserLocationDot({center})`; `MapConfig.{mapBounds,mapMinZoom,mapMaxZoom}` — consistent across tasks. All flutter_map APIs (`MapCamera.of`/`projectAtZoom`, `CameraFit.bounds`, `CircleMarker(useRadiusInMeter:false)`, `OverlayImage`, `CrsSimple`) verified against installed 8.3.1 source.
