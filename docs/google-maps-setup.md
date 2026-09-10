# Google Maps setup — keys, wiring, and Cloud console

Astronomy Open Night uses **Google Maps as the only navigation provider**.
Directions are **walking only**. In production they are **scoped to the
Macquarie University campus**; a debug-only flag
(`--dart-define=AON_ALLOW_OFF_CAMPUS_TESTING=true`) lifts that scope so the flow
can be exercised from off campus during QA. The flag defaults to **false**, so a
release build keeps the campus rule and the branch is compiled out. There is no provider chooser, no other travel mode, and no
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

## iOS build — run `pod install` after pulling the Maps changes

The Google Maps / Routes work added **native CocoaPods** (`google_maps_flutter_ios`
and friends), so `ios/Podfile.lock` changed. A checkout whose `ios/Pods/` sandbox
predates that change fails the iOS build with:

```
error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' …
** BUILD FAILED **
```

Fix it once, then build normally:

```
cd ios && pod install
```

`flutter run` / `flutter build ios` run `pod install` for you; a bare `xcodebuild`
(or an IDE/simulator build that drives `xcodebuild` directly) does **not**, so run
it by hand in that path. `ios/Pods/` is git-ignored — nothing to commit; only
`Podfile.lock` is tracked, and it is already in sync on `main`.

> **CocoaPods `Encoding::CompatibilityError` (ASCII-8BIT).** If `pod install`
> crashes in `unicode_normalize` before doing anything, the shell has a non-UTF-8
> locale. Prefix the command:
>
> ```
> LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
> ```

## Web

There is deliberately **no** `<script src="maps.googleapis.com/maps/api/js?key=…">`
tag in `web/index.html`. That file is committed, so a key pasted there would
become a tracked secret. Instead the app injects the Maps JavaScript API at
runtime with the same `MAPS_API_KEY` every other platform resolves — see
`lib/services/maps_js_loader_web.dart` (single injection, success cached, 12 s
timeout, retry on failure).

Web is a **first-class** target: `MapsNavPlatform.web` renders a real embedded
map and calls the Routes API directly (its CORS preflight allows our headers —
see below), so no proxy or backend is required.

```
flutter run -d chrome --dart-define-from-file=.env
```

**Verified 2026-08-27 in Chrome:** embedded Google map renders in-app, WALK
polyline drawn, distance + ETA shown.

> A web key is public by nature — it ships in `main.dart.js`, which is
> unavoidable for the Maps JavaScript API — so a production web key **must**
> carry an HTTP-referrer restriction.

## Google Cloud console — enable exactly these

| API | Needed by | Status |
| --- | --- | --- |
| **Maps SDK for Android** | native map on Android | required |
| **Maps SDK for iOS** | native map on iOS | ✅ verified working (route rendered on simulator) |
| **Maps JavaScript API** | embedded map on **web** | ✅ verified working (map rendered in Chrome) |
| **Routes API** | the walking route, every platform | ✅ **verified working** |

Do **not** enable anything else. In particular the app does **not** use the
Places API, Directions API (legacy), Geocoding, or Roads API — leave them off.

### Device 401 from the Routes API — a STALE BAKED KEY, not a code bug

Field run (Pouya, 2026-08-28): the Routes API returned **HTTP 401** on a
physical iPhone while the same key returns **200** from a server-side probe AND
from the web build. Root cause is the **build**, not the request:

- The device was launched with `flutter run … lib/main.dart` **without**
  `--dart-define-from-file=.env` (visible in the run log). With no Dart defines,
  `GOOGLE_MAPS_IOS_ROUTES_KEY` and `MAPS_API_KEY` are empty, so the iOS Routes
  key falls back to the **native Info.plist `GMSApiKey`** — the same path the
  Maps SDK tiles use (which is why the tiles were blank too).
- `Info.plist` sets `GMSApiKey = $(MAPS_API_KEY)`, substituted at build time from
  `Secrets.xcconfig`. Xcode **caches** that substitution: after the key was
  rotated to the new MQ_NAVIGATION key, an incremental build can keep the OLD
  baked value even though `.env` and `Secrets.xcconfig` are current.

A differential probe of the CURRENT `.env` key confirms the code path is correct
— all of these return **200**, including the exact combination the iOS app sends:

```
key only ................................. 200
key + X-Ios-Bundle-Identifier (iOS app) .. 200   ← the header is NOT the problem
key + a wrong bundle id .................. 200   ← key is unrestricted
key + Referer (browser) .................. 200
```

**Fix on the device (operational, not code):**

1. Prefer building/running the device with the fresh key explicitly:
   ```
   flutter run --dart-define-from-file=.env -d <device>
   flutter build ios --release --dart-define-from-file=.env
   ```
   The Dart-define key then wins and no longer depends on the Info.plist cache.
2. If launching without the define (from Xcode/IDE), force a **clean** iOS build
   after any key change so the `$(MAPS_API_KEY)` substitution re-runs:
   ```
   flutter clean && cd ios && pod install && cd ..
   flutter build ios --release --dart-define-from-file=.env
   ```

**Confirming which key the device actually used:** the debug build now logs a
NON-SECRET fingerprint at route time —
`GoogleNavTrace: routes_key source=<…> len=<n> fp=<8-hex>`. If that `fp` differs
between a server probe of `.env` and the device run, the binary baked a stale
key. The fingerprint is one-way and never prints key material.

### Routes API — working (was previously blocked)

