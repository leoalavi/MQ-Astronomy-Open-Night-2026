# MQ Journey Map Parity → AON — Program Spec (design)

**Status:** design, gauntlet round 2 applied. Program umbrella. Forked from `main` (5312b14, post Phase B) onto `feature/map-parity-program`.

**Supersedes:** `2026-08-13-aon-map-overlays-phaseC1-design.md` (raster-overlays-on-the-dark-OSM-map — abandoned; see §2).

## 1. Goal

**100% *functional* parity against a frozen MQ-map capability matrix (§3), with intentional AON-specific adaptations documented as parity-preserving deviations.** Concretely: replace AON's dark OSM/WGS84 map with MQ Journey's map *platform* — the `CrsSimple` illustrated campus basemap, its GPS→pixel projection, thematic map layers, building registry + search, on-campus wayfinding, and AR/compass — **night-reskinned**, with a **hybrid data model**, keeping AON's shipped features (panorama, `DataConfidence` honesty). Phase A (live location) and Phase B (heading) are **re-seated**, not discarded.

"100% parity" does **not** mean byte-identical to MQ. We deliberately deviate (dark reskin, hybrid data, panorama retained, offline-tile service not ported, possibly reduced AR, localised chrome). Each deviation is a *documented* row in the capability matrix, not a silent gap. A real 10/10 = every matrix row is either `parity` or `intentional-deviation (evidence)`.

This is a **program**, not a phase. Six phases (M0–M5), each its own spec → plan → TDD → verify → merge, as Phases A/B were run.

## 2. Why "replace the map" (measured discoveries)

1. **The MQ "overlays" are full illustrated basemap flyers, not data layers.** Each `overlay_*.png` is 3509×2481, **~94% opaque**, cream-dominated (`216,216,192`), with **baked-in English legend + MQ letterhead + a "Parking Map" title**, sharing a common basemap re-inked per theme (water vs permits 95% identical). MQ places them as a plain rectangular `OverlayImage(bounds:)` at **opacity 0.95** — never `RotatedOverlayImage`. They are the **bright illustrated basemap sliced four ways** — i.e. *alternate full basemaps*, which is why they must be **exclusive thematic variants**, not stacked toggles (§6 M2).
2. **`CrsSimple` dissolves overlay placement.** Drawn in the basemap's pixel space, on the `CrsSimple` base they share the same `bounds` — no affine-corner derivation, no rotation, no ≤5 m test.
3. **AON has no confirmed structured geodata for "native" layers.** `routes_data` is entirely `DataConfidence.placeholder`, `isAccessible = null`; water/fountain coords exist nowhere but flyer pixels; parking is already point-markers. AON's West-6-null rule forbids inventing pins off a low-res flyer. So the honest source for parking/water/accessibility *visual* info is the calibrated illustrated raster (reskinned) — with the accessibility limitation named honestly (§9).

## 3. Scope decisions + the parity matrix

**Locked by the user (2026-08-15):** night-reskinned parity · reskin **(c)** cream→slate keep-ink · everything incl. routing + AR · hybrid data (MQ 170-building registry + AON curated venues as event layer).

**Capability matrix (frozen at approval; each phase fills its rows with evidence).** Columns: *MQ behaviour · AON target · status (parity / intentional-deviation / open) · evidence*.

