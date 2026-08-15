# Map Parity Phase C1 — Campus overlay layers + picker (design)

**Status:** design, pre-gauntlet. Forked from `main` after Phase B (heading) merged.

## 1. Goal

Port MQ Journey's toggleable campus **overlay layers** (parking, accessible routes, drinking water — permits built but hidden) onto AON's **existing** OSM + dark WGS84 map, with a picker to switch them on/off. Additive: the Phase A live-location dot / follow-me / off-campus guard and the Phase B "Point me there" bearing keep working, because **the map's coordinate system does not change**. This is the low-risk half of the "both layers + custom basemap" parity goal; the custom illustrated basemap (a parallel `CrsSimple` mode) is **Phase C2**.

## 2. Framing (two corrections that keep the claims honest)

- **`flutter_map` is not "the Leaflet port."** It is a pure-Flutter mapping package whose API is Leaflet-*like*. AON already has the equivalent map-engine capability through it; the missing parity is MQ Journey's custom **data/layer system**, not a missing engine.
- **Placement is "affine-calibration-derived, empirically verified," not "affine-accurate."** `RotatedOverlayImage` positions an image by three geographic corners (rotation + parallelogram skew; the 4th corner is derived) — verified in flutter_map 8.3.1 (`topLeftCorner`/`bottomLeftCorner`/`bottomRightCorner`, `opacity`). MQ's calibration is a pixel↔lat/lng affine, but the map renders through a projected CRS (Web Mercator), so `RotatedOverlayImage` reproduces the calibration *inside projected space* — expected to be visually accurate at campus scale, but **proven by measurement, not asserted** (§7).

## 3. Scope

**In (Phase C1):**
- Copy MQ's 4 overlay PNGs into AON; a `CampusOverlayDefinition` registry (all four built) with an `eventVisible` flag exposing **parking + accessibility + water**, **permits hidden**.
- 3-geographic-corner placement derived from MQ's affine calibration; render each active overlay as a `RotatedOverlayImage` in one `OverlayImageLayer`, **under** the venue/parking markers and the location dot.
- A picker (bottom sheet, labelled switches); **non-exclusive** active set (`Set<String>`), **not persisted** (transient viewing state).
- Opacity-first night treatment (per-overlay default opacity), EN/FA labels, 320×568/2.0, a11y, TDD.

**Out (IOUs):**
- **IOU-C1a** — dark/night-exported overlay PNGs (or a runtime `ColorFilter`) *if* opacity tuning proves insufficient for dark adaptation.
- **IOU-C1b** — persisting the active overlay set across sessions (only if a real need appears).
- **Phase C2** — the custom illustrated `CrsSimple` basemap (separate spec).

## 4. Architecture

```
MQ overlay assets (copied into AON)
        ↓
asset-integrity gate (§8) + licence/provenance gate (§9)
        ↓
MQ affine calibration (campus_overlay_meta.json)  ── inverse affine ──▶  3 geographic image corners
        ↓
RotatedOverlayImage(topLeft, bottomLeft, bottomRight, opacity)  (one per active overlay)
        ↓
OverlayImageLayer  ── inside the existing WGS84 FlutterMap ──
```

**Render order (map_screen children), unchanged except the new overlay layer:**
```
DarkTileLayer
CampusOverlayLayer          ← new (active overlays, under the pins)
UserLocationCircle          (Phase A)
MarkerLayer (venues/parking)
UserLocationDot             (Phase A)
MapControlIsland + status notes + LocateButton
```
**Phase A GPS, Phase B Point-me, and the map CRS all stay untouched.**

**Files (create):** `lib/widgets/campus_overlay_layer.dart` (the `OverlayImageLayer` builder), `lib/data/campus_overlays_data.dart` (the registry), `lib/services/overlay_providers.dart` (`overlayControllerProvider`), `lib/widgets/overlay_picker_sheet.dart`, and mirrored tests. Corner constants live in `lib/widgets/map_config.dart`.
**Files (modify):** `pubspec.yaml` (+`assets/maps/`), `lib/screens/map_screen.dart` (insert the layer + a picker control), `lib/l10n/app_en.arb` + `app_fa.arb`.
**Assets (add):** `assets/maps/overlay_parking.png`, `overlay_accessibility.png`, `overlay_water.png`, `overlay_permits.png` (copied from MQ Journey).

