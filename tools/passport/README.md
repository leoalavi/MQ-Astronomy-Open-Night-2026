# Passport station QR signs

Generates the nine printable Astronomy Passport station signs — one per stamp
station, each carrying the QR code the app scans plus the same code in text as
the accessibility fallback.

```bash
python3 tools/passport/build_station_qr.py        # -> build/passport-qr/
```

Needs `qrcode`, `pillow` and `reportlab`. Output is written to `build/`, which
is git-ignored: the signs are a build product, the script is the source of
truth.

## What it produces

| File | Use |
|---|---|
| `AON2026-passport-stations.pdf` | Nine A4 pages — the thing you send to a printer |
| `qr/station-<L>-<venue>.png` | The bare QR for each station, if a designer wants to lay the signs out differently |
| `stations.csv` | Station ↔ venue ↔ code ↔ payload manifest, for the organisers to check against their own list |

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
re-print.

**The codes are not secrets.** An offline open-source app that can validate a
code necessarily contains everything needed to forge one — see the doc comment
on `StampStation`. Staff redemption at the prize booth is the actual control.

## While the codes are placeholders

Every station currently ships as `AON-<L>-TBC`. The script stamps those pages
DRAFT and refuses to pretend otherwise, because:

- the app's own release gate (`PassportPolicy.isCollectionEnabled`) disables
  passport collection in release builds while any code is a placeholder, so a
  visitor scanning one of these signs on the night would get nothing; and
- release blocker **B5** in `docs/release-blockers.md` stays open until the
  organisers supply the nine real codes.

When the real codes arrive: edit `stamp_stations_data.dart`, set each station's
`codeConfidence` to `DataConfidence.confirmed`, re-run this script, and the
DRAFT watermark disappears on its own.

## Verifying a batch before it goes to the printer

The QR is drawn over the DRAFT watermark, not under it, so the watermark cannot
add contrast noise across the finder patterns. To confirm a generated batch
still scans, rasterise the PDF and decode the pages:

```bash
pdftoppm -r 300 -png build/passport-qr/AON2026-passport-stations.pdf /tmp/pg
```

then decode each `/tmp/pg-*.png` and compare against the `qr_payload` column of
`stations.csv`. Note that OpenCV's `QRCodeDetector` is scale-sensitive and can
fail on a symbol that decodes perfectly at a different resolution — check a
second resolution before believing a failure.
