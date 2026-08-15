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
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';

void main() {
  test('geometry wrappers hold their value without conflation', () {
    expect(GpsPoint(const LatLng(-33.77, 151.11)).value.latitude, -33.77);
    expect(CampusMapPoint(const LatLng(42.5, 60.1)).value.longitude, 60.1);
    expect(const CampusPixelPoint(Offset(880, 2862)).value.dx, 880);
  });
}
```
- [ ] **Step 2: Run → FAIL** (undefined). `flutter test test/unit/campus_projection_test.dart`.
- [ ] **Step 3: Implement** — `lib/models/campus_geometry.dart`:
```dart
import 'package:flutter/painting.dart' show Offset;
import 'package:latlong2/latlong.dart';

/// WGS84 degrees (projection INPUT). A wrapper so a GPS LatLng cannot be passed
/// to a map layer un-projected. Note: does not validate range — the projection
/// validates (extension types guard semantics, not data).
extension type const GpsPoint(LatLng value) {}

/// Raster pixel space (intermediate).
extension type const CampusPixelPoint(Offset value) {}

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
  static const double _scale = 38.905882;               // max(1,max(_pw/170,_ph/85))
  static const List<double> _ax = [880.374832, 3889.927306, 12.547607];
  static const List<double> _ay = [2862.069113, -64.093654, -2349.078357];
  static const double _minLat = -33.7772506, _maxLat = -33.7703261;
  static const double _minLng = 151.1080508, _maxLng = 151.1211352;
  static const double _eps = 1e-9;

  static double get mapNorth => _ph / _scale;           // 85.0
  static double get mapEast => _pw / _scale;            // 120.2389

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

- [ ] **Step 1: Write the test** (it should PASS immediately — it locks the constants to the vendored JSON):
```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiled projection constants match docs/fixtures calibration', () {
    final j = jsonDecode(
        File('docs/fixtures/campus_overlay_meta.json').readAsStringSync());
    final pb = j['pixelBounds'];
    expect(pb['east'], 4678);
    expect(pb['north'], 3307);
    final aff = j['gpsProjection']['affine'];
    expect((aff['x'] as List).map((e) => (e as num).toDouble()).toList(),
        [880.374832, 3889.927306, 12.547607]);
    expect((aff['y'] as List).map((e) => (e as num).toDouble()).toList(),
        [2862.069113, -64.093654, -2349.078357]);
    final n = aff['normalization'];
    expect(n['minLat'], -33.7772506);
    expect(n['maxLat'], -33.7703261);
    expect(n['minLng'], 151.1080508);
    expect(n['maxLng'], 151.1211352);
  });
}
```
- [ ] **Step 2: Run → PASS** (fails loudly if the constants and the vendored JSON ever diverge).
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
- [ ] **Step 2: Run → PASS.** *If it fails:* a real venue is outside the normbox → apply the design §7-1 decision (loosen domain to pixel-footprint-only, record why) and re-run — do NOT allowlist a legitimate venue.
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
- [ ] **Step 3: Implement** — add to `map_config.dart` (keep the WGS84 constants; they stay for Phase B/wayfinding):
```dart
  // ── CrsSimple campus-map units (Map Parity M1). Derived from the Task 0
  //    receipt: scale = max(1,max(4678/170,3307/85)) = 38.905882.
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(0, 0),
    const LatLng(85.0, 120.2389),   // (mapNorth lat, mapEast lng)
  );
  static const double mapMinZoom = -4.0;
  static const double mapMaxZoom = -2.2;
```
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

**Files:** Modify `lib/widgets/user_location_layer.dart`; Create `test/widget/user_location_layer_test.dart`.

**Interfaces:** `UserLocationCircle({required CampusMapPoint center, required UserLocationFix fix})`, `UserLocationDot({required CampusMapPoint center})`.

- [ ] **Step 1: Failing tests** — (a) low-accuracy fix → no circle; (b) good fix at higher zoom → larger pixel radius (same footprint):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

const _proj = CampusProjection();
final _centre = _proj.project(const GpsPoint(LatLng(-33.7737, 151.1134)))!;

Widget _host(Widget child, {double zoom = -3.6}) => MaterialApp(
  home: Scaffold(body: FlutterMap(
    options: MapOptions(
      crs: const CrsSimple(),
      initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds),
    ),
    children: [child],
  )),
);

