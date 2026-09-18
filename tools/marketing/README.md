# App flyer — "Get the app"

The printed flyer that goes up around campus and into hands. Same discipline as
the passport station signs: nothing on it is typed in twice, and it refuses to
pretend a link exists before it does.

Three ways to get the app, three QR codes: **App Store**, **Android** (a direct
APK download) and the **web app**.

```bash
python3 tools/marketing/build_app_flyer.py --preview     # -> build/app-flyer/
```

Needs `qrcode`, `pillow`, `reportlab` (+ `arabic-reshaper`, `python-bidi` for
the Persian name; `pypdfium2` for `--preview`). Output goes to `build/`, which
is git-ignored — the script and `flyer_links.json` are the source of truth.

## What it produces

| File | Use |
|---|---|
| `AON2026-app-flyer-A4.pdf` | Poster / noticeboard size |
| `AON2026-app-flyer-A5.pdf` | Handout size — the same layout scaled; all three QRs verified to decode at A5 |
| `qr-app-store.png`, `qr-android.png`, `qr-web-app.png` | The bare QRs, once the links exist |
| `app-icon-rounded.png` | The app icon with the Home-screen corner mask, for other collateral |
| `*.png` previews | With `--preview` |

## Where every word comes from

| On the flyer | Source |
|---|---|
| Name, subtitle, promotional line | `docs/release/app-store-listing.md` — the fenced blocks under `## Name`, `## Subtitle`, `## Promotional text` |
| The six feature headings + first sentence | The ALL-CAPS sections inside that document's `## Description` block (stops before BUILT TO BE HONEST / PRIVACY / ACCESSIBILITY) |
| Persian name | `eventName` in `lib/l10n/app_fa.arb` |
| "Two student app developers…" | `creditsAcknowledgement` in `app_en.arb`. Names no university (changed 2026-09-07): this is **not** a university product and must not imply endorsement. No university logo or crest appears anywhere, for the same reason. |
| Event title / date line | `EVENT_TITLE` / `EVENT_META` shared with the station signs |
| Palette, starfield, fonts | `tools/passport/build_station_qr.py` — one design system, imported |

The store listing copy has already been vetted against App Review guideline
2.3.1, so the flyer inherits its honesty. Change the listing, re-run, and the
flyer follows.

## Placeholders — `flyer_links.json`

```json
{
  "app_store_url": "https://apps.apple.com/au/app/astronomy-open-night-2026/id6808865067",
  "android_url": "https://info.syllabus-sync.app/astronomy-open-night/android",
  "web_url": "https://aon.syllabus-sync.app/",
  "apple_badge_png": "tools/marketing/badges/app-store-badge-black-en-us.png"
}
```

While any of the three links is `null` the flyer:

- prints a dashed, labelled slot where that QR will go,
- is watermarked **DRAFT** with a red banner,
- and the script prints a warning.

### `android_url` is a redirect, and must stay one

It points at `info.syllabus-sync.app/astronomy-open-night/android`, **never** at
a GitHub release asset. The APK's tag changes with every build; a flyer does
not. The redirect lives in the info-site repo (`next.config.ts`), targets
`aonAndroidApkUrl`, and is deliberately **temporary (307)** so no browser or
scanner caches one build's asset URL. A test there asserts all three of those
properties, so the redirect and the constant cannot drift.

On a new APK build: publish the release, bump `aonAndroidApkUrl`, deploy. The
flyer already in people's hands keeps working and is **not** reprinted.

### There is no Google Play column

The app is not published on Google Play, so the flyer never says "Google Play",
carries no Play badge, and claims no Google trademark. The Android column is
labelled `ANDROID / Direct download (APK)`, and a line under the panel says
Android will ask permission to install — which is what actually happens. If the
app is ever published to Play, that is the moment to add the badge and the
trademark credit line back, not before.

## The App Store badge — official artwork only

The flyer **does not draw** the badge. Apple requires its own artwork,
unmodified, and offers it for download:

| Store | Get the artwork | Rules the layout meets |
|---|---|---|
| Apple | [App Store Marketing Tools](https://toolbox.marketingtools.apple.com/app-store/) | min **10 mm** high in print; clear space **¼ badge height**; one badge per layout; never modify, angle or recolour |

The slot is 12 mm high with ¼-height clear space, on the white panel. The badge
in `tools/marketing/badges/` came from Apple's own endpoint
(`.../api/v2/badges/download-on-the-app-store/black/en-us`) as SVG and was
rasterised with `rsvg-convert -h 600`; the aspect ratio is preserved to four
decimals (2.9917 against the source's 2.9916). The SVG sits beside the PNG so a
future re-render never has to trust the raster. It is Apple's artwork: re-render
it, never redraw or recolour it.

It is the only store badge on the flyer, so Apple's "place it first alongside
other stores" ordering rule does not apply here.

Copy rules also encoded: the app is "for iPhone and Android" — Apple asks that
you never say "iOS app" or "smartphone". The Apple trademark credit appears
once, in the footer. There is no Google credit line because nothing on the
flyer uses a Google mark.

## What is deliberately not on it

The Home-screen hero photograph (*A Deep Triangulum Galaxy*, Aleix Roig).
Rights sit with the photographer and print use is not covered — see
`docs/release/organiser-requests.md`. The artwork is the app's own icon.

## Verifying before print

```bash
python3 tools/marketing/build_app_flyer.py --preview
python3 tools/marketing/verify_flyer_qr.py
```

`verify_flyer_qr.py` is the gate on a print run. It renders **both** PDFs at
300 dpi, decodes every QR with zbar (the same class of decoder a phone camera
uses), and requires the decoded set to equal `flyer_links.json` exactly — no
missing code, no stray one, no typo. Then it follows each URL and reports what
it lands on, because a code that scans perfectly into a 404 is still a broken
flyer. It exits non-zero on any mismatch.

It also warns if a code falls under ~0.4 mm per module, the rough floor for
scanning at arm's length in the dark — which is the condition this flyer is
actually read in.

Needs `pypdfium2` and `pyzbar`, and `brew install zbar` for the decoder itself.

Last verified 2026-09-18: 3/3 codes decode at A4 (32.7/32.2/31.6 mm) and A5
(23.2/22.8/22.4 mm), all three resolve 200.

Source for the badge rules (checked 2026-09-04, still current 2026-09-18):
[Apple App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
