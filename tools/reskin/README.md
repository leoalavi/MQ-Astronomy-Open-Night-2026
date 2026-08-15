# Night-reskin asset pipeline (M0)

Build-time tool that turns MQ Journey's **bright** illustrated campus PNGs into
AON's **dark, night-vision-safe** campus assets. Deterministic and reproducible;
the app ships only the generated `*_dark.png`, never this tool.

Program spec: `docs/superpowers/specs/2026-08-15-aon-map-parity-program-design.md` §5.
Plan: `docs/superpowers/plans/2026-08-15-aon-map-reskin-M0.md`.

## Reproduce

```bash
cd tools/reskin
python3 test_reskin.py     # 6 asserts — the transform is unit-tested
python3 reskin.py c        # writes out/*_dark.png (style c, the chosen one)
```
Then the 5 outputs are copied into `assets/maps/`. Requires Python 3 + Pillow + numpy.

## The transform

- `reskin_pixel(r,g,b,a,*,style)` — pure, deterministic, unit-tested.
- `reskin_array(arr,*,style)` — numpy vectorisation, **asserted equal** to
  `reskin_pixel` over 600 sample pixels (`test_array_matches_pixel`).
- **style `c` (chosen):** low-saturation cream ground → dark AON slate
  (`(11,16,32)` + luminance lift `(30,38,55)`); saturated ink (`sat ≥ 0.18`)
  preserved but dimmed (`×0.55`); transparent margins kept.
- **style `b` (fallback):** luminance-invert onto a slate→pale ramp. Rejected as
  primary — monochrome, erases the feature ink the thematic variants exist for.

## Receipts

| Item | Value |
|---|---|
| Source | `MQ_Journey/assets/maps/{mq-campus, overlay_parking, overlay_accessibility, overlay_water, overlay_permits}.png` |
| Source dims | basemap 4678×3307; 4 overlays 3509×2481; all have alpha |
| Output dims | **2048×1448** (downscaled, aspect kept, alpha kept) |
| Decoded memory | **11.3 MiB / image** (vs 33 MiB raw) — under the memory gate; exclusive-variant model (M2) caps to ≤1 thematic decode |
| Disk | ~0.8–1.5 MB / png |
| Determinism | **byte-identical** on re-run |
| Legibility gate | **(c) PASS** — legible dark map, feature ink survives (parking/water/accessible-route colour); (b) rejected as primary |

## Gate status

- **Provenance (copy/transform/commit):** ✅ CONFIRMED — owner reuse rights (raoof.r12, 2026-08-15). Public-release attribution remains a later release gate.
- **Content-freshness (AON 2026):** ✅ CONFIRMED current for the 2026 event (raoof.r12, 2026-08-15) — M2 may label the thematic variants as authoritative.
- **Memory/resolution:** ✅ 2048px / 11.3 MiB.
- **Night-legibility:** ✅ (c) passes; buildings/greens run slightly bright → on-device fine-tune tracked as **IOU-P2** at M2.
- **In-map legend/branding:** English baked raster (MQ letterhead + legend) survives the reskin — accepted limitation **IOU-P1**.

## Status split

- **M0 CODE COMPLETE** ✅ — transform tested, 5 assets generated + committed, memory + legibility gates passed, web build green.
- **M0 RELEASE READY** — pending only public-release attribution (in-app credits + docs) for the MQ artwork; provenance + content already confirmed.
