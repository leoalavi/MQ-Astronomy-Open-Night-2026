"""Deterministic extraction of the OFFICIAL AON 2026 campus map basemap.

Build-time asset tool (NOT shipped Dart). Renders page 1 of the official
"AON 2026 Program and Map" A3 PDF — the artwork Faculty of Science and
Engineering publishes for the event — into the single basemap PNG the app
ships as `assets/maps/aon_event_map.png`.

The PDF is fully vector (InDesign 21.0, no embedded rasters), so the render
resolution is ours to choose. We render at 283 dpi (=> 4680x3310, matching the
MQ cartographic master's pixel frame) and then downscale to the 2048px memory
gate, exactly as the M0 reskin pipeline does.

The artwork ships UNMODIFIED (no night-reskin): brand fidelity was chosen over
scotopic dimming — see docs/superpowers/specs. If that is revisited, dim at
RUNTIME with a ColorFiltered over the layer and leave this asset pristine.

Reproduce:
    python3 tools/aon_map/extract.py
    shasum -a 256 assets/maps/aon_event_map.png   # must match the provenance record
"""

import os
import subprocess
import sys

SRC_PDF = "source/aon2026_program_and_map_A3.pdf"
MAP_PAGE = 1
RENDER_DPI = 283          # => 4680x3310, the MQ cartographic master's frame
MAX_DIM = 2048            # memory gate: 2048x1448 RGBA == 11.3 MiB decoded
OUT_REL = "../../assets/maps/aon_event_map.png"


def render_page(pdf_path, page, dpi, out_prefix):
    """pdftoppm -> RGB PNG at `dpi`. Deterministic for a fixed poppler build."""
    subprocess.run(
        ["pdftoppm", "-f", str(page), "-l", str(page), "-r", str(dpi),
         "-png", pdf_path, out_prefix],
        check=True, capture_output=True,
    )
    return f"{out_prefix}-{page}.png"


def main():
    from PIL import Image
    here = os.path.dirname(os.path.abspath(__file__))
    pdf = os.path.join(here, SRC_PDF)
    if not os.path.isfile(pdf):
        sys.exit(f"source PDF missing: {pdf}")

    tmp_prefix = os.path.join(here, "_render")
    raw = render_page(pdf, MAP_PAGE, RENDER_DPI, tmp_prefix)
    try:
        im = Image.open(raw).convert("RGBA")
        print(f"rendered page {MAP_PAGE} @ {RENDER_DPI}dpi -> {im.size}")
        scale = min(1.0, MAX_DIM / max(im.size))
        if scale < 1.0:
            im = im.resize((round(im.width * scale), round(im.height * scale)),
                           Image.LANCZOS)
        out = os.path.normpath(os.path.join(here, OUT_REL))
        im.save(out, optimize=True)
        mib = im.width * im.height * 4 / 2 ** 20
        print(f"wrote {out}  {im.size}  {os.path.getsize(out)/1e6:.2f} MB on disk"
              f"  {mib:.1f} MiB decoded")
    finally:
        if os.path.exists(raw):
            os.remove(raw)


if __name__ == "__main__":
    main()