**No new dependency** — `OverlayImageLayer`/`RotatedOverlayImage` ship with `flutter_map`.

## 5. Overlay registry

`CampusOverlayDefinition { String id; String assetPath; String labelKey; String descriptionKey; double defaultOpacity; Color swatch; bool eventVisible; }`

| id | label | asset | default opacity | eventVisible |
|---|---|---|---:|:---:|
| `parking` | Parking | `overlay_parking.png` | 0.30 | ✅ |
| `accessibility` | Accessible routes | `overlay_accessibility.png` | 0.40 | ✅ |
| `water` | Drinking water | `overlay_water.png` | 0.35 | ✅ |
| `permits` | Permit areas | `overlay_permits.png` | 0.30 | ❌ (built, hidden) |

Building all four but exposing three means "turn water on/off" or "show permits" is later a one-line data change, not a new UI feature. The registry is reached via a provider (AON's data-seam pattern); the picker lists only `eventVisible` entries.

## 6. State

`overlayControllerProvider` = `NotifierProvider<OverlayController, Set<String>>` (default empty). `OverlayController.toggle(id)` / `clear()`. **Non-exclusive** — any combination (none / parking / parking+accessibility / all relevant). **Not persisted** — overlays are transient viewing state; persistence is IOU-C1b.

## 7. Placement + the empirical acceptance test

The three geographic corners are computed **once** (Task 0) by inverting MQ's affine at the image footprint's pixel corners `(0,0)`, `(0,H)`, `(W,H)` and denormalising to lat/lng, then stored as `MapConfig` constants (`overlayTopLeft`, `overlayBottomLeft`, `overlayBottomRight`). All four overlays share one corner set **iff** the integrity gate (§8) confirms one shared canvas.

**Acceptance test (on-device, Task N):** pick ≥4 features visible in an overlay against the OSM base — a building corner, a car-park edge, a main-path intersection, a water point — and measure rendered-vs-geographic offset:
```
≤ 5 m   → PASS
5–10 m  → review (accept with a noted caveat, or recalibrate corners)
> 10 m  → FAIL — recalibrate (do NOT ship a misaligned overlay)
```
**`RotatedOverlayImage` is the default and only placement.** A plain rectangular `OverlayImage` is used **only if** measurement shows the rotation/shear contribution is below tolerance — never as a convenience fallback that discards calibration.

## 8. Asset-integrity gate (Task 0, not eyeballing)

For **each** overlay PNG, record: filename · pixel W×H · full-canvas-or-cropped · origin · calibration source. Established so far: basemap `mq-campus.png` = **4678×3307**; all four overlays = **3509×2481** (uniform **0.75×** the basemap in both axes → same footprint, lower resolution). The affine `pixelBounds` is `0..4678 × 0..3307` (basemap space), so the corner derivation uses the **basemap** footprint and relies on the overlays sharing it. If any overlay is cropped / re-origined / a different aspect, it gets its **own** corner transform. This is a hard preflight gate — a mis-shared canvas is discovered here, not in the UI.

## 9. Licence / provenance — a HARD release gate

The overlay PNGs are MQ Journey's artwork. **Project ownership does not by itself establish reuse rights.** Split the status:
```
C1 CODE COMPLETE  ≠  C1 RELEASE READY
```
**RELEASE READY additionally requires:** overlay provenance identified · reuse permission confirmed · any required attribution recorded (in-app credits + `docs/`). If those can't be proven, ship locally recreated overlays or organiser-supplied replacements. The code is asset-agnostic (swap the PNGs), so CODE COMPLETE does not block on this — but shipping does.

## 10. Night treatment — opacity first

The overlays were drawn for MQ's bright illustrated map; on the dark night map they may read too hot. **Start with opacity** (`BaseOverlayImage.opacity`), defaults in §5 (parking 0.30 / accessibility 0.40 / water 0.35), tuned on-device. Only if opacity is insufficient for dark adaptation do we add a night-exported PNG or a runtime `ColorFilter` (IOU-C1a) — do not build filter machinery pre-emptively.

## 11. iOS Impeller render check

flutter_map's docs flag historical overlay-image rendering issues under some Impeller configurations. Not expected, but it makes an **on-device iOS render check mandatory** (Task N): confirm an active overlay actually paints (not blank/garbled) on the iOS simulator/device, in addition to the web build gate.

## 12. Global constraints

- **No new dependency.** **Web build stays a hard gate** (`OverlayImageLayer` is web-safe; re-verify after adding assets).
- **`context.aon` colours** for the picker/swatches; overlay tint comes from the PNGs + opacity.
- **EN + FA** for every overlay label/description (build fails if FA misses a key).
- **Every new surface passes 320×568 / 2.0**; picker switches are a11y-labelled; overlays never the sole information channel (markers/sheets remain).
- **TDD**; **never weaken an existing test**; the Phase A/B map tests must stay green (the map CRS is unchanged).
- **Per-task gate:** `flutter analyze && flutter test`; web build re-verified where assets/layers change.

## 13. Testing

- Corner math (pure): inverse-affine of the footprint pixel corners → expected lat/lng (within campus bounds; deterministic).
- `OverlayController`: toggle adds/removes ids; non-exclusive; `clear` empties; default empty.
- Registry: exactly the `eventVisible` set is offered to the picker; all four defs exist.
- `CampusOverlayLayer` widget: renders one `RotatedOverlayImage` per active id, none when empty, correct opacity; sits under the marker layer (order).
- `OverlayPickerSheet`: lists visible overlays, switch toggles state, a11y labels, 320×568/2.0, FA.
- Gate: `flutter build web`; on-device iOS render check (§11) + the ≤5 m alignment test (§7).

## 14. Scorecard (self, pre-build)

| Axis | Score | What moves it up |
|---|---:|---|
| Parity coverage | 6/10 | Overlay-layer system closed; basemap (C2) still open. |
| Additive safety | 9/10 | No CRS change; Phase A/B untouched. Higher = a regression test asserting the dot still renders with overlays on. |
| Placement fidelity | 6/10 | Calibration-derived + ≤5 m acceptance; bounded by projected-space skew. Higher = per-overlay GCP re-fit. |
| Night legibility | 6/10 | Opacity-first; may need a dark export (IOU-C1a). |
| Testability | 7/10 | Pure corner math + fakeable state; render-order asserted. |
| A11y / 2.0 / RTL | 8/10 | Picker labelled + 2.0 + EN/FA. |
| Release honesty | 8/10 | CODE-COMPLETE vs RELEASE-READY split on the licence gate. |

## 15. IOU ledger

- **IOU-C1a** — dark/night overlay treatment (export or `ColorFilter`) if opacity is insufficient.
- **IOU-C1b** — persist the active overlay set across sessions.

## 16. Open questions

1. **Licence/provenance** of MQ's overlay art — the release gate (§9). Who owns them, what attribution is required?
2. Confirm the three event overlays (parking / accessibility / water) are the right default set for a night event; confirm permits stays hidden unless operations asks.
3. Do the overlays geographically still make sense on the OSM street base (they were drawn to MQ's illustrated map)? The ≤5 m test (§7) answers alignment; a human check answers "does the parking overlay cover the real parking."

## 17. Next step

On approval → **writing-plans**. Plan Task 0: asset-integrity gate (§8) + compute & record the 3 corners (§7). Then dep-free asset add + web gate → corner constants → registry → controller → overlay layer → picker → map wiring → l10n → verification (web build + iOS render + ≤5 m alignment). No implementation before the plan is written and gauntletted.
