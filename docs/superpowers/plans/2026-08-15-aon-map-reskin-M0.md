# M0 — Night Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Produce reskinned dark campus assets (basemap + 4 thematic variants) from MQ Journey's illustrated PNGs via a deterministic, tested transform, and pass M0's five gates — so M1 has a night-appropriate basemap to render.

**Architecture:** A build-time Python tool (`tools/reskin/`) with a **pure pixel-transform function** (unit-tested on synthetic pixels, no artwork needed) plus a thin PIL driver that reads MQ source PNGs and writes downscaled reskinned outputs. The Flutter app consumes only the output PNGs. No new Flutter/Dart dependency.

**Design source:** program spec `2026-08-15-aon-map-parity-program-design.md` §5 (the approved M0 design).

## Global Constraints (from program spec §5, §9 — verbatim)

- **Reskin direction (c):** low-saturation cream ground → dark AON slate scaled by luminance; **preserve saturated ink**; dim the rest. Same transform on basemap + all 4 overlays.
- **Night-legibility gate (hard):** (c) tuned to AON slate; **fall back to (b) luminance-invert** if (c) can't be made legible at event-night brightness. Merge condition.
- **Copy/transform permission = PRE-COMMIT gate:** do NOT commit derived MQ artwork until reuse rights are confirmed; else keep outputs local/untracked.
- **Content-freshness gate:** record per asset — content owner · last update · AON-2026 applicability (parking/water/accessible validity) · baked branding suitability · reviewer + date.
- **Memory/resolution gate:** a 3509×2481 RGBA decode ≈ 33 MiB; downscale source to max useful on-device resolution; record decoded dims + peak memory; the exclusive-variant model (M2) caps to ≤1 thematic decode.
- **Integrity receipt:** dimensions · alpha · dominant colour · shared-footprint (all 3509×2481).
- **Deterministic + reproducible:** no randomness; re-running the tool on the same source yields identical bytes.
- `CODE COMPLETE ≠ RELEASE READY` (public-release attribution is a later gate).

## File Structure

- **Create:** `tools/reskin/reskin.py` (pure `reskin_pixel()` + `night_style` params + PIL driver), `tools/reskin/test_reskin.py` (plain-assert tests, run via `python3`), `tools/reskin/README.md` (pipeline + provenance/content receipt).
- **Produce (local first, commit gated):** `assets/maps/mqcampus_dark.png`, `overlay_parking_dark.png`, `overlay_accessibility_dark.png`, `overlay_water_dark.png`, `overlay_permits_dark.png`.
- **No app code** — M0 ships assets + tool only. M1 wires them in.

**Source:** `/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/{mq-campus,overlay_parking,overlay_accessibility,overlay_water,overlay_permits}.png`.

**Task order:** 0 preflight + gates → 1 pure transform (TDD) → 2 driver + generate outputs + memory/integrity → 3 legibility gate + (b) fallback decision → 4 add to assets + pubspec (commit gated) + web build → 5 closeout receipt.

---

## Task 0: Preflight + gates

- [ ] **Step 1: Branch + clean tree** — Run:
```bash
git -C /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026 branch --show-current   # expect feature/map-parity-program
git -C /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026 status --short           # expect clean
```
- [ ] **Step 2: Source integrity receipt** (already measured; re-confirm) — all five source PNGs, dimensions + alpha:
```bash
MQ=/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps
for f in mq-campus overlay_parking overlay_accessibility overlay_water overlay_permits; do
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$MQ/$f.png" | grep -E 'pixel|hasAlpha' | tr '\n' ' '; echo " <- $f";
done
```
Expected: basemap 4678×3307; four overlays 3509×2481; all `hasAlpha: yes`.
- [ ] **Step 3: PROVENANCE gate (needs the user).** Confirm AON may copy/transform/commit MQ Journey's map artwork. If **not** confirmed: generate outputs but keep them **untracked** (Task 4 commit is skipped), and record the gate as OPEN. Record the answer in `tools/reskin/README.md`.
- [ ] **Step 4: CONTENT-FRESHNESS gate (needs the user/organiser).** Record per asset: owner · last update · AON-2026 applicability. Until confirmed, thematic variants are labelled neutrally / stay unavailable in M2 (does not block M0 asset generation).
- [ ] **Step 5: No commit yet.**

---

