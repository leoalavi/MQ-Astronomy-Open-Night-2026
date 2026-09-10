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
  --base-href /
```

- `--dart-define-from-file=.env.web` supplies `MAPS_API_KEY` (and, if used, the
  web-specific Routes key) at build time, with the **native route keys left
  empty** so they never enter the web bundle (see the security note below).
  **Without a key the app still works** — the illustrated campus basemap,
  programme, My Night, Passport, 360° tours and Info are offline/basemap
  features; only Google walking directions need the key, and they degrade to a
  truthful "map unavailable" state.
- `--base-href /` serves the app at the domain root.

Output is written to `build/web/`.

## SPA routing — required for refresh & deep links

The app uses `go_router` with real path URLs (`/program`, `/night`, `/map`,
`/info`, `/settings`, `/privacy`). A static host must **rewrite unknown paths to
`index.html`** so that refreshing or opening a deep link does not 404:

**Vercel** (`vercel.json`):

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Netlify** (`_redirects`):

```
/*  /index.html  200
```

**Nginx**:

```
location / {
  try_files $uri $uri/ /index.html;
}
```

Because the app owns the whole `aon.syllabus-sync.app` origin, the catch-all
rewrite is safe — there are no other routes on this host to protect.

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

Flutter's web build emits a service worker (`flutter_service_worker.js`) and the
app is installable via `manifest.json`.

**Works offline once the app has loaded** (all bundled, no network):
- App shell, programme, My Night, Passport (manual codes), Info, campus basemap,
  and the 360° venue tours — every panorama image is bundled.
- My Night, Passport stamps, favourites and settings persist in the browser
  (localStorage) across refresh and reopen.

**Requires a connection:**
- Google Maps embedded map and walking directions (by design — the request goes
  to Google, and only after the visitor agrees).

Installation is **not** forced — the primary experience is a normal browser tab.
The manifest simply lets a visitor add it to the home screen if they want.

## Analytics

There are none, by design — no Google Analytics, no tracking pixels, no
telemetry. Do not add any without an explicit decision and a privacy-copy update.