| Capability | AON target (summary) | Phase |
|---|---|---|
| Basemap | reskinned `CrsSimple` illustrated raster (dark) — *deviation: dark* | M0/M1 |
| Projection | ported `gcp_affine`, **non-clamping for live data** (§7) | M1 |
| Live location | Phase A dot/circle re-seated | M1 |
| Thematic layers | **exclusive** reskinned variants (parking/water/accessibility/permits) — *deviation: exclusive, dark* | M2 |
| Buildings | hybrid: MQ 170 registry + AON curated event layer | M3 |
| Search | MQ building search | M3 |
| Routing engine | **non-Google** provider (P0, §6 M4) — *deviation: provider* | M4 |
| Route panel / turn-by-turn | ported, projected geometry | M4 |
| AR building picker | ported (needs M3 + Phase B) | M5 |
| Compass mode | reuse Phase B heading | M5 |
| Mode toggle | `{ campusMap, panorama, ar }` — *deviation: panorama retained* | M5 |
| Offline tiles (FMTC) | **not ported** (raster is in-bundle) — *deviation, IOU-P5* | — |
| In-map legend l10n | English baked raster — *deviation, IOU-P1* | M0 |

## 4. Architecture (target) + the coordinate contract

`flutter_map` 8.3.1 under **`CrsSimple`** (pixel/Cartesian map units — **not** WGS84 tiles), rendering the reskinned basemap as a single `OverlayImage`, GPS projected through a ported `CampusProjection`. Replaces AON's WGS84 `TileLayer`.

**Layer order (target children):**
```
CampusMapOverlay        (reskinned basemap OR the selected thematic variant — exclusive)   ← M0/M1/M2
CampusMapRouteLayer     (projected route PolylineLayer, when navigating)                    ← M4
MarkerLayer             (M1: AON venues/parking re-seated → M3: + MQ registry, hybrid)
CampusMapLocationLayer  (Phase A dot + accuracy circle, re-projected, NON-clamped)          ← M1
controls / sheets       (recenter, layers, search, mode toggle)
```

**Strong coordinate types (introduced in M1 — non-negotiable).** WGS84 degrees and `CrsSimple` map-units are **both** `LatLng` shapes and must not be interchangeable. M1 introduces semantic wrappers:
```dart
class GpsPoint    { final LatLng value; }   // WGS84 degrees — Phase A/B geographic math
class CampusPoint { final double x, y; }     // pixel space (MQ already has this)
// map-unit LatLng only appears at the flutter_map boundary, produced by the projection
```
Rule: **GPS math accepts `GpsPoint`; the projection converts `GpsPoint → CampusMapPoint?`; map layers accept only projected points.** This kills the "code thinks 60,85 are degrees" bug (Phase B computes real bearings/distances).

**Projection (ported from MQ, but hardened):**
- `mapCoordinateScale = max(1, max(pixelW/170, pixelH/85)) = max(1, max(27.518, 38.906)) = **38.906**`; so `mapNorth = pixelH/scale = **85.0**` (lat/y), `mapEast = pixelW/scale = **120.24**` (lng/x); Y flipped (`pixelYToMapLatitude(y) = (pixelBounds.north − y)/scale`). *(scale formula verified vs `campus_overlay_meta.dart:41-42`; the earlier "120.2/170.0" figures were a computation error — corrected 2026-08-15 gauntlet.)*
- GPS→pixel via `gcp_affine`: normalize into `[0,1]`, `x = a.x[0] + a.x[1]·normLng + a.x[2]·normLat`, likewise `y`. *(verified vs `campus_projection_impl.dart:26-30`.)*
- **NON-CLAMPING for live/user data (P1 fix).** MQ's `gpsToPixel` `.clamp(pixelBounds…)` (`campus_projection_impl.dart:33-40`) would paint a **false "you are here" at the campus edge** for an off-campus user — a data-honesty violation. M1 exposes `gpsToCampusPoint(GpsPoint) → CampusMapPoint?` returning **null** when the result falls outside the calibrated footprint; **never clamp** for the location dot, markers, or route vertices. A separate clamped variant may exist only for non-user-facing internal rendering, and live GPS never uses it.
- **NO silent affine→linear fallback (P1 fix).** MQ silently drops to linear `gpsBounds` interpolation when the affine is missing (`campus_projection_impl.dart:45-64`). That is a plausible-wrong path. M1 **fails closed**: valid calibration → project; missing/invalid calibration → explicit degraded map state, **no fake-position markers**. Linear interpolation survives only as a debug comparison tool, never silent production behaviour.

