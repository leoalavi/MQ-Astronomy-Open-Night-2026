# Passport station signs

Generates the nine printable Astronomy Passport station signs — one per stamp
station, each carrying the QR code the app scans plus the same code in text as
the accessibility fallback.

```bash
python3 tools/passport/build_station_qr.py            # -> build/passport-qr/
python3 tools/passport/build_station_qr.py --preview  # + PNG of every page
```

Needs `qrcode`, `pillow` and `reportlab`; `arabic-reshaper` + `python-bidi` for
the Persian line; `pypdfium2` for `--preview`. Output is written to `build/`,
which is git-ignored: the signs are a build product, the script is the source
of truth.

## What it produces

| File | Use |
|---|---|
| `AON2026-passport-stations.pdf` | Nine A4 pages — the thing you send to a printer |
| `qr/station-<L>-<venue>.png` | The bare QR for each station, 4-module quiet zone included, if a designer lays the sign out differently |
| `stations.csv` | Station ↔ venue ↔ code ↔ payload manifest, for the organisers to check against their own list |
| `preview/<L>.png` | 110 dpi rasters of each page (`--preview` only) |

## The payload contract

Each QR encodes exactly:

```
AON2026:<CODE>
```

`AON2026:` is `StampService._qrNamespace` — a QR without it is rejected as a
foreign code, which is what stops a random poster elsewhere on campus from
registering as a stamp. The remainder is upper-cased before matching, so the
printed casing does not matter.

The script reads the codes out of `lib/data/stamp_stations_data.dart` and the
venue names out of `lib/data/venues_data.dart` rather than keeping its own copy,
so a sign cannot silently drift from the app. Change the Dart file, re-run,
re-print. `test/unit/stamp_service_test.dart` (*printed station signs*) is the
app-side half of that contract.

**The codes are not secrets.** An offline open-source app that can validate a
code necessarily contains everything needed to forge one — see the doc comment
on `StampStation`. Staff redemption at the prize booth is the actual control.

## Status: the codes are live

As of 2026-09-04 all nine stations carry real codes (`AON-A-FL3R` …
`AON-I-JRYL`) marked `DataConfidence.confirmed`, so the signs print clean and
the app's release gate (`PassportPolicy.isCollectionEnabled`) allows collection
in release builds.

**These are the signs to print.** The app accepts these nine codes and nothing
else, so a sign produced anywhere else will scan to nothing on the night. If a
code has to change, change it in `stamp_stations_data.dart`, re-run this
script, and re-print — never edit a sign by hand.

## The design — "night sky, one bright panel"

The sign is read outdoors, at night, by someone holding up a phone in a queue.
Every choice follows from that.

**Palette.** The page uses the app's own dark scheme from
`lib/app/theme/aon_palette.dart` so sign and app read as one system:

| Role | Token | Hex |
|---|---|---|
| page | `surfaceBase` → `surfaceRaised` fade | `#05070F` → `#141A2E` |
| accent, rules, "you are here" | `accent` / `accentBright` / `accentDeep` | `#FFB945` / `#FFD180` / `#C17A12` |
| primary type | `contentPrimary` | `#F2F4FA` |
| secondary type | `contentSecondary` / `contentTertiary` | `#B9C0D4` / `#8790A8` |
| **QR panel** | — | pure `#FFFFFF`, QR modules pure black |

**The one bright surface.** The QR lives on an opaque white rounded panel and
nothing decorative is ever drawn inside it — no stars, no gradient, no
watermark. Black on white is the highest-contrast pairing there is, and the
panel is the only thing on the page a camera needs. The starfield is
generated *around* the panel, not clipped by it, so nothing bleeds in at the
edges either.

**Size.** The QR block is 122 mm; the symbol inside its quiet zone is ~92 mm.
By the 10:1 rule that scans from about a metre — without stepping out of a
queue — and is well over the 25–50 % outdoor margin.

**Hierarchy, in the order a visitor meets it from across a courtyard:**

1. The station letter — DIN Condensed Bold at 172 pt, with a ghosted outline
   copy at 760 pt bleeding off the page as texture. You spot "F" before you can
   read anything.
2. A 3×3 passport grid with this station filled gold — the same "you are here"
   language as the app's passport screen.
3. The venue name — condensed, up to two balanced lines.
4. The panel: `SCAN TO COLLECT YOUR STAMP`, the QR, then the manual-entry code
   in a monospace face at 30 pt with 3.5 pt tracking, because it will be typed
   in the dark by someone whose camera would not focus.
5. The instruction repeated in Persian, using the app's own translated string
   (`passportScanOrEnter` from `app_fa.arb`) — never invented copy.

**Texture, not decoration.** A seeded starfield (420 points, 9 sparkles, seed
`1000 + index`) and a soft radial glow give it the atmospheric, grainy feel of
current poster work. It is deterministic per station, so a re-print is
pixel-identical, and it keeps clear of every block of small type.

**Fonts.** Resolved at runtime from `FONT_CANDIDATES`; anything missing falls
back to Helvetica/Courier so the script never fails on a machine without them.
The reference render uses macOS's DIN Condensed Bold (display), DIN Alternate
Bold (headings), Andale Mono (code) and Sahel Bold (Persian, SIL OFL). The
console output names which fonts actually resolved.

**Grid.** A4 portrait, 16 mm margins. Top band 13 mm from the top; hero
baseline 62 mm; panel from 17 mm to 93 mm-from-top; footer at 10 / 6 mm. All
positions are in `draw_poster` as `mm` expressions — change the numbers there.

## The DRAFT watermark

A page is stamped DRAFT unless its station is `DataConfidence.confirmed` — the
same field the app's release gate reads. Keying it off the code text alone
would let a real-looking code with a placeholder confidence print clean while
release builds silently refused every stamp, which is the drift this script
exists to prevent. The watermark is drawn *under* the panel and the hero, so it
can never add contrast noise across the QR.

## Verifying a batch before it goes to the printer

Rasterise the PDF and decode every page:

```bash
python3 tools/passport/build_station_qr.py --preview
```

then decode each `build/passport-qr/preview/*.png` (or a 300 dpi
`pdftoppm` render) and compare against the `qr_payload` column of
`stations.csv`. Note that OpenCV's `QRCodeDetector` is scale-sensitive and can
fail on a symbol that decodes perfectly at a different resolution — check a
second scale before believing a failure. Every batch shipped so far has
decoded 9/9 at 300 dpi.
