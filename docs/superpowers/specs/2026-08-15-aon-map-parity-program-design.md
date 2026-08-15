# MQ Journey Map Parity → AON — Program Spec (design)

**Status:** design, pre-gauntlet. Program umbrella. Forked from `main` (5312b14, post Phase B) onto `feature/map-parity-program`.

**Supersedes:** `2026-08-13-aon-map-overlays-phaseC1-design.md` (the raster-overlays-on-the-dark-OSM-map approach — abandoned; see §2).

## 1. Goal

Achieve **100% parity with MQ Journey's map** by **replacing AON's current dark OSM/WGS84 map** with MQ Journey's map *platform* — the `CrsSimple` illustrated campus basemap, its GPS→pixel projection, toggleable overlays, building registry + search, Google-Routes wayfinding, and AR/compass mode — **night-reskinned** to protect stargazing-night vision, with a **hybrid data model** (MQ's full campus registry for browse/search + AON's curated event venues as the highlighted event layer). Phase A (live location) and Phase B (heading) are **re-seated** onto the new coordinate system, not discarded.

This is a **program**, not a single phase. It decomposes into six phases (M0–M5), each its own spec → plan → TDD → verify → merge cycle, exactly as Phases A and B were run.

## 2. Why "replace the map" (the discoveries that forced this)

Three measured findings (receipts, not assertions) killed the earlier "additive overlays on the dark OSM map" plan and pointed here:

1. **The MQ "overlays" are full illustrated basemap flyers, not data layers.** Each `overlay_*.png` is 3509×2481, **~94% opaque**, cream-dominated (`216,216,192`), with **baked-in English legend + MQ letterhead + a "Parking Map" title**. They share a common basemap (water vs permits are 95% identical) re-inked per theme, and MQ places them with a **plain rectangular `OverlayImage(bounds:)` at opacity 0.95** — never `RotatedOverlayImage`. On the dark OSM map at low opacity they read as mud; at 0.95 they erase the dark map. They are, functionally, the **bright illustrated basemap** sliced four ways.
2. **`CrsSimple` dissolves the overlay-placement problem.** The overlays were drawn in the basemap's own pixel space. On MQ's `CrsSimple` illustrated base they drop in at the **same `bounds`** as the base — no affine-corner derivation, no rotation/skew, no ≤5 m alignment test. Replacing the map is therefore the *coherent* path, not a detour.
3. **AON has no confirmed structured geodata to build "native" layers instead.** `routes_data` is entirely `DataConfidence.placeholder` with `isAccessible = null`; water/fountain coordinates exist nowhere but the flyer pixels; parking is already point-markers on the map. AON's own doctrine ("never a plausible-looking pin you can't confirm" — the West-6-null rule) forbids inventing accessibility/water pins off a low-res flyer. So the honest way to deliver parking/water/accessibility information is MQ's **calibrated illustrated map + its overlays**, reskinned — not hand-digitised pins.

## 3. Scope decisions (locked by the user, 2026-08-15)

| Decision | Choice | Consequence |
|---|---|---|
| Aesthetic | **Night-reskinned parity** | Port the full platform but recolour the basemap + overlays dark. Not byte-identical to MQ; needs an asset transform (§5). |
| Depth | **Everything, incl. routing + AR** | All six phases in scope, including Google Routes wayfinding (M4) and AR/compass (M5). |
| Data | **Hybrid** | MQ's 170-building registry for browse/search **and** AON's curated venues/parking as the highlighted event layer (§6, M3). |
| Reskin style | **(c) cream→slate, keep ink** | Dark slate ground; feature ink (green space, parking/water/permit colours) preserved. Tunable to AON's palette (§5). |

## 4. Architecture (target)

`flutter_map` 8.3.1 under **`CrsSimple`** (pixel/Cartesian map units — **not** WGS84 tiles), rendering the reskinned `mq-campus.png` as a single `OverlayImage`, with GPS positions projected through a ported `CampusProjection` (the `gcp_affine` GCP model). This **replaces** AON's WGS84 `TileLayer` map.

**Layer order (target `FlutterMap` children):**
```
CampusMapOverlay        (reskinned basemap OverlayImage)
CampusOverlayLayers     (active reskinned overlays, OverlayImage @ tuned opacity)   ← M2
CampusMapRouteLayer     (wayfinding PolylineLayer, when navigating)                 ← M4
CampusMapMarkerLayer    (hybrid: MQ registry + AON event venues)                    ← M3
CampusMapLocationLayer  (Phase A dot + accuracy circle, re-projected)               ← M1 re-seat
controls / sheets       (recenter, layers, search, mode toggle)
```