**Camera:** `initialCameraFit: CameraFit.bounds(mapBounds)` is the **single authoritative** startup rule — `initialCameraFit` takes precedence over `initialCenter`/`initialZoom` in flutter_map, so M1 does **not** also pretend those define startup. Zoom clamps `minZoom = -4.0`, `maxZoom = min(meta.maxZoom, -2.2)` (all negative — `CrsSimple`), tested. `cameraConstraint: CameraConstraint.contain(mapBounds)`. `DarkTileLayer` and `MapConfig.campusCentre` (WGS84) are removed/replaced with map-unit equivalents.

## 5. M0 — Night reskin (a genuine, independent phase)

**M0 is its own phase**: designed, planned, TDD'd, verified, and **merged before M1 starts** (it carries real gates worth an independent rollback point). It is *not* folded into M1.

The reskin is **generated by code** (reproducible, re-runnable when MQ updates art). Direction **(c)**: cream ground → dark AON slate scaled by luminance, **preserve saturated ink**, dim the rest; same transform on all four `overlay_*.png`. **Caveat:** in the prototype (c) read busiest/least-legible (b, luminance-invert, was cleaner), so M0 carries a **hard on-device night-legibility gate**: tune (c) to the AON slate palette; if it can't be made legible at event-night brightness, **fall back to (b)** — a merge condition, not a preference.

**M0 hard gates (all must pass to merge):**
1. **Permission to copy/transform/commit the artwork** — establishing reuse rights is a **pre-commit** gate, *separate from* public-release attribution. Committing transformed MQ PNGs into AON is itself reproduction; if permission isn't established, use **local untracked fixtures**, do not commit the artwork.
2. **Content-freshness** — the flyers bake parking/water/accessibility info that may be stale. Record per asset: content owner · last known update · **AON-2026 applicability** (parking valid? accessible routes valid? water valid?) · baked title/branding suitability · reviewer + date. A perfectly calibrated *old* parking map is still an old parking map — until confirmed, a thematic variant ships labelled neutrally or stays unavailable.
3. **Asset memory/resolution** — a 3509×2481 RGBA decode ≈ **33 MiB**. Freeze: max useful on-device resolution (downscale the source), compression, peak decoded memory, image-cache behaviour, and verify on **iOS (Impeller) + Android + web**. The exclusive-variant model (§6 M2) bounds this to ≤1 thematic image decoded at a time.
4. **Night-legibility** (above).
5. **Integrity receipt** — dimensions · alpha · dominant colour · source · shared-footprint check (all 3509×2481).

**Release-gate carryover:** public-release attribution/licensing (in-app credits + `docs/`). `CODE COMPLETE ≠ RELEASE READY`. Baked English legend is an accepted localisation limitation (IOU-P1).

## 6. Phase decomposition

| Phase | Deliverable | Gating dependency |
|---|---|---|
| **M0 — Night reskin** | Deterministic dark-reskin transform + reskinned basemap & 4 variants; the 5 M0 gates (§5) | none |
| **M1 — Basemap platform** | Port `CampusOverlayMeta` + hardened `CampusProjection` (non-clamping `→ CampusMapPoint?`, fail-closed, strong types §4); `CrsSimple` `FlutterMap` **replacing** the WGS84 map (remove `DarkTileLayer`; authoritative `initialCameraFit`; map-unit bounds); **re-seat Phase A dot + accuracy circle (§7) AND the existing venue/parking `MarkerLayer`** (else pins strand off-map, §7); near-campus guard preserved separately (§7); **web runtime render test** (§9) | M0 merged |
| **M2 — Thematic map variants** | **Exclusive** selection (0 or 1 active): swap the single rendered illustrated image between plain base and each reskinned variant; picker is single-select (radio), not `Set<String>`; per-variant memory gate | M1 |
| **M3 — Buildings + search (hybrid)** | Port `buildings.json` (170) + `Building` + marker layer + search; reconcile with AON `Venue`/`ParkingArea` (§8) behind the data-seam | M1 |
| **M4 — Routing / navigation** | **Non-Google routing provider** compatible with a non-Google basemap (P0 §below); credential architecture; dual-coordinate route pipeline (§below); route `PolylineLayer` (projected) + turn-by-turn; off-campus handoff | provider decision + credential arch + **user-supplied key/billing for the chosen provider** |
| **M5 — AR / compass** | AR building picker + compass view; toggle → `MapMode { campusMap, panorama, ar }` (AON already ships `panorama` — AR is *added*, panorama kept) | **M1 + M3 (registry) + Phase B (heading) + camera permission** |

