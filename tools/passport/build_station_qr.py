#!/usr/bin/env python3
"""Build the nine Astronomy Passport station QR posters.

The app is the single source of truth. This script reads the station codes
straight out of `lib/data/stamp_stations_data.dart` and the venue names out of
`lib/data/venues_data.dart`, so when the organisers confirm the real codes you
change the Dart file and re-run this — the posters cannot drift from the app.

The QR payload is exactly what `StampService` accepts:

    AON2026:<CODE>

`StampService._tokenFromQr` requires the `AON2026:` namespace (so a stray QR
from anywhere else is rejected) and upper-cases the remainder before matching.
The code is deliberately NOT a secret — see the doc comment on `StampStation`;
staff redemption at the booth is the real control.

While any station code is still a placeholder (`AON-*-TBC`), every poster is
stamped DRAFT and carries a red watermark, because a poster printed with a
placeholder code would scan to nothing on the night: the app's own release gate
(`PassportPolicy.isCollectionEnabled`) disables collection in release builds
until every code is confirmed.

Usage:
    python3 tools/passport/build_station_qr.py [--out DIR]
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_H
from reportlab.lib.colors import Color, HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

REPO = Path(__file__).resolve().parents[2]
STATIONS_DART = REPO / "lib" / "data" / "stamp_stations_data.dart"
VENUES_DART = REPO / "lib" / "data" / "venues_data.dart"

QR_NAMESPACE = "AON2026:"  # must match StampService._qrNamespace
PLACEHOLDER_RE = re.compile(r"-TBC$", re.IGNORECASE)

INK = HexColor("#101418")
MUTED = HexColor("#5A6472")
RULE = HexColor("#C9D1DA")
ALERT = HexColor("#B3261E")

EVENT_TITLE = "Astronomy Open Night 2026"
EVENT_DATE = "Saturday 19 September 2026  ·  4–10pm  ·  Macquarie University"


def parse_stations(path: Path) -> list[tuple[str, str]]:
    """Return [(venueId, code)] in declaration order."""
    src = path.read_text(encoding="utf-8")
    body = src.split("static const List<StampStation> all = [", 1)
    if len(body) != 2:
        sys.exit(f"could not find the station list in {path}")
    # Each entry has a venueId and a code, in that order, possibly split
    # across lines by the formatter.
    entries = re.findall(
        r"venueId:\s*'([^']+)'\s*,\s*(?:\n\s*)?code:\s*'([^']+)'",
        body[1],
    )
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


def make_qr(payload: str) -> qrcode.image.pil.PilImage:
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,  # survives scuffs, damp, night glare
        box_size=20,
        border=2,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    return qr.make_image(fill_color="black", back_color="white")


def centred(c: canvas.Canvas, text: str, font: str, size: int, y: float) -> None:
    c.setFont(font, size)
    c.drawCentredString(A4[0] / 2, y, text)


def fit_font_size(c: canvas.Canvas, text: str, font: str, start: int, max_w: float) -> int:
    size = start
    while size > 10 and c.stringWidth(text, font, size) > max_w:
        size -= 1
    return size


def draw_poster(
    c: canvas.Canvas,
    *,
    letter: str,
    venue: str,
    code: str,
    payload: str,
    qr_path: Path,
    is_draft: bool,
) -> None:
    w, h = A4
    margin = 18 * mm

    # --- draft watermark (drawn FIRST, so the opaque QR covers it) ---------
    # An overlay on the QR — even at 12% alpha — is contrast noise straight
    # across the finder patterns on a sign read by phone cameras in the dark.
    if is_draft:
        c.saveState()
        c.setFillColor(Color(179 / 255, 38 / 255, 30 / 255, alpha=0.12))
        c.translate(w / 2, h / 2)
        c.rotate(38)
        c.setFont("Helvetica-Bold", 92)
        c.drawCentredString(0, 0, "DRAFT")
        c.restoreState()
        c.setFillColor(ALERT)
        c.setFont("Helvetica-Bold", 11)
        c.drawCentredString(
            w / 2,
            h - margin + 2 * mm,
            "DRAFT — PLACEHOLDER CODE, DO NOT PRINT FOR THE EVENT",
        )

    # --- header -----------------------------------------------------------
    c.setFillColor(MUTED)
    centred(c, EVENT_TITLE.upper(), "Helvetica-Bold", 13, h - margin - 4 * mm)
    c.setFillColor(RULE)
    c.setLineWidth(0.8)
    c.line(margin, h - margin - 8 * mm, w - margin, h - margin - 8 * mm)

    # --- station identity -------------------------------------------------
    c.setFillColor(INK)
    centred(c, "ASTRONOMY PASSPORT", "Helvetica-Bold", 30, h - margin - 24 * mm)

    badge_y = h - margin - 46 * mm
    c.setFillColor(INK)
    c.circle(w / 2, badge_y + 4 * mm, 11 * mm, stroke=0, fill=1)
    c.setFillColor(HexColor("#FFFFFF"))
    c.setFont("Helvetica-Bold", 30)
    c.drawCentredString(w / 2, badge_y, letter)

    c.setFillColor(INK)
    size = fit_font_size(c, venue, "Helvetica-Bold", 22, w - 2 * margin)
    centred(c, venue, "Helvetica-Bold", size, badge_y - 16 * mm)

    # --- QR ---------------------------------------------------------------
    qr_side = 104 * mm
    qr_x = (w - qr_side) / 2
    qr_y = badge_y - 30 * mm - qr_side
    c.setStrokeColor(RULE)
    c.setLineWidth(1)
    c.rect(qr_x - 5 * mm, qr_y - 5 * mm, qr_side + 10 * mm, qr_side + 10 * mm)
    c.drawImage(str(qr_path), qr_x, qr_y, qr_side, qr_side)

    # --- instructions -----------------------------------------------------
    c.setFillColor(INK)
    centred(c, "Scan to collect your stamp", "Helvetica-Bold", 17, qr_y - 16 * mm)
    c.setFillColor(MUTED)
    centred(
        c,
        "Open the Astronomy Open Night app  ·  Passport  ·  Scan",
        "Helvetica",
        12,
        qr_y - 23 * mm,
    )

    # --- manual fallback --------------------------------------------------
    box_y = margin + 14 * mm
    c.setStrokeColor(RULE)
    c.setLineWidth(0.8)
    c.rect(margin, box_y, w - 2 * margin, 20 * mm)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 10)
    c.drawCentredString(w / 2, box_y + 14 * mm, "Camera not working? Type this code into the app instead.")
    c.setFillColor(INK)
    c.setFont("Courier-Bold", 21)
    c.drawCentredString(w / 2, box_y + 4 * mm, code)

    # --- footer -----------------------------------------------------------
    c.setFillColor(MUTED)
    centred(c, EVENT_DATE, "Helvetica", 8.5, margin + 6 * mm)
    c.setFont("Helvetica", 6.5)
    c.drawCentredString(w / 2, margin + 2 * mm, payload)

    c.showPage()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--out",
        type=Path,
        default=REPO / "build" / "passport-qr",
        help="output directory (default: build/passport-qr)",
    )
    args = ap.parse_args()

    stations = parse_stations(STATIONS_DART)
    names = parse_venue_names(VENUES_DART)

    out = args.out
    (out / "qr").mkdir(parents=True, exist_ok=True)

    any_placeholder = any(PLACEHOLDER_RE.search(code) for _, code in stations)

    pdf_path = out / "AON2026-passport-stations.pdf"
    c = canvas.Canvas(str(pdf_path), pagesize=A4)
    c.setTitle("Astronomy Open Night 2026 — Passport station signs")

    rows = []
    for index, (venue_id, code) in enumerate(stations):
        letter = chr(ord("A") + index)
        venue = names.get(venue_id, venue_id)
        payload = f"{QR_NAMESPACE}{code.upper()}"
        is_draft = bool(PLACEHOLDER_RE.search(code))

        qr_path = out / "qr" / f"station-{letter}-{venue_id}.png"
        make_qr(payload).save(qr_path)

        draw_poster(
            c,
            letter=letter,
            venue=venue,
            code=code.upper(),
            payload=payload,
            qr_path=qr_path,
            is_draft=is_draft,
        )
        rows.append(
            {
                "station": letter,
                "venue_id": venue_id,
                "venue": venue,
                "code": code.upper(),
                "qr_payload": payload,
                "status": "PLACEHOLDER" if is_draft else "confirmed",
                "qr_png": qr_path.relative_to(out).as_posix(),
            }
        )

    c.save()

    csv_path = out / "stations.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"{len(rows)} stations -> {out}")
    print(f"  posters : {pdf_path.relative_to(REPO)}")
    print(f"  manifest: {csv_path.relative_to(REPO)}")
    print(f"  qr pngs : {(out / 'qr').relative_to(REPO)}/")
    for r in rows:
        flag = "  DRAFT" if r["status"] == "PLACEHOLDER" else ""
        print(f"  {r['station']}  {r['code']:<14} {r['venue']}{flag}")
    if any_placeholder:
        print(
            "\nWARNING: at least one code is still a placeholder. These posters are\n"
            "         proofs only. The app disables passport collection in release\n"
            "         builds until every code is confirmed.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
