# Changelog — Astronomy Open Night 2026 (`aon2026`)

Human-readable release log. Entries are newest first and use the `Raouf:`
template (date in Australia/Sydney, scope, summary, files, verification,
follow-ups). Commit-level history lives in `git log`; the architecture is in
`ARCHITECTURE.md`; open release prerequisites in `docs/release-blockers.md`.

---

## Raouf: 2026-09-05 — Google Play release audit → signed AAB, closed-test candidate

**Scope:** Android release readiness on top of Leo's `46dc81e` (privacy
disclosures, contextual location, scanner UX). Publisher confirmed as Leo
Alavi's personal Play account.

**Summary**
- `GOOGLE_PLAY_RELEASE_AUDIT.md`: verdict CONDITIONALLY READY — code and
  bundle pass every local check; production is gated on the hosted Privacy
  Policy URL, the Data safety form, Play App Signing registration of the new
  upload key, the 14-day/12-tester closed test (personal account created after
  13 Nov 2023) and the asset rights.
- **Reverted** the iOS project/scheme downgrade that rode along in `46dc81e`
  (`objectVersion 60→54`, `LastUpgradeCheck 2660→1510`, custom prepare script)
  back to the Build 1 configuration.
- **Liquid-glass surfaces were a vertical mirror on Android** (P1, reported by
  Raouf 2026-09-06): the refraction shader un-flipped Y under
  `IMPELLER_TARGET_OPENGLES`, double-flipping the backdrop that
  `FlutterFragCoord()` already orients correctly. Flip removed; verified by
  before/after captures on the API 36 emulator; iOS (Metal) unaffected.
- **Camera denial re-prompted on Android** (P1): the OS dialog's own
  `inactive → resumed` restarted the scanner, and `MobileScannerController.start()`
  does not throw on refusal. The view now restarts only what it stopped for the
  background (or on return from app Settings); refusal is read from
  `controller.value`. `shouldRestartScannerOnResume` + 5 unit tests.
- Locate control read "Location unavailable" on a fresh install after the
  contextual-location change: a passive `checkPermission` answer of `denied`
  (which also means "never asked") was being stored on Map entry. Only
  `granted`/`serviceOff` are adopted now; a refusal is learned from the tap.
- Adaptive launcher icon (`mipmap-anydpi-v26`, dark background, no monochrome
  layer); `app_icon_assets_test` extended.
- Upload keystore generated outside the repo; `android/key.properties`
  (ignored) wired; `flutter build appbundle --release` → signed AAB, final
  artefact `1.0.0 (3)` (build 2 was inspected first; the tree merged to
  `1.0.0+3` before commit).
- Play listing doc: Data safety answers rewritten to the Maps SDK / ML Kit
  disclosures; publisher/contact corrected.
- Maestro: `android-back.yaml` (predictive back); cold-boot/restart guards in
  `open-map`, `program`, `my-night`, `settings`; `map-location` rewritten for
  the tap-initiated permission; cross-platform dialog regex in `passport`.
- Docs reconciled to the contextual-location model (review notes,
  ARCHITECTURE, onboarding decision, Apple audit, CLAUDE.md).
- The passport's "Reset passport" action is now behind an explicit per-run
  define (`AON_PASSPORT_RESET_TOOL`, `qa_mode.dart`) instead of `kDebugMode`:
  it had appeared in a store screenshot taken from a debug simulator build.
  Release is unchanged (never shown); tests opt in via the provider.
- Store screenshots recaptured (2026-09-06) from the current build: iPhone
  6.9" ×6 (1320×2868), iPad 13" ×6 (2064×2752), Android phone ×6 (1080×2160,
  exactly 2:1 for Play). Old sets deleted.

**Verification:** see `GOOGLE_PLAY_RELEASE_AUDIT.md` (Build Results): AAB
signed and verified; all 64-bit `.so` 16 KB-aligned + `zipalign -P 16`
successful; merged manifest audited; `lintRelease` 0 errors; Android 16
emulator flows; full gate before commit.

