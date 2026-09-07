# App flyer — "Get the app"

The printed flyer that goes up around campus and into hands once the app is
on the App Store and Google Play. Same discipline as the passport station
signs: nothing on it is typed in twice, and it refuses to pretend a link
exists before it does.

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
| `AON2026-app-flyer-A5.pdf` | Handout size — the same layout scaled; both QRs verified to decode at A5 |
| `qr-app-store.png`, `qr-google-play.png` | The bare QRs, once the links exist |
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
  "app_store_url": null,
  "play_store_url": null,
  "web_url": null,
  "apple_badge_png": null,
  "google_badge_png": null
}
```

While either store link is `null` the flyer:

- prints a dashed, labelled slot where that QR will go,
- is watermarked **DRAFT** with a red "STORE LINKS NOT YET LIVE" banner,
- and the script prints a warning.

Fill in the real links (App Store Connect gives you the `apps.apple.com/…/id…`
URL; Google Play's is `https://play.google.com/store/apps/details?id=au.edu.mq.astronomy.aon2026`),
re-run, and the QRs appear and the watermark goes. The "search for Astronomy
Open Night in the App Store or on Google Play" line is there so the flyer still
works for someone who cannot scan.

## Store badges — official artwork only

The flyer **does not draw** the App Store or Google Play badges. Both stores
require their own artwork, unmodified, and both offer it as a download:

| Store | Get the artwork | Rules the layout already meets |
|---|---|---|
| Apple | [App Store Marketing Tools](https://toolbox.marketingtools.apple.com/app-store/) — badge, short link and an official **QR code** for your product page | min **10 mm** high in print; clear space **¼ badge height**; alongside other stores use the **black** badge and place it **first**; one badge per layout; never modify, angle or recolour |
| Google | [Google Play badge guidelines / Partner Marketing Hub](https://partnermarketinghub.withgoogle.com/brands/google-play/google-play/lockups-icons-badges/) | min **7.6 mm** high in print; clear space **¼ badge height**; must be the **same size or larger** than other store badges; solid, contrasting background |

Slots are 12 mm high (both minimums met), equal size (Google's "same or
larger"), App Store first (Apple's ordering), on the white panel with ¼-height
clear space. Download the PNGs, point `apple_badge_png` / `google_badge_png`
at them, re-run. Until then a dashed outline marks each slot so a proof can
never go out with a home-made badge.

Copy rules also encoded: the app is "for iPhone and Android" — Apple asks that
you never say "iOS app" or "smartphone". The two trademark credit lines appear
once, in the footer, as both guidelines require.

## What is deliberately not on it

The Home-screen hero photograph (*A Deep Triangulum Galaxy*, Aleix Roig).
Rights sit with the photographer and print use is not covered — see
`docs/release/organiser-requests.md`. The artwork is the app's own icon.

## Verifying before print

```bash
python3 tools/marketing/build_app_flyer.py --preview
```

then decode the PDFs (A4 **and** A5) — both QRs should return exactly the URLs
in `flyer_links.json`. The links-filled test proof decoded 2/2 at both sizes at
300 dpi.

Sources for the badge rules (checked 2026-09-04):
[Apple App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/) ·
[Google Play badge guidelines](https://partnermarketinghub.withgoogle.com/brands/google-play/google-play/lockups-icons-badges/)
