#!/usr/bin/env python3
"""Build the nine Astronomy Passport station signs.

The app is the single source of truth. This script reads the station codes
straight out of `lib/data/stamp_stations_data.dart` and the venue names out of
`lib/data/venues_data.dart`, so a sign cannot drift from the app: change the
Dart file, re-run, re-print.

The QR payload is exactly what `StampService` accepts:

    AON2026:<CODE>

`StampService._tokenFromQr` requires the `AON2026:` namespace (so a stray QR
from anywhere else is rejected) and upper-cases the remainder before matching.
The code is deliberately NOT a secret — see the doc comment on `StampStation`;
staff redemption at the booth is the real control.

A sign is stamped DRAFT unless its station is `DataConfidence.confirmed` —
the *same field* `PassportPolicy.isCollectionEnabled` reads. Keying the
watermark off the code text alone would let a real-looking code with a
placeholder confidence print clean while release builds silently refused every
stamp on the night, which is the exact drift this script exists to prevent.

DESIGN — "night sky, one bright panel"
--------------------------------------
The sign is read outdoors, at night, by someone holding up a phone. Everything
follows from that:

* The page is the app's own dark palette (`aon_palette.dart`: navy surfaces,
  gold accent) so the sign and the app read as one system. A seeded starfield
  and a soft radial glow give it the atmospheric, textured feel of 2026 poster
  work without ever touching the QR.
* The QR sits on the ONE bright surface: an opaque white panel. Black-on-white
  is the highest-contrast combination there is, and the panel is the only
  thing on the page a camera needs. Nothing decorative is allowed inside it.
* The QR block is 122 mm (symbol ~92 mm inside its quiet zone) — by the 10:1
  rule that scans from ~1 m, i.e. without
  stepping out of a queue. The PNG carries the spec's 4-module quiet zone.
* The station letter is the hero, set in a heavy condensed face at poster
  scale, with a ghosted outline copy bleeding off the page: the visitor
  spots "A" from across the courtyard before they can read anything else.
* Manual entry is the accessibility fallback, so the code is printed large in
  a monospace face, and the instruction line is repeated in Persian using the
  app's own translated string — never an invented one.

Fonts are optional and resolved at runtime (see FONT_CANDIDATES). Missing ones
fall back to Helvetica/Courier so the script never fails on a machine without
them; the render just loses some character. The reference render uses DIN
Condensed / DIN Alternate (macOS), Andale Mono, and Sahel (OFL) for Persian.

Usage:
    python3 tools/passport/build_station_qr.py [--out DIR] [--preview]
"""

from __future__ import annotations

import argparse
import csv
import os
import random
import re
import sys
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_H
from reportlab.lib.colors import Color, HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

REPO = Path(__file__).resolve().parents[2]
STATIONS_DART = REPO / "lib" / "data" / "stamp_stations_data.dart"
VENUES_DART = REPO / "lib" / "data" / "venues_data.dart"
FA_ARB = REPO / "lib" / "l10n" / "app_fa.arb"

QR_NAMESPACE = "AON2026:"  # must match StampService._qrNamespace
PLACEHOLDER_RE = re.compile(r"-TBC$", re.IGNORECASE)

# --- palette: lifted from lib/app/theme/aon_palette.dart (dark scheme) -------
NAVY_DEEP = HexColor("#05070F")   # surfaceBase
NAVY = HexColor("#0B0F1D")        # surface
NAVY_RAISED = HexColor("#141A2E") # surfaceRaised
BORDER = HexColor("#232B45")
GOLD = HexColor("#FFB945")        # accent
GOLD_BRIGHT = HexColor("#FFD180") # accentBright
GOLD_DEEP = HexColor("#C17A12")   # accentDeep
WHITE = HexColor("#F2F4FA")       # contentPrimary
MUTED = HexColor("#B9C0D4")       # contentSecondary
DIM = HexColor("#8790A8")         # contentTertiary
PANEL = HexColor("#FFFFFF")       # the one bright surface — pure white for the QR
INK = HexColor("#101418")
INK_SOFT = HexColor("#5A6472")
ALERT = HexColor("#FF8A8A")