**Follow-ups:** host the policy, enter Data safety verbatim, register the
upload cert, restrict the Maps key, capture Android screenshots + feature
graphic, start the closed test today.

---
## Raouf: 2026-09-05 — final pre-submission pass; `1.0.0+3` is the Build 3 candidate

**Scope:** the whole App Store submission surface — privacy answers, hosted-page
decisions, Routes verification, screenshots, review notes, blocker register, and
the version bump. Branch `fix/ios-always-location-purpose-string`.

**Summary**
- **Google Routes: the 401 is gone.** A real request with the shipped iOS key
  and the app's own headers returned **HTTP 200** and a real walking route —
  West 6 parking → Macquarie Theatre, 581 m / 476 s. B3's original cause is
  closed.
- **A worse finding in its place: the shipped Routes key has no application
  restriction.** The same request succeeded with **no** bundle-id header and
  again with a *wrong* bundle id. The key ships inside the binary and is
  extractable — `routes_client_identity.dart` says so itself and calls the
  identity headers "load-bearing", which they are only if the server enforces
  them. Anyone can bill this GCP project. Not an App Review blocker; fix it in
  the GCP console before the app is public. B3 stays OPEN on this.
- **App Privacy cannot be answered "Data Not Collected".** Apple's definition of
  *collect* covers transmission to a third-party partner, and the app POSTs the
  visitor's live latLng to Google. `PrivacyInfo.xcprivacy` now declares
  **PreciseLocation — App Functionality, not linked, not tracking**; the old
  empty array contradicted the app's own privacy copy. The test that guarded the
  empty array said "if that changes, declare it here" — so it was changed, not
  deleted, and now pins exactly one collected type.
- **Macquarie's own Privacy Policy cannot be the store URL** — checked, not
  assumed. `policies.mq.edu.au/document/view.php?id=107` scopes itself to staff,
  students and researchers, addresses no mobile app, and says nothing about the
  Routes transmission or ML Kit. MQ *hosting the app's own policy* is the right
  shape and is what `mq-hosted-pages.md` was written for.
- **Support URL found and verified live:** `https://event.mq.edu.au/astronomy-open-night/`
  — official, public, no login, event-specific, with `astronomyopennight@mq.edu.au`
  on the page. It also confirms the date the app shows.
- **Terms of Use: Apple's standard EULA is sufficient.** No custom EULA is
  required. Page 3 of the hosted pages exists for the Google Maps flow-down, not
  for Apple.
- **Screenshots were stale and are now recaptured.** The 2026-08-23 set showed
  *"Venues, toilets, first aid — and walking directions from the car parks"*,
  copy the app no longer ships. 6 of 6 iPhone (1320×2868) and 1 of 4 iPad
  (2064×2752) recaptured from this branch; the three remaining iPad shots were
  removed rather than shipped stale — Maestro reports success against the iPad
  UDID while the taps land elsewhere (three captures came back byte-identical).
- **App Review notes corrected to match the binary.** They claimed directions sit
  behind "an explicit in-app consent screen". Only the car-park wayfinding path
  shows one; the venue Directions path takes opening Directions *as* the choice.
  Both are now described, along with exactly what is sent to Google.
- **B6 closed by owner decision** (ship the hero photo on its existing credit),
  recorded as an accepted risk under a new register status rather than as
  `CLOSED — VERIFIED`, because no permission exists.
- **New:** `docs/release/app-store-connect-final-checklist.md` (23 rows, every
  ASC field with its evidence or its blocker) and
  `docs/release/device-qa-checklist.md` (the physical-device pass that closes B4).
- `pubspec.yaml` → **`1.0.0+3`**. Build 2 is spent.

