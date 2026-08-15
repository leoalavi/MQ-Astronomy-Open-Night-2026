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