EVENT_TITLE = "ASTRONOMY OPEN NIGHT 2026"
EVENT_META = "MACQUARIE UNIVERSITY  ·  SATURDAY 19 SEPTEMBER  ·  4 – 10 PM"

# --- fonts: optional, first match wins, graceful fallback --------------------
HOME = Path(os.path.expanduser("~"))
SYS = Path("/System/Library/Fonts/Supplemental")
FONT_CANDIDATES: dict[str, tuple[list[Path], str]] = {
    # role: ([candidate files...], fallback built-in)
    "display": ([SYS / "DIN Condensed Bold.ttf", SYS / "Arial Narrow Bold.ttf"], "Helvetica-Bold"),
    "heading": ([SYS / "DIN Alternate Bold.ttf", SYS / "Arial Bold.ttf"], "Helvetica-Bold"),
    "body": ([SYS / "Arial.ttf"], "Helvetica"),
    "mono": ([SYS / "Andale Mono.ttf", SYS / "Courier New Bold.ttf"], "Courier-Bold"),
    "persian": ([HOME / "Library/Fonts/Sahel-Bold.ttf", HOME / "Library/Fonts/Sahel.ttf",
                 REPO / "tools/passport/fonts/Sahel-Bold.ttf"], ""),
}
FONTS: dict[str, str] = {}


def resolve_fonts() -> None:
    for role, (paths, fallback) in FONT_CANDIDATES.items():
        for p in paths:
            if p.exists():
                name = f"aon-{role}"
                try:
                    pdfmetrics.registerFont(TTFont(name, str(p)))
                    FONTS[role] = name
                    break
                except Exception:  # noqa: BLE001 — a bad font file is not fatal
                    continue
        else:
            FONTS[role] = fallback


def parse_stations(path: Path) -> list[tuple[str, str, bool]]:
    """Return [(venueId, code, isConfirmed)] in declaration order.

    `isConfirmed` mirrors `DataConfidence.isReliable` on the Dart side: the
    field is optional and defaults to `placeholder`, so an entry that omits it
    is NOT confirmed and its poster is stamped DRAFT.
    """
    src = path.read_text(encoding="utf-8")
    body = src.split("static const List<StampStation> all = [", 1)
    if len(body) != 2:
        sys.exit(f"could not find the station list in {path}")
    entries = []
    for m in re.finditer(
        r"venueId:\s*'([^']+)'\s*,\s*(?:\n\s*)?code:\s*'([^']+)'"
        r"(?P<tail>(?:[^)]|\)(?!\s*,\s*(?:\n\s*)?(?:StampStation|\])))*)",
        body[1],
    ):
        venue_id, code = m.group(1), m.group(2)
        conf = re.search(r"codeConfidence:\s*DataConfidence\.(\w+)", m.group("tail"))
        confirmed = bool(conf) and conf.group(1) != "placeholder"
        entries.append((venue_id, code, confirmed))
    if not entries:
        sys.exit(f"no stations parsed from {path}")
    return entries


def parse_venue_names(path: Path) -> dict[str, str]:
    """Return {venueId: name} for every venue declared in venues_data.dart."""
    src = path.read_text(encoding="utf-8")
    names: dict[str, str] = {}
    for match in re.finditer(r"id:\s*'([^']+)'", src):
        vid = match.group(1)
        tail = src[match.end() : match.end() + 400]
        name = re.search(r"name:\s*'((?:[^'\\]|\\.)*)'", tail)
        if name:
            names[vid] = name.group(1).replace("\\'", "'")
    return names