**Coordinate model (ported verbatim from MQ, verified):** `CampusOverlayMeta` from `assets/data/campus_overlay_meta.json` → `mapCoordinateScale = max(1, max(pixelW/170, pixelH/85))`; `mapNorth = pixelH/scale (~120.2)`, `mapEast = pixelW/scale (~170.0)`, `mapSouth=mapWest=0`; **Y is flipped** (`pixelYToMapLatitude(y) = (pixelBounds.north − y)/scale`). GPS→pixel via `gcp_affine`: normalize lat/lng into `[0,1]` over the `normalization` bounds, then `x = a.x[0] + a.x[1]·normLng + a.x[2]·normLat` (clamp to pixel bounds), likewise `y`; then `pixelToMapPoint`. Fallback: linear `gpsBounds` interpolation.

**Camera:** `initialZoom = -3.6`, `minZoom = -4.0`, `maxZoom = min(meta.maxZoom, -2.2)`, `cameraConstraint: CameraConstraint.contain(bounds)`, `initialCameraFit: CameraFit.bounds(...)`. (All zooms negative — `CrsSimple`.)

## 5. Night reskin (M0) — a deterministic asset transform

The reskin is **generated by code, not hand-drawn**, so it is reproducible and re-runnable when MQ updates the art. Chosen direction **(c)**: map the low-saturation cream ground → dark AON slate scaled by luminance, **preserve saturated ink** (roads/greens/feature colours), dim the rest. Prototyped on the real `mq-campus.png` (a legible dark campus map results). The **same transform** is applied to all four `overlay_*.png` so base and overlays stay coherent.

**M0 deliverables:** a documented, deterministic transform script (input → output PNGs) checked into the repo; reskinned `mq-campus.png` + 4 overlays under `assets/maps/`; a tuning pass against AON's slate palette + on-device night legibility; and an **asset-integrity + provenance receipt** (dimensions, alpha, dominant colour, source, reuse permission). Opacity for overlays is **re-tuned for the dark base** (MQ's 0.95 assumes the bright base; the reskinned overlays on a dark base need their own values, set on-device).

**Honesty flags carried by M0:**
- **Licence/provenance is a HARD RELEASE gate.** The basemap + overlays are MQ Journey's artwork; project ownership ≠ reuse rights. Provenance + attribution must be confirmed before shipping (in-app credits + `docs/`). `CODE COMPLETE ≠ RELEASE READY`.
- **Baked English text.** Legend/letterhead are raster; the reskin recolours but does not localise them. Localised chrome (picker, labels) is separate; the in-map legend stays English (documented limitation / IOU).

## 6. Phase decomposition

Each phase produces working, tested, mergeable software and gets its own spec + gauntletted plan.

| Phase | Deliverable | Gating dependency |
|---|---|---|
| **M0 — Night reskin** | Deterministic dark-reskin transform + reskinned basemap & 4 overlays + provenance/integrity receipt | none |
| **M1 — Basemap platform** | Port `CampusOverlayMeta` + `CampusProjection(Impl)` + `CrsSimple` `FlutterMap`; **replace** AON's WGS84 map; **re-seat Phase A** dot + accuracy circle onto `gpsToMapPoint`; camera/zoom constraints; off-campus guard revisited | M0 assets |
| **M2 — Overlays** | 4 reskinned overlays as `OverlayImage`s at tuned opacity + picker (`Set<String>`, non-exclusive) on the new base | M1 |
| **M3 — Buildings + search (hybrid)** | Port `buildings.json` (170) + `Building` model + marker layer + search; **reconcile** with AON `Venue`/`ParkingArea` so curated event venues are the highlighted layer; preserve the data-seam + `DataConfidence` honesty | M1 |
| **M4 — Routing / navigation** | Google Routes API v2 source, polyline decode, route `PolylineLayer`, turn-by-turn `route_panel` | **⚠ user-supplied Google Maps API key + billing** |
| **M5 — AR / compass** | `MapMode { campusMap, ar }` toggle + AR building picker + compass view; reuse Phase B heading | camera permission |

**Sequencing:** M0 → M1 are strictly ordered (nothing renders without a basemap + projection). M2 and M3 both depend on M1 and can run in either order. M4 is independent of M2/M3 but blocked on the API key. M5 is last (largest, reuses Phase B). M1+M2 deliver the visual parity; M3 the browse/search parity; M4 the wayfinding parity; M5 the AR parity.

## 7. Phase A / B re-seating (not a rewrite)

