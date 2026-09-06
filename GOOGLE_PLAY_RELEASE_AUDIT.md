# Google Play Release Audit — Astronomy Open Night 2026 (`aon2026`)

**Date:** 2026-09-05 · **Publisher (confirmed by Leo Alavi):** Leo Alavi, personal
Google Play developer account · **Application ID:** `au.edu.mq.astronomy.aon2026`
(unchanged; it is the ID the Play App Signing bootstrap AAB was uploaded under)
· **Artefact audited:** `build/app/outputs/bundle/release/app-release.aab`,
`1.0.0 (3)` (the merged tree also carries Build 3 for iOS), built from the working tree described in *Changes Made*.

Every claim below names its evidence. Where something could not be verified in
this environment it says **UNVERIFIED** and why. Nothing here promises
acceptance — Play review is partly automated and partly human.

---

## Executive Summary

**CONDITIONALLY READY.**

The Android build is code-complete and passes every check that can be run
here: targetSdk 36, a signed release App Bundle, 16 KB-aligned native code, a
minimal merged manifest with no restricted permissions, no foreground services,
no exported components beyond the launcher activity, lint with zero errors, the
full Dart gate, and the core journeys driven on an Android 16 emulator.

Two things were **wrong** at the start of the day and are fixed in this tree:
the app's privacy copy and Data safety draft said "nothing is collected", which
the Google Maps SDK and ML Kit disclosures contradict (P0 consistency), and the
Android camera-denial path prompted the visitor twice in a row (P1 UX/policy).

What remains is **not code**: a public HTTPS Privacy Policy URL, the Play
Console forms (Data safety, content rating, app content), the feature graphic
and Android screenshots, and — because this is a **personal developer account
created after 13 November 2023** — the closed-test requirement (12 testers,
14 days) before production access.

## Release Risk

**MEDIUM** — driven by the Play Console side (Data safety answers must match
the SDK disclosures exactly; the closed-test gate; the hosted policy URL) and
by the same asset-rights question the iOS audit carries. Code risk is LOW.

---

## Environment

| Item | Value |
|---|---|
| Flutter / Dart | 3.47.1 stable / 3.13.1 |
| Java (Gradle) | Android Studio JBR, OpenJDK 21.0.10 (the shell default is Java 23 — set `JAVA_HOME` to the JBR) |
| Kotlin | 2.3.20 |
| Gradle / AGP | 9.1.0 / 8.12.1 (Flutter warns AGP < 9.0.1 will lose support soon — not a Play requirement) |
| Android SDK | compileSdk 36, build-tools 36.1.0, NDK 28.2.13676358 |
| compileSdk / targetSdk / minSdk | **36 / 36 / 24** (Flutter 3.47 defaults; read from the built APK badging) |
| versionName / versionCode | **1.0.0 / 3** (`pubspec.yaml` `1.0.0+3`, bumped upstream in `02720db`; the first AAB inspected today was build 2 — the final one is rebuilt at 3) |
| applicationId | `au.edu.mq.astronomy.aon2026` |
| Emulator | AVD `aon_api36`, Pixel 8, `system-images;android-36.1;google_apis_playstore;arm64-v8a`, Android 16 (API 36); `getconf PAGE_SIZE` = 4096 |
| Commit | `3a435f9` (main; re-verified 2026-09-06 19:30 after the mirrored-glass fix `65ebf45`, the QA-define change `c125067` and the screenshot recapture `e3faf49`) |

## Commands Actually Executed

```text
flutter doctor -v · flutter analyze · flutter test · ./scripts/check.sh (→ CHECK PASSED, 7/7, exit 0 on 46dc81e)
keytool -genkeypair (PKCS12, RSA 4096, alias aon2026-upload) → ~/Keys/aon2026/aon2026-upload.jks
flutter build appbundle --release      → app-release.aab (build 2: 128.5 MB inspected; final build 3: 129.0 MB)
flutter build apk --release            → app-release.apk (137.8 MB, for emulator install + static checks)
jarsigner -verify / keytool -printcert -jarfile (AAB) · apksigner verify --print-certs (APK)
unzip -l app-release.aab · llvm-readelf -l on all 21 .so · zipalign -c -P 16 -v 4 app-release.apk
aapt2 dump badging · apkanalyzer apk summary | manifest debuggable | apk download-size
cat build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
./gradlew :app:lintRelease
avdmanager create avd (aon_api36) · emulator · adb install -r · adb shell getconf PAGE_SIZE
~/.maestro/bin/maestro --device emulator-5554 test <flow> (11 flows, see Build Results)
WebFetch: Play target API page, personal-account testing page, Data safety page, ML Kit + Maps SDK disclosures, Android 16 behaviour changes, 16 KB page-size page
```