def persian_line() -> str | None:
    """The app's own translation of 'Scan or enter a code' — never invented."""
    try:
        m = re.search(r'"passportScanOrEnter"\s*:\s*"([^"]+)"', FA_ARB.read_text(encoding="utf-8"))
    except OSError:
        return None
    if not m or not FONTS.get("persian"):
        return None
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
    except ImportError:
        return None
    return get_display(arabic_reshaper.reshape(m.group(1)))


def make_qr(payload: str) -> qrcode.image.pil.PilImage:
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,  # survives scuffs, damp, night glare
        box_size=20,
        # The QR spec's 4-module quiet zone. The bare PNGs are handed to
        # designers who may drop one onto a coloured panel, where a short quiet
        # zone stops scanning.
        border=4,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    return qr.make_image(fill_color="black", back_color="white")


# --- drawing helpers ---------------------------------------------------------

def text(c: canvas.Canvas, x: float, y: float, s: str, font: str, size: float,
         color, *, align: str = "left", tracking: float = 0) -> float:
    """Draw a run of text; returns its width."""
    c.setFont(font, size)
    c.setFillColor(color)
    width = c.stringWidth(s, font, size) + tracking * max(len(s) - 1, 0)
    if align == "center":
        x -= width / 2
    elif align == "right":
        x -= width
    t = c.beginText(x, y)
    t.setFont(font, size)
    t.setCharSpace(tracking)
    t.textOut(s)
    c.drawText(t)
    return width


def fit_size(c: canvas.Canvas, s: str, font: str, start: float, max_w: float, floor: float = 12) -> float:
    size = start
    while size > floor and c.stringWidth(s, font, size) > max_w:
        size -= 1
    return size


def wrap_two(c: canvas.Canvas, s: str, font: str, size: float, max_w: float) -> list[str]:
    """Greedy wrap into at most two lines, balanced-ish."""
    if c.stringWidth(s, font, size) <= max_w:
        return [s]
    words = s.split()
    best: list[str] | None = None
    for i in range(1, len(words)):
        a, b = " ".join(words[:i]), " ".join(words[i:])
        if c.stringWidth(a, font, size) <= max_w and c.stringWidth(b, font, size) <= max_w:
            spread = abs(c.stringWidth(a, font, size) - c.stringWidth(b, font, size))
            if best is None or spread < best[0]:
                best = (spread, [a, b])  # type: ignore[assignment]
    return best[1] if best else [s]  # type: ignore[index]


def starfield(c: canvas.Canvas, w: float, h: float, seed: int, *, avoid: list[tuple[float, float, float, float]]) -> None:
    """A seeded scatter of stars — texture, not decoration. Deterministic per
    station so a re-print is pixel-identical. `avoid` rects (x, y, w, h) keep
    stars off the QR panel and out of the small type."""
    rng = random.Random(seed)

    def clear(x: float, y: float) -> bool:
        return not any(ax - 4 * mm < x < ax + aw + 4 * mm and ay - 4 * mm < y < ay + ah + 4 * mm
                       for ax, ay, aw, ah in avoid)

    ax, ay, aw, ah = avoid[0]
    c.saveState()
    for _ in range(420):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        if not clear(x, y):
            continue
        r = rng.choice([0.35, 0.45, 0.6, 0.8, 1.1, 1.5])
        tone = rng.random()
        col = GOLD_BRIGHT if tone < 0.22 else (WHITE if tone < 0.9 else GOLD)
        c.setFillColor(col)
        c.setFillAlpha(rng.uniform(0.18, 0.95) if r < 1.1 else rng.uniform(0.6, 1.0))
        c.circle(x, y, r, stroke=0, fill=1)
    # a handful of four-point sparkles
    c.setStrokeColor(GOLD_BRIGHT)
    c.setLineWidth(0.5)
    for _ in range(9):
        x, y = rng.uniform(10 * mm, w - 10 * mm), rng.uniform(ay + ah + 12 * mm, h - 8 * mm)
        if not clear(x, y):
            continue
        s = rng.uniform(2.2, 4.5)
        c.setStrokeAlpha(rng.uniform(0.5, 0.95))
        c.line(x - s, y, x + s, y)
        c.line(x, y - s, x, y + s)
    c.restoreState()


