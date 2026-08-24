# Google Maps setup — keys, wiring, and Cloud console

Astronomy Open Night uses **Google Maps as the only navigation provider**.
Directions are **walking only** and **scoped to the Macquarie University
campus**. There is no provider chooser, no other travel mode, and no
OpenStreetMap. The illustrated campus map needs **no** key (it renders a bundled
asset); only Google **walking directions** need keys, and they degrade to a
clear "Google Maps is not configured yet" message — never a crash, never a fake
route — when the keys are absent.

## Two key families

| Purpose | Variable(s) | What it powers |
| --- | --- | --- |
| **Native Maps SDK** | `MAPS_API_KEY` | The interactive map: tiles, the destination marker, the drawn route polyline. |
| **Routes API** | `GOOGLE_MAPS_ANDROID_ROUTES_KEY`, `GOOGLE_MAPS_IOS_ROUTES_KEY` | The walking route itself — polyline geometry, distance, ETA (per platform). |

For **local testing a single Google Cloud key may fill all three** (as long as
it is unrestricted, or restricted to all the APIs/apps below). For
**production**, use per-platform restricted keys — Google allows only **one**
application-restriction type per key (Android SHA-1 *or* iOS bundle-ID, not
both), so a fully restricted setup needs separate Android and iOS keys.

## One-key wiring via `.env` (recommended for testing)

Put the key in the git-ignored `.env` (copy `.env.example`):

```
MAPS_API_KEY=AIza...
GOOGLE_MAPS_ANDROID_ROUTES_KEY=AIza...
GOOGLE_MAPS_IOS_ROUTES_KEY=AIza...
```

Then run/build with the file:

```
flutter run   --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
flutter build ios --release --dart-define-from-file=.env
```

What each consumer does with `MAPS_API_KEY`:

- **Dart** reads it via `--dart-define` (`nativeMapsApiKeyProvider`). Its presence
  flips `embeddedMapConfiguredProvider` → the Directions flow enables itself. No
  separate flag to set.
- **Android** — `android/app/build.gradle.kts` reads `MAPS_API_KEY` from
  `android/secrets.properties` if present, else falls back to the project-root
  `.env`, and substitutes it into `AndroidManifest.xml`'s
  `com.google.android.geo.API_KEY`. (Android's SDK reads the key from the
  manifest when a map view is built; it cannot be injected at runtime.)
- **iOS** — Dart hands the key to `AppDelegate` through the consent-gated
  `aon2026/maps_sdk` method channel; `initializeMapsSdk` calls
  `GMSServices.provideAPIKey` at consent time. It still falls back to the
  Info.plist `GMSApiKey` build setting if you prefer the old two-file setup.

### Alternative: keep the split (native files instead of `.env`)

- Android: create `android/secrets.properties` (from `.sample`) with
  `MAPS_API_KEY=…`.
- iOS: set the `MAPS_API_KEY` **build setting** (CI secret / xcconfig →
  Info.plist `GMSApiKey`).
- These win over `.env` when present.

## Web

`web/index.html` has a commented Maps JavaScript API `<script>` placeholder. The
web build does **not** read `MAPS_API_KEY` from `.env`; to show the Google map on
web, uncomment the tag with a **browser-restricted** key. Left commented (the
default), web ships without the interactive Google map. The embedded Google map
+ direct Routes calls are a **mobile-only** capability (`mapsNavPlatform` reports
`unsupported` on web/desktop), so on web the Directions flow shows the
"not configured" state by design.

## Google Cloud console — enable exactly these

- **Maps SDK for Android** — native map on Android.
- **Maps SDK for iOS** — native map on iOS.
- **Routes API** — the walking route (`directions/v2:computeRoutes`, `WALK`).
- *(Web only, optional)* **Maps JavaScript API** — only if you enable the web map.

Do **not** enable anything else. In particular the app does **not** use the
Places API, Directions API (legacy), Geocoding, or Roads API — leave them off.

## Recommended restrictions

**Application restrictions** (who may use the key):

- Android key → *Android apps*: package `au.edu.mq.astronomy.aon2026` + the
  signing SHA-1. The app sends its **live** signing cert as `X-Android-Cert`
  (see `MainActivity.signingCertSha1`), so the restricted key works for both
  debug and release once each SHA-1 is listed.
- iOS key → *iOS apps*: bundle id `au.edu.mq.astronomy.aon2026` (sent as
  `X-Ios-Bundle-Identifier`).
- Web key → *HTTP referrers*: the served origin(s).

**API restrictions** (what the key may call): restrict each key to only the APIs
it needs — Android key → Maps SDK for Android + Routes API; iOS key → Maps SDK
for iOS + Routes API; web key → Maps JavaScript API.

## Key rotation

1. Create the replacement key(s) in the same project with the same restrictions.
2. Update `.env` (or `secrets.properties` / the iOS build setting / CI secrets).
3. Rebuild and verify directions load on a device.
4. Delete the old key in the Cloud console **after** the new build is live.

Because the keys live only in git-ignored files / build secrets, rotation never
touches source control.

## Do not

- Do **not** commit a real key — to `.env`, `web/index.html`, `Info.plist`, the
  manifest, or `secrets.properties`. All key inputs are git-ignored or
  build-time secrets, and `.env` is listed in `.gitignore`.
- Do **not** add other travel modes or a provider chooser — walking only, Google
  only, campus only, by design.
