# M1 — Basemap Platform (design)

**Status:** design, pre-gauntlet. Phase M1 of the map-parity program. On `feature/map-parity-program` (M0 merged into the branch).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` (§4/§6/§7 froze M1's hard decisions; this expands them into a concrete component + test design).

## 1. Goal

Replace AON's WGS84 OSM map with the **`CrsSimple` reskinned illustrated basemap** (M0 assets), rendering under a **hardened, non-clamping GPS→campus projection**, and **re-seat** the Phase A live-location dot/accuracy-circle **and** the existing venue/parking markers onto it — with **no Phase A/B test regression** and a **web-runtime render check** (not just a green build).

Deliverable: the Map tab shows the dark illustrated campus, the live dot sits correctly on it, venue/parking pins are in the right places, pan/zoom/off-campus/follow behave, panorama toggle still works. Overlays (M2), buildings/search (M3), routing (M4), AR (M5) come later.

## 2. What changes vs stays

**Stays untouched:** `LocationService`/`LocationController` seam + providers; `UserLocationFix`; Phase B heading math (geographic bearing); the off-campus **UX** guard `MapConfig.isNearCampus` (2.5 km, raw GPS); panorama mode; category filter; control island; wayfinding FAB.

**Changes:** `MapOptions` (→ `CrsSimple` + `initialCameraFit`); the basemap layer (`DarkTileLayer` → reskinned `OverlayImage`); how the dot, accuracy circle, and venue/parking markers get their map position (raw WGS84 → **projected**).

## 3. The coordinate contract (the load-bearing part)

### 3.1 Types (introduced in M1)
```dart
/// A WGS84 fix in degrees. Wrapper so GPS never silently reaches a map layer.
extension type const GpsPoint(LatLng value) {}
/// A point in CrsSimple map-units, ready for flutter_map. Produced ONLY by the
/// projection — a raw GPS LatLng can never be constructed as one by accident.
extension type const CampusMapPoint(LatLng value) {}
```
`extension type` (zero-cost wrappers) keeps the boundary honest without runtime overhead. flutter_map constructors still take a bare `LatLng`, so we **unwrap (`.value`) only at the final flutter_map call** (`Marker(point: p.value)`, `_controller.move(p.value, …)`); everywhere in *our* pipeline the position is a `CampusMapPoint`, so a raw GPS `LatLng` can't reach a layer by accident. The projection is the sole producer of `CampusMapPoint`.

### 3.2 Projection — synchronous const, non-clamping, fail-closed
The calibration is fixed, so AON bundles it as **compile-time constants** (no async `FutureBuilder` map-init, unlike MQ's json loader — a deliberate robustness simplification). The `campus_overlay_meta.json` is copied into `assets/data/` as the documented source-of-truth, but the app reads constants.

```dart
class CampusProjection {
  const CampusProjection();
  // pixel bounds 0..4678 × 0..3307; mapCoordinateScale = max(1, max(4678/170, 3307/85))
  // affine x=[880.374832,3889.927306,12.547607] y=[2862.069113,-64.093654,-2349.078357]
  // norm minLat -33.7772506 maxLat -33.7703261 minLng 151.1080508 maxLng 151.1211352

  /// GPS → map-units, or **null** when the fix falls OUTSIDE the calibrated
  /// pixel footprint. NEVER clamps — a clamped edge dot is a false "you are
  /// here" (data-honesty). This is the only public projector for live data.
  CampusMapPoint? project(GpsPoint gps);