## Build Results

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | No issues | run on the final tree |
| `flutter test` / `./scripts/check.sh` | **CHECK PASSED 7/7, exit 0** on `46dc81e`, and again on the final tree before commit (see the commit series); targeted suites green after each fix | gate logs |
| Android lint (`lintRelease`) | **0 errors, 6 warnings** (`IconLauncherShape` ×5 on the legacy PNGs, `MonochromeLauncherIcon` ×1 — deliberate, see P3) | `build/app/reports/lint-results-release.xml` |
| Release AAB | **BUILT** (rebuilt from `3a435f9`, 2026-09-06 19:30) — `app-release.aab`, **1.0.0 (3)**, 129.0 MB, signed with the upload key (CN "Astronomy Open Night upload key", SHA-256 `33:21:F0:14:16:A2:3B:53:6C:81:E7:8C:CA:81:8D:DE:0D:1B:65:D6:01:2B:B9:A7:41:EA:73:28:E9:7B:88:2A`); adaptive icon resources present; all arm64-v8a / x86_64 libraries re-checked at ≥ 0x4000 after the final rebuild | `jarsigner`, `keytool -printcert -jarfile`, `unzip -l`, `llvm-readelf` |
| Release APK (install test) | Built, v2-signed with the same key, `debuggable=false`, installed and launched on the API 36 emulator | `apksigner`, `apkanalyzer`, `adb install` |
| 16 KB page size | **PASS (static)**: every arm64-v8a and x86_64 library has LOAD alignment ≥ 0x4000 (Flutter/Dart libs 0x10000, ML Kit/CameraX/datastore 0x4000); `zipalign -c -P 16 -v 4` → "Verification successful". The only 0x1000 library is `armeabi-v7a/libbarhopper_v3.so` (32-bit, exempt). **Runtime on a 16 KB device: NOT VERIFIED** — the installed API 36.1 image runs 4 KB pages | `llvm-readelf -l`, `zipalign` |
| Native ABIs | arm64-v8a, armeabi-v7a, x86_64 (7 `.so` each) — no accidental exclusion | `aapt2 dump badging` |
| Bundle inspection | package/version correct, `base/manifest`, one dex, `flutter_assets`, `extractNativeLibs=false`, no debug artefacts, no kernel blob (AOT) | `unzip -l`, merged manifest |
| Android E2E (Maestro CLI, Pixel 8 API 36) | **10/10 flows** (table below) | `.maestro/*.yaml` |
| iOS regression after the shared-code changes | **21/21 flows** on iPhone 17 Pro (iOS 26.5), rebuilt simulator app | Maestro CLI |

### Android E2E (release APK on the Android 16 emulator, Maestro CLI)

| Flow | Journey | Result |
|---|---|---|
| `first-launch` | J7 first launch — no onboarding, no permission dialog, tabs reachable, no intro-replay row | **PASS** |
| `home` | J1 identity, what's on, save from a card, map CTA | **PASS** |
| `program` | J1 Program → time/activity filters → activity details | **PASS** |
| `my-night` | J2/J3 save two → My Night → restart persistence → clash flag → remove → clear | **PASS** |
| `settings` | Appearance, EN↔FA flip (RTL), Delete-my-data dialog, Credits reachable past the tab bar | **PASS** |
| `passport` | J6/J10 Home → passport (zero-stamp hint) → scanner → camera prompt **in context** → "Don't allow" → "Camera unavailable" + "Open app settings" + manual entry → code → **stamp collected** | **PASS** |
| `map-basemap` | J4 official basemap, camera fit, zoom controls | **PASS** |
| `map-360-picker` | J5 360° picker, last card reachable, tour opens | **PASS** |
| `map-location` | J9 no prompt on Map entry; "Show my location" → Android dialog "While using the app" → follow; fresh session off-campus → honest "km from campus" banner | **PASS** |
| `android-back` | API 36 predictive back: detail route pops to Program; passport pops to Home; back on a modal dialog dismisses only the dialog | **PASS** |

