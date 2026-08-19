"""Deterministic night-reskin transform for the MQ campus basemap + overlays.

Build-time asset tool (NOT shipped Dart). The pure `reskin_pixel` is unit-tested
(test_reskin.py); the PIL driver (`main`) applies it to the source PNGs. The
Flutter app consumes only the generated `*_dark.png` outputs.

Program spec 2026-08-15-aon-map-parity-program-design.md §5:
  - style 'c' (default, user's choice): cream ground -> dark AON slate scaled by
    luminance; preserve saturated ink (dimmed); keep transparent margins.
  - style 'b' (legibility fallback): luminance-invert onto a slate->pale ramp.
Deterministic: same input bytes -> same output bytes (no randomness).
"""

SLATE = (11, 16, 32)          # AON night floor
GROUND_GAIN = (30, 38, 55)    # luminance lift added to SLATE for the ground
SAT_THRESHOLD = 0.18          # below = "ground" (recolour); above = ink (keep)
INK_DIM = 0.55                # dim preserved ink so it isn't hot at night
_INVERT_HI = (150, 170, 200)  # pale end of the style-'b' ramp


def saturation(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    return 0.0 if mx == 0 else (mx - mn) / mx


def _lum(r, g, b):
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def reskin_pixel(r, g, b, a, *, style='c'):
    """(r,g,b,a) -> (r,g,b,a). Pure + deterministic."""
    if a == 0:
        return (0, 0, 0, 0)                       # keep transparent margins
    if style == 'b':
        inv = 1.0 - _lum(r, g, b)
        out = tuple(round(SLATE[i] + (_INVERT_HI[i] - SLATE[i]) * inv)
                    for i in range(3))
        return (out[0], out[1], out[2], a)
    # style 'c'
    if saturation(r, g, b) < SAT_THRESHOLD:
        lum = _lum(r, g, b)
        out = tuple(min(255, round(SLATE[i] + GROUND_GAIN[i] * lum))
                    for i in range(3))
        return (out[0], out[1], out[2], a)
    return (round(r * INK_DIM), round(g * INK_DIM), round(b * INK_DIM), a)


def reskin_array(arr, *, style='c'):
    """Vectorised equivalent of `reskin_pixel` over an HxWx4 uint8 array.
    Must match `reskin_pixel` pixel-for-pixel (asserted in test_reskin.py)."""
    import numpy as np
    a = arr[..., 3]
    rgb = arr[..., :3].astype(np.float64)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    out = np.empty(arr.shape, dtype=np.float64)

    if style == 'b':
        inv = 1.0 - lum
        for i in range(3):
            out[..., i] = np.round(SLATE[i] + (_INVERT_HI[i] - SLATE[i]) * inv)
    else:  # style 'c'
        mx = rgb.max(axis=2)
        mn = rgb.min(axis=2)
        sat = np.where(mx == 0, 0.0, (mx - mn) / np.where(mx == 0, 1.0, mx))
        ground = sat < SAT_THRESHOLD
        for i in range(3):
            g_out = np.minimum(255, np.round(SLATE[i] + GROUND_GAIN[i] * lum))
            i_out = np.round(rgb[..., i] * INK_DIM)
            out[..., i] = np.where(ground, g_out, i_out)

    out[..., 3] = a
    # transparent margins -> (0,0,0,0)
    transparent = a == 0
    out[transparent] = 0
    return out.astype(np.uint8)


# --- build-time driver ------------------------------------------------------

_MQ = "/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps"  # last-resort fallback


def _sibling_src():
    """A sibling MQ_Journey checkout next to this repo, if present."""
    import os
    p = os.path.normpath(os.path.join(
        os.path.dirname(__file__), "..", "..", "..", "MQ_Journey", "assets", "maps"))
    return p if os.path.isdir(p) else None
_MAP = [
    ("mq-campus", "mqcampus_dark"),
    ("overlay_parking", "overlay_parking_dark"),
    ("overlay_accessibility", "overlay_accessibility_dark"),
    ("overlay_water", "overlay_water_dark"),
    ("overlay_permits", "overlay_permits_dark"),
]
_MAX_DIM = 2048   # memory gate: downscale so a decode stays well under 33 MiB


def main(style='c', src_dir=None, out_dir=None):
    import os
    import numpy as np
    from PIL import Image
    # Prefer an explicit source (CLI arg / RESKIN_SRC env), then a sibling
    # MQ_Journey checkout, then the legacy absolute fallback — so the documented
    # reproduce step is not tied to the author's machine (map audit P2).
    src_dir = src_dir or os.environ.get("RESKIN_SRC") or _sibling_src() or _MQ
    out_dir = out_dir or os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(out_dir, exist_ok=True)
    print(f"reskin style={style}  ->  {out_dir}")
    for src, dst in _MAP:
        im = Image.open(os.path.join(src_dir, f"{src}.png")).convert("RGBA")
        w, h = im.size
        scale = min(1.0, _MAX_DIM / max(w, h))
        if scale < 1.0:
            im = im.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        arr = np.asarray(im)
        out = reskin_array(arr, style=style)
        path = os.path.join(out_dir, f"{dst}.png")
        Image.fromarray(out, "RGBA").save(path, optimize=True)
        ow, oh = im.size
        decoded_mib = ow * oh * 4 / (1024 * 1024)
        disk_kib = os.path.getsize(path) / 1024
        print(f"  {dst}.png  {ow}x{oh}  decoded={decoded_mib:.1f}MiB  "
              f"disk={disk_kib:.0f}KiB")


if __name__ == "__main__":
    import sys
    main(style=sys.argv[1] if len(sys.argv) > 1 else 'c',
         src_dir=sys.argv[2] if len(sys.argv) > 2 else None)