def stamp_grid(c: canvas.Canvas, x: float, y_top: float, this_index: int, total: int, cell: float, gap: float) -> None:
    """3×3 passport grid, this station filled — the sign says 'you are here'
    in the same language as the app's passport screen."""
    cols = 3
    for i in range(total):
        r, col = divmod(i, cols)
        cx = x + col * (cell + gap)
        cy = y_top - (r + 1) * cell - r * gap
        if i == this_index:
            c.setFillColor(GOLD)
            c.setStrokeColor(GOLD)
        else:
            c.setFillColor(NAVY_DEEP)
            c.setStrokeColor(BORDER)
        c.setLineWidth(0.7)
        c.roundRect(cx, cy, cell, cell, 1.2, stroke=1, fill=1)


def draw_poster(
    c: canvas.Canvas,
    *,
    letter: str,
    index: int,
    total: int,
    venue: str,
    code: str,
    payload: str,
    qr_path: Path,
    is_draft: bool,
    fa_line: str | None,
) -> None:
    w, h = A4
    margin = 16 * mm
    F = FONTS

    # --- background: navy, vertical fade, warm glow behind the hero ----------
    c.setFillColor(NAVY_DEEP)
    c.rect(0, 0, w, h, stroke=0, fill=1)
    c.saveState()
    c.linearGradient(0, h, 0, h * 0.42, [NAVY_RAISED, NAVY_DEEP], extend=True)
    c.restoreState()
    c.saveState()
    c.setFillAlpha(0.42)
    c.radialGradient(w * 0.30, h - 60 * mm, 150 * mm, [GOLD_DEEP, NAVY_DEEP], extend=False)
    c.restoreState()

    # --- the bright panel geometry (needed early so stars avoid it) ----------
    panel_x, panel_w = margin, w - 2 * margin
    panel_bottom, panel_top = 17 * mm, h - 93 * mm
    panel_h = panel_top - panel_bottom

    hero_base = h - 62 * mm
    letter_w = c.stringWidth(letter, F["display"], 172)
    lab_x = margin + letter_w + 6 * mm
    starfield(c, w, h, seed=1000 + index, avoid=[
        (panel_x, panel_bottom, panel_w, panel_h),   # the QR panel — never
        (0, h - 20 * mm, w, 20 * mm),                # top band type
        (0, 0, w, 14 * mm),                          # footer type
        (lab_x, hero_base + 4 * mm, 46 * mm, 28 * mm),  # station label column
    ])

    # --- ghosted hero letter, bleeding off the page ---------------------------
    c.saveState()
    c.setFillColor(WHITE)
    c.setFillAlpha(0.045)
    t = c.beginText(w * 0.34, 92 * mm)
    t.setFont(F["display"], 760)
    t.textOut(letter)
    c.drawText(t)
    c.setStrokeColor(GOLD)
    c.setStrokeAlpha(0.22)
    c.setLineWidth(1.1)
    t = c.beginText(w * 0.34 + 2.5 * mm, 92 * mm - 2.5 * mm)
    t.setFont(F["display"], 760)
    t.setTextRenderMode(1)
    t.textOut(letter)
    c.drawText(t)
    c.restoreState()

    # --- draft watermark: drawn UNDER everything that matters -----------------
    if is_draft:
        c.saveState()
        c.setFillColor(ALERT)
        c.setFillAlpha(0.16)
        c.translate(w / 2, h * 0.62)
        c.rotate(34)
        c.setFont(F["display"], 150)
        c.drawCentredString(0, 0, "DRAFT")
        c.restoreState()

    # --- top band -------------------------------------------------------------
    y = h - 13 * mm
    text(c, margin, y, EVENT_TITLE, F["heading"], 10.5, GOLD, tracking=2.2)
    text(c, w - margin, y, EVENT_META, F["heading"], 7.2, MUTED, align="right", tracking=0.9)
    c.setStrokeColor(GOLD)
    c.setStrokeAlpha(0.55)
    c.setLineWidth(0.6)
    c.line(margin, y - 4 * mm, w - margin, y - 4 * mm)
    c.setStrokeAlpha(1)

    if is_draft:
        text(c, w / 2, y - 9.5 * mm, "DRAFT — UNCONFIRMED CODE, DO NOT PRINT FOR THE EVENT",
             F["heading"], 8.5, ALERT, align="center", tracking=0.8)

    # --- hero row: solid letter + station label + stamp grid ------------------
    text(c, margin - 1.5 * mm, hero_base, letter, F["display"], 172, WHITE)
    text(c, lab_x, hero_base + 28 * mm, "PASSPORT", F["heading"], 12, GOLD, tracking=2.4)
    text(c, lab_x, hero_base + 22 * mm, "STATION", F["heading"], 12, GOLD, tracking=2.4)
    text(c, lab_x, hero_base + 8 * mm, f"{index + 1}", F["display"], 44, WHITE)
    n_w = c.stringWidth(f"{index + 1}", F["display"], 44)
    text(c, lab_x + n_w + 2 * mm, hero_base + 8 * mm, f"of {total}", F["heading"], 13, MUTED)

    cell, gap = 6.2 * mm, 1.6 * mm
    grid_w = 3 * cell + 2 * gap
    stamp_grid(c, w - margin - grid_w, hero_base + 30 * mm, index, total, cell, gap)

    # --- venue name -----------------------------------------------------------
    name_size = 40
    lines = wrap_two(c, venue, F["display"], name_size, w - 2 * margin)
    if len(lines) == 2:
        name_size = min(35, fit_size(c, max(lines, key=len), F["display"], name_size, w - 2 * margin))
    else:
        name_size = fit_size(c, venue, F["display"], name_size, w - 2 * margin)
    ny = panel_top + 8 * mm + (name_size * 0.95 if len(lines) == 2 else 0)
    for ln in lines:
        text(c, margin, ny, ln, F["display"], name_size, WHITE)
        ny -= name_size * 0.95

    # --- the one bright surface -----------------------------------------------
    c.setFillColor(PANEL)
    c.setStrokeColor(GOLD)
    c.setLineWidth(1.4)
    c.roundRect(panel_x, panel_bottom, panel_w, panel_h, 5 * mm, stroke=1, fill=1)

    cy = panel_top - 12.5 * mm
    text(c, w / 2, cy, "SCAN TO COLLECT YOUR STAMP", F["heading"], 16, INK, align="center", tracking=1.4)
    text(c, w / 2, cy - 6.5 * mm, "Open the Astronomy Open Night app  ·  Passport  ·  Scan",
         F["body"], 9.6, INK_SOFT, align="center")

    qr_side = 122 * mm
    qr_x = (w - qr_side) / 2
    qr_y = cy - 10.5 * mm - qr_side
    c.drawImage(str(qr_path), qr_x, qr_y, qr_side, qr_side)

    # divider + manual fallback
    dy = qr_y - 6 * mm
    c.setStrokeColor(HexColor("#D3DAE8"))
    c.setLineWidth(0.7)
    c.line(panel_x + 12 * mm, dy, w - panel_x - 12 * mm, dy)

    text(c, w / 2, dy - 7 * mm, "Camera not working?  Type this code into the app instead.",
         F["body"], 9.6, INK_SOFT, align="center")
    text(c, w / 2, dy - 19 * mm, code, F["mono"], 30, INK, align="center", tracking=3.5)
    if fa_line:
        text(c, w / 2, dy - 27 * mm, fa_line, F["persian"], 10.5, INK_SOFT, align="center")

    # --- footer ---------------------------------------------------------------
    text(c, margin, 10 * mm, "ASTRONOMY PASSPORT", F["heading"], 7.5, GOLD, tracking=1.8)
    text(c, w - margin, 10 * mm, payload, F["mono"], 6.5, DIM, align="right")
    text(c, margin, 6 * mm, "Collect all nine, then show your passport at the prize booth.",
         F["body"], 7.2, MUTED)

    c.showPage()


