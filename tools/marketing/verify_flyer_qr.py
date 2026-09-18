#!/usr/bin/env python3
"""Decode every QR on the built flyer and check it against `flyer_links.json`.

A flyer is printed once. A QR that encodes the wrong URL, or one that no longer
resolves, is not something you find out about until someone is standing in a
dark car park trying to scan it. So this checks both halves:

1. **Decode** — render each PDF at 300 dpi and read every QR symbol on the page
   with zbar, the same class of decoder a phone camera uses. The decoded set
   must equal the links in `flyer_links.json` exactly: no missing code, no
   stray one, no typo'd URL. A5 is checked as well as A4 because the handout is
   the same artwork scaled down, and the small one is the one that fails first.
2. **Resolve** — follow each decoded URL and report the status it lands on, so a
   code that scans perfectly into a 404 still fails the check.

    python3 tools/marketing/verify_flyer_qr.py            # decode + resolve
    python3 tools/marketing/verify_flyer_qr.py --offline  # decode only

Needs `pypdfium2` and `pyzbar` (which needs the zbar library itself:
`brew install zbar`). Exits non-zero on any mismatch, so it can gate a print run.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_LINKS = REPO / "tools" / "marketing" / "flyer_links.json"
DEFAULT_DIR = REPO / "build" / "app-flyer"
DPI = 300
URL_KEYS = ("app_store_url", "android_url", "web_url")

# A phone needs roughly this much physical size per QR module to scan at arm's
# length in poor light. Below it the code technically decodes from a 300 dpi
# render and still fails on a cold night with a cheap camera.
MIN_MODULE_MM = 0.4


def expected_urls(links_path: Path) -> set[str]:
    data = json.loads(links_path.read_text(encoding="utf-8"))
    return {data[k] for k in URL_KEYS if data.get(k)}


def resolve(url: str, timeout: float = 15.0) -> str:
    """Follow the URL and describe where it lands, without downloading a body."""
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "aon2026-flyer-check"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            ctype = r.headers.get("Content-Type", "?").split(";")[0]
            return f"{r.status} {ctype}"
    except Exception as e:  # noqa: BLE001 — any failure is a failure to report
        return f"UNREACHABLE ({type(e).__name__}: {e})"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--links", type=Path, default=DEFAULT_LINKS)
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR, help="where the built PDFs are")
    ap.add_argument("--offline", action="store_true", help="decode only; do not fetch the URLs")
    args = ap.parse_args()

    try:
        import pypdfium2 as pdfium
        from pyzbar.pyzbar import ZBarSymbol, decode
    except ImportError as e:
        print(f"missing dependency: {e}\n  pip install pypdfium2 pyzbar   (and: brew install zbar)", file=sys.stderr)
        return 2

    want = expected_urls(args.links)
    if not want:
        print(f"no links set in {args.links} — nothing to verify", file=sys.stderr)
        return 2
    pdfs = sorted(args.dir.glob("AON2026-app-flyer-*.pdf"))
    if not pdfs:
        print(f"no flyer PDFs in {args.dir} — run build_app_flyer.py first", file=sys.stderr)
        return 2

    ok = True
    for pdf in pdfs:
        page = pdfium.PdfDocument(str(pdf))[0]
        width_mm = page.get_width() / 72 * 25.4
        image = page.render(scale=DPI / 72).to_pil().convert("L")
        symbols = decode(image, symbols=[ZBarSymbol.QRCODE])
        got = sorted(s.data.decode() for s in symbols)

        print(f"\n{pdf.name}  ({width_mm:.0f} mm wide, read at {DPI} dpi)")
        for s in symbols:
            side_mm = s.rect.width / DPI * 25.4
            # zbar reports the symbol box; modules across it tell us the pitch.
            url = s.data.decode()
            print(f"  {side_mm:5.1f} mm  {url}")
            # Version from the data length is unreliable, so measure instead:
            # a QR is at least 21 modules; use the decoded polygon's width.
            if side_mm / 41 < MIN_MODULE_MM:  # 41 modules = version 6, the worst case here
                print(f"      WARNING: ~{side_mm / 41:.2f} mm per module, under the {MIN_MODULE_MM} mm"
                      " rule of thumb for scanning in the dark")

        missing, extra = want - set(got), set(got) - want
        if missing or extra or len(got) != len(want):
            ok = False
            print(f"  FAIL: decoded {len(got)}, expected {len(want)}")
            for u in sorted(missing):
                print(f"    missing: {u}")
            for u in sorted(extra):
                print(f"    unexpected: {u}")
        else:
            print(f"  OK: {len(got)}/{len(want)} codes match flyer_links.json exactly")

    if not args.offline:
        print("\nwhere each code actually lands:")
        for url in sorted(want):
            status = resolve(url)
            print(f"  {status:<34} {url}")
            if "UNREACHABLE" in status or not status.startswith(("2", "3")):
                ok = False

    print("\n" + ("FLYER QR CHECK PASSED" if ok else "FLYER QR CHECK FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
