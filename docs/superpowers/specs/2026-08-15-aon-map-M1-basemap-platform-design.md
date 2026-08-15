# M1 — Basemap Platform (design)

**Status:** design, gauntlet round 2 applied. Phase M1 of the map-parity program. On `feature/map-parity-program` (M0 merged into the branch).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` (§4/§6/§7). This expands M1 into a concrete, gauntletted component + test design.

## 1. Goal

Replace AON's WGS84 OSM map with the **`CrsSimple` reskinned illustrated basemap** (M0 assets), under a **hardened, non-clamping GPS→campus projection**, re-seating the Phase A dot/accuracy-circle **and** the venue/parking markers — no Phase A/B test regression, and a **web-runtime render check**.

## 2. What changes vs stays

**Stays:** `LocationService`/`LocationController` seam + providers; `UserLocationFix`; Phase B heading math (geographic); the off-campus **UX** guard `MapConfig.isNearCampus` (2.5 km, raw GPS); panorama mode; category filter; control island; wayfinding FAB; **Phase A's low-accuracy circle suppression** (§4.3).

**Changes:** `MapOptions` (→ `CrsSimple` + `initialCameraFit`); basemap layer (`DarkTileLayer` → reskinned `OverlayImage`); how dot, circle, venue/parking markers, and follow-me get their map position (raw WGS84 → **projected**).

## 3. The coordinate contract

### 3.1 Types (M1)
```dart
extension type const GpsPoint(LatLng value) {}          // WGS84 degrees (input)
extension type const CampusMapPoint(LatLng value) {}    // CrsSimple map-units (output, for flutter_map)
```
Pipeline: `GpsPoint → (affine, internal double pixel math) → CampusMapPoint`. (No public `CampusPixelPoint` — the pixel stage is internal doubles; an unused wrapper is YAGNI.) flutter_map takes a bare `LatLng`, so we **unwrap `.value` only at the final flutter_map call**; everywhere in our code the position is typed. `extension type` = zero runtime cost. **Caveat documented:** a `CampusMapPoint.value` is NOT a valid geographic lat/lng — it must never be fed to `latlong2 Distance`/bearing/Phase B math (§6 has a guard test).

### 3.2 Projection — const, validated, non-clamping, fail-closed, explicit domain
Calibration is fixed → bundled as **compile-time constants** (no async map-init). Validity is a **build/test invariant**: an invalid constant set fails tests and cannot merge (there is no runtime "degraded calibration" recovery path — that earlier wording is dropped).

```dart
class CampusProjection {
  const CampusProjection();
  CampusMapPoint? project(GpsPoint gps);   // null outside the frozen domain; NEVER clamps
  bool canProject(GpsPoint gps);           // == project(gps) != null
}
```
`project` order (fail-closed):
1. **Validate GPS** — `lat`/`lng` finite; `-90 ≤ lat ≤ 90`; `-180 ≤ lng ≤ 180`. Invalid → `null` (an `extension type` does not enforce data validity — validation lives here).
2. **Domain gate (frozen, §7-1)** — the accepted input domain is the calibration's normalization box **and** the resulting pixel inside the raster footprint. Requiring *both* prevents an out-of-region GPS from extrapolating through the affine into an in-bounds pixel (accidental accept). The venue-projection test (§6) proves every real venue lies inside this domain; if any legitimate venue falls outside the normalization box, the domain is re-frozen to pixel-footprint-only **with that decision recorded** — not left accidental.
3. Apply affine → `CampusPixelPoint`; reject if outside pixel bounds.
4. Pixel → map-units (scale + Y-flip) → `CampusMapPoint`.

**No silent linear fallback.** (MQ's linear path is not ported to production; it may exist only as a debug comparator in tests.)

### 3.3 Two distinct "off-campus" concepts (never conflated)
- `MapConfig.isNearCampus(gps)` — **UX** guard, 2.5 km, raw GPS → off-campus banner. **Unchanged.**
- `CampusProjection.canProject(gps)` — **render** rule → whether the dot/circle paint. New.
- Near-campus-but-not-projectable → a small l10n "locating on the campus map…" note (EN+FA, §5), **never a fake dot**.

## 4. Rendering

### 4.1 Camera + the CORRECTED map constants
**Corrected (gauntlet 2):** `scale = max(1, max(4678/170, 3307/85)) = 38.906`. Therefore:
```
mapNorth (lat/y) = 3307 / 38.906 = 85.0
mapEast  (lng/x) = 4678 / 38.906 = 120.24
mapBounds = LatLngBounds(LatLng(0, 0), LatLng(85.0, 120.24))   // center (42.5, 60.12)
mapMinZoom = -4.0 ;  mapMaxZoom = -2.2                          // CrsSimple (negative)
```
*(The prior 120.2/170.0 were a computation error. Task 0 re-derives these from a printed receipt — pixelW/H → scale → bounds → center — and the constants are copied from that receipt, never from a summary.)*
```dart
MapOptions(
  crs: const CrsSimple(),
  initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds,
      padding: EdgeInsets.all(12)),      // AUTHORITATIVE (initialCenter/Zoom dropped)
  minZoom: MapConfig.mapMinZoom, maxZoom: MapConfig.mapMaxZoom,
  cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
  backgroundColor: context.aon.surfaceBase,
  onPositionChanged: (camera, hasGesture) { if (hasGesture) …onUserPan(); },
)
```
WGS84 `MapConfig` constants (`campusCentre`/`campusBounds`/`initialZoom`/`min/maxZoom`/`tileUrlTemplate`) are **kept, not deleted** — Phase B/wayfinding read them; M1 only stops the *map* using them.

### 4.2 Layers — compute the projected fix ONCE (null-safe)
Phase A can be `active == true` with `fix == null` (awaiting first sensor). Compute once:
```dart
final fix = loc.fix;
final projected = (fix == null) ? null : projection.project(GpsPoint(fix.position));
// reused by circle, dot, follow-me, and the off-illustration note — one affine eval
```
```dart
children: [
  const CampusBasemapLayer(),                          // reskinned OverlayImage (M2 swaps variant)
  if (loc.active && projected != null)
    UserLocationCircle(center: projected, fix: fix!),  // fix non-null in this branch
  MarkerLayer(markers: projectedMarkers),              // venues/parking projected (§4.4)
  if (loc.active && projected != null)
    UserLocationDot(center: projected),
]
```
`CampusBasemapLayer` (new): `OverlayImageLayer([OverlayImage(bounds: mapBounds, imageProvider: AssetImage('assets/maps/mqcampus_dark.png'))])`.

### 4.3 Accuracy circle — zoom-aware SCREEN-PIXEL radius (corrected)
`user_location_layer.dart:20-24` today: `CircleMarker(point: fix.position, radius: fix.accuracyMeters, useRadiusInMeter: true)`. Under `CrsSimple`, `useRadiusInMeter: true` uses hardcoded WGS84 haversine → meaningless. And `useRadiusInMeter: false` interprets `radius` in **screen pixels**, not map-units — so feeding map-units there is wrong (constant on-screen size across zoom).

**Correct model** (camera-aware, rebuilds on zoom): convert metres → screen pixels at the current zoom via the camera:
```dart
final camera = MapCamera.of(context);
final cPx = camera.projectAtZoom(center.value);                         // Offset
final nPx = camera.projectAtZoom(projectOffsetMetres(fix, north: 25));  // 25 m north, projected
final pixelsPerMetre = (nPx - cPx).distance / 25.0;
final radiusPx = fix.accuracyMeters * pixelsPerMetre;
CircleMarker(point: center.value, radius: radiusPx, useRadiusInMeter: false, …);
```
- **Preserve Phase A policy (verified `:19`):** `if (fix.isLowAccuracy) return SizedBox.shrink();` — no suburb-sized blob. Unchanged.
- **Anisotropy tolerance (frozen):** measure metres→pixels **north and east**; `anisotropy = |n−e| / max(n,e)`. **≤ 5% → single-radius `CircleMarker` accepted**; `> 5%` → use the larger (conservative) radius. (At campus scale expected ≪5%, but the gate is explicit, tested.)
- **Zoom regression (required):** same 20 m accuracy at zoom −3.8 vs −2.8 → `radiusPx` grows, same projected footprint.

### 4.4 Markers + follow-me project
- **Markers:** each venue/parking → `projection.project(GpsPoint(LatLng(lat,lng)))`; skip `null`. A **data-integrity test (§6)** asserts every current venue/parking coord projects (allowlisting deliberately-null records like West-6), so a curated pin can never silently vanish.
- **Follow-me** (`map_screen.dart:67-72`): `_controller.move(s.fix!.position, …)` is raw WGS84 → off-map under `CrsSimple`. Move to `projection.project(GpsPoint(s.fix!.position))?.value`; **skip if null**. `hasGesture:false` follow-not-self-cancel (Phase A §5.7) preserved; zoom arg stays `camera.zoom`.
- **Zoom buttons** (control island): clamp to `mapMinZoom/mapMaxZoom` (−4.0/−2.2) with a CrsSimple step; verify `clampZoom` behaves with negatives.

## 5. Files

**Create:** `lib/models/campus_geometry.dart` (`GpsPoint`/`CampusPixelPoint`/`CampusMapPoint`), `lib/services/campus_projection.dart` (const projection + GPS validation), `lib/widgets/campus_basemap_layer.dart`; tests `test/unit/campus_projection_test.dart`, `test/unit/campus_calibration_drift_test.dart`, `test/unit/venue_projection_integrity_test.dart`, `test/widget/campus_basemap_layer_test.dart`, `test/widget/map_platform_wiring_test.dart`.
**Modify:** `lib/widgets/map_config.dart` (+map-unit bounds/zooms), `lib/screens/map_screen.dart` (MapOptions + layers + projected markers + follow-me), `lib/widgets/user_location_layer.dart` (accept `CampusMapPoint`, camera-aware radius), `lib/l10n/app_en.arb` + `app_fa.arb` (+ off-illustration note), regenerate l10n.
**Calibration source (NOT bundled):** copy MQ's `campus_overlay_meta.json` to **`docs/fixtures/campus_overlay_meta.json`** (documented source-of-truth; production uses constants). A **drift test** parses it and asserts every value equals the compiled constants. Not under `assets:` (production never loads it).

## 6. Testing

- **Projection (pure) — reference-vector tests** (not "round-trips"; no inverse API is added just for wording): known GPS inputs → expected map-units computed from MQ's published affine; **`project` returns null outside the frozen domain (no clamp)**; **invalid GPS (NaN, out-of-range) → null**; `canProject` boundary; campus centre lands mid-map (≈42.5, 60.12); determinism.
- **Calibration drift:** `docs/fixtures/campus_overlay_meta.json` values == compiled constants (pixel W/H, normalization, affine x/y, scale). Fails if they diverge.
- **Venue/parking projection integrity:** every current record with coordinates projects non-null; deliberately-null records (West-6) are an explicit allowlist. Guards against silently-vanishing curated markers.
- **Accuracy circle:** zoom regression (radius grows with zoom, same footprint); N/E anisotropy ≤5% → circle; **low-accuracy fix → no circle** (Phase A policy preserved).
- **Basemap layer:** one `OverlayImage` at `mapBounds`, no exception under `CrsSimple`.
- **Wiring regression (M1 proof):** projectable fix + active category → base + projected markers + dot render, `takeException()` null; **off-footprint fix → no dot** (not a clamped edge dot); **active + null-fix → no crash**; **follow-me moves toward the projected point**, never raw `(-33,151)`; panorama toggle still switches.
- **Geographic-guard:** a `CampusMapPoint.value` is finite at max bounds and is never passed to `latlong2 Distance`/bearing (compile-boundary + a lint-style assertion test).
- **320×568 / 2.0:** MapScreen (base + markers + off-illustration note + controls + panorama toggle) survives; the new note is the collision risk.
- **Camera viewport matrix:** initial fit shows the full map with no giant gutters and a coherent `CameraConstraint` at 320×568, a wide/web viewport, and a typical iPhone; zoom buttons clamp between the negative min/max.
- **No Phase A/B regression:** re-baseline the count at Task 0; suite stays green.
- **Web-runtime render (gate):** open Map in the browser build — dark base paints, markers show, pan/zoom works, panorama survives, **no black screen** (a green `flutter build web` is insufficient).
- **iOS Impeller render:** the `OverlayImage` basemap actually paints on the simulator.

## 7. Decisions frozen

1. **Projection domain** = normalization-box ∧ pixel-footprint (both), unless the venue-integrity test shows a legitimate venue outside the box → then pixel-footprint-only, decision recorded. Not accidental.
2. **Const projection**, validity as a build/test invariant (no runtime degraded state). `campus_overlay_meta.json` lives in `docs/fixtures/` (not `assets:`), guarded by the drift test.
3. **Strong typing** scoped to the projection↔layer boundary (`GpsPoint`/`CampusPixelPoint`/`CampusMapPoint`); Phase B keeps raw geographic `LatLng`/doubles.
4. **Accuracy circle** = zoom-aware screen-pixel radius via `MapCamera.projectAtZoom`, Phase A low-accuracy suppression preserved, ≤5% anisotropy → single circle.
5. **Projected-fix computed once** per build; reused by circle/dot/follow/note.
6. **WGS84 `MapConfig` constants kept**, not deleted (Phase B/wayfinding read them).

## 8. Scorecard (M1, pre-build)

| Axis | Score | Raises it |
|---|---:|---|
| Coordinate correctness | 8/10 | scale/bounds corrected + Task-0 receipt + drift test. 10 = the receipt is checked in. |
| Coordinate honesty | 8/10 | non-clamping null + GPS validation + frozen domain + typed boundary. |
| Additive safety | 7/10 | marker re-seat + venue-integrity gate + null-fix safety + low-accuracy preserved; proven by wiring + web-runtime. |
| Render fidelity | 6/10 | zoom-aware circle + affine placement; bounded until on-device. |
| Testability | 8/10 | pure projection + drift + integrity + zoom + viewport tests. |

## 9. Next step

Design is gauntlet-clean. Next → write the M1 TDD plan (Task 0 baseline/re-count + **the calibration receipt** → geometry types → projection (pure, TDD, incl. validation/domain) → drift + venue-integrity tests → basemap layer → map_config map-units → user-location re-seat + zoom-aware circle → map_screen wiring + markers + follow-me → l10n note → verification incl. web-runtime + iOS + viewport). No code before the plan is gauntletted.