def rel(p: Path) -> str:
    """Repo-relative when inside the repo, absolute otherwise — `--out` may
    point anywhere."""
    try:
        return str(p.relative_to(REPO))
    except ValueError:
        return str(p)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=REPO / "build" / "passport-qr",
                    help="output directory (default: build/passport-qr)")
    ap.add_argument("--preview", action="store_true",
                    help="also rasterise each page to preview/<L>.png (needs pypdfium2)")
    args = ap.parse_args()

    resolve_fonts()
    stations = parse_stations(STATIONS_DART)
    names = parse_venue_names(VENUES_DART)
    fa_line = persian_line()

    out = args.out
    (out / "qr").mkdir(parents=True, exist_ok=True)

    any_placeholder = any(not confirmed for _, _, confirmed in stations)

    pdf_path = out / "AON2026-passport-stations.pdf"
    c = canvas.Canvas(str(pdf_path), pagesize=A4)
    c.setTitle("Astronomy Open Night 2026 — Passport station signs")
    c.setAuthor("aon2026 — generated by tools/passport/build_station_qr.py")

    rows = []
    for index, (venue_id, code, confirmed) in enumerate(stations):
        letter = chr(ord("A") + index)
        venue = names.get(venue_id, venue_id)
        payload = f"{QR_NAMESPACE}{code.upper()}"
        is_draft = not confirmed or bool(PLACEHOLDER_RE.search(code))

        qr_path = out / "qr" / f"station-{letter}-{venue_id}.png"
        make_qr(payload).save(qr_path)

        draw_poster(
            c, letter=letter, index=index, total=len(stations), venue=venue,
            code=code.upper(), payload=payload, qr_path=qr_path,
            is_draft=is_draft, fa_line=fa_line,
        )
        rows.append({
            "station": letter, "venue_id": venue_id, "venue": venue,
            "code": code.upper(), "qr_payload": payload,
            "status": "PLACEHOLDER" if is_draft else "confirmed",
            "qr_png": qr_path.relative_to(out).as_posix(),
        })

    c.save()

    csv_path = out / "stations.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"{len(rows)} stations -> {out}")
    print(f"  posters : {rel(pdf_path)}")
    print(f"  manifest: {rel(csv_path)}")
    print(f"  qr pngs : {rel(out / 'qr')}/")
    print("  fonts   : " + ", ".join(f"{k}={v}" for k, v in FONTS.items()))
    print(f"  persian : {'yes' if fa_line else 'no (font or shaping libs missing)'}")
    for r in rows:
        flag = "  DRAFT" if r["status"] == "PLACEHOLDER" else ""
        print(f"  {r['station']}  {r['code']:<14} {r['venue']}{flag}")

    if args.preview:
        try:
            import pypdfium2 as pdfium
        except ImportError:
            print("  preview : skipped (pip install pypdfium2)", file=sys.stderr)
        else:
            (out / "preview").mkdir(exist_ok=True)
            doc = pdfium.PdfDocument(str(pdf_path))
            for i, r in enumerate(rows):
                doc[i].render(scale=110 / 72).to_pil().save(out / "preview" / f"{r['station']}.png")
            print(f"  preview : {rel(out / 'preview')}/")

    if any_placeholder:
        print(
            "\nWARNING: at least one station is unconfirmed. Those pages are watermarked\n"
            "         DRAFT. The app disables passport collection in release builds\n"
            "         until every station is DataConfidence.confirmed.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
