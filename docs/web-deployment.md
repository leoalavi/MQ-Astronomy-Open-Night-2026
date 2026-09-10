# Web deployment — Astronomy Open Night 2026

The web app is the **same Flutter app**, built for the web target. There is no
separate web project, no second copy of the event data, and no backend. This
document covers building, hosting, environment variables, SPA routing, and what
works offline.

> Native iOS/Android is unaffected by anything here. The web-specific code sits
> behind `kIsWeb` / conditional-import seams that already existed in the
> codebase; the mobile build compiles and runs exactly as before.

## Where this app lives

The app is served at the **root of its own dedicated subdomain**,
`aon.syllabus-sync.app`. The `syllabus-sync.app` domain is used **only as
hosting infrastructure** — Astronomy Open Night is an independent project (built
by Leo Alavi and Mohammad Raouf Abedini for the Astronomy Night – FSE Outreach
Team), **not** a Syllabus Sync product and not part of any "ecosystem". Nothing
about the hosting domain implies ownership or affiliation.

| Thing | URL | Served by |
| --- | --- | --- |
| Web app | `https://aon.syllabus-sync.app/` | this Flutter bundle |
| Canonical Privacy Policy | `https://aon.syllabus-sync.app/privacy` | this app's own `/privacy` route |
| Official event info / support | `https://event.mq.edu.au/astronomy-open-night/` | Macquarie University |

The privacy policy is the app's own `/privacy` page — the same address used for
the App Store and Google Play privacy fields. It is deliberately fine that the
privacy domain (`aon.syllabus-sync.app`) and the support domain
(`event.mq.edu.au`) differ; neither store requires them to match.

## Build

```bash
flutter build web --release \
  --dart-define-from-file=.env.web \
  --base-href / \
  --no-web-resources-cdn
```

- `--no-web-resources-cdn` serves CanvasKit/WASM from the app's own origin
  (`build/web/canvaskit/`) instead of `gstatic.com`, so the app makes no Google
  request just to render. (Persian glyphs are covered separately by the bundled
  Vazirmatn font — see `## Web fonts` below.)
- `--dart-define-from-file=.env.web` supplies `MAPS_API_KEY` (and, if used, the
  web-specific Routes key) at build time, with the **native route keys left
  empty** so they never enter the web bundle (see the security note below).
  **Without a key the app still works** — the illustrated campus basemap,
  programme, My Night, Passport, 360° tours and Info are offline/basemap
  features; only Google walking directions need the key, and they degrade to a
  truthful "map unavailable" state.
- `--base-href /` serves the app at the domain root.

Output is written to `build/web/`.

## SPA routing + the static Privacy Policy

The app uses `go_router` with real path URLs (`/program`, `/night`, `/map`,
`/info`, `/settings`, `/privacy`). Two rules are needed:

1. **`/privacy` serves the static `privacy.html`** — the canonical, JS-free
   Privacy Policy that a store reviewer or JS-disabled client can read without
   the Flutter runtime (`web/privacy.html`, generated from the in-app strings by
   `tool/privacy/gen_privacy_html.py`). This rule must come **before** the
   catch-all.
2. **Everything else rewrites to `index.html`** so refreshing/deep-linking any
   app route does not 404. (The in-app Settings → Privacy link still opens the
   Flutter privacy screen client-side; the *same* content, one source.)

**Vercel** (`vercel.json`):

