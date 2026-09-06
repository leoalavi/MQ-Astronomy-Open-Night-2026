# Apple App Store Release Audit — Astronomy Open Night 2026 (`aon2026`)

**Date:** 2026-09-05 · **Auditor:** Claude (release/App Review/security/privacy/UX/a11y/QA pass)
**Baseline:** `main` @ `689c259` (after Leo's "Redesign program filters" and the README refresh) + this audit's
uncommitted working tree · **Bundle:** `au.edu.mq.astronomy.aon2026` · **Version:** `1.0.0 (1)` — TestFlight Build 1 uploaded 2026-09-05; the bump to build 2 is made on the commit that is archived

Every claim below names its evidence. Where something could not be verified in
this environment it says **UNVERIFIED** and why.

---

## Executive Summary

**CONDITIONALLY READY.**

The *code and binary* have no known P0 and no unresolved P1 that is under the
repository's control. Two P1s found today were fixed and re-verified (privacy
manifest, review-notes contradiction). The remaining blockers are **not code**:
they are the same four people/infrastructure items already tracked in
`docs/release-blockers.md` (B3 GCP keys, B4 physical-device pass, B6 asset
redistribution rights, B7 hosted Privacy/Support URLs). Signing is **not** a
blocker: TestFlight Build 1 was archived and uploaded from Xcode on 2026-09-05
(Team "Leo Alavi", bundle `au.edu.mq.astronomy.aon2026`). The CLI archive
attempt in *this* audit environment failed only because this macOS user's Xcode
is signed into a different, individual team (see Signing reconciliation).

## Acceptance Risk

**MEDIUM** — driven entirely by items outside the code: the publisher account
(a university-branded app must be submitted from Macquarie's account or with
written authority, guidelines 4.1 / 5.2.1), the unresolved asset rights (5.2),
and the not-yet-hosted Privacy Policy URL (5.1.1(i)). With those closed, the
residual risk is LOW.

## Onboarding Decision

**NOT IMPLEMENTED — deliberately.** Full reasoning: `docs/onboarding-decision.md`.

A newcomer's seven questions ("what is this / what's on / where is the map /
how do I save / what is 360° / what is the passport / how do I collect stamps")
are answered by the Home hero, the tab labels, the Home map card, the venue
sheets ("Directions", "Look inside in 360°"), the Map mode toggle
(Map / 360° / Compass) and the My Night empty state. The one genuine gap — the
passport screen never said the codes are on QR signs at the venues — was fixed
**in place** with a single zero-stamp sentence (`passportHowItWorks`, EN + FA)
that disappears after the first stamp. That reaches the visitor at the exact
moment they need it, instead of on a slide three hours earlier. An intro
carousel would restate the tab bar and cost every visitor a tap while walking
across a dark campus. Guarded by `test/widget/first_launch_test.dart` (fails if
any first-launch gate is ever added) and `.maestro/first-launch.yaml`.