## Task 1: Pure reskin transform (TDD)

**Files:** Create `tools/reskin/reskin.py`, `tools/reskin/test_reskin.py`.

**Interfaces:** Produces `reskin_pixel(r, g, b, a, *, style) -> (r, g, b, a)` — pure, deterministic. `style='c'` (cream→slate keep-ink) and `style='b'` (luminance-invert) both supported (the legibility gate picks one). Params: slate floor `(11,16,32)`, luminance ceiling gain, saturation threshold `0.18`, ink-dim factor `0.55`.

- [ ] **Step 1: Write the failing test** — `tools/reskin/test_reskin.py`:
```python
import sys
from reskin import reskin_pixel, saturation

def approx(a, b, tol=8):
    return all(abs(x - y) <= tol for x, y in zip(a, b))

def test_transparent_pixel_stays_transparent():
    assert reskin_pixel(216, 216, 192, 0, style='c') == (0, 0, 0, 0)

def test_cream_ground_becomes_dark_slate_c():
    # the dominant cream ground -> near the slate floor, NOT bright
    r, g, b, a = reskin_pixel(216, 216, 192, 255, style='c')
    assert a == 255
    assert r < 70 and g < 80 and b < 100          # dark
    assert b >= r                                  # slate is blue-ish

def test_saturated_ink_is_preserved_c():
    # a saturated blue parking mark keeps its hue (dimmed), not slate-flattened
    r, g, b, a = reskin_pixel(59, 130, 246, 255, style='c')  # #3B82F6
    assert b > r and b > g                          # still clearly blue
    assert saturation(r, g, b) > 0.25               # ink not desaturated to slate

def test_deterministic():
    assert reskin_pixel(200, 100, 50, 255, style='c') == reskin_pixel(200, 100, 50, 255, style='c')

def test_style_b_inverts_luminance():
    dark_ground = reskin_pixel(216, 216, 192, 255, style='b')   # bright cream -> dark
    assert sum(dark_ground[:3]) < 240

if __name__ == '__main__':
    fns = [v for k, v in sorted(globals().items()) if k.startswith('test_')]
    for fn in fns:
        fn(); print('ok', fn.__name__)
    print(f'{len(fns)} passed')
```
- [ ] **Step 2: Run to verify it fails** — Run: `cd tools/reskin && python3 test_reskin.py` — Expected: FAIL (`ModuleNotFoundError: reskin` / `reskin_pixel` undefined).
- [ ] **Step 3: Implement** — `tools/reskin/reskin.py`:
```python
"""Deterministic night-reskin transform for the MQ campus basemap + overlays.
Build-time asset tool (not shipped Dart). Pure `reskin_pixel` is unit-tested;
the PIL driver applies it. See README.md. Program spec §5, direction (c)/(b)."""

SLATE = (11, 16, 32)          # AON night floor
GROUND_GAIN = (30, 38, 55)    # luminance lift added to SLATE for the ground
SAT_THRESHOLD = 0.18          # below this = "ground", recolour; above = ink, keep
INK_DIM = 0.55                # dim preserved ink so it isn't hot at night

def saturation(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    return 0.0 if mx == 0 else (mx - mn) / mx

def _lum(r, g, b):
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

def reskin_pixel(r, g, b, a, *, style='c'):
    if a == 0:
        return (0, 0, 0, 0)                       # keep transparent margins
    if style == 'b':
        inv = 1.0 - _lum(r, g, b)
        lo, hi = SLATE, (150, 170, 200)
        out = tuple(round(lo[i] + (hi[i] - lo[i]) * inv) for i in range(3))
        return (*out, a)
    # style 'c': cream ground -> dark slate; preserve saturated ink (dimmed)
    if saturation(r, g, b) < SAT_THRESHOLD:
        lum = _lum(r, g, b)
        out = tuple(min(255, round(SLATE[i] + GROUND_GAIN[i] * lum)) for i in range(3))
        return (*out, a)
    return (round(r * INK_DIM), round(g * INK_DIM), round(b * INK_DIM), a)
```
- [ ] **Step 4: Run to verify it passes** — Run: `cd tools/reskin && python3 test_reskin.py` — Expected: `5 passed`.
- [ ] **Step 5: Commit** (tool + tests only — AON's own code, no artwork):
```bash
git add tools/reskin/reskin.py tools/reskin/test_reskin.py
git commit -m "feat(reskin): deterministic night-reskin pixel transform (c + b), TDD (M0)"
```

---

## Task 2: Driver + generate outputs + memory/integrity gate

**Files:** Modify `tools/reskin/reskin.py` (add `main()` driver).

- [ ] **Step 1: Add the PIL driver** — reads each source PNG, applies `reskin_pixel` per pixel (vectorised via numpy for speed), **downscales** to the memory-gate target (max width 2048 → ~2048×1448, ≈ 11.3 MiB decoded vs 33 MiB), writes `*_dark.png` with alpha preserved. `style` from argv (default `c`). Deterministic (no random). Print decoded-dim + byte-size receipt per file.
- [ ] **Step 2: Generate** — Run: `cd tools/reskin && python3 reskin.py c` — Expected: 5 `*_dark.png` written to a local out dir; receipt printed.
- [ ] **Step 3: Integrity + memory receipt** — confirm outputs: same aspect as source, alpha present, target ≤2048 wide; record decoded MiB. Record in README.
- [ ] **Step 4: Commit** (driver only):
```bash
git add tools/reskin/reskin.py
git commit -m "feat(reskin): PIL driver — downscaled deterministic dark asset generation (M0)"
```

---

## Task 3: Night-legibility gate + (b) fallback decision

- [ ] **Step 1: Generate a comparison** — basemap + each variant under (c), composited at the AON slate background, plus the (b) variant of the basemap, into one strip.
- [ ] **Step 2: Legibility judgement** — assess: are labels/roads readable? is feature ink distinct without being hot? Record PASS/FAIL for (c). **If (c) FAILS**, regenerate with `style=b` and adopt (b); record the switch. (Program spec §5 fallback.)
- [ ] **Step 3: Record** the chosen style + rationale in README. No commit (assets committed in Task 4).

---

## Task 4: Add reskinned assets + pubspec + web build (COMMIT GATED on provenance)

**Files:** copy `*_dark.png` → `assets/maps/`; modify `pubspec.yaml`.

- [ ] **Step 1: PROVENANCE check** — if Task 0 Step 3 is **not** confirmed, STOP here: leave assets untracked, record M0 as CODE-COMPLETE-pending-provenance. Do not commit artwork.
- [ ] **Step 2 (if confirmed): Place assets** — copy the 5 `*_dark.png` into `assets/maps/`.
- [ ] **Step 3: pubspec** — ensure `assets/maps/` is under `flutter: assets:`.
- [ ] **Step 4: Web build gate** — Run: `flutter build web` — Expected: SUCCESS (assets bundle).
- [ ] **Step 5: Commit** (only if provenance confirmed):
```bash
git add pubspec.yaml assets/maps/*_dark.png
git commit -m "feat(map): reskinned dark campus basemap + 4 thematic variants (M0)"
```

---

## Task 5: Closeout receipt

**Files:** `tools/reskin/README.md` (pipeline + all receipts).

- [ ] **Step 1: Write README** — the transform (c/b) + params, the exact command to reproduce, the integrity + memory + legibility receipts, the chosen style, and the **provenance + content-freshness gate status** (CONFIRMED / OPEN + who/when).
- [ ] **Step 2: Split status** — record: **M0 CODE COMPLETE** (tool tested, assets generated, legibility passed) vs **M0 RELEASE READY** (+ provenance confirmed + content-freshness confirmed + release attribution).
- [ ] **Step 3: Commit**:
```bash
git add tools/reskin/README.md
git commit -m "docs(reskin): M0 closeout — pipeline + integrity/memory/legibility + gate status (M0)"
```

---

## Self-Review

**Spec coverage:** §5.1 permission (Task 0.3, Task 4.1) · §5.2 content-freshness (Task 0.4) · §5.3 memory/resolution (Task 2) · §5 legibility + (b) fallback (Task 3) · §5.5 integrity receipt (Task 0.2, Task 2.3) · release split (Task 5.2). Covered.

**Placeholder scan:** transform code + tests are complete and concrete; the driver (Task 2.1) is described against a complete interface + generates verifiable receipts. No TBD.

**Type consistency:** `reskin_pixel(r,g,b,a,*,style) -> (r,g,b,a)`, `saturation(r,g,b)` — consistent across test + impl + driver.