```json
{
  "rewrites": [
    { "source": "/privacy", "destination": "/privacy.html" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Netlify** (`_redirects`):

```
/privacy   /privacy.html   200
/*         /index.html     200
```

**Nginx**:

```
location = /privacy { try_files /privacy.html =404; }
location /          { try_files $uri $uri/ /index.html; }
```

`build/web/privacy.html` is emitted automatically (Flutter copies `web/` into
the build). Verify: after `flutter build web`, `build/web/privacy.html` exists
and opens as plain readable HTML.

## Hosting

Serve the contents of `build/web/` as static files at the root of
`aon.syllabus-sync.app`, and add the catch-all rewrite above. Any static host
works (Vercel/Netlify/Cloudflare Pages/S3+CloudFront/Nginx); the Flutter bundle
is just static assets. Point the subdomain's DNS at that host and serve over
HTTPS only.

## Environment variables (names only — never commit values)

| Name | Purpose | Notes |
| --- | --- | --- |
| `MAPS_API_KEY` | Maps JavaScript API (embedded map) and, if no web-specific Routes key is set, the Routes API on web | Web keys are public in `main.dart.js` — **must** carry an HTTP-referrer restriction. See `docs/google-maps-setup.md`. |
| `GOOGLE_MAPS_WEB_ROUTES_KEY` | Optional web-only Routes key | If set, web uses it for Routes; otherwise `MAPS_API_KEY` serves both. |

Supply these via `.env` (git-ignored) consumed by `--dart-define-from-file`, or
via the CI secret store. **Do not** reuse the Android package or iOS bundle
restricted keys for web — application restrictions are mutually exclusive; the
web key is its own key with an HTTP-referrer restriction.

### Security: don't ship the native keys in the web bundle

`lib/services/maps_nav_providers.dart` reads `GOOGLE_MAPS_ANDROID_ROUTES_KEY`,
`GOOGLE_MAPS_IOS_ROUTES_KEY` and `GOOGLE_MAPS_WEB_ROUTES_KEY` via
`String.fromEnvironment`. dart2js therefore **embeds whatever those defines hold
at build time into `main.dart.js`** — even the native ones. So build the web
release with an env file whose **native route keys are empty**, e.g. a
`.env.web`:

```
APP_ENV=production
MAPS_API_KEY=<the web Maps JS key, HTTP-referrer restricted>
GOOGLE_MAPS_WEB_ROUTES_KEY=<the web Routes key, HTTP-referrer restricted>
GOOGLE_MAPS_ANDROID_ROUTES_KEY=
GOOGLE_MAPS_IOS_ROUTES_KEY=
```

```bash
flutter build web --release --dart-define-from-file=.env.web \
  --base-href /
```

This keeps the Android/iOS keys out of the web JS entirely. The web key(s) that
remain **will** be visible in `main.dart.js` — that is inherent to the Maps
JavaScript API — which is exactly why they must carry an HTTP-referrer
restriction (see `docs/google-maps-setup.md`). The repo's shared dev `.env`
(one unrestricted key in all four fields — release blocker **B3**) is for local
QA only and must never be the key a public web build ships.

## HTTPS only

Serve over HTTPS. Geolocation, the service worker, and (on iOS) add-to-home-
screen all require a secure context. Redirect HTTP → HTTPS at the host.

## Offline / PWA

> **Web is online-first, not offline-first.** Flutter 3.44 has **deprecated its
> service worker**: the emitted `flutter_service_worker.js` is a stub that
> **unregisters itself** on activation and precaches nothing. So the web build
> has **no service-worker offline cache**. (The *native* iOS/Android apps remain
> offline-first — their assets are bundled into the app.)

What this means in practice:

- **No forced bulk download.** Because nothing is precached, installing/opening
  the web app does **not** download the ~56 MB panorama library. A 360° tour's
  images are fetched only when that tour is opened. First load is the app shell
  (`main.dart.js` ≈ 4.3 MB + CanvasKit), not the whole 101 MB bundle.
- **Best-effort caching only.** Repeat visits reuse the browser's HTTP cache,
  but there is no guaranteed offline mode on the night. Treat web as needing a
  connection; point attendees who want reliable offline use to the native app.
- **What persists locally:** My Night, Passport stamps, favourites and settings
  are in `localStorage` and survive refresh/reopen (not cleared by cache).
- **Requires a connection:** the Google Maps embedded map and walking directions
  (by design — only after consent); **CanvasKit** (loaded from `gstatic.com`
  unless built with `--no-web-resources-cdn`); and **Persian glyphs** (Noto
  fonts fetched from `fonts.gstatic.com` — see `## Web fonts` note below).

Installation is **not** forced — the primary experience is a normal browser tab.
The manifest lets a visitor add it to the home screen, but without a functional
service worker an installed instance still needs the network.

## Web fonts and CanvasKit (external requests)

Two Google (`gstatic.com`) requests happen on the web build regardless of Maps
consent, and both should be closed before a privacy-sensitive public release:

1. **CanvasKit** loads from `https://www.gstatic.com/flutter-canvaskit/…` by
   default. Build with **`--no-web-resources-cdn`** to serve the copy already in
   `build/web/canvaskit/` locally instead.
2. **Persian text** has **no bundled font**; CanvasKit fetches Noto from
   `fonts.gstatic.com` at runtime, so Persian is **not available offline** and
   makes an uncovered Google request. Bundle an OFL Persian face (e.g.
   Vazirmatn) and set it as `fontFamilyFallback` to fix both.

Until (1) and (2) are done, the in-app claim that Google is only involved for
maps/after consent is **not strictly accurate for the web build**.

## Analytics

There are none, by design — no Google Analytics, no tracking pixels, no
telemetry. Do not add any without an explicit decision and a privacy-copy update.