- **Phase A (live location):** the dot + accuracy circle move from WGS84 `LatLng` to **map-unit** points via `CampusProjection.gpsToMapPoint`. MQ's `CampusMapLocationLayer` is the proven pattern (accuracy metres → map units via `pixelWidth / gpsLongitudeSpanMetres / scale`, capped). The `LocationService`/`LocationController` seam and providers are **unchanged**; only the render layer's coordinate mapping changes. The off-campus guard is re-expressed in map units (or kept in WGS84 pre-projection).
- **Phase B (heading):** the *bearing* is geographic and **survives unchanged** (declination, tilt-comp, `HeadingService`). The "Point me there" screen is largely map-independent. Any on-map heading indicator uses the same projection. No heading math changes.
- **Hard floor:** the **527 existing tests stay green**. Any phase that reddens Phase A/B tests does not merge. The projection port ships with its own pure-math tests (GPS→pixel→map round-trips against MQ's published affine).

## 8. Hybrid data reconciliation (M3 design seed)

MQ's `Building` (170, campus registry, GPS + `campusX/Y` pixel coords, rich taxonomy) and AON's `Venue`/`ParkingArea` (curated, event-scoped, `DataConfidence`, West-6-null) are different shapes. M3 unifies them **behind AON's data-seam** (screens read providers, never `data/*_data.dart`): the MQ registry drives browse/search markers; AON's curated venues render as the **highlighted event layer** on top (distinct marker treatment). Conflicts resolve in favour of AON's curated coordinate + confidence where a building is also an event venue. Full design deferred to the M3 spec.

## 9. Global constraints (every phase inherits, verbatim)

- **`flutter_map` 8.3.1, `CrsSimple`.** No WGS84 tiles once M1 lands. `latlong2` values are map units, not degrees.
- **New dependencies only where MQ requires them** (routing: Google Routes API + `http`; AR: camera/sensor). No dep added speculatively. Each new dep is justified in its phase spec.
- **Web build stays a hard gate** where it applies. `CrsSimple` + `OverlayImageLayer` are web-safe; AR/GPS degrade gracefully on web (documented).
- **`context.aon` palette** for all chrome; the map raster carries its own (reskinned) colours.
- **EN + FA** for every new string (build fails if FA misses a key). In-map baked legend text is an accepted English-only limitation (§5).
- **Every new surface passes 320×568 / 2.0**; a11y-labelled; the map is never the sole information channel (sheets/markers remain).
- **TDD; never weaken an existing test.** The 527-test floor holds across the program (§7).
- **Data-seam guard** (`integration_seams_test`): screens/widgets must not import `data/*_data.dart` directly — use providers.
- **Per-task gate:** `flutter analyze && flutter test`; web build re-verified where assets/layers/deps change; on-device iOS (Impeller) render check where the map renders.
- **Licence/provenance HARD release gate** on MQ artwork (§5). `CODE COMPLETE ≠ RELEASE READY`.

## 10. Hard external dependencies / blockers

- **Google Maps Routes API key + billing (M4).** User-provisioned; Claude will **not** enter or handle the credential. M4 is blocked until a key is supplied via secure config (e.g. `--dart-define` / secure storage, never committed). M0–M3, M5 proceed without it.
- **Camera permission (M5).** iOS `NSCameraUsageDescription` + Android camera permission for AR.
- **MQ artwork reuse rights (M0/release).** Must be confirmed before public release.

## 11. IOU ledger

- **IOU-P1** — in-map legend/letterhead stay English after reskin (raster). Pay by re-drawing a localised legend or moving the legend to localised chrome, if required.
- **IOU-P2** — reskin opacity/palette tuned on-device per phase; final tokens recorded at M2 closeout.
- **IOU-P3** — offline routing: M4 uses MQ's online Google Routes; an offline fallback (AON's honest "that way" indicators) is retained until a key exists, and as a graceful degrade.
- **IOU-P4** — reconciling MQ registry vs AON curated data conflicts (M3) — the full merge policy is an M3 deliverable.

## 12. Scorecard (program, pre-build)

| Axis | Score | What moves it up |
|---|---:|---|
| Parity coverage | 3/10 | Nothing ported yet. Rises per phase; 10 = M0–M5 all merged + verified on-device. |
| Night-vision integrity | 6/10 | Reskin prototyped + chosen (c); bounded by on-device tuning (M0/M2). |
| Additive safety (A/B) | 7/10 | Clear re-seat path + 527-test floor; proven once M1's regression asserts the dot renders on the new base. |
| Data honesty | 7/10 | Hybrid keeps `DataConfidence`; bounded until M3 defines the merge policy. |
| Release honesty | 8/10 | Licence + baked-text limitations named as gates/IOUs up front. |
| Testability | 7/10 | Projection is pure math (round-trip tests); layers are fakeable; routing/AR need seams. |

## 13. Open questions

1. **MQ artwork licence/provenance** — owner + required attribution (release gate, §5/§10).
2. **Google Routes key ownership** — whose account/billing, and the secure-config mechanism (M4).
3. **Hybrid conflict policy** — when an MQ building *is* an AON event venue, which coordinate/label wins (M3).
4. **AR scope** — full MQ AR parity vs a reduced compass-only mode for the event (M5).
5. **Reskin (c) tuning target** — exact AON slate tokens + per-overlay opacity (M0/M2).

## 14. Next step

On approval → brainstorm **M1 (basemap platform)** in full (its own design → gauntlet → plan), folding **M0 (reskin)** in as M1's asset preflight (M1 cannot render without a basemap). No implementation before M1's plan is written and gauntletted. Each subsequent phase (M2–M5) repeats the spec → plan → execute → verify → merge cycle.