**Sequencing:** M0 → M1 strict. M2 and M3 depend on M1 (either order). M4 is independent of M2/M3 but blocked on provider+credential+key. M5 requires M1 **and M3 and Phase B**. M1+M2 deliver visual parity; M3 browse/search; M4 wayfinding; M5 AR.

### 🚨 P0 — M4 cannot use Google Routes on this map

Google Maps Platform's Service Specific Terms prohibit using **Routes/Directions content in conjunction with a non-Google map**. The MQ illustrated `CrsSimple` raster is plainly a non-Google map, so `Google Routes → polyline → PolylineLayer → MQ raster` is **not viable**. M4 is therefore a **routing-provider-selection architecture/legal gate**, not just an API-key blocker. Candidate providers whose terms permit non-Google-map display (e.g. Mapbox Directions, OpenRouteService, GraphHopper, self-hosted OSRM/Valhalla) are evaluated in the M4 spec. Google Routes could serve a *separate, non-map* experience if compliant, but never draws on this map.

### M4 credential + privacy + geometry constraints (frozen now)
- **Credentials are not "secret" just because they're in `--dart-define`.** A client-embedded key is recoverable; dart-define only keeps it out of git. The chosen provider needs **provider-specific client restrictions OR a trusted proxy**, decided before implementation. Claude never handles the credential value.
- **Privacy contract changes.** External routing sends the user's GPS off-device, breaking Phase A's "processed on-device" posture. M4 release requires a privacy-disclosure review (App Store privacy / Play Data Safety / third-party-transmission disclosure) — surfaced now, not at submission.
- **Dual-coordinate route pipeline.** Route engines return WGS84 geometry: `GpsPoint origin/dest → provider → WGS84 vertices → project EACH vertex → CampusMapPoint → PolylineLayer`. Raw geographic `LatLng`s never enter the map (the strong types enforce this).
- **Off-campus routes are a product decision.** The raster covers campus only; a 1.8 km route can't be drawn on it. Freeze: outside campus → external-nav handoff / text directions / Phase B "Point me there"; once near the calibrated campus → the internal illustrated route becomes available. Never clamp an off-campus route onto the map.

## 7. Phase A / B re-seating (not a rewrite)

- **Phase A (live location):** dot + accuracy circle move to map-units via `gpsToCampusPoint` (**non-clamping**, §4). The `LocationService`/`LocationController` seam and providers are **unchanged**; only render-layer mapping changes.
- **The existing venue/parking markers (M1, not M3):** AON places them at raw WGS84 (`map_screen.dart:264` `LatLng(v.latitude!, v.longitude!)`). Under `CrsSimple` those read as **map-units** (0–120 / 0–170), so `-33.77` falls off-map and **every pin vanishes**. M1 **must** re-seat the current markers through the projection (they become the curated event layer); M3 adds the registry on top. Hard M1 requirement.
- **Two distinct "off-campus" concepts (do not conflate):**
  - `isWithinCampus(GpsPoint)` — Phase A's **UX** guard, frozen at `MapConfig.locationCampusRadiusMeters = 2500` (2.5 km). A user at Metro/parking is outside the tight raster but still "near campus." **Unchanged.**
  - `canProjectOntoCampusRaster(GpsPoint)` — the **calibration/render** rule (inside the GCP footprint). Drives whether the dot renders on the map. Much smaller than 2.5 km. **New, separate.**
