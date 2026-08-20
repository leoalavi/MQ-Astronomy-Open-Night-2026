"""Measure where the OFFICIAL AON 2026 map PRINTS each of its own markers.

Build-time audit tool (NOT shipped Dart). Produces the `artworkX/artworkY`
values baked into `lib/data/venues_data.dart`, so the pin the app draws lands on
the marker the paper map shows instead of beside it.

Why this exists: the app used to derive every pin from a GPS centroid. That
collided (five venues share one coordinate, so their pins stacked into identical
hit boxes and only the topmost was tappable) and it duplicated the artwork —
each app pin sat next to the printed disc for the same place. The published map
has already solved the layout; this reads that solution back out.

The markers are flat vector discs of a known radius, so detection is a template
correlation, not a heuristic:

  * event discs A–I  — near-black. A FILLED template fails because each disc
    carries a white letter; correlate against a RING (r 23..34) instead.
  * 1 / 2 / 3        — magenta.  toilets T — purple.  first aid + — green.
    These are solid, so a filled-disc component test is enough.

Run:
    python3 tools/aon_map/extract.py            # need the page-1 render first
    python3 tools/aon_map/measure_markers.py
"""

import os
import subprocess
import sys
from collections import deque

RENDER_DPI = 283          # must match extract.py — the coordinates are in its space
DISC_R = 34               # printed marker radius, full-res px
RING_R_INNER = 23

# The baked legend repeats every marker as a swatch; ignore that column.
LEGEND_BOX = (0, 0, 1300, 1900)


def render(here):
    pdf = os.path.join(here, "source", "aon2026_program_and_map_A3.pdf")
    prefix = os.path.join(here, "_measure")
    subprocess.run(["pdftoppm", "-f", "1", "-l", "1", "-r", str(RENDER_DPI),
                    "-png", pdf, prefix], check=True, capture_output=True)
    return f"{prefix}-1.png"


def ring_discs(ink, thresh=0.90, step=4):
    import numpy as np
    H, W = ink.shape
    yy, xx = np.mgrid[-DISC_R:DISC_R + 1, -DISC_R:DISC_R + 1]
    d2 = xx * xx + yy * yy
    ring = ((d2 <= DISC_R ** 2) & (d2 >= RING_R_INNER ** 2)).astype(np.float32)
    ring /= ring.sum()
    cands = []
    for y in range(DISC_R, H - DISC_R, step):
        for x in range(DISC_R, W - DISC_R, step):
            if LEGEND_BOX[0] <= x < LEGEND_BOX[2] and LEGEND_BOX[1] <= y < LEGEND_BOX[3]:
                continue
            v = float((ink[y - DISC_R:y + DISC_R + 1,
                           x - DISC_R:x + DISC_R + 1] * ring).sum())
            if v > thresh:
                cands.append((v, x, y))
    cands.sort(reverse=True)
    kept = []
    for v, x, y in cands:
        if all((x - kx) ** 2 + (y - ky) ** 2 > (1.5 * DISC_R) ** 2
               for _, kx, ky in kept):
            kept.append((v, x, y))
    return kept


def blobs(mask, factor, min_area=180, max_area=4000):
    """Round solid components of `mask`, returned in FULL-res coordinates."""
    import numpy as np
    lab = np.zeros(mask.shape, np.int32)
    out, cur = [], 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        cur += 1
        q = deque([(y0, x0)])
        lab[y0, x0] = cur
        pix = []
        while q:
            y, x = q.popleft()
            pix.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if (0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1]
                        and mask[ny, nx] and not lab[ny, nx]):
                    lab[ny, nx] = cur
                    q.append((ny, nx))
        if not (min_area <= len(pix) <= max_area):
            continue
        P = np.array(pix)
        h, w = np.ptp(P[:, 0]) + 1, np.ptp(P[:, 1]) + 1
        if not (0.62 < len(pix) / (h * w) < 1.02 and 0.72 < w / h < 1.38):
            continue
        out.append((P[:, 1].mean() * factor, P[:, 0].mean() * factor))
    return out


def main():
    import numpy as np
    from PIL import Image
    here = os.path.dirname(os.path.abspath(__file__))
    raw = render(here)
    try:
        im = Image.open(raw).convert("RGB")
        a = np.asarray(im).astype(np.int16)
        mx = a.max(axis=2)

        print(f"render {im.size} @ {RENDER_DPI}dpi\n")
        print("event discs A–I (near-black, ring-matched):")
        for v, x, y in sorted(ring_discs((mx < 100).astype(np.float32)),
                              key=lambda c: (c[2], c[1])):
            print(f"   ({x:5d},{y:5d})  score={v:.3f}")

        F = 4
        small = np.asarray(im.resize((im.width // F, im.height // F),
                                     Image.LANCZOS)).astype(np.int16)
        r, g, b = [small[..., i].astype(float) for i in range(3)]
        named = {
            "registration / information (magenta)":
                (r > 150) & (g < 90) & (b > 90) & (b < 190),
            "toilets (purple)":
                (r > 90) & (r < 170) & (g < 70) & (b > 70) & (b < 150),
            "first aid (green)":
                (g > 110) & (r < 110) & (b < 130) & (g - r > 40),
        }
        for label, mask in named.items():
            print(f"\n{label}:")
            for cx, cy in sorted(blobs(mask, F), key=lambda c: (c[1], c[0])):
                print(f"   ({cx:7.1f},{cy:7.1f})")

        print("\nNOTE: three ring hits near (3990,750) and (4214/4362,666) are"
              " NOT markers —\n      they are the bold letter 'O's in the"
              " 'ASTRONOMY OPEN NIGHT' branding block.\n")
        print("Identify each disc by eye against the artwork before pasting "
              "into venues_data.dart — the\nletters are what disambiguate "
              "clustered discs, and no detector reads them.")
    finally:
        if os.path.exists(raw):
            os.remove(raw)


if __name__ == "__main__":
    sys.exit(main())