Live probes of `directions/v2:computeRoutes` with the project key return
**HTTP 200** with real WALK routes, both server-side and with a browser
`Referer`. Verified end to end on 2026-08-27: a walking route rendered inside
the app on the iOS simulator and in Chrome.

Historical note, kept because the error is deeply misleading: while the key was
not permitted to call Routes, the API returned

```
HTTP 401 UNAUTHENTICATED
"API keys are not supported by this API…"
```

That message does **not** mean API keys are unsupported — the Routes API accepts
them. It is what Google returns when the key/project cannot reach the service.
If it ever reappears, check the **key's API restrictions** include Routes API,
and that Routes API is enabled on the key's project — not the request format.

### Browser support (verified)

The Routes API **does** allow browser calls. Its CORS preflight from
`http://localhost:8080` returns:

```
access-control-allow-origin: http://localhost:8080
access-control-allow-methods: DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT
access-control-allow-headers: content-type,x-goog-api-key,x-goog-fieldmask
```

— exactly the headers `GoogleRoutesService` sends, so no proxy or backend is
required for the web build.

## Recommended restrictions

> **Do not ship one unrestricted key.** The single shared key in `.env` is fine
> for development and QA only.
>
> **Current state, measured 2026-09-07:** `.env` holds **one** key serving all
> three variables, and it is **unrestricted** — six live probes returned HTTP
> 200, including with no identity header and with a deliberately wrong app id,
> on both the iOS and the Android path. That is release blocker **B3**. Verify
> any change with `./tools/security/check_routes_key_restrictions.sh`, which
> prints status codes only and never echoes a key. Application restrictions are **mutually
> exclusive** — a key can be restricted to Android apps *or* iOS bundle IDs *or*
> HTTP referrers, never several — so a locked-down production setup needs **one
> key per platform**: an Android key, an iOS key, and a web key. Give each the
> API restrictions listed below. On web the key is inherently public (it ships in
> `main.dart.js`, which is unavoidable for the Maps JavaScript API), so the HTTP
> referrer restriction is the only thing protecting it.

**Application restrictions** (who may use the key):

- Android key → *Android apps*: package `au.edu.mq.astronomy.aon2026` + the
  signing SHA-1. The app sends its **live** signing cert as `X-Android-Cert`
  (see `MainActivity.signingCertSha1`), so the restricted key works for both
  debug and release once each SHA-1 is listed.

  **List EVERY SHA-1 that can sign an install — this is the one that bites.**
  `signingCertSha1()` reads `apkContentsSigners` at runtime, and **Play re-signs
  your AAB**, so:

  | Install route | Cert the app actually sends |
  |---|---|
  | Installed from Play (every real user) | the **Play App Signing** SHA-1 |
  | Locally built release APK / internal sideload | the **upload key** SHA-1 |
  | `flutter run` debug build | the **debug keystore** SHA-1 |

  Registering only the upload key **works on every build you test and fails for
  every real user** — the failure appears exactly once the app is live. Get the
  Play App Signing SHA-1 from Play Console → *Test and release* → *Setup* →
  *App signing*. The upload key's is
  `A4:26:BD:18:EF:21:BC:FD:05:FA:95:A2:D5:EF:C3:03:A5:CD:92:6D`
  (or re-read it with `keytool -list -v -keystore ~/Keys/aon2026/aon2026-upload.jks`).
- iOS key → *iOS apps*: bundle id `au.edu.mq.astronomy.aon2026` (sent as
  `X-Ios-Bundle-Identifier`).
- Web key → *HTTP referrers*: the served origin(s). Supply it as
  `GOOGLE_MAPS_WEB_ROUTES_KEY` (Routes) and `MAPS_API_KEY` (Maps JS); with only
  `MAPS_API_KEY` set, web uses it for both.

  **Header format trap (found 2026-09-07):** the Cloud console and `keytool`
  *display* the SHA-1 as `A4:26:BD:...`, but the `X-Android-Cert` **header must
  carry it without colons** (`A426BD...`). Verified live against the restricted
  key: colon form -> 403 PERMISSION_DENIED "Requests from this Android client
  application ... are blocked"; plain form -> 200. `MainActivity` now emits
  plain hex and `routes_client_identity.dart` normalises defensively. Paste the
  colon form into the **console** (it expects that); never into the header.

**API restrictions** (what the key may call): restrict each key to only the APIs
it needs — Android key → Maps SDK for Android + Routes API; iOS key → Maps SDK
for iOS + Routes API; web key → Maps JavaScript API **+ Routes API** (web calls
the Routes API directly for walking directions, so both are required).

### HTTP-referrer patterns for the web build

The web key's *Application restriction* → **HTTP referrers** must list every
origin the app is served from. The app runs at the root of its own subdomain,
`https://aon.syllabus-sync.app/`.

**Production referrers:**

```
https://aon.syllabus-sync.app/*
https://aon.syllabus-sync.app/
```

The `/*` pattern is what Google matches on (referrer patterns match the **page
origin**). Do **not** add `info.syllabus-sync.app/*`, `syllabus-sync.app/*` or
`sylla.syllabus-sync.app/*` — the app is not served from those origins. And do
**not** use `syllabussync.app/*` (wrong domain — the real one has a hyphen).

**Development only** (keep on a *separate* dev key, never the production key):

```
http://localhost:*
http://127.0.0.1:*
```

Never reuse the Android package or iOS bundle restriction for web — application
restrictions are mutually exclusive, so the web key is its own key.

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