- **Accuracy circle (measure, don't port blindly):** the affine has scale + skew and can be locally anisotropic; a single `pixelWidth/gpsLongitudeSpanMetres/scale` factor is not trustworthy. M1 derives a **local metres→map-unit scale around the fix** (project small north/east GPS offsets, measure both map-space deltas) and **tests** the rendered radius at 10 m/50 m north and east.
- **Phase B (heading):** the *bearing* is geographic and **survives unchanged** (declination, tilt-comp, `HeadingService`); it consumes `GpsPoint`s. No heading math changes.
- **Hard floor:** the existing suite stays green. The projection ships pure-math tests (GPS→pixel→map round-trips + the null-outside-footprint contract). The **"527" figure is carried from Phase B and NOT verified on this base — re-baseline the exact count at M1 Task 0 and freeze it there.**

## 8. Hybrid data reconciliation (M3 seed) — authority split

MQ's `Building` (170, GPS + pixel-exact `campusX/Y`, rich taxonomy) and AON's `Venue`/`ParkingArea` (curated, `DataConfidence`, West-6-null) differ in shape. Unify **behind AON's data-seam** (screens read providers, never `data/*_data.dart`). Authority is **two independent dimensions** (they were conflated before):
- **Semantic authority → AON curated record wins** for a matched identity: label, event status, `DataConfidence`, event-specific content.
- **Render-placement authority → MQ's pixel-exact `campusX/Y` may win** *only after an identity match is confirmed*, because it has no affine residual. Don't force the less-accurate GPS-affine coordinate onto a marker merely because its *record* has higher semantic confidence.

**Mixed precision (constraint):** MQ buildings → `buildingPixelToMapPoint` (exact); AON-only venues → `gpsToCampusPoint` (affine residual). M3 decides whether to backfill `campusX/Y` for AON venues (IOU-P6). Full policy is the M3 spec.

## 9. Global constraints (every phase inherits)

- **`flutter_map` 8.3.1, `CrsSimple`.** No WGS84 tiles once M1 lands. Map-unit `LatLng`s appear only at the flutter_map boundary, produced by the projection (strong types elsewhere, §4).
- **New dependencies only where a phase requires them** (routing provider SDK/http; AR camera/sensor), each justified in its phase spec. FMTC/offline is **not** ported (IOU-P5).
- **Web is a hard gate AND a runtime test.** `flutter build web` green is insufficient (a pre-existing web-runtime black-screen exists). M1 adds a **runtime web render check**: base visible · markers visible · pan/zoom works · panorama toggle survives · no black screen.
- **Raster memory is a gate** at M0/M1/M2 (§5.3); the exclusive-variant model caps simultaneous decodes.
- **`context.aon` palette** for chrome; the raster carries its reskinned colours.
- **EN + FA** for every new string; in-map baked legend is an accepted English-only limitation (IOU-P1).
- **Accessibility — narrowed, honest claim.** The illustrated overlays are **supplemental visual information**; **no critical accessible-navigation or safety workflow may depend solely on interpreting raster artwork** (a screen reader cannot read a fountain or path from pixels). Structured accessible routing is future work, not an M-phase deliverable. The map is never the sole channel for *actionable event tasks* (sheets/markers/text remain).
- **Every new surface passes 320×568 / 2.0**, a11y-labelled.
- **TDD; never weaken an existing test.** 527-floor re-baselined at M1 T0 (§7).
- **Data-seam guard** (`integration_seams_test`): use providers, not `data/*_data.dart`.
- **Per-task gate:** `flutter analyze && flutter test`; web build + runtime render re-verified where the map changes; on-device iOS (Impeller) render check where the map renders.
- **Licence/provenance** — copy/transform permission is a **pre-commit** M0 gate (§5.1); public-release attribution is a release gate. `CODE COMPLETE ≠ RELEASE READY`.

## 10. Hard external dependencies / blockers

- **Routing provider selection + legality (M4, P0).** Must be a non-Google-map-compatible provider (§6).
- **Routing credentials + billing (M4).** User-provisioned; client-restricted or proxied; Claude never handles the value.
- **Camera permission (M5).** iOS `NSCameraUsageDescription` + Android camera permission.
- **MQ artwork reuse rights (M0 pre-commit + release).**

## 11. IOU ledger

- **IOU-P1** — in-map legend/letterhead stay English after reskin (raster). Pay by re-drawn localised legend or moving legend to localised chrome.
- **IOU-P2** — reskin (c) palette/opacity tuned on-device; fall back to (b) if it fails the legibility gate (§5); final tokens recorded at M2 closeout.
- **IOU-P3** — offline routing / degraded-network wayfinding; retain Phase B "Point me there" as the honest fallback.
- **IOU-P4** — full MQ↔AON merge policy (§8) is an M3 deliverable.
- **IOU-P5** — MQ's `offline_maps_service` (FMTC, WGS84 tiles) is **N/A** under a bundled `CrsSimple` raster and is **not ported**.
- **IOU-P6** — backfill pixel-exact `campusX/Y` for AON venues vs keep GPS-affine (§8), decided at M3.
- **IOU-P7** — structured accessible-routing data (real geodata) to lift the accessibility limitation (§9) — future, needs organiser data.

## 12. Scorecard (program, pre-build)

| Axis | Score | What moves it up |
|---|---:|---|
| Parity coverage | 3/10 | Nothing ported. Rises per phase; 10 = every capability-matrix row `parity`/`intentional-deviation(evidence)` + on-device verified. |
| Coordinate honesty | 8/10 | Non-clamping `→ CampusMapPoint?`, fail-closed, strong types, split off-campus concepts — all frozen before M1. Proven by M1's null-outside-footprint + accuracy-radius tests. |
| Night-vision integrity | 6/10 | Reskin (c) chosen + legibility gate/fallback; bounded by on-device tuning. |
| Additive safety (A/B) | 7/10 | Clear re-seat path + marker-stranding caught + test floor; proven by M1 regression. |
| Data honesty | 7/10 | Hybrid keeps `DataConfidence`; authority split; bounded until M3 policy. |
| Legal/privacy realism | 6/10 | P0 (non-Google routing), credential + privacy reviews surfaced at the umbrella, not submission week. |
| Release honesty | 8/10 | Licence pre-commit gate, content-freshness gate, baked-text + accessibility limitations named. |

## 13. Open questions

1. **MQ artwork licence/provenance** — owner + copy/transform permission (M0 pre-commit) + release attribution.
2. **Routing provider** — which non-Google-map-compatible engine (M4), and its credential model (client-restricted vs proxy).
3. **Hybrid conflict policy** — semantic vs render-placement authority specifics when an MQ building *is* an AON venue (M3, §8).
4. **AR scope** — full MQ AR parity vs reduced compass-only event mode (M5).
5. **Reskin (c) tuning target** — AON slate tokens + fallback-to-(b) trigger (M0/M2).
6. **Toggle target** — confirm `{ campusMap, panorama, ar }` (keep panorama, add AR) vs replacing panorama (M5).
7. **Off-campus routing behaviour** — handoff vs text vs Point-me (M4).

## 14. Next step

On approval → **gauntlet M0**, then brainstorm **M0 (night reskin)** in full (design → gauntlet → plan → execute → verify → **merge**) as an independent phase. Only after M0 merges does **M1 (basemap platform)** begin its own cycle. No implementation before each phase's plan is written and gauntletted.