void main() {
  testWidgets('low-accuracy fix paints no circle', (t) async {
    final fix = UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 250);
    await t.pumpWidget(_host(UserLocationCircle(center: _centre, fix: fix)));
    await t.pump();
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('good fix paints a circle', (t) async {
    final fix = UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 15);
    await t.pumpWidget(_host(UserLocationCircle(center: _centre, fix: fix)));
    await t.pump();
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
```
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — rewrite `user_location_layer.dart`. Key change: circle is camera-aware, radius in screen pixels via `MapCamera.projectAtZoom`; keep the `isLowAccuracy` short-circuit; dot takes `center`.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';

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
    // metres→pixels: project the fix + a 25 m offset N and E, measure both.
    final north = _proj.project(GpsPoint(
        const Distance().offset(fix.position, 25, 0)));
    final east = _proj.project(GpsPoint(
        const Distance().offset(fix.position, 25, 90)));
    if (north == null || east == null) return const SizedBox.shrink();
    final c = camera.projectAtZoom(center.value);
    final nPx = (camera.projectAtZoom(north.value) - c).distance / 25.0;
    final ePx = (camera.projectAtZoom(east.value) - c).distance / 25.0;
    // anisotropy ≤5% → single radius; else the conservative (larger) one.
    final pxPerM = (nPx - ePx).abs() / (nPx > ePx ? nPx : ePx) <= 0.05
        ? (nPx + ePx) / 2
        : (nPx > ePx ? nPx : ePx);
    final accent = context.aon.accent;
    return CircleLayer(circles: [
      CircleMarker(
        point: center.value,
        radius: fix.accuracyMeters * pxPerM,   // screen pixels (useRadiusInMeter:false)
        useRadiusInMeter: false,
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

- [ ] **Step 1: Failing wiring test** — reuse the Phase A `FakeLocationService` container pattern (`map_location_wiring_test.dart`). Cases: (a) projectable fix + active parking category → `CampusBasemapLayer`, `UserLocationDot`, and the parking `MarkerLayer` all present, `takeException()` null; (b) **active + null fix → no crash, no dot**; (c) **off-footprint fix** (e.g. `LatLng(-33.90,151.30)`) → **no `UserLocationDot`** (not a clamped edge dot); (d) panorama toggle still switches to `PanoramaBuildingPicker`. (Do not assert z-order.)
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
  5. **Follow-me** (`ref.listen`, ~:67-72): project before moving:
     ```dart
     if (s.following && s.fix != null && !s.fix!.isLowAccuracy) {
       final mp = _proj.project(GpsPoint(s.fix!.position));
       if (mp != null) _controller.move(mp.value, _controller.camera.zoom);
     }
     ```
  6. **Off-illustration note** — where the off-campus/low-accuracy notes are chosen, add: if `loc.active && fix != null && MapConfig.isNearCampus(fix.position) && projected == null` → show `_MapNote(text: l.mapLocatingOnCampus)`.
  7. **Zoom buttons** (`MapControlIsland`) — `clampZoom(..., min: MapConfig.mapMinZoom, max: MapConfig.mapMaxZoom)`.
- [ ] **Step 4: Run tests + build** — `flutter test test/widget/map_platform_wiring_test.dart && flutter analyze && flutter build web` — PASS/clean/green.
- [ ] **Step 5: Commit** — `feat(map): replace WGS84 map with CrsSimple basemap; project dot/markers/follow-me (M1 T9)`

---

## Task 10: 320×568 / 2.0 + camera viewport matrix

**Files:** extend `test/widget/map_platform_wiring_test.dart`.

- [ ] **Step 1: Tests** — (a) MapScreen at `view.physicalSize = Size(320,568)` + `textScaleFactorTestValue = 2.0`, projectable fix, `pumpAndSettle`, `takeException()` null (base + markers + note + controls + panorama toggle); (b) camera fit at 320×568, a wide size (e.g. 1280×800), and iPhone (390×844) each pumps without exception and the map fills the viewport (no assertion crash from `CameraConstraint`).
- [ ] **Step 2: Run → PASS** (fix overflows if any).
- [ ] **Step 3: Commit** — `test(map): 320x568/2.0 + camera viewport matrix (M1 T10)`

---

## Task 11: Verification gate + closeout

**Files:** Append a closeout to the M1 design spec.

- [ ] **Step 1: Full static + test** — `flutter analyze && flutter test` — clean; suite = Task 0 floor + new; **Phase A/B tests green** (heading math untouched; location seam unchanged).
- [ ] **Step 2: Builds** — `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — all succeed.
- [ ] **Step 3: Web-runtime render (gate, NOT just build)** — serve `build/web`, open the Map tab: dark illustrated base paints, venue/parking pins in place, pan/zoom works within the negative-zoom clamp, panorama toggle switches, **no black screen**. Record PASS/FAIL + a screenshot.
- [ ] **Step 4: iOS Impeller render** — launch the simulator, open Map: confirm the `OverlayImage` basemap actually paints (not blank/garbled); the dot sits on campus. Record PASS/FAIL.
- [ ] **Step 5: On-device alignment sanity** — with a fix (or a simulated position), the dot lands on the correct campus location; ≥3 venue pins visually match their buildings on the illustration.
- [ ] **Step 6: Closeout** — append: the Task 0 calibration receipt, the re-baselined test count, all build + render results, the alignment note, and the split: **M1 CODE COMPLETE** (analyze/tests green, 3 builds green, base renders on web + iOS, dot/markers projected, no Phase A/B regression) vs **release** (rolls up with the program).
- [ ] **Step 7: Final re-gate** — `flutter analyze && flutter test && git diff --check`, then a hostile read of `git diff` for the phase.
- [ ] **Step 8: Commit** — `docs(map): M1 verification + closeout (basemap platform code-complete)`

---

## Self-Review

**Spec coverage:** §3.1 types (T1) · §3.2 projection incl. validation/domain/fail-closed (T2) · drift (T3) · venue integrity (T4) · §4.1 camera/constants (T5, T9) · basemap (T6) · §4.3 zoom-aware circle + low-accuracy preserved + anisotropy (T7) · §4.2 projected-once null-safety + §4.4 markers/follow-me (T9) · off-illustration l10n (T8) · 2.0 + viewport (T10) · web-runtime + iOS + no-regression (T11). Covered.

**Placeholder scan:** projection, geometry, drift, integrity, basemap, circle are complete code; the map_screen wiring (T9) is exact edits against real line refs + a fully-pinning test. No TBD.

**Type consistency:** `GpsPoint`/`CampusPixelPoint`/`CampusMapPoint`; `CampusProjection.{project→CampusMapPoint?, canProject, mapNorth, mapEast}`; `UserLocationCircle({center,fix})`/`UserLocationDot({center})`; `MapConfig.{mapBounds,mapMinZoom,mapMaxZoom}` — consistent across tasks. All flutter_map APIs (`MapCamera.of`/`projectAtZoom`, `CameraFit.bounds`, `CircleMarker(useRadiusInMeter:false)`, `OverlayImage`, `CrsSimple`) verified against installed 8.3.1 source.