**Files changed:** `ios/Runner/PrivacyInfo.xcprivacy`,
`test/unit/ios_privacy_manifest_test.dart`, `pubspec.yaml`,
`docs/release/app-store-connect-final-checklist.md` (new),
`docs/release/device-qa-checklist.md` (new), `docs/release-blockers.md`,
`docs/release/app-review-notes.md`, `docs/release/app-store-listing.md`,
`docs/release/screenshots/**`, `ARCHITECTURE.md`.

**Verification**
- `./scripts/check.sh` → **CHECK PASSED, 7/7, exit 0**; coverage 91.10%.
- `flutter build ios --release --no-codesign` ✓, then
  `flutter build ios --config-only --release` → `FLUTTER_BUILD_NUMBER=3`.
- Built bundle inspected: `CFBundleVersion 3`, `CFBundleShortVersionString
  1.0.0`, bundle id `au.edu.mq.astronomy.aon2026`, **4** purpose strings, **0**
  of the keys that must not appear (photo library, microphone, tracking,
  contacts, background modes, ATS exceptions), privacy manifest carrying
  PreciseLocation. `App.framework` contains exactly one network host —
  `https://routes.googleapis.com`.
- One `AIza…` string does appear in the `Runner` binary. It is **not ours**: the
  same string is inside the vendored `GoogleMaps.framework` slice, and this
  worktree has no `Secrets.xcconfig` and was built without
  `--dart-define-from-file`. Recorded so it is not re-raised as a leak.

**Follow-ups**
- Restrict the GCP keys (B3), host the Privacy Policy (B7), fill the App Review
  contact, answer App Privacy / age rating / DSA in ASC, capture the three
  remaining iPad screenshots, and run `device-qa-checklist.md` on a real iPhone
  (B4). Then archive Build 3 from the Xcode signed into team `94273WB4G3`.

## Raouf: 2026-09-05 — record the owner's answers on assets, the account and policy hosting

**Scope:** release blockers B6 and B7, organiser requests, provenance. Docs only
— no code, no behaviour change.

**Summary**
- **Assets (B6).** The owner attested: *"all the assets and material are ours.
  And if it's not ours, we already cited."* That settles three of the four sets
  — the basemap artwork, `buildings.json`, and the 39 360° photographs. B6 is
  narrowed from four assets to **one**.
- **The exception is the Home hero photograph**, and it is not a technicality:
  "A Deep Triangulum Galaxy" is Aleix Roig's, and the app *credits* it. A credit
  says who made a work; a licence is what permits shipping it. The repo's own
  README already states *"Rights remain with the photographer. Do not reuse it
  outside this project without permission."* Two surfaces are affected — the
  bundled app and the store screenshots, where `01-home.png` (iPhone and iPad)
  shows the hero, and a store listing is marketing rather than "this project".
  Closing needs the photographer's written yes for **both**, or a different hero.
- **Apple Developer account.** Confirmed in hand; TestFlight Builds 1 and 2 were
  uploaded from team `94273WB4G3`. No longer a blocker. The residual point, kept
  as a note rather than a blocker: a University-branded bundle id published from
  an individual account can draw a 4.1 request for written authority — worth
  keeping any MQ authorisation email with the review notes.
- **"Can we use Macquarie's privacy policy?" — no, but MQ can host ours.** MQ's
  institutional policy describes the University's services, not this app: it
  says nothing about the Routes origin, Google Maps' own collection, or ML Kit
  diagnostics. A policy that does not describe the app is a 5.1.1 defect of the
  same kind as B1. The right shape — and what `mq-hosted-pages.md` was always
  for — is MQ **hosting the app's own policy** at an `mq.edu.au` URL. Any stable
  HTTPS URL works if that is slow; Android already does this with
  `android-privacy-policy.html` on Leo's Play account.
- **Terms of Use** is not an Apple requirement — apps without one fall under
  Apple's standard licence agreement. Page 3 exists because Google Maps Platform
  requires the app's terms to flow its Maps/Earth Additional ToS down to users.