10/10 on reruns. The emulator's own system process ANR'd twice during the
session on a memory-starved host (Gradle/Kotlin daemons + two iOS simulators);
those runs were discarded, not counted. The Maestro **MCP** session could not
drive the emulator after a reboot ("Unable to launch app" while `adb` launched
fine), so the CLI was used. Not covered on Android: live Google walking route
(needs the GCP key restriction — B3), real magnetometer (emulator has none),
TalkBack (not driven).

---

## Google Play Policy Matrix

Sources fetched 2026-09-05 (see Commands). Status: PASS / FAIL / N/A /
HUMAN ACTION REQUIRED.

| Policy | Applicable | Status | Evidence | Severity | Action |
|---|---|---|---|---|---|
| Target API level — new apps/updates must target Android 16 (API 36) from 31 Aug 2026 | Yes | **PASS** | badging `targetSdkVersion:'36'` | — | — |
| Android App Bundle required for new apps | Yes | **PASS** | `app-release.aab` built and signed | — | Upload the AAB, never the APK |
| Play App Signing | Yes | **HUMAN** | Upload key generated here; Play holds the app-signing key. The bootstrap AAB uploaded earlier used a different key — see Signing | P1 | Register this upload certificate (or reset the upload key) in Play Console before uploading |
| 16 KB page-size support (apps targeting 15+; hard cut-off for updates 1 Feb 2027) | Yes | **PASS (static)** | ELF + zipalign checks above | — | Optionally verify on a 16 KB device |
| Data safety — accurate, includes SDK data, form mandatory | Yes | **HUMAN** (answers prepared; **were wrong before today**) | Maps SDK + ML Kit disclosures; answers in *Data Safety* | P0 if wrong | Enter the answers below verbatim |
| Privacy policy — in Console **and** in-app, publicly accessible | Yes | **HUMAN** for the URL; **PASS** in-app | In-app: Settings → Privacy Policy opens the full text offline (`settingsPrivacyPolicyBody`); hosted copy `docs/release/android-privacy-policy.html` is ready but **not hosted** | P0 until hosted | Host the HTML at a stable HTTPS URL, paste it in Console, set `EventConfig.privacyPolicyUrl` |
| User Data — disclosure + consent for location sent to a third party | Yes | **PASS** | Explicit `MapsNavDisclosure` before any Google surface; revocable in Settings; `routes_consent_guard_test`, `privacy-consent` E2E | — | — |
| Permissions — minimal, contextual, no background location | Yes | **PASS** | Merged manifest: INTERNET, CAMERA, FINE/COARSE location, ACCESS_NETWORK_STATE only; location asked on first "Show my location" tap, camera on entering the scanner | — | — |
| Account creation / deletion | No | **N/A** | No accounts anywhere; "Delete my data" offered anyway | — | Answer "no account" in Console |
| Foreground services / FGS declarations | No | **PASS** | No `FOREGROUND_SERVICE*` permission; geolocator's bound service has its `foregroundServiceType` removed (`tools:remove`) and is never promoted | — | Nothing to declare |
| Exact alarms, full-screen intent, `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, `AD_ID`, `POST_NOTIFICATIONS`, media permissions | No | **PASS** | None in the merged manifest; `<queries>` lists only PROCESS_TEXT, https VIEW, CustomTabs, `com.google.android.apps.maps` | — | — |
| Package visibility | Yes | **PASS** | Specific `<queries>` only | — | — |
| Exported components | Yes | **PASS** | Only `MainActivity` (launcher) and androidx `ProfileInstallReceiver` (permission `DUMP`, framework-standard) are exported | — | — |
| Deep links / App Links | No | **PASS** | `flutter_deeplinking_enabled=false`; no VIEW intent filters on the activity | — | — |
| Network security / cleartext | Yes | **PASS** | `network_security_config.xml`: cleartext only for `localhost`/`127.0.0.1` (panorama loopback server); `android_cleartext_policy_test` | — | — |
| WebView | Yes | **PASS** | `flutter_inappwebview` loads exactly `http://localhost:8459/web/indoor_viewer.html`; every other main-frame navigation is cancelled (`isAllowedViewerUrl`); no JS interface exposed to remote content | — | — |
| Malware / dynamic code | Yes | **PASS** | No dynamic code loading, no downloads, no self-update; only Google SDK network paths | — | — |
| Device and Network Abuse (background work, wake locks) | Yes | **PASS** | GPS stream gated on Map/compass visibility; no WorkManager/Alarm of our own (the `datatransport` scheduler belongs to Google's SDKs) | — | — |
| Deceptive behaviour / metadata accuracy | Yes | **PASS** after today's copy fixes | Listing copy and in-app privacy text now state the Google SDK data flows | — | Keep listing and policy in step |
| Ads | No | **N/A** | No ad SDK, no `AD_ID` | — | Declare "No ads" |
| Families / target audience | Yes | **HUMAN** | General-audience public event; not child-directed | — | Choose 13+ / not designed for children |
| Content rating (IARC) | Yes | **HUMAN** | No objectionable content; WebView is not a browser | — | Answer the questionnaire (below) |
| Minimum functionality / not a web wrapper | Yes | **PASS** | Offline programme, illustrated map, compass, 360° tours, passport | — | — |
| Testing requirement for personal accounts created after 13 Nov 2023 | **Yes** (Leo confirmed) | **HUMAN ACTION REQUIRED** | 12 testers opted in continuously for 14 days, then apply for production access | P0 for production | Closed track first (below) |

---

## P0 Findings

| # | Finding | Status |
|---|---|---|
| P0-1 | **Data safety / privacy copy said "no data collected"** while the shipped Android build embeds Google Maps SDK (device metadata, IP, pseudonymous SDK id, crash traces, map interactions) and ML Kit barcode scanning (device/app info, per-installation identifiers, usage/performance diagnostics). Google's own disclosure pages list these; Play's definition of *collected* covers SDK traffic. A mismatch between the form and behaviour is a policy violation. | **FIXED in code and docs** (Leo's `46dc81e`: in-app summary + full policy text EN/FA, `android-privacy-policy.html`; this audit: `docs/release/play-store-listing.md` Data safety answers rewritten, README/ARCHITECTURE aligned). **HUMAN:** enter the answers in Console |
| P0-2 | **No hosted Privacy Policy URL.** Required for the Console form and the listing. | **HUMAN** — host `docs/release/android-privacy-policy.html` |
| P0-3 | **Production access on a personal account created after 13 Nov 2023** requires a 14-day closed test with 12 opted-in testers. | **HUMAN** — see Testing Track Requirement |

## P1 Findings

| # | Finding | Status |
|---|---|---|
| P1-1 | **Camera denial prompted twice on Android.** Declining the OS camera dialog puts the app through `inactive → resumed`; the scanner view restarted the camera on every `resumed`, and `MobileScannerController.start()` does **not** throw on a refusal (it parks the error in `controller.value`), so the "denied" state was never known and a second system prompt followed the first "Don't allow" immediately — which on Android 11+ also spends the ask-again allowance. Invisible on iOS (one prompt ever). Reproduced three times on the emulator (Maestro tap, then an adb-injected tap with `dumpsys package` showing `CAMERA: granted=false USER_SET` while the dialog was back on screen). | **FIXED** — `passport_scanner_view.dart`: a resume restarts the camera only when this view stopped it for the background (paused/hidden/detached) or the visitor returns from app Settings; no stop on `inactive`; refusal read from `controller.value.error`. Rule `shouldRestartScannerOnResume` pinned by 5 unit tests. **Re-verified:** after denial the screen shows "Camera unavailable — enter the code", "Open app settings" and "Enter a code"; permission flags `USER_SET`; no second dialog |
| P1-0 | **Every glass surface rendered a vertical MIRROR of its backdrop on Android** (tab bar, hero date pill, map island): `shaders/glass_refraction.frag` un-flipped the sampled Y coordinate under `IMPELLER_TARGET_OPENGLES`, but `FlutterFragCoord()` already normalises orientation per backend and the `ImageFilter.shader` backdrop is supplied in that same orientation, so Android's OpenGLES path (the emulator, and every device Impeller runs on GLES) was double-flipped. iOS (Metal) never defined the macro, so it never showed. Reported by Raouf 2026-09-06; confirmed by capture (a streak through the date pill, the top of the hero showing inside the bottom tab bar). | **FIXED** — the backend-specific flip is removed; before/after captures on the API 36 emulator show the correct backdrop through the glass. No change on Metal/Vulkan |
| P1-2 | **`INTERNET` permission was only in the debug/profile manifests.** Release builds merge only `src/main`, so a release build had no INTERNET permission and Google Routes/Maps could never work in production. | **FIXED** in `46dc81e` (declared in `src/main/AndroidManifest.xml`); merged release manifest verified |
| P1-3 | **Upload key.** No release keystore existed; a release build fails closed by design. | **FIXED** — upload keystore generated outside the repo (`~/Keys/aon2026/aon2026-upload.jks`, PKCS12, RSA-4096, 30 y), credentials in git-ignored `android/key.properties`. **HUMAN:** back it up; register the certificate in Play App Signing (the earlier bootstrap AAB was signed with a different key — request an upload-key reset if Play still expects that one) |
| P1-4 | Location prompt fired on merely opening the Map tab (Play/Apple both want contextual requests). | **FIXED** in `46dc81e` — Map entry only restores an existing grant; the OS dialog appears on the first "Show my location" tap, compass entry or directions request. Docs/tests/flows reconciled by this audit |
| P1-5 | Leo's commit also downgraded the **iOS** project file/scheme (`objectVersion 60→54`, `LastUpgradeCheck 2660→1510`, custom prepare script) — the configuration that uploaded TestFlight Build 1. | **REVERTED** to `bfe383d` in this tree |

## P2 Findings

| # | Finding | Status |
|---|---|---|
| P2-1 | No adaptive launcher icon: only legacy PNGs, so Android 8+ launchers masked the square artwork onto a white plate; lint `IconLauncherShape`. | **FIXED** — `mipmap-anydpi-v26/ic_launcher.xml` (foreground = the approved artwork at 108dp per density, background `#05070F`, no monochrome layer on purpose); `app_icon_assets_test` extended |
| P2-2 | `drawable-v21/launch_background.xml` (`?android:colorBackground`) shadowed the dark splash on every device ≥ API 21, so the white flash fixed for iOS this morning was still there on Android. | **FIXED** in `46dc81e` (file removed; the dark `drawable/launch_background.xml` now applies everywhere) |
| P2-3 | Three Maestro flows (`my-night`, `settings`, `map-*` via `open-map`) tapped a tab by point right after a cold start/restart and missed on Android's slower boot. | **FIXED** — cold-boot wait + swipe, label taps after restarts |
| P2-4 | Play listing doc named MQ as publisher and an `@mq.edu.au` contact. | **FIXED** — publisher Leo Alavi, contact `leo@leoalavi.dev`, policy pointer to the Android HTML |
| P2-6 | After the switch to tap-initiated location (`46dc81e`), the Map's locate control read **"Location unavailable"** on a fresh install before any prompt: `restoreGrantedLocation` stored the passive `checkPermission` answer, and geolocator reports `denied` for a never-asked install (iOS maps not-determined to denied; Android has no not-determined). Seen on the Android 16 emulator with location unset. | **FIXED** — `location_providers.dart`: a passive check adopts only `granted` (activate) or `serviceOff` (a nameable reason); `denied`/`deniedForever` are learned from the explicit tap. Tests updated + one added (`location_controller_test.dart`) |
| P2-5 | Android screenshots and the 1024×500 feature graphic did not exist. | **Screenshots DONE** (`e3faf49`: six 1080×2160 captures, release APK, Android 16). **Feature graphic still HUMAN** — do not build it from the hero photo (rights) |

## P3 Findings

| # | Finding | Status |
|---|---|---|
| P3-1 | `MonochromeLauncherIcon` lint warning. A monochrome layer needs a purpose-drawn silhouette; the full-bleed artwork would render as a solid tile under themed icons. | Left as-is, documented in the icon XML and pinned by test |
| P3-2 | AAB is 128 MB (59 MB of bundled panoramas + basemap × 3 ABIs). Per-device download ≈ 95 MB (`apkanalyzer download-size` of the fat APK). Under Play's limits; no asset packs needed for a one-night event app. | Note only |
| P3-3 | Flutter warns AGP 8.12.1 will lose Flutter support "soon" (wants ≥ 9.0.1). Not a Play requirement; do not upgrade the day before release. | Deferred |
| P3-4 | No R8 minification is enabled (Flutter default; Dart is AOT). Java/Kotlin plugin code ships unshrunk. Enabling R8 would need keep-rule verification for Maps/ML Kit — not worth the risk before the event. | Deferred |
| P3-5 | Runtime 16 KB verification needs a 16 KB emulator image or a Pixel 8+/9 on Android 15+. | UNVERIFIED (static checks pass) |

---

## Changes Made (this audit, on top of `46dc81e`)

| File | Change |
|---|---|
| `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | Reverted to `bfe383d` (the Build 1 configuration) |
| `lib/widgets/passport_scanner_view.dart` | `shouldRestartScannerOnResume`: a resume restarts only what this view stopped for the background (or on return from Settings); no stop on `inactive`; refusal read from `controller.value` |
| `lib/services/location_providers.dart`, `test/unit/location_controller_test.dart` | Passive Map-entry check adopts only `granted`/`serviceOff` (P2-6) |
| `shaders/glass_refraction.frag` | Backend-specific Y un-flip removed (P1-0, mirrored glass on Android GLES) |
| `test/unit/scanner_resume_policy_test.dart` | NEW — pins the rule (4 tests) |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `values/ic_launcher_background.xml`, `mipmap-*/ic_launcher_foreground.png` | NEW adaptive icon |
| `test/unit/app_icon_assets_test.dart` | Adaptive icon sizes + declaration asserted |
| `.maestro/map-location.yaml` | Rewritten for the tap-initiated permission (no prompt on Map entry) |
| `.maestro/passport.yaml` | Cross-platform dialog regex `Don.t allow` |
| `.maestro/android-back.yaml` | NEW — predictive back at three depths |
| `.maestro/flows/open-map.yaml`, `.maestro/program.yaml`, `.maestro/my-night.yaml`, `.maestro/settings.yaml`, `.maestro/settings-persistence.yaml` | Cold-boot guard; tab taps by label; centred scroll before "Delete"; the Google Maps licences step is iOS-only (Android surfaces Play-services licences in system Settings — `MainActivity.kt`) |
| `docs/release/play-store-listing.md` | Data safety answers rewritten to the SDK disclosures; publisher/contact corrected |
| `docs/release/app-review-notes.md`, `docs/onboarding-decision.md`, `APPLE_RELEASE_AUDIT.md`, `ARCHITECTURE.md`, `CLAUDE.md` | Location-prompt wording updated to the contextual model; Android facts recorded |
| `GOOGLE_PLAY_RELEASE_AUDIT.md` | This report |

Not in Git, by design: `~/Keys/aon2026/aon2026-upload.jks`, `android/key.properties`.

---

## Onboarding Decision

**NOT IMPLEMENTED — deliberately** (same decision as the Apple audit,
`docs/onboarding-decision.md`). First launch opens on Home; the tab labels,
Home cards, venue sheets and the Map mode toggle answer the first-time
questions; the one comprehension gap (what the passport is) is a single
zero-stamp sentence on the passport screen (EN + FA). Verified on Android 16:
`first-launch.yaml` — no dialog, no permission prompt, every tab one tap away,
no intro-replay row in Settings. Permissions: location only on the first
"Show my location" tap / compass / directions; camera only on entering the
scanner; no notifications, photos, Bluetooth, microphone or contacts.

## Permissions (final merged release manifest)

| Permission | Declared by | Why | When asked |
|---|---|---|---|
| `INTERNET` | app (`src/main`) | Google Routes request, Maps SDK tiles, ML Kit diagnostics | install-time (normal) |
| `CAMERA` | app | QR scanning for the passport (`uses-feature camera required=false`) | on entering the scanner |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | app | "You are here" dot, compass, route origin | on the first "Show my location" tap / compass / directions |
| `ACCESS_NETWORK_STATE` | Maps SDK (merged) | SDK connectivity checks | install-time (normal) |
| `au.edu.mq.astronomy.aon2026.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | androidx | signature-level guard for the app's own dynamic receivers | — |

Absent and verified absent: `ACCESS_BACKGROUND_LOCATION`, `POST_NOTIFICATIONS`,
`FOREGROUND_SERVICE*`, `READ_MEDIA_*`, `READ/WRITE_EXTERNAL_STORAGE`,
`MANAGE_EXTERNAL_STORAGE`, `RECORD_AUDIO`, `BLUETOOTH*`, contacts, calendar,
`QUERY_ALL_PACKAGES`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
`SYSTEM_ALERT_WINDOW`, `REQUEST_INSTALL_PACKAGES`, `AD_ID`.

## Data Safety (recommended answers — enter verbatim)

Full reasoning and the per-type table: `docs/release/play-store-listing.md`
§"Data safety form". Summary:

- **Collects or shares data: Yes.**
- **Location → Precise** and **Approximate**: collected, shared with Google,
  ephemeral, optional (consent + OS permission), purpose *App functionality*
  (route origin to Google Routes; Maps SDK IP-derived location).
- **App info and performance → Crash logs, Diagnostics**: collected, not
  shared, required, purpose *Analytics* (Maps SDK crash traces; ML Kit + Maps
  performance metrics).
- **App activity → App interactions**: collected, not shared, optional, purpose
  *Analytics* (Maps SDK pan/zoom events once a Google map is shown).
- **Device or other IDs**: collected, not shared, required, purpose
  *Analytics* (ML Kit per-installation/diagnostic identifiers; Maps SDK
  pseudonymous SDK identifier).
- Everything else: **not collected**.
- **Encrypted in transit: Yes.** **Deletion:** on-device data yes (Settings →
  Delete my data); SDK-held data is Google's — the in-app policy says so.

Four-way consistency (code ↔ SDK disclosures ↔ in-app/hosted policy ↔ these
answers): aligned as of this tree; `privacy_copy_truth_test.dart` guards the
in-app copy.

## Privacy Policy

- **In-app:** Settings → Privacy Policy opens the full text offline (dialog),
  EN + FA; it names the publisher (Leo Alavi), contact, data flows, retention,
  deletion and the Google links. Once `EventConfig.privacyPolicyUrl` is set the
  row opens the hosted page instead.
- **Hosted:** `docs/release/android-privacy-policy.html` — same text, ready to
  host. **Not yet at a public URL (HUMAN).**
- The older MQ-publisher draft in `docs/release/mq-hosted-pages.md` is marked
  *not approved for Android* (its "nothing collected" claim is false for this build).

## Account Deletion

**NOT APPLICABLE** — no accounts, no sign-in, no server. "Delete my data"
(Settings) clears all on-device data; verified across a restart by the
`settings-persistence` flow on iOS and `settings`/`android-back` on Android.

## Security

- Secrets: none tracked (`git check-ignore` on `.env`, `key.properties`,
  `secrets.properties`, `*.jks`; only `.sample` files in history). The Maps
  Android key is substituted into the manifest at build time from `.env` —
  **it must be restricted in GCP to this package + the Play app-signing
  certificate SHA-1(s)**, otherwise every real user's map fails (B3).
- Transport: HTTPS only; cleartext confined to loopback by the network
  security config; no TLS overrides, no custom trust managers.
- WebView: bundled files over `localhost:8459` only; navigation allow-list is
  an exact scheme/host/port/path match; no `addJavascriptInterface` to remote
  content.
- Untrusted input: QR payload matched against nine fixed codes.
- Backup: `allowBackup` left at the default (true). The stored data is
  non-sensitive preferences/stamps; the privacy copy discloses that Android
  backups may include it. No `dataExtractionRules` needed.
- Logging: all `debugPrint` gated on `kDebugMode`; nothing logs coordinates,
  QR payloads or keys.
- Signing: release fails closed without the upload key; debug key never used.

## Google Play Store Listing

- **Name:** Astronomy Open Night
- **Short description (80):** "The official guide to Macquarie University's
  Astronomy Open Night. Works offline" — **check with the organisers whether
  "official" is acceptable from a personal account**; safer: "Your guide to
  Macquarie University's Astronomy Open Night. Works offline."
- **Full description:** reuse `docs/release/app-store-listing.md` verbatim;
  replace the PRIVACY paragraph's "No analytics… No tracking" with: "No
  account, no sign-in, no advertising. Your stamps, favourites and plan stay on
  your phone. Walking directions use Google Maps only after you agree; Google
  Maps and the QR scanner report technical diagnostics to Google — see the
  Privacy Policy."
- **Category:** Applications → Education (tags: education, maps & navigation, events)
- **Graphics:** 512 px icon exists (`docs/release/play-graphics/icon-512.png`);
  feature graphic **TODO**; phone screenshots **TODO** — capture Program, My
  Night, Map, a 360° tour, Passport on the AVD (ratio ≤ 2:1).

## App Content Answers

| Section | Answer |
|---|---|
| Privacy policy | hosted URL (HUMAN) |
| Ads | **No** |
| App access | All functionality available without credentials; note the nine passport codes for testers (as in the App Review notes) |
| Target audience | 13+ (not designed for children) |
| Content rating | IARC: no violence/sex/profanity/drugs/gambling; no user interaction; no location sharing between users; WebView is not a browser → expected PEGI 3 / Everyone / G |
| Data safety | as above |
| Government app | No |
| Financial features | None |
| Health | No |
| News | No |
| Permissions declarations | None triggered (no sensitive/restricted permissions) |
| Foreground service declarations | None |

## Testing Track Requirement

**APPLICABLE** — Leo confirmed a personal account created after 13 November
2023 with production access not yet approved. Google's rule (fetched today):
at least **12 testers opted in continuously for 14 days** on a closed test,
then apply for production access from the Console dashboard (review usually
≤ 7 days). Plan: upload this AAB to a **closed** track now, invite the
organisers/volunteers as testers, keep them opted in for the full 14 days, then
apply. The event is 19 September — start the closed test immediately.

## Human Actions Required

1. Back up `~/Keys/aon2026/aon2026-upload.jks` and `android/key.properties`
   somewhere safe; register the upload certificate (SHA-256 above) in Play App
   Signing, or request an upload-key reset if Play still expects the earlier
   bootstrap key.
2. Host `docs/release/android-privacy-policy.html` at a stable public HTTPS
   URL; paste it in Console; set `EventConfig.privacyPolicyUrl`.
3. Complete Data safety with the answers above; complete content rating, ads,
   app access, target audience.
4. Restrict the Android Maps key in GCP to the package + signing certificates;
   enable the Routes API (B3).
5. Capture Android screenshots and a feature graphic (not from the hero photo).
6. Upload the AAB to a closed track; run the 14-day / 12-tester period; apply
   for production access.
7. Written redistribution rights for the map artwork, buildings dataset, 360°
   photographs and the hero image (B6 — same as iOS).

---

# FINAL GOOGLE PLAY RELEASE GATE

- [x] Full repository audited
- [x] Current Google Play policies verified (target API, AAB, Data safety, testing requirement, 16 KB, Android 16 behaviour — fetched 2026-09-05)
- [x] targetSdk meets current submission requirement (36)
- [x] Android 16/API 36 behaviour audited (edge-to-edge insets via Flutter SafeArea; predictive back via Flutter's OnBackInvoked path — `android-back.yaml`; no `screenOrientation` restriction beyond portrait on phones)
- [x] Edge-to-edge tested (tab bar, settings last row, scanner keyboard on the emulator)
- [x] Predictive back tested (`android-back.yaml`)
- [x] 16 KB page-size compatibility audited (static PASS; runtime UNVERIFIED)
- [x] Flutter dependencies audited (same set as the iOS audit; Android natives: Flutter, ML Kit barcode, CameraX, datastore, dartjni)
- [x] Gradle dependencies audited (AGP 8.12.1, Gradle 9.1, Kotlin 2.3.20, Java 17 target)
- [x] Third-party SDKs audited (Maps SDK, ML Kit — disclosures incorporated)
- [x] Final merged manifest audited
- [x] Permissions minimised
- [x] Camera permission contextual
- [x] Location permission contextual
- [x] Notification permission contextual (N/A — none)
- [x] No unnecessary background location
- [x] No unjustified restricted permissions
- [x] Foreground services audited (none)
- [x] Exported components audited
- [x] Deep links audited (none)
- [x] Network security audited
- [x] Privacy policy reviewed (hosting pending)
- [x] Data safety answers prepared
- [x] Data safety matches actual implementation
- [x] Account deletion audited (N/A)
- [x] Security audit passed
- [x] Secrets audit passed
- [x] Production logging reviewed
- [x] Onboarding explicitly evaluated (not implemented, documented)
- [x] Program / My Night / Map / Directions / 360° / Passport / QR / permission denial / offline behaviour tested (Android E2E table + iOS suite; live route needs GCP keys — B3)
- [x] Accessibility audited (semantics tests; large fonts verified on iPad at 2.0×; TalkBack **not** driven here — UNVERIFIED)
- [x] Localisation + Persian RTL audited (402 EN/FA keys, RTL flows)
- [x] flutter analyze / flutter test passed
- [x] Integration tests passed where available
- [x] Android lint: 0 errors
- [x] Release AAB built, inspected, signing verified, package ID and versionCode verified
- [x] Store listing / screenshots / content rating / target audience / ads reviewed
- [x] App access instructions prepared
- [x] Play App Signing reviewed (HUMAN step remains)
- [x] Testing-track requirement checked (APPLICABLE)
- [ ] No known P0 blockers — **P0-2 (hosted policy URL) and P0-3 (closed-test gate) are human actions**
- [x] No unresolved P1 rejection risks in code

# RELEASE DECISION

## DO NOT SUBMIT — to production, yet.

The bundle is ready for the **closed testing track today**. Production
submission is blocked by exactly these non-code items: (1) a public HTTPS
Privacy Policy URL in Console and in `EventConfig.privacyPolicyUrl`; (2) the
Data safety form entered as above; (3) the upload certificate registered with
Play App Signing; (4) the 14-day / 12-tester closed test and production-access
approval; (5) asset redistribution rights (B6). Once those are done, the same
AAB (or a rebuild at the next build number) is the production candidate.
