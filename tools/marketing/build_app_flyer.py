#!/usr/bin/env python3
"""Build the "get the app" flyer for Astronomy Open Night 2026.

Printed and handed out / pinned up. Same discipline as the station signs:
nothing on it is typed in twice.

Three ways to get the app, three QR codes: the App Store, a direct Android
download, and the web app. The Android one is NOT Google Play -- the app is not
published there -- so the column is labelled "ANDROID / Direct download" and
carries no Play badge or Play wording. Calling it Google Play would be the exact
dishonesty the DRAFT watermark below exists to prevent.

The Android QR encodes a short, stable redirect path, never the release asset
URL: the APK tag moves with every build and nobody reprints a flyer per build.

* Copy comes from `docs/release/app-store-listing.md` — the name, subtitle,
  promotional text and the six feature headings with their first sentence.
  That copy has already been vetted against App Review guideline 2.3.1
  ("describe what the app actually does"), so the flyer inherits its honesty.
* The event name in Persian is the app's own `eventName` from `app_fa.arb`.
* Store links live in `flyer_links.json`. While a link is `null` the flyer
  prints a labelled placeholder slot where the QR will go and is watermarked
  DRAFT, exactly as the station signs are while a code is unconfirmed. Fill in
  the JSON, re-run, re-print — the QR appears and the watermark goes.
* The App Store badge is NOT drawn here. Apple requires its own artwork,
  unmodified: "Use only the badge artwork provided in these guidelines". The
  flyer reserves a correctly sized, correctly spaced slot and takes the official
  PNG via `apple_badge_png` in the JSON. Until then a dashed outline marks the
  slot so a proof never goes out with a home-made badge. There is no Google Play
  badge because there is no Google Play listing.

Badge rules encoded below, from the 2026 guideline pages (see README):
  Apple  — min 10 mm high in print; clear space ¼ badge height; one App Store
           badge per layout; never modify, angle or recolour. The flyer uses a
           12 mm badge with ¼-height clear space on the white panel, and is the
           only store badge present, so Apple's ordering rule does not bite.

Naming rules (Apple): the app is "Astronomy Open Night for iPhone", never an
"iOS app"; no "smartphone"/"tablet"; credit lines once, in the footer.

The Home-screen hero photograph ("A Deep Triangulum Galaxy", Aleix Roig) is
deliberately NOT used: rights sit with the photographer and print use is not
covered. The artwork is the app's own icon illustration.

Usage:
    python3 tools/marketing/build_app_flyer.py [--links JSON] [--out DIR] [--preview]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw
from qrcode.constants import ERROR_CORRECT_M
from reportlab.lib.pagesizes import A3, A4, A5
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "passport"))
import build_station_qr as sign  # noqa: E402 — the one design system

LISTING = REPO / "docs" / "release" / "app-store-listing.md"
FA_ARB = REPO / "lib" / "l10n" / "app_fa.arb"
EN_ARB = REPO / "lib" / "l10n" / "app_en.arb"
ICON = REPO / "assets" / "branding" / "app_icon_source.png"
DEFAULT_LINKS = REPO / "tools" / "marketing" / "flyer_links.json"

APPLE_CREDIT = "Apple and the Apple logo are trademarks of Apple Inc., registered in the U.S. and other countries. App Store is a service mark of Apple Inc."
# No Google Play credit line: the flyer names neither Google Play nor Android as
# a Google product, because the app is not published on Play. Claiming the mark
# we do not use would be as wrong as using a mark we may not.
BADGE_H = 12 * mm  # ≥ Apple's 10 mm print minimum


# --- sources ------------------------------------------------------------------

def fenced_after(md: str, heading: str) -> str:
    """The first ``` block after a '## <heading>' line."""
    m = re.search(rf"^## {re.escape(heading)}[^\n]*\n(?:.*?\n)*?```\n(.*?)\n```", md, re.M | re.S)
    if not m:
        sys.exit(f"could not find '{heading}' in {LISTING}")
    return m.group(1).strip()


def features(md: str) -> list[tuple[str, str]]:
    """ALL-CAPS section headings inside the Description block, with the first
    sentence of the paragraph under each. Stops at the non-feature sections."""
    desc = fenced_after(md, "Description")
    out: list[tuple[str, str]] = []
    blocks = re.split(r"\n\s*\n", desc)
    for b in blocks:
        lines = b.strip().split("\n")
        if len(lines) >= 2 and re.fullmatch(r"[A-Z][A-Z ,'’\-]+", lines[0].strip()):
            head = lines[0].strip()
            if head in {"BUILT TO BE HONEST", "PRIVACY", "ACCESSIBILITY"}:
                break
            para = " ".join(x.strip() for x in lines[1:])
            first = re.split(r"(?<=[.!?])\s", para, 1)[0]
            out.append((head, first))
    if len(out) < 4:
        sys.exit("fewer than four feature sections parsed from the listing")
    return out[:6]


def arb_value(path: Path, key: str) -> str | None:
    m = re.search(rf'"{key}"\s*:\s*"([^"]+)"', path.read_text(encoding="utf-8"))
    return m.group(1) if m else None


def load_links(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    links = {k: v for k, v in data.items() if not k.startswith("_")}
    # Badge paths are stored repo-relative so the flyer builds the same from any
    # working directory; an absolute path in the JSON is left alone.
    for k in ("apple_badge_png",):
        if links.get(k) and not Path(links[k]).is_absolute():
            links[k] = str(REPO / links[k])
    return links


# --- artwork ------------------------------------------------------------------

def rounded_icon(src: Path, out: Path, px: int = 1024, radius_frac: float = 0.2237) -> Path:
    """The icon with the iOS-style continuous-corner mask — the shape people
    already have on their Home screen, so the flyer and the phone agree."""
    im = Image.open(src).convert("RGBA").resize((px, px), Image.LANCZOS)
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, px - 1, px - 1), radius=int(px * radius_frac), fill=255)
    im.putalpha(mask)
    im.save(out)
    return out


def make_qr(url: str, out: Path) -> Path:
    qr = qrcode.QRCode(version=None, error_correction=ERROR_CORRECT_M, box_size=16, border=4)
    qr.add_data(url)
    qr.make(fit=True)
    qr.make_image(fill_color="black", back_color="white").save(out)
    return out


# --- layout -------------------------------------------------------------------

def wrap_lines(c: canvas.Canvas, s: str, font: str, size: float, max_w: float, max_lines: int) -> list[str]:
    """Greedy wrap; the last permitted line is ellipsised if text remains."""
    words, lines, cur = s.split(), [], ""
    for wd in words:
        trial = (cur + " " + wd).strip()
        if c.stringWidth(trial, font, size) <= max_w:
            cur = trial
        else:
            lines.append(cur); cur = wd
            if len(lines) == max_lines:
                break
    if len(lines) < max_lines:
        lines.append(cur)
    elif cur:
        while c.stringWidth(lines[-1] + "…", font, size) > max_w and " " in lines[-1]:
            lines[-1] = lines[-1].rsplit(" ", 1)[0]
        lines[-1] += "…"
    return [ln for ln in lines if ln]


def placeholder_box(c: canvas.Canvas, x: float, y: float, w: float, h: float, label: str, sub: str) -> None:
    c.saveState()
    c.setStrokeColor(sign.INK_SOFT)
    c.setDash(3, 3)
    c.setLineWidth(0.8)
    c.roundRect(x, y, w, h, 2 * mm, stroke=1, fill=0)
    c.setDash()
    sign.text(c, x + w / 2, y + h / 2 + 2.2 * mm, label, sign.FONTS["heading"], 8.5, sign.INK_SOFT, align="center", tracking=0.8)
    sign.text(c, x + w / 2, y + h / 2 - 3.2 * mm, sub, sign.FONTS["body"], 7, sign.INK_SOFT, align="center")
    c.restoreState()


# Vertical anchors inside the white panel, shared by all three columns so the
# QRs, captions and the badge slot line up across them.
QR_SIDE = 40 * mm      # 28.3 mm once scaled to A5; decoding is verified at both sizes
CAPTION_Y = 49.5 * mm  # baseline
BADGE_Y = 32 * mm      # bottom edge; ¼-badge-height clear space above and below


def link_column(c: canvas.Canvas, *, x: float, w: float, top: float, title: str, caption: str,
                url: str | None, qr_png: Path | None, placeholder_label: str,
                badge_png: str | None = None, badge_slot: bool = False) -> None:
    """One way to get the app: heading, QR, one-line caption, optional badge."""
    F = sign.FONTS
    sign.text(c, x + w / 2, top, title, F["heading"], 10.5, sign.INK, align="center", tracking=1.6)
    qx, qy = x + (w - QR_SIDE) / 2, top - 5 * mm - QR_SIDE
    if url and qr_png:
        c.drawImage(str(qr_png), qx, qy, QR_SIDE, QR_SIDE)
    else:
        placeholder_box(c, qx + 3 * mm, qy + 3 * mm, QR_SIDE - 6 * mm, QR_SIDE - 6 * mm,
                        placeholder_label, "QR goes here when the link exists")
    sign.text(c, x + w / 2, CAPTION_Y, caption, F["body"], 8.2, sign.INK_SOFT, align="center")
    if not badge_slot:
        return
    # badge slot: official artwork only, 12 mm high, ¼-height clear space all round
    bh = BADGE_H
    bw = bh * (120 / 40)  # the official badge is ~3:1
    bx = x + (w - bw) / 2
    if badge_png and Path(badge_png).exists():
        c.drawImage(badge_png, bx, BADGE_Y, bw, bh, mask="auto")
    else:
        placeholder_box(c, bx, BADGE_Y, bw, bh, "OFFICIAL BADGE", "drop in artwork from the store")


def draw_flyer(c: canvas.Canvas, *, links: dict, name: str, subtitle: str, promo: str,
               feats: list[tuple[str, str]], fa_name: str | None, ack: str | None,
               icon_png: Path, qrs: dict[str, Path | None], is_draft: bool) -> None:
    w, h = A4
    margin = 16 * mm
    F = sign.FONTS

    # background — identical system to the station signs
    c.setFillColor(sign.NAVY_DEEP)
    c.rect(0, 0, w, h, stroke=0, fill=1)
    c.saveState(); c.linearGradient(0, h, 0, h * 0.45, [sign.NAVY_RAISED, sign.NAVY_DEEP], extend=True); c.restoreState()
    c.saveState(); c.setFillAlpha(0.38); c.radialGradient(w * 0.72, h - 52 * mm, 120 * mm, [sign.GOLD_DEEP, sign.NAVY_DEEP], extend=False); c.restoreState()

    panel_x, panel_w = margin, w - 2 * margin
    panel_bottom, panel_top = 21 * mm, 128 * mm
    sign.starfield(c, w, h, seed=2026, avoid=[
        (panel_x, panel_bottom, panel_w, panel_top - panel_bottom),
        (0, h - 20 * mm, w, 20 * mm),
        (0, 0, w, 20 * mm),
        (margin, panel_top + 4 * mm, w - 2 * margin, 82 * mm),  # promo + feature grid type
    ])

    if is_draft:
        c.saveState(); c.setFillColor(sign.ALERT); c.setFillAlpha(0.16)
        c.translate(w / 2, h * 0.66); c.rotate(34); c.setFont(F["display"], 150)
        c.drawCentredString(0, 0, "DRAFT"); c.restoreState()

    # top band
    y = h - 13 * mm
    sign.text(c, margin, y, sign.EVENT_TITLE, F["heading"], 10.5, sign.GOLD, tracking=2.2)
    sign.text(c, w - margin, y, sign.EVENT_META, F["heading"], 7.2, sign.MUTED, align="right", tracking=0.9)
    c.setStrokeColor(sign.GOLD); c.setStrokeAlpha(0.55); c.setLineWidth(0.6)
    c.line(margin, y - 4 * mm, w - margin, y - 4 * mm); c.setStrokeAlpha(1)
    if is_draft:
        sign.text(c, w / 2, y - 9.5 * mm, "DRAFT — A LINK IS NOT YET LIVE, DO NOT PRINT FOR DISTRIBUTION",
                  F["heading"], 8.5, sign.ALERT, align="center", tracking=0.8)

    # hero: icon + name
    icon = 50 * mm
    ix, iy = margin, h - 30 * mm - icon
    c.saveState(); c.setFillColor(sign.GOLD); c.setFillAlpha(0.35)
    c.roundRect(ix - 1.2 * mm, iy - 1.2 * mm, icon + 2.4 * mm, icon + 2.4 * mm, 11.6 * mm, stroke=0, fill=1); c.restoreState()
    c.drawImage(str(icon_png), ix, iy, icon, icon, mask="auto")

    tx = ix + icon + 9 * mm
    sign.text(c, tx, iy + icon - 9 * mm, "THE APP FOR", F["heading"], 11, sign.GOLD, tracking=2.6)
    size = sign.fit_size(c, name, F["display"], 52, w - margin - tx)
    sign.text(c, tx, iy + icon - 26 * mm, name, F["display"], size, sign.WHITE)
    if fa_name:
        try:
            import arabic_reshaper
            from bidi.algorithm import get_display
            sign.text(c, tx + 1 * mm, iy + icon - 35 * mm, get_display(arabic_reshaper.reshape(fa_name)), F["persian"], 14, sign.GOLD_BRIGHT)
        except ImportError:
            pass
    sign.text(c, tx, iy + 8 * mm, subtitle, F["heading"], 12.5, sign.WHITE)
    sign.text(c, tx, iy + 2 * mm, "Free for iPhone and Android  ·  English and Persian  ·  Works with no signal",
              F["body"], 9.2, sign.MUTED)

    # promo line
    py = iy - 9 * mm
    for ln in sign.wrap_two(c, promo, F["body"], 10.5, w - 2 * margin):
        sign.text(c, margin, py, ln, F["body"], 10.5, sign.MUTED); py -= 5.2 * mm

    # feature grid 2 × 3
    gx, gy = margin, py - 6 * mm
    col_w, row_h = (w - 2 * margin - 8 * mm) / 2, 20.5 * mm
    for i, (head, body) in enumerate(feats):
        r, col = divmod(i, 2)
        x0, y0 = gx + col * (col_w + 8 * mm), gy - r * row_h
        c.setFillColor(sign.GOLD); c.rect(x0, y0 - 1.2 * mm, 5 * mm, 1.2 * mm, stroke=0, fill=1)
        sign.text(c, x0, y0 - 6 * mm, head, F["heading"], 9.5, sign.GOLD, tracking=1.2)
        lines = wrap_lines(c, body, F["body"], 8.4, col_w, 3)
        yy = y0 - 10.6 * mm
        for ln in lines:
            sign.text(c, x0, yy, ln, F["body"], 8.4, sign.MUTED); yy -= 4.2 * mm

    # the one bright panel — get the app
    c.setFillColor(sign.PANEL); c.setStrokeColor(sign.GOLD); c.setLineWidth(1.4)
    c.roundRect(panel_x, panel_bottom, panel_w, panel_top - panel_bottom, 5 * mm, stroke=1, fill=1)
    sign.text(c, w / 2, panel_top - 12 * mm, "GET THE APP", F["heading"], 17, sign.INK, align="center", tracking=1.6)
    sign.text(c, w / 2, panel_top - 18 * mm, "Three ways in. Scan any code — or search “Astronomy Open Night 2026” in the App Store.",
              F["body"], 9.6, sign.INK_SOFT, align="center")

    col_top = panel_top - 28 * mm
    third = panel_w / 3
    # The App Store is the only store here, so it is the only column with a
    # badge slot. Android is a direct download, not a Play listing, and the web
    # app is not distributed by anyone.
    link_column(c, x=panel_x, w=third, top=col_top, title="APP STORE",
                caption="Free for iPhone and iPad", url=links.get("app_store_url"),
                qr_png=qrs.get("app_store"), placeholder_label="APP STORE LINK — TBC",
                badge_png=links.get("apple_badge_png"), badge_slot=True)
    link_column(c, x=panel_x + third, w=third, top=col_top, title="ANDROID",
                caption="Direct download (APK)", url=links.get("android_url"),
                qr_png=qrs.get("android"), placeholder_label="ANDROID LINK — TBC")
    link_column(c, x=panel_x + 2 * third, w=third, top=col_top, title="WEB APP",
                caption="Opens in your browser", url=links.get("web_url"),
                qr_png=qrs.get("web"), placeholder_label="WEB LINK — TBC")
    c.setStrokeColor(sign.HexColor("#D3DAE8")); c.setLineWidth(0.7)
    for i in (1, 2):
        c.line(panel_x + i * third, col_top - 46 * mm, panel_x + i * third, col_top + 3 * mm)

    # For anyone who cannot scan: the two addresses short enough to type. The
    # App Store one is not here on purpose — searching the name is easier than
    # typing an eleven-digit id.
    web, android = links.get("web_url"), links.get("android_url")
    typed = "   ·   ".join(u.replace("https://", "").rstrip("/") for u in (web, android) if u)
    sign.text(c, w / 2, panel_bottom + 6.5 * mm,
              typed or "Web and Android links: TBC — set them in flyer_links.json",
              F["mono"] if typed else F["body"], 8.4 if typed else 8,
              sign.INK if typed else sign.INK_SOFT, align="center")
    sign.text(c, w / 2, panel_bottom + 2.8 * mm,
              "Android asks you to allow installs from your browser the first time.",
              F["body"], 7, sign.INK_SOFT, align="center")

    # footer: acknowledgement + the credit lines, once
    if ack:
        sign.text(c, margin, 15 * mm, ack, F["body"], 7.6, sign.MUTED)
    sign.text(c, margin, 8.6 * mm, APPLE_CREDIT, F["body"], 5.6, sign.DIM)
    sign.text(c, w - margin, 7.4 * mm, "generated by tools/marketing/build_app_flyer.py", F["mono"], 5.4, sign.DIM, align="right")
    c.showPage()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--links", type=Path, default=DEFAULT_LINKS)
    ap.add_argument("--out", type=Path, default=REPO / "build" / "app-flyer")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()

    sign.resolve_fonts()
    md = LISTING.read_text(encoding="utf-8")
    name, subtitle, promo = fenced_after(md, "Name"), fenced_after(md, "Subtitle"), fenced_after(md, "Promotional text")
    feats = features(md)
    fa_name = arb_value(FA_ARB, "eventName") if sign.FONTS.get("persian") else None
    ack = arb_value(EN_ARB, "creditsAcknowledgement")
    links = load_links(args.links)

    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    icon_png = rounded_icon(ICON, out / "app-icon-rounded.png")
    qrs: dict[str, Path | None] = {}
    for key, fname in (("app_store_url", "qr-app-store.png"),
                       ("android_url", "qr-android.png"),
                       ("web_url", "qr-web-app.png")):
        qrs[key.replace("_url", "")] = make_qr(links[key], out / fname) if links.get(key) else None
    # All three have to be real: a flyer with one dead column is still a flyer
    # someone hands to a visitor.
    is_draft = not all(links.get(k) for k in ("app_store_url", "android_url", "web_url"))

    outputs = []
    # A3, A4 and A5 are all the same √2 shape, so one layout scales to each
    # exactly -- no reflow, and the QR module size scales with it. A3 is the
    # poster; A5 is the handout.
    for label, size, scale in (("A3", A3, A3[0] / A4[0]), ("A4", A4, 1.0), ("A5", A5, A5[0] / A4[0])):
        pdf = out / f"AON2026-app-flyer-{label}.pdf"
        c = canvas.Canvas(str(pdf), pagesize=size)
        c.setTitle(f"Astronomy Open Night 2026 — app flyer ({label})")
        c.setAuthor("aon2026 — generated by tools/marketing/build_app_flyer.py")
        c.scale(scale, scale)
        draw_flyer(c, links=links, name=name, subtitle=subtitle, promo=promo, feats=feats, fa_name=fa_name,
                   ack=ack, icon_png=icon_png, qrs=qrs, is_draft=is_draft)
        c.save()
        outputs.append(pdf)

    print(f"flyer -> {sign.rel(out)}")
    for p in outputs:
        print(f"  {sign.rel(p)}")
    print("  fonts   : " + ", ".join(f"{k}={v}" for k, v in sign.FONTS.items()))
    for k in ("app_store_url", "android_url", "web_url", "apple_badge_png"):
        print(f"  {k:<17}: {links.get(k) or 'TBC (placeholder)'}")
    if args.preview:
        try:
            import pypdfium2 as pdfium
            for p in outputs:
                pdfium.PdfDocument(str(p))[0].render(scale=110 / 72).to_pil().save(p.with_suffix(".png"))
            print("  preview : PNG beside each PDF")
        except ImportError:
            print("  preview : skipped (pip install pypdfium2)", file=sys.stderr)
    if is_draft:
        print("\nWARNING: a link is still null in flyer_links.json — the flyer is a\n"
              "         DRAFT proof with placeholder QR slots. Do not print for distribution.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
