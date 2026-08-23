# Google Maps API key — where it goes

Turn-by-turn **walking navigation** (the in-app Google map on the wayfinding /
"Get directions" screens) uses the Google Maps SDK. The **illustrated campus
map** does *not* need a key — it renders a bundled asset — so the app is fully
usable without any key. Navigation degrades gracefully to a clear
"map unavailable / configuration required" state when the key is missing; it
never crashes.

There is **one** secret, `MAPS_API_KEY`, wired into three places. Nothing else
needs to change when the key arrives.

## 1. Android

- **File:** `android/secrets.properties` (git-ignored; copy from
  `android/secrets.properties.sample`).
- **Set:** `MAPS_API_KEY=AIza...`
- Flow: `android/app/build.gradle.kts` reads it and defaults to `""` when the
  file is absent → `AndroidManifest.xml`'s `com.google.android.geo.API_KEY`
  placeholder → the app ships "dark" (no Google map) rather than failing.

## 2. iOS

- **Where:** the `MAPS_API_KEY` **build setting** (CI secret / xcconfig), which
  substitutes into `ios/Runner/Info.plist` → `GMSApiKey` (`$(MAPS_API_KEY)`).
- Flow: `ios/Runner/AppDelegate.swift` reads `GMSApiKey`; an empty/missing value
  makes `initializeMapsSdk()` return `false` and the feature stays dark.

## 3. Web

- **File:** `web/index.html`. Uncomment the placeholder `<script>` tag and
  replace `YOUR_WEB_MAPS_API_KEY` with a **browser-restricted** Maps JavaScript
  API key. Left commented (the default), web ships without Google Maps and the
  illustrated basemap still works.

## Key restrictions (recommended)

- Android key: restrict to the app's package name + SHA-1.
- iOS key: restrict to the bundle id.
- Web key: restrict to the served HTTP referrer(s).
- Enable: **Maps SDK for Android/iOS**, **Maps JavaScript API** (web), and
  **Routes API** (used by the walking-route service).

## Do not

- Do **not** commit a real key to `web/index.html`, `Info.plist`, the manifest,
  or `secrets.properties`. All key inputs are git-ignored or build-time secrets.
