# Official AON 2026 basemap pipeline

Build-time tool that turns the **published AON 2026 Program and Map** A3 PDF
into the single basemap PNG the app ships. Deterministic and reproducible; the
app ships only `assets/maps/aon_event_map.png`, never this tool.

This replaces the M0 night-reskin pipeline (`tools/reskin/`) as the source of
the basemap. `tools/reskin/` is retained — it is still the way to produce a
dark treatment if the brightness call is ever revisited — but nothing it
generates is shipped any more.

## Reproduce

```bash
python3 tools/aon_map/extract.py
shasum -a 256 assets/maps/aon_event_map.png   # must match the provenance record
```

Requires Python 3 + Pillow, and `pdftoppm` (poppler). The SHA is gated by
`scripts/check.sh` — a silent re-render fails the build rather than quietly
shifting the artwork.

## Why the official map, and why it drops in cleanly

The app previously rendered MQ Journey's generic campus basemap, night-reskinned.
The AON program map is better for this event on the merits: it carries the
**event's own** A–I lettering, registration and information points, first aid,
toilets, food, the complimentary shuttle, and the driving/pedestrian routes —
so the pins the app draws and the paper map in someone's hand agree.

The reason it is a drop-in rather than a re-calibration: the AON map and MQ
Journey's basemap are **the same MQ cartographic master at different crops**.
The relation is a pure similarity — uniform scale plus translation, no rotation:

| Fit | Value |
|---|---|
| Method | edge-map NCC template matching, robust least-squares affine, 20% trimmed |
| Correspondences | 56 candidates → **45 inliers** at NCC ≥ 0.55 |
| Residual | **0.77 px mean · 0.66 px median · 1.82 px p95 · 2.12 px max** (frame is 4678 px wide) |
| Scale | x 1.02398, y 1.02406 → isotropic **1.024017937** |
| Rotation | **−0.0031°** (i.e. none) |
| Shear | **−0.0143°** (i.e. none) |
| Translation | tx **−252.463703**, ty **−74.694819** |

So `MQ_px = AON_px · 1.024017937 + (−252.464, −74.695)`.

Because that is exact, the artwork needed **no** resampling and the app needed
**no** change to the `gcp_affine` GPS calibration, `buildings.json` `campusX/Y`,
or any baked venue coordinate. The overlay simply carries its own bounds in the
same `CrsSimple` space — see `CampusProjection.aonPixel` and
`MapConfig.aonMapBounds`, both derived, never hand-typed, and pinned by
`test/unit/aon_basemap_georef_test.dart`.

Deriving the fit:

```bash
python3 tools/aon_map/fit_georef_coarse.py    # FFT scale+translation search
python3 tools/aon_map/fit_georef_refine.py    # robust least-squares affine
```

Both expect a sibling `MQ_Journey` checkout (the reference frame) and the page-1
render; they are kept for audit, not run by the build.

## Receipts

| Item | Value |
|---|---|
| Source | `source/aon2026_program_and_map_A3.pdf` p.1 — Adobe InDesign 21.0, created 2026-08-06 |
| Source nature | **fully vector**, no embedded rasters → render resolution is ours to choose |
| Render | `pdftoppm -r 283` → 4680×3310 (matches the MQ master's pixel frame) |
| Output | **2048×1448**, RGBA, **11.3 MiB decoded** — identical to the M0 memory gate |
| Disk | 1.10 MB |
| Modifications | **none** — official artwork ships unaltered |
| Coverage | full vertically; horizontally to MQ px 4539.9 of 4678 (the last 2.95% is off-campus) |

## Known limitations

- **Not night-reskinned.** Brand fidelity was chosen over scotopic dimming. This
  is a real trade-off: a bright map at the observing field harms dark
  adaptation, which is the one thing `DarkTileLayer`'s own doc says must never
  happen. If revisited, dim at **runtime** with a `ColorFiltered` over
  `CampusBasemapLayer` and leave this asset pristine.
- **Baked English legend + branding.** Cannot be localised to Persian (carried
  over from M0's IOU-P1; the app surfaces the same information in EN + FA
  through its own filter bar, search and sheets).
- **`Macquarie Centre` sits off the artwork.** Its `campusX` is 4678 — the MQ
  frame's right edge, a clamped value for the off-campus shopping centre — and
  the AON crop ends at 4539.9. Its search-only transient marker would render on
  background. 1 of 170; pinned by the georef test so the count cannot grow
  unnoticed.
- **Redistribution permission** for the official artwork is a release gate,
  as with `buildings.json`.
