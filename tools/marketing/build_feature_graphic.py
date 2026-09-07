#!/usr/bin/env python3
"""Build the Google Play feature graphic (1024 x 500, no transparency).

Play requires one for every listing. Run from the repo root:

    python3 tools/marketing/build_feature_graphic.py

Constraints this script exists to respect:

* **No third-party photograph.** The Home hero ("A Deep Triangulum Galaxy") is
  Aleix Roig's and is credited, not licensed — see `docs/release/organiser-
  requests.md`. The starfield here is generated procedurally from a fixed seed,
  so it is this project's own output and reproducible byte-for-byte.
* **No university branding.** No crest, wordmark, name or endorsement — the app
  is an independent project (ARCHITECTURE.md §14 invariant 18).
* **Play-safe layout.** Play crops and overlays this image in several
  placements, so nothing that matters sits within `MARGIN` of an edge and the
  right third is kept clear of type.
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1024, 500
MARGIN = 64
SEED = 20260919  # the event date — keeps the starfield reproducible

REPO = Path(__file__).resolve().parents[2]
ICON = REPO / "assets/branding/app_icon_source.png"
OUT = REPO / "docs/release/play-graphics/feature-graphic-1024x500.png"

# Design tokens, from lib/app/theme/aon_palette.dart
GROUND = (5, 7, 15)          # #05070F, the app's dark ground and launch colour
ACCENT = (255, 185, 69)      # #FFB945 accent
ACCENT_BRIGHT = (255, 209, 128)  # #FFD180
TEXT = (242, 244, 250)       # #F2F4FA contentPrimary
MUTED = (185, 192, 212)      # #B9C0D4 contentSecondary

FONTS = {
    "display": ["/System/Library/Fonts/Supplemental/Arial Bold.ttf"],
    "body": ["/System/Library/Fonts/Supplemental/Arial.ttf"],
}


def font(role: str, size: int) -> ImageFont.FreeTypeFont:
    for path in FONTS[role]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def starfield(img: Image.Image) -> None:
    """A procedural night sky — our own pixels, not a licensed photograph."""
    rng = random.Random(SEED)
    d = ImageDraw.Draw(img)

    # A faint galactic wash so the field is not flat black.
    glow = Image.new("RGB", (W, H), GROUND)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-160, -260, 620, 420], fill=(18, 22, 46))
    gd.ellipse([80, -140, 520, 300], fill=(30, 30, 62))
    img.paste(Image.blend(img, glow.filter(ImageFilter.GaussianBlur(120)), 0.85))

    for _ in range(900):  # dust
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        v = rng.randint(70, 130)
        d.point((x, y), fill=(v, v, min(255, v + 18)))
    for _ in range(240):  # stars
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.6, 1.7)
        v = rng.randint(170, 255)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v, v, min(255, v + 10)))
    for _ in range(9):  # a few bright ones, with a soft cross flare
        x, y = rng.uniform(60, W - 60), rng.uniform(40, H - 40)
        d.ellipse([x - 2.4, y - 2.4, x + 2.4, y + 2.4], fill=(255, 255, 250))
        d.line([x - 11, y, x + 11, y], fill=(120, 130, 165), width=1)
        d.line([x, y - 11, x, y + 11], fill=(120, 130, 165), width=1)


def main() -> None:
    img = Image.new("RGB", (W, H), GROUND)
    starfield(img)

    # The app icon, right-of-centre, with a soft accent halo behind it.
    if ICON.exists():
        side = 300
        icon = Image.open(ICON).convert("RGBA").resize((side, side), Image.LANCZOS)
        ix, iy = W - MARGIN - side, (H - side) // 2

        halo = Image.new("RGB", (W, H), GROUND)
        ImageDraw.Draw(halo).ellipse(
            [ix - 46, iy - 46, ix + side + 46, iy + side + 46], fill=(60, 44, 16)
        )
        img.paste(Image.blend(img, halo.filter(ImageFilter.GaussianBlur(70)), 0.55))

        mask = Image.new("L", (side, side), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, side, side], radius=64, fill=255)
        img.paste(icon.convert("RGB"), (ix, iy), mask)

    d = ImageDraw.Draw(img)
    x = MARGIN
    d.text((x, 168), "ASTRONOMY", font=font("display", 62), fill=TEXT)
    d.text((x, 236), "OPEN NIGHT", font=font("display", 62), fill=TEXT)
    d.text((x, 306), "2026", font=font("display", 62), fill=ACCENT)

    d.line([x, 380, x + 118, 380], fill=ACCENT_BRIGHT, width=3)
    d.text((x, 400), "Saturday 19 September  ·  4pm – 10pm",
           font=font("body", 25), fill=MUTED)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")  # RGB, so no alpha channel is written

    check = Image.open(OUT)
    assert check.size == (W, H), check.size
    assert check.mode == "RGB", check.mode
    print(f"wrote {OUT.relative_to(REPO)}  {check.size}  mode={check.mode}")


if __name__ == "__main__":
    main()