  /// True iff `project` would return non-null. Drives whether the dot renders.
  bool canProject(GpsPoint gps);
}
```
- Affine is applied on normalized lat/lng; the result is checked against pixel bounds and returns **null if outside** (no `.clamp`). Then pixel → map-unit via the scale + Y-flip.
- **No silent linear fallback.** If the affine were ever invalid the map enters an explicit degraded state; there is no rough-rectangle production path. (Const affine is always valid, so this is a guard, not a runtime branch.)

### 3.3 Two distinct "off-campus" concepts (never conflated)
- `MapConfig.isNearCampus(gps)` — **UX** guard, 2.5 km, raw GPS → drives the off-campus banner. **Unchanged.**
- `CampusProjection.canProject(gps)` — **render** rule (inside the calibrated footprint) → drives whether the dot/circle paint. New.
- A fix can be *near* campus (banner hidden) yet *not projectable* (no dot): then show a small "locating on campus…"/off-illustration note rather than a fake dot. (Copy TBD in plan; honest fallback.)

## 4. Rendering

### 4.1 Camera (map_screen `MapOptions`)
```dart
MapOptions(
  crs: const CrsSimple(),
  initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds, padding: ...),  // AUTHORITATIVE
  minZoom: MapConfig.mapMinZoom,   // -4.0
  maxZoom: MapConfig.mapMaxZoom,   // -2.2
  cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
  backgroundColor: context.aon.surfaceBase,
  onPositionChanged: (camera, hasGesture) { if (hasGesture) …onUserPan(); },  // unchanged
)
```
`initialCenter`/`initialZoom` are **dropped** — `initialCameraFit` takes precedence in flutter_map, so keeping them would be misleading. `MapConfig` gains: `mapBounds = LatLngBounds(LatLng(0,0), LatLng(mapNorth≈120.2, mapEast≈170.0))`, `mapMinZoom=-4.0`, `mapMaxZoom=-2.2`. WGS84 `campusCentre`/`campusBounds`/`initialZoom`/`minZoom`/`maxZoom`/`tileUrlTemplate` stay for the off-campus guard + are unused-by-map (kept, not deleted, to avoid touching Phase B/wayfinding that may read them).

### 4.2 Layers (map_screen children)
```dart
const CampusBasemapLayer(),                                   // reskinned OverlayImage (M2 will swap variant)
if (loc.active && proj.canProject(GpsPoint(loc.fix!.position)))
  UserLocationCircle(center: p, fix: loc.fix!),               // projected