Permissions are contextual: location only on the first "Show my location"
tap, compass entry or a directions request — entering the Map tab restores an
existing grant without a dialog (`46dc81e`, 2026-09-05, after this audit's
first pass) — camera only on entering the QR scanner, motion only in compass
mode. No notifications, photo
library, or ATT are used. Verified on the simulator (`passport.yaml`: the camera
alert appears only after "Scan or enter a code", denial degrades to "Camera
unavailable — enter the code" with manual entry working).

## Environment

| Item | Value |
|---|---|
| macOS | 26.6.2 (25G83), arm64 |
| Xcode | 26.6 (17F113), SDK iOS 26.5 — satisfies the Xcode 26 / iOS 26 SDK minimum in force since 28 Apr 2026 |
| Flutter / Dart | 3.47.1 stable / 3.13.1 (`flutter doctor`: no issues) |
| CocoaPods | 1.17.0 (Ruby 4.0.6 — `pod install` needs `LANG=en_US.UTF-8`) |
| Simulators used | iPhone 17 Pro (iOS 26.5), iPad Pro 13-inch M5 (iOS 26.5) |
| Signing (this audit's shell) | Xcode on this macOS user is signed into team `3L5A4R7JNY` (individual) with one "Apple Development" identity; the repo's team is `94273WB4G3`. That is why the CLI archive failed here. Build 1 was uploaded from a Mac/user signed into team 94273WB4G3 ("Leo Alavi") — archive Build 2 there, unchanged |

## Commands Executed

```text
flutter doctor -v · flutter analyze · flutter gen-l10n · flutter test (1667 passed)
./scripts/check.sh   (twice: before and after merging origin/main ea63063) → CHECK PASSED, exit 0, 7/7
flutter build ios --release --no-codesign   → ✓ build/ios/iphoneos/Runner.app (100 MB)
flutter build ios --simulator --debug       → ✓ (installed on iPhone 17 Pro + iPad Pro 13)
flutter build ipa --release                 → ✗ in THIS shell only: its Xcode user is not signed into team 94273WB4G3 (Build 1 was uploaded from a correctly signed-in Xcode) — see Signing reconciliation
pod install (LANG=en_US.UTF-8)
PlistBuddy / plutil / lipo / strings / find on the built Runner.app
maestro (MCP) — 21 flows, 435 commands on iPhone 17 Pro → all passed
xcrun simctl ui … appearance light / content_size accessibility-extra-extra-extra-large (iPad) + simctl io screenshot
git fetch / git pull --ff-only (ea63063) with the audit changes stashed and re-applied — no conflicts
```

## Test Results

| Suite | Result | Evidence |
|---|---|---|
| `flutter analyze` | **No issues found** | run before and after the upstream merge |
| `flutter test` | **1667 passed, 0 failed** | `06:32 +1667: All tests passed!` |
| `./scripts/check.sh` (pub get, analyze, asset provenance, l10n EN+FA, tests+coverage, coverage policy, reskin tests) | **CHECK PASSED, exit 0, 7/7** | coverage **91.13%** (floor 90.4%) |
| Maestro E2E — iPhone 17 Pro | **21/21 flows, 435 commands** | first-launch, passport, home, program, my-night, info, settings, settings-persistence, map-basemap, map-markers, map-search-favorites, map-location, map-modes, map-wayfinding, map-360-picker, map-solar-walk, my-night-open-all-night, privacy-consent, privacy-consent-fa, privacy-revoke-retry, changes-verify |
| iPad Pro 13 layout | Home renders the multi-column layout, tab bar, passport card | `simctl io screenshot` (dark; and light-appearance at accessibility XXXL text — the app clamps at 2.0× and nothing overflows) |
| Physical device | **UNVERIFIED by this audit** — a wireless iPhone (iOS 26.6.1) is visible to `flutter doctor`, but this shell's Xcode user cannot sign for team 94273WB4G3; run the B4 pass from TestFlight Build 2 | B4 stays open |

New tests added: `test/widget/first_launch_test.dart` (3), and the privacy
manifest test now asserts the exact required-reason declarations.

## Apple Compliance Matrix

Guideline text re-read from developer.apple.com on 2026-09-05; the
Upcoming-Requirements page confirmed the Xcode 26 / iOS 26 SDK minimum
(28 Apr 2026), the age-rating questionnaire (31 Jan 2026) and required-reason
API enforcement (1 May 2024). Apple's privacy-manifest reference pages render
client-side and could not be fetched as text; the reason codes 35F9.1 / C617.1
were confirmed through secondary sources and the official code list.

| Guideline | Applicable | Status | Evidence | Risk | Action |
|---|---|---|---|---|---|
| 1.1–1.5 Safety (objectionable content, UGC, kids, physical harm) | Yes | PASS | No UGC, no chat, no medical/financial content; night-walking copy is advisory ("Walking directions are a guide, not a survey") | Low | — |
| 2.1(a) App completeness — crashes, placeholders, demo access | Yes | PASS | 1667 tests + 21 E2E flows; no `TODO/FIXME/HACK` in `lib/`, `ios/`, `android/`; no account; passport reviewable with the nine live codes listed in review notes | Low | Fill `<NAME/EMAIL/PHONE>` in review notes |
| 2.3.1(a) No hidden/dormant features; notes for review specific | Yes | PASS (fixed today) | Review notes no longer claim codes "do not exist yet"; passport enabled in release; preview switches are visible in Settings | Low | — |
| 2.3.3 Screenshots show the app in use | Yes | PASS (existing) | `docs/release/screenshots/` — unretouched simulator captures, 6 iPhone 6.9" + 4 iPad 13" | Low | Re-capture if Home copy changes (Leo's Good-to-know wording changed today) |
| 2.3.6 / 2.3.8 Age rating honest, 4+ metadata | Yes | PASS | Recommended answers below | Low | Answer questionnaire in ASC |
| 2.4.1 iPad compatibility | Yes | PASS | `UIDeviceFamily 1,2`; iPad Home verified by screenshot; all four iPad orientations allowed | Low | — |
| 2.5.1 Public APIs; runs on current OS | Yes | PASS | Flutter 3.47.1 / iOS 26.5 SDK; min iOS 15.0; arm64 only | Low | — |
| 2.5.4 Background modes | Yes | PASS | `UIBackgroundModes` absent (verified in built plist); GPS gated on Map visibility | Low | — |
| 2.5.14 / 5.1.1 Camera & location purpose strings accurate | Yes | PASS | Built plist strings quoted in Info.plist audit below; `ios_location_purpose_test.dart` | Low | — |
| 4.1 Copycats / impersonation | Yes | **RISK — external** | App is MQ-branded with an `au.edu.mq` bundle id; must ship from MQ's account or with written authority | Medium | Organisers (`docs/release/organiser-requests.md` §4) |
| 4.2 Minimum functionality (not a web wrapper) | Yes | PASS | Offline programme, illustrated map, 360° tours, compass, passport; the only WebView loads bundled files over `localhost` | Low | — |
| 4.8 Sign in with Apple | No | N/A | No third-party login, no accounts | — | — |
| 5.1.1(i) Privacy policy in ASC **and in-app** | Yes | **BLOCKED — external (B7)** | In-app row exists (`_PrivacyPolicyCard`) and activates when `EventConfig.privacyPolicyUrl` is set; hosted copy ready in `docs/release/mq-hosted-pages.md` | High until hosted | MQ hosts the page; set the URL; run `settings_privacy_policy_test.dart` |
| 5.1.1(ii) Consent for data collection; withdrawable | Yes | PASS | Explicit `MapsNavDisclosure` before any Google surface; Settings revoke; verified E2E (privacy-consent, privacy-revoke-retry) | Low | — |
| 5.1.1(iii) Data minimisation | Yes | PASS | Only camera/location/motion; no photos, contacts, mic, ATT | Low | — |
| 5.1.1(iv) Respect denial, offer alternatives | Yes | PASS | Location denied → map still works; camera denied → manual code entry (E2E `passport.yaml`) | Low | — |
| 5.1.1(v) Account deletion | No | N/A | No accounts; "Delete my data" offered anyway | — | — |
| 5.1.2(i) Third-party sharing disclosed, ATT | Yes | PASS | Location → Google Routes only after explicit consent; no tracking (manifest `NSPrivacyTracking=false`) | Low | Confirm ASC "Data Not Collected" vs the location-to-Google classification (B7 item 10, legal review) |
| 5.2.1 / 5.2.2 IP and third-party content | Yes | **OPEN — external (B6)** | Campus map artwork, buildings.json, 360° photos, hero photo: rights not yet confirmed in writing | High | Organisers (`organiser-requests.md` §1) |
| 5.3 Gaming/contests | No | N/A | Passport has no prizes of chance, no leaderboard | — | — |
| Privacy manifest / required-reason APIs (since 1 May 2024) | Yes | PASS (fixed today) | App manifest now declares SystemBootTime 35F9.1 + FileTimestamp C617.1; all 10 plugin manifests present in the built bundle | Low | — |
| Export compliance | Yes | PASS | `ITSAppUsesNonExemptEncryption=false`, working in `docs/release/export-compliance.md` (no new networked dependency since) | Low | — |
| Accessibility Nutrition Labels | Optional today | RECOMMENDED | VoiceOver semantics, 2.0× Dynamic Type, Reduce Motion all implemented and tested | — | Claim in ASC |

## P0 Findings

None in the repository. (Externally blocking, already registered: B6 asset
rights, B7 hosted privacy/support URLs, publisher account.)

## P1 Findings

| # | Finding | Status |
|---|---|---|
| P1-1 | **Privacy manifest under-declared required-reason APIs.** Flutter 3.47 links SwiftPM plugins statically into Runner. `sensors_plus 7.1.0` calls `ProcessInfo.systemUptime` and `package_info_plus 10.2.1` calls `fileModificationDate`, and both ship an *empty* `NSPrivacyAccessedAPITypes`, so App Store Connect attributes the calls to "Runner" with no reason → ITMS-91053 upload risk. | **FIXED** — app manifest declares SystemBootTime 35F9.1 and FileTimestamp C617.1 with the evidence inline; `ios_privacy_manifest_test.dart` asserts the exact list; verified present in the built `Runner.app/PrivacyInfo.xcprivacy` |
| P1-2 | **Review notes contradicted themselves** ("the final QR codes do not exist yet" beside "these are the live codes"), a 2.3.1 specificity problem. | **FIXED** — rewritten; a FIRST LAUNCH paragraph added (no onboarding, no launch prompt) |
| P1-3 | ~~Signed archive cannot be run here~~ **Withdrawn (2026-09-05, corrected by Raouf).** TestFlight Build 1 was archived and uploaded from Xcode with team 94273WB4G3 / bundle `au.edu.mq.astronomy.aon2026`. The CLI failure came from this audit shell's Xcode user being signed into a different individual team (`3L5A4R7JNY`). Repo signing config verified unchanged and consistent with the successful upload. | **NOT A BLOCKER** — archive Build 2 on the same Mac/account that uploaded Build 1; App Store Connect validation runs as part of that upload |

## P2 Findings

| # | Finding | Status |
|---|---|---|
| P2-1 | Launch screen was Flutter's white default while the app opens dark by default → white flash on every cold start at a night event | **FIXED** — `LaunchScreen.storyboard` background = `AonPalette.dark.surfaceBase` (#05070F); Android `launch_background.xml` matched; observed on the iPad simulator |
| P2-2 | Build number `1.0.0+1` consumed by a Play upload **and** by TestFlight Build 1 | **DEFERRED by decision** — `pubspec.yaml` stays `1.0.0+1` in this working tree; set `1.0.0+2` on the commit that is archived as Build 2 (the release build inspected below was produced with +2 to prove the plumbing: `CFBundleVersion 2`) |
| P2-3 | Hosted privacy-policy draft listed "text-size preferences" (not stored) and omitted the haptics preference; support page still said the passport "opens on event night" | **FIXED** in `docs/release/mq-hosted-pages.md` |
| P2-4 | Passport screen gave no explanation of what a stamp is or where codes come from (the only first-launch comprehension gap found) | **FIXED** — `passportHowItWorks` (EN + real FA), shown at zero stamps |
| P2-5 | Two pre-existing Maestro flows (`info`, `settings-persistence`) failed on by-point tab taps after a bare restart (stale pre-restart tree); `program.yaml` still tapped the old "6–8pm" chip removed by Leo's filter redesign | **FIXED** — flows hardened (label taps after restart, cold-boot swipe, scroll timeout); documented in `.maestro/README.md` §7 |

## P3 Findings

| # | Finding | Status |
|---|---|---|
| P3-1 | Two `debugPrint` calls not gated on `kDebugMode` (non-sensitive error paths) | **FIXED** |
| P3-2 | `EventFeatures.scan/stamps` comments claimed to hide the passport; neither flag is read anywhere | **FIXED** — comments now state they are unused/reserved |
| P3-3 | Stale "five tabs" comments in `app_router.dart` / `app_shell.dart` | **FIXED** |
| P3-4 | `WayfindingScreen` (`Routes.wayfinding`, 600 lines) is registered but unreachable from any UI | Left as-is (dead route, not a hidden feature — it cannot be reached); candidate for removal after the event |
| P3-5 | `package_info_plus` is linked into the iOS binary via `geolocator_linux` although the app never calls it | Left as-is (declared in the manifest); pruning would mean forking geolocator's dependency graph |
| P3-6 | Location was requested on first entry to the Map tab rather than on the first "Locate me" tap | **Changed 2026-09-05 (`46dc81e`)** — the Map tab now only restores an existing grant; the dialog appears on the first "Show my location" tap, compass entry or directions request |
| P3-7 | `dart format` drift (251 files, 3.12 tall style) | Left as-is by repo policy (informational, never a gate) |

## Changes Made

| File | Change |
|---|---|
| `ios/Runner/PrivacyInfo.xcprivacy` | Declares SystemBootTime 35F9.1 + FileTimestamp C617.1 with per-plugin evidence |
| `test/unit/ios_privacy_manifest_test.dart` | Asserts the exact declared list; forbids UserDefaults/DiskSpace/ActiveKeyboards |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | Dark launch background (#05070F) |
| `android/app/src/main/res/drawable/launch_background.xml` | Same colour for parity |
| `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb` (+ regenerated `lib/l10n/generated/*`) | `passportHowItWorks` |
| `lib/screens/passport_screen.dart` | Zero-stamp explanation line (keyed `passport-how-it-works`) |
| `lib/config/event_config.dart` | Truthful comments on the unused `scan`/`stamps` flags |
| `lib/services/building_providers.dart`, `lib/widgets/glass_shader.dart` | `kDebugMode`-gated logging |
| `lib/app/router/app_router.dart`, `lib/widgets/app_shell.dart` | "six tabs" |
| `test/widget/first_launch_test.dart` | NEW — no-onboarding tripwire + passport hint (EN/FA) |
| `.maestro/first-launch.yaml`, `.maestro/passport.yaml` | NEW — Journeys 5, 6, 8 on device |
| `.maestro/info.yaml`, `.maestro/settings-persistence.yaml`, `.maestro/program.yaml`, `.maestro/README.md` | Hardened flows; restart trap documented |
| `docs/onboarding-decision.md` | NEW — the decision and its evidence table |
| `docs/release/app-review-notes.md` | Contradiction removed; FIRST LAUNCH paragraph |
| `docs/release/mq-hosted-pages.md` | Stored-data list corrected; passport FAQ updated |
| `docs/release/app-store-submission-checklist.md` | Manifest row re-audited; version row DONE |
| `docs/release-blockers.md` | 2026-09-05 change-log entry |
| `ARCHITECTURE.md` | §10.2 permission timing corrected, §10.2a manifest, §10.2b no-onboarding, §11 logging, R10 resolved, §17 pointers |

Machine-local churn deliberately **not** kept: `pubspec.lock` (intl 0.20.3
bump) and `ios/Podfile.lock` (Flutter pod checksum) were restored with
`git checkout --`.

## Privacy

- **What leaves the device:** only a Google Routes `computeRoutes` POST
  (origin + destination) after the explicit in-app disclosure is accepted; the
  Google Maps SDK's own tile/config traffic once keyed (also consent-gated —
  `mapsSdkReadyProvider` is the single enforcement point, `AppDelegate` never
  keys the SDK at launch). Verified: the only `https://` host compiled into the
  Dart AOT binary is `routes.googleapis.com`.
- **Stored locally:** passport stamps, favourites, saved plan, maps consent,
  theme/language/motion/haptics preferences (`shared_preferences`). "Delete my
  data" clears session-then-storage and was E2E-verified across a restart.
- **Info.plist (built, quoted):** camera — "Used only to scan the QR code on a
  venue sign for your Astronomy Passport…never stored or sent anywhere";
  location — "…Your location is sent to Google only when you choose walking
  directions"; motion — "…never leaves your device". No photo-library,
  microphone, always-location, local-network, tracking, background-mode, URL
  scheme or ATS-exception keys.
- **Privacy manifest:** no collected data, no tracking, two required-reason
  declarations (above). Present in the bundle for the app and all ten plugins.
- **Contradiction check (code ↔ manifest ↔ policy ↔ labels):** none remaining.
  The only judgement call left for legal is how ASC's "App Privacy" should
  classify the consented location→Google request (B7 item 10).

## Signing reconciliation (2026-09-05, after Raouf's correction)

| Fact | Value | Source |
|---|---|---|
| Repo `DEVELOPMENT_TEAM` (Runner, all configs) | `94273WB4G3` | `ios/Runner.xcodeproj/project.pbxproj` lines 483/609/669 |
| Repo `CODE_SIGN_STYLE` | `Automatic` (Runner + RunnerTests) | pbxproj |
| Repo bundle id | `au.edu.mq.astronomy.aon2026` | pbxproj + built `Info.plist` |
| Entitlements / capabilities | none (no `.entitlements` file, no `CODE_SIGN_ENTITLEMENTS`) | pbxproj |
| TestFlight Build 1 | archived + "Uploaded to Apple" from Xcode, Team "Leo Alavi", same bundle id, 1.0.0 (1) | Raouf, 2026-09-05 |
| This audit shell's Xcode user | signed into team `3L5A4R7JNY` (individual, "Mohammad Raouf Abedini"); one `Apple Development` identity; only a wildcard `3L5A4R7JNY.*` profile; no archives since 2025-10-03 | `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`, `security find-identity`, `~/Library/Developer/Xcode/UserData/Provisioning Profiles`, `~/Library/Developer/Xcode/Archives` |

**Why the CLI said "No Account for Team 94273WB4G3":** `flutter build ipa`
runs `xcodebuild -allowProvisioningUpdates`, which can only use the Apple IDs
signed into Xcode *for the macOS user running it*. That user here is signed into
`3L5A4R7JNY`, not `94273WB4G3`, so automatic signing for the repo's team could
not resolve and no profile for the bundle id existed to fall back on. Build 1
succeeded from an Xcode session that *is* signed into team 94273WB4G3 (Leo's).
Nothing in the repository was wrong; nothing was changed. **Build 2 should be
archived from exactly that Xcode/account, with the pbxproj untouched.**
Pre-archive check: in Xcode → Runner → Signing & Capabilities, Team must read
"Leo Alavi (94273WB4G3)", bundle `au.edu.mq.astronomy.aon2026`, Automatic.

## Security

- No secrets tracked: `.env`, `ios/Flutter/Secrets.xcconfig`,
  `android/secrets.properties`, `key.properties` are git-ignored (verified with
  `git check-ignore`); only `.sample` files and an obvious test fixture key
  pattern are in history.
- The Maps SDK key is embedded in the built `Info.plist` (39 chars) — expected
  for Google Maps, and must stay **restricted to this bundle id** in GCP (B3).
- Transport: HTTPS only, platform TLS; no ATS exceptions. Android cleartext is
  loopback-only (test-guarded).
- WebView: `flutter_inappwebview` loads exactly `http://localhost:8459/web/indoor_viewer.html`
  from bundled assets; `shouldOverrideUrlLoading` cancels every other main-frame
  navigation (`isAllowedViewerUrl` is an exact scheme/host/port/path match).
  JavaScript is enabled (Pannellum needs it); no remote content, no file access.
- Untrusted input: the QR payload is matched against a fixed nine-station list,
  never executed or rendered as HTML.
- Logging: four `debugPrint` sites, all `kDebugMode`-gated.
- Binary residue: no dev/staging URLs (the "…Staging" strings in `Runner` are
  Google Maps SDK enum symbols).

## App Store Connect Checklist

- [x] Built with Xcode 26.6 / iOS 26.5 SDK (required since 28 Apr 2026)
- [ ] Version 1.0.0, build 2 — set `1.0.0+2` on the archive commit (Build 1 is on TestFlight)
- [x] App icon: 19 slots, 1024×1024 marketing icon, no alpha, custom artwork
- [x] Launch screen: storyboard, dark, no text
- [x] Privacy manifest bundled and accurate; required-reason APIs declared
- [x] Purpose strings for camera, location (When In Use), motion
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] No background modes, no ATT, no push
- [x] Portrait-only on iPhone; all orientations on iPad; iPad screenshots exist
- [x] Review notes drafted (`docs/release/app-review-notes.md`) — **fill in the contact name/email/phone**
- [ ] **Privacy Policy URL** (B7) — host `docs/release/mq-hosted-pages.md` page 1, then set `EventConfig.privacyPolicyUrl`
- [ ] **Support URL** (B7) — page 2
- [ ] App Privacy questionnaire — answers below
- [ ] Age rating questionnaire — answers below
- [ ] Archive Build 2 from the same Xcode/account that uploaded Build 1 (team 94273WB4G3); ASC validates on upload
- [ ] Written redistribution permission for the map artwork, buildings dataset, 360° photos and hero photograph (B6)
- [ ] Optional: Accessibility Nutrition Labels (VoiceOver, Larger Text, Reduced Motion)

## Recommended Privacy Answers (App Privacy "nutrition label")

Start from **"Data Not Collected"** for every category: no account, no
analytics, no advertising, no identifiers, no crash reporting; everything the
app stores stays on the device and is not linked to a person.

**One item needs a legal decision (B7 item 10):** when the visitor accepts the
walking-directions disclosure, their coarse/precise location is sent to Google
Routes and Google receives the request. Apple's definition of "collected"
covers data "transmitted off the device in a way that allows you and/or your
third-party partners to access it". If counsel decides this counts, declare
**Location → Precise Location → App Functionality → Not linked to identity →
Not used for tracking**. The app-side disclosure and consent are already in
place either way. Do not answer this one by default.

## Recommended Age Rating Answers

Every question **None / No**: no violence, sexual content, profanity,
alcohol/tobacco/drugs, gambling or contests, horror, mature themes, medical
information; **unrestricted web access: No** (the only web view shows bundled
files over `localhost`); no user-generated content, no messaging, no location
shared with other users, no in-app purchases, no advertising, no loot boxes.
Expected rating: **4+**.

## Export Compliance

`ITSAppUsesNonExemptEncryption = false` — the app and every linked library use
only OS-provided TLS for standard HTTPS transport (Google Routes, Google Maps
SDK); nothing bundles or implements its own cryptography. The working, per
dependency, is in `docs/release/export-compliance.md`; the dependency set has
not gained a networked package since that audit. Answer "No" to the
non-exempt-encryption question in ASC; no CCATS/ERN needed.

## Reviewer Notes

Paste `docs/release/app-review-notes.md` → "Notes for Review". It now states:
no account; **no onboarding and no launch-time permission prompt**; how to
review the passport with the nine live codes via manual entry (and the
`AON2026:` QR prefix); that location is requested on first entry to the Map tab
and is optional; that Google Maps is consent-gated and the app is otherwise
offline; that the 360° tours are bundled files over `localhost`; VoiceOver /
Dynamic Type 200% / Reduce Motion support. Replace `<NAME>/<EMAIL>/<PHONE>`.

## Known Limitations

1. **Archive and App Store validation were not run by this audit** — the shell
   it ran in belongs to a macOS user whose Xcode is signed into an individual
   team, not `94273WB4G3`. This is an environment fact, not a project defect:
   TestFlight Build 1 uploaded fine from Xcode on 2026-09-05. The unsigned
   release build succeeded here and its bundle was inspected instead.
2. **Physical-device behaviour UNVERIFIED** (B4): GPS accuracy, magnetometer
   heading, live Google route rendering, real camera QR scan. Simulator only.
3. **Live walking routes** need the GCP Routes API enabled and bundle-restricted
   keys (B3); the app degrades honestly ("Walking route is temporarily
   unavailable") — verified E2E.
4. **Passport signage** must be the PDF generated by
   `tools/passport/build_station_qr.py`; the app accepts those nine codes only (B5).
5. `lib/data/` programme copy is English-only under the Persian UI (R12) — an
   organiser translation decision, not a defect; the UI chrome is fully bilingual.
6. Maestro's iPad device session drove a phone-shaped screen; iPad evidence is
   from `simctl io screenshot`, not from a Maestro flow.
7. Apple's privacy-manifest reference pages could not be fetched as text
   (client-rendered); reason-code meanings were cross-checked via the official
   code list quoted in secondary sources.

---

# FINAL RELEASE GATE

- [x] Full repository audited
- [x] Current Apple rules verified (App Review Guidelines, Upcoming Requirements — 2026-09-05)
- [x] First-launch UX reviewed
- [x] Onboarding explicitly evaluated
- [x] Onboarding implemented only if justified (it was not — documented)
- [x] Onboarding is maximum 2–3 screens if present (N/A)
- [x] Onboarding has Skip (N/A)
- [x] Onboarding has Get Started (N/A)
- [x] Onboarding appears only on first launch (N/A)
- [x] Onboarding can be replayed from Settings (N/A)
- [x] No Location permission requested during onboarding / at launch (E2E `first-launch.yaml`)
- [x] No Camera permission requested during onboarding / at launch (E2E `passport.yaml`)
- [x] Camera requested contextually for QR scanning (E2E)
- [x] Location requested contextually (first "Show my location" tap / compass / directions; Map entry never prompts; E2E `map-location.yaml`)
- [x] Program tested (E2E + widget)
- [x] My Night tested (E2E + widget)
- [x] Map tested (E2E, 7 flows)
- [x] Directions tested (E2E `map-wayfinding`, consent decline path; live route UNVERIFIED — B3)
- [x] 360° views tested (E2E `map-360-picker`, `map-solar-walk`)
- [x] Astronomy Passport tested (E2E `passport.yaml` + widget)
- [x] QR stamp collection tested (manual code path E2E; camera decode simulator-limited)
- [x] flutter analyze passed
- [x] Flutter tests passed (1667)
- [x] integration tests passed where available (21/21 Maestro)
- [x] release iOS build passed (unsigned)
- [x] archive passed where environment permits — Build 1 archived + uploaded from Xcode 2026-09-05 (Raouf); not reproducible from this audit shell (different Xcode user/team)
- [x] App Store validation passed where environment permits — Build 1 accepted by App Store Connect ("Uploaded to Apple")
- [x] privacy manifest passed (declared + present in bundle)
- [x] Required Reason API audit passed
- [x] third-party SDK audit passed (10 plugins, all with manifests; no SDK on Apple's manifest-required list)
- [x] Info.plist audit passed (built plist inspected)
- [x] entitlement audit passed (no entitlements file, none needed; no capabilities beyond defaults)
- [x] privacy labels match implementation (recommended answers above; one legal classification flagged)
- [x] privacy policy matches implementation (draft corrected; hosting pending — B7)
- [x] accessibility reviewed (semantics, 2.0× text, reduce motion, tap targets — existing tests + XXXL screenshot)
- [x] localisation reviewed (402 EN/FA keys, parity + placeholder tests; FA E2E)
- [x] RTL reviewed (Persian mirrored tab bar, hero, cards verified on device)
- [x] metadata reviewed (`docs/release/app-store-listing.md`)
- [x] screenshots reviewed (existing captures are real; re-capture Home if desired after today's copy change)
- [x] age rating reviewed
- [x] export compliance reviewed
- [x] reviewer instructions prepared
- [x] no known P0 blockers **in code**
- [ ] no unresolved P1 rejection risks — **none in code; B6/B7 are external and gate App Review, not TestFlight**

# RELEASE DECISION

**DO NOT SUBMIT — yet.** The build is code-complete and passes every check
that can be run here, but submission is blocked by items no repository change
can close:

1. Host the Privacy Policy and Support pages on `mq.edu.au` and set
   `EventConfig.privacyPolicyUrl` (B7; guideline 5.1.1(i)).
2. Obtain written redistribution permission for the campus map artwork, the
   buildings dataset, the 360° photographs and the hero photograph (B6; 5.2).
3. Publisher identity: Build 1 shipped to TestFlight from team `94273WB4G3`
   ("Leo Alavi"). For the *public* listing of a University-branded app under an
   `au.edu.mq` bundle id, hold written authority from Macquarie to publish on
   its behalf, or transfer to the University's account (4.1 / 5.2.1). TestFlight
   internal testing is not affected.
4. Decide the App Privacy classification of the consented location→Google
   request with legal (B7 item 10), then complete the App Privacy and age-rating
   questionnaires.

Once those four are done, re-run `./scripts/check.sh` and the Maestro suite on
the submission commit and submit; the expected outcome is **APP STORE SUBMISSION
RECOMMENDED** with LOW residual risk.