- Fixed stale facts in `organiser-requests.md`: the panoramas are **39 images
  across nine locations in `assets/data/indoor/`**, not "28 images of six
  venues" under `assets/panorama/**`.

**Files changed:** `docs/release-blockers.md` (B6 rewritten and narrowed, B7
hosting decision), `docs/release/organiser-requests.md`, `docs/release/mq-hosted-pages.md`,
`docs/panorama-image-provenance.md`, `ARCHITECTURE.md` (R4).

**Verification:** `./scripts/check.sh` → CHECK PASSED, 7/7, exit 0.

**Follow-ups**
- Still open and only a person can close them: the hero-image permission (B6),
  the hosted Privacy Policy / Support / Terms URLs (B7), the GCP Routes keys
  (B3), a physical-device pass (B4), and the App Store Connect metadata —
  age rating, App Privacy answers, screenshots, and the review contact, which
  is still `<NAME>/<EMAIL>/<PHONE>` in the notes.

## Raouf: 2026-09-05 — ITMS-90683: add the iOS Always-location purpose string

**Scope:** iOS Info.plist purpose strings, App Review notes, architecture doc.
Branch `fix/ios-always-location-purpose-string` (off `main@46dc81e`, worked in a
git worktree so a parallel session's staged Xcode changes were never touched).

**Summary**
- **The gate was already red on `main` before this branch existed, and is now
  green.** `settings_screen_test.dart:163` demanded the Settings privacy card
  read "no account and no sign-in" and "collects no analytics"; `46dc81e`
  (Leo, "Update privacy disclosures…") rewrote `settingsPrivacyBody` to "No
  account or advertising…" and added the Android ML Kit diagnostics
  disclosure, and `git show --stat 46dc81e` does not list that test. Worse, its
  "collects no analytics" assertion was in direct contradiction with
  `privacy_copy_truth_test.dart`, which `46dc81e` *did* update to forbid that
  exact phrase. The assertions now pin the substance of the shipped copy — no
  account, local storage, ML Kit diagnostics, and that walking directions send
  the origin and destination to Google — and the two tests no longer disagree.
- App Store Connect returned **ITMS-90683** for TestFlight **Build 2**
  (1.0.0+2): "the Info.plist file for the Runner.app bundle should contain a
  `NSLocationAlwaysAndWhenInUseUsageDescription` key". Delivery succeeded — this
  is a warning, not a rejection, and Build 2 remains installable — but it recurs
  on every upload until the key ships.
- **Cause, verified against the shipped binary, not inferred.**
  `strings build/ios/iphoneos/Runner.app/Runner` contains both
  `requestAlwaysAuthorization` and the literal
  `NSLocationAlwaysAndWhenInUseUsageDescription`, while that app's Info.plist
  declared only `NSLocationWhenInUseUsageDescription`. The symbols come from
  `geolocator_apple`'s `PermissionHandler.m`, which Flutter 3.47 links
  *statically* into Runner (the same mechanism as the privacy-manifest work
  above), so Apple's static scan attributes the API to the app bundle.
- **The app still never requests Always.** `PermissionHandler.m` calls
  `requestWhenInUseAuthorization` whenever `NSLocationWhenInUseUsageDescription`
  is present and only falls through to `requestAlwaysAuthorization` when it is
  absent — so the new key cannot change the prompt the user sees. There is no
  location background mode and no `allowsBackgroundLocationUpdates`
  (`location_service.dart` uses a plain `LocationSettings`).
- The new string is written for App Review and stays truthful on both counts
  that matter here: it discloses the Google walking-directions transmission
  (blocker B1's rule, now enforced for *both* location keys) and states that the
  app only uses location while it is open.
- `docs/release/app-review-notes.md` now pre-empts the obvious reviewer
  question — why an Always string exists for an app that only asks When In Use.
- Fixed a stale claim while in the file: `ARCHITECTURE.md` §10.3 still described
  the purpose string as saying location "is never sent anywhere", which was
  corrected on 2026-09-01. Rewritten to describe both keys as they now are.

**Files changed:** `ios/Runner/Info.plist`,
`test/unit/ios_location_purpose_test.dart`, `test/widget/settings_screen_test.dart`,
`docs/release/app-review-notes.md`,
`ARCHITECTURE.md` (§10.2 permissions row, §10.3 rewritten, new risk **R14**).

**Verification**
- `./scripts/check.sh` → **CHECK PASSED, 7/7, exit 0**; 1672 tests, coverage
  91.10% (floor 90.4%). The first run of this branch was **6/7**, and that
  failure was pre-existing on `main` — see the second bullet of the Summary.
- `test/unit/ios_location_purpose_test.dart` 4/4 pass (was 1 test, now 4: the
  When In Use string's truthfulness, the Always string's presence, its
  truthfulness, and that nothing in the bundle contradicts "only while open").
- `plutil -lint ios/Runner/Info.plist` → OK.
- `flutter build ios --release --no-codesign` ✓ (590.8s), and the *built*
  bundle was inspected — `plutil -p build/ios/iphoneos/Runner.app/Info.plist`
  now prints both location keys, and the bundle still declares no
  `UIBackgroundModes`. The **previous** build of that same path printed only
  `NSLocationWhenInUseUsageDescription`, which is precisely what Apple flagged.
- Cause evidence: `strings build/ios/iphoneos/Runner.app/Runner` on the old
  build matched both `requestAlwaysAuthorization` and
  `NSLocationAlwaysAndWhenInUseUsageDescription` — the API really is compiled
  into the app binary.

**Release-doc reconciliation (same branch)**
- `docs/release/app-store-submission-checklist.md`: the purpose-strings row said
  "all three present … each stating use *and* that data stays on device" — now
  four keys, and the two location strings must **not** claim the data stays on
  device. The version row still pointed at `1.0.0+2`; Build 2 is spent, so the
  next archive is `1.0.0+3`.
- `docs/release-blockers.md` **B7**: its "no accessible in-app Privacy Policy
  link or text … no `url_launcher`/`launchUrl` anywhere in `lib/`" evidence was
  overtaken by `46dc81e`, which added the Settings policy card (hosted URL when
  configured, full text offline otherwise) and `lib/services/url_opener.dart`.
  Conditions 2 and 6 are met; B7 stays `OPEN` on the hosted URLs and store
  metadata, which only the organisers can provide.

**Follow-ups**
- **Not yet verified end-to-end:** the warning can only be confirmed gone by the
  next upload. Bump to `1.0.0+3`, run
  `flutter build ios --config-only --release`, then archive **Build 3** from the
  Xcode session signed into team `94273WB4G3` and check the delivery mail.
- No l10n change: purpose strings are localised via `InfoPlist.strings`, which
  this app does not ship. The Persian UI shows the English system prompt today —
  a pre-existing gap, unchanged by this commit.

## Raouf: 2026-09-05 — Apple App Store release audit → TestFlight Build 2 candidate

**Scope:** iOS release readiness, privacy manifest, first-launch UX / onboarding
decision, E2E suite, release docs. Commits `12111f4..58577e0` on `main`.

**Summary**
- Full App Store audit recorded in `APPLE_RELEASE_AUDIT.md`: verdict
  CONDITIONALLY READY — no P0/P1 left in code; App Review still gated on hosted
  Privacy/Support URLs, asset redistribution rights, App Privacy answers and
  reviewer contact (people, not code). TestFlight is not gated by any of these.
- **Privacy manifest (P1):** `sensors_plus` (`systemUptime`) and
  `package_info_plus` (`fileModificationDate`) are statically linked into the
  Runner executable by Flutter 3.47's SwiftPM path and ship EMPTY manifests, so
  the app manifest now declares SystemBootTime `35F9.1` and FileTimestamp
  `C617.1`; the test asserts the exact list.
- **Onboarding: evaluated, deliberately NOT implemented**
  (`docs/onboarding-decision.md`). The one comprehension gap — what the passport
  is — is answered on the passport screen at zero stamps (`passportHowItWorks`,
  EN + FA). `first_launch_test.dart` fails if a first-launch gate is ever added.
- Launch screens (iOS storyboard + Android drawable) changed from white to the
  app's dark `surfaceBase` (#05070F) — the app opens dark by default.
- App Review notes no longer say the passport codes "do not exist yet";
  hosted-pages draft corrected (haptics, not text size); FIRST LAUNCH paragraph.
- Maestro: new `first-launch.yaml` and `passport.yaml`; `info`,
  `settings-persistence`, `program` fixed (post-restart tab taps by label,
  cold-boot swipe, redesigned "Filter by time" sheet).
- `pubspec.yaml` → `1.0.0+2`: Build 1 is spent on Play and on TestFlight
  (uploaded 2026-09-05). `58577e0` is the commit to archive as Build 2.

**Files changed:** `ios/Runner/PrivacyInfo.xcprivacy`,
`test/unit/ios_privacy_manifest_test.dart`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`,
`android/app/src/main/res/drawable/launch_background.xml`, `lib/l10n/app_en.arb`,
`lib/l10n/app_fa.arb`, `lib/l10n/generated/*`, `lib/screens/passport_screen.dart`,
`test/widget/first_launch_test.dart` (new), `docs/onboarding-decision.md` (new),
`lib/services/building_providers.dart`, `lib/widgets/glass_shader.dart`,
`lib/config/event_config.dart`, `lib/app/router/app_router.dart`,
`lib/widgets/app_shell.dart`, `.maestro/{first-launch,passport,info,program,settings-persistence}.yaml`,
`.maestro/README.md`, `APPLE_RELEASE_AUDIT.md` (new), `docs/release/app-review-notes.md`,
`docs/release/mq-hosted-pages.md`, `docs/release/app-store-submission-checklist.md`,
`docs/release-blockers.md`, `ARCHITECTURE.md`, `pubspec.yaml`.

**Verification**
- `./scripts/check.sh` → CHECK PASSED, 7/7, exit 0 (three runs: before the
  upstream merge, after merging `ea63063`, and immediately before committing);
  `flutter test` 1667 passed; coverage 91.13%.
- `flutter build ios --release --no-codesign` ✓; built `Runner.app` inspected
  (Info.plist strings, no photo/mic/background/ATT keys, privacy manifests for
  the app + all 10 plugins, arm64 AOT, only `routes.googleapis.com` compiled in).
- Maestro on iPhone 17 Pro (iOS 26.5): 21/21 flows, 435 commands. iPad Pro 13
  Home verified by `simctl` screenshot, including light appearance at
  accessibility XXXL text (clamped at 2.0×, no overflow).
- Xcode-resolved Release settings after `flutter build ios --config-only`:
  `FLUTTER_BUILD_NAME=1.0.0`, `FLUTTER_BUILD_NUMBER=2`, team `94273WB4G3`.

**Follow-ups**
- Archive Build 2 from the Xcode session signed into team 94273WB4G3 (the one
  that uploaded Build 1); this audit's shell user is a different individual
  team, which is why `flutter build ipa` could not sign here — not a project defect.
- Before App Review: host Privacy Policy + Support pages and set
  `EventConfig.privacyPolicyUrl`; obtain written asset rights (B6); answer App
  Privacy with Location → App Functionality (consented Google Routes request);
  fill reviewer contact.
- Consider deleting the unreachable `WayfindingScreen` route after the event.

---

## Earlier (before this changelog existed)

See `git log` and the dated audits under `docs/` (`map-audit-2026-08-30.md`,
`home-program-audit-2026-08-30.md`, `settings-mynight-audit-2026-08-30.md`) and
`docs/release-blockers.md`'s change log for 2026-09-01 → 2026-09-04.