MarkerLayer(markers: projectedMarkers),                       // venues/parking projected
if (loc.active && proj.canProject(...)) UserLocationDot(center: p),
```
- **`CampusBasemapLayer`** (new, `lib/widgets/campus_basemap_layer.dart`): an `OverlayImageLayer` with one `OverlayImage(bounds: mapBounds, imageProvider: AssetImage('assets/maps/mqcampus_dark.png'))`. M2 will make the image the selected thematic variant.
- **Markers:** each venue/parking projected via `proj.project(GpsPoint(LatLng(lat,lng)))`; skip if null (on-campus venues always project). Marker widgets unchanged (`_MarkerPin`).
- **Dot/circle:** `UserLocationCircle`/`UserLocationDot` (`user_location_layer.dart`) take a `CampusMapPoint center` instead of computing from `fix.position`.

### 4.3 Accuracy circle — local metres→map-unit scale (measured, not ported)
The affine has scale + skew, so a single longitude factor is untrustworthy. Compute a **local** scale around the fix:
```dart
// project the fix and a point ~offsetM north; the map-unit distance / offsetM = local scale
double localMapUnitsPerMeter(GpsPoint fix, {double offsetM = 25}) { … }
```
**`user_location_layer.dart` today uses `CircleMarker(point: fix.position, radius: fix.accuracyMeters, useRadiusInMeter: true)` (`:20-23`).** Under `CrsSimple`, `useRadiusInMeter: true` is meaningless (no Earth metres). M1 changes it to **`useRadiusInMeter: false`** with `point:` = the projected `CampusMapPoint.value` and `radius:` = `accuracyMeters × localMapUnitsPerMeter(fix)`, capped. **Tested** at 10 m/50 m north & east. If not projectable near the edge, no circle.

### 4.4 Follow-me recenter must project the fix
`map_screen.dart:67-72` recenters via `ref.listen` → `_controller.move(s.fix!.position, _controller.camera.zoom)` — **raw WGS84**, which under `CrsSimple` moves the camera to map-unit `(-33, 151)` = **off-map**. M1 projects first: move to `proj.project(GpsPoint(s.fix!.position))?.value` and **skip the move if null** (don't fling the camera when the fix isn't on the illustration). The `hasGesture:false` follow-doesn't-self-cancel contract (Phase A §5.7) is preserved. Zoom argument stays `camera.zoom` (now a `CrsSimple` negative zoom — fine).

## 5. Files

**Create:** `lib/models/campus_point.dart` (`CampusPoint` pixel + `GpsPoint`/`CampusMapPoint` extension types), `lib/services/campus_projection.dart` (const projection), `lib/widgets/campus_basemap_layer.dart`, mirrored tests (`test/unit/campus_projection_test.dart`, `test/widget/campus_basemap_layer_test.dart`, `test/widget/map_platform_wiring_test.dart`).
**Modify:** `lib/widgets/map_config.dart` (+map-unit bounds/zooms), `lib/screens/map_screen.dart` (MapOptions + layers + projected markers), `lib/widgets/user_location_layer.dart` (accept `CampusMapPoint`), `pubspec.yaml` (+`assets/data/campus_overlay_meta.json`).
**Add asset:** copy `campus_overlay_meta.json` from MQ → `assets/data/`.

## 6. Testing

- **Projection (pure, the critical suite):** GPS→map round-trips against MQ's published affine; **`project` returns null outside the footprint (no clamp)**; `canProject` boundary; `centerLatitude/Longitude` sanity; determinism. Round-trip a known campus point (e.g. campus centre) and assert it lands mid-map.
- **Accuracy scale:** `localMapUnitsPerMeter` yields the expected rendered radius at 10/50 m N/E (isotropy within tolerance).
- **Basemap layer:** renders one `OverlayImage` at `mapBounds`, no exception under `CrsSimple`.
- **Wiring regression (the M1 proof):** with a projectable fix + an active category, the base, the projected venue/parking markers, and the dot all render and `takeException()` is null; an **off-footprint** fix renders **no dot** (not a clamped edge dot). Panorama toggle still switches.
- **Follow-me projects:** a `following` fix update moves the camera toward the **projected** point (near map-centre for an on-campus fix), never toward raw `(-33,151)`; a non-projectable fix does not move the camera.
- **No Phase A/B regression:** re-baseline the count at Task 0; the suite stays green.
- **Web runtime render check (gate):** serve the web build, load the Map tab, confirm the dark base paints, markers show, pan/zoom works, panorama toggle survives, **no black screen** (the known pre-existing web-runtime issue means a green `flutter build web` is insufficient).
- **iOS Impeller render check:** the `OverlayImage` basemap actually paints on the simulator.

## 7. Risks / decisions to freeze

1. **Const projection vs bundled json** — chosen: **const** (no async map-init; json kept as documented source). Freeze in gauntlet.
2. **Strong-typing scope** — M1 introduces `GpsPoint`/`CampusMapPoint` at the projection↔layer boundary only; Phase B's internal geographic math keeps raw `LatLng`/doubles (it never touches map-units). Not a full Phase-A/B retype.
3. **`_controller.move`/zoom buttons** — the control-island zoom in/out must use the new `mapMinZoom/mapMaxZoom` (-4.0/-2.2) and a `CrsSimple`-appropriate step; verify `clampZoom` still behaves with negative zooms.
4. **`WGS84` constants kept, not deleted** — Phase B/wayfinding may read `MapConfig.campusCentre` etc.; deleting them is out of M1 scope (avoid collateral breakage). M1 only stops the *map* from using them.
5. **Dot-but-not-projectable copy** — the honest note when a fix is near-campus but off the illustrated footprint (plan decides exact string + l10n).

## 8. Scorecard (M1, pre-build)

| Axis | Score | Raises it |
|---|---:|---|
| Coordinate honesty | 8/10 | non-clamping null + fail-closed + typed boundary + accuracy tested. 10 = full GpsPoint typing through Phase A. |
| Additive safety | 7/10 | marker re-seat in M1 + test floor; proven by the wiring regression + web runtime check. |
| Render fidelity | 6/10 | affine-projected on the illustrated base; bounded until on-device ≤ (M2 alignment feel). |
| Testability | 8/10 | projection is pure; wiring + null-edge asserted. |

## 9. Next step

On approval → **gauntlet this design**, then write the M1 TDD plan (Task 0 baseline/re-count → projection (pure, TDD) → basemap layer → map_config map-units → user-location re-seat + accuracy scale → map_screen wiring + marker projection → verification incl. web-runtime + iOS render). No code before the plan is gauntletted.
