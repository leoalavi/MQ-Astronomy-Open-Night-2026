# Changelog — Astronomy Open Night 2026 (`aon2026`)

Human-readable release log. Entries are newest first and use the `Raouf:`
template (date in Australia/Sydney, scope, summary, files, verification,
follow-ups). Commit-level history lives in `git log`; the architecture is in
`ARCHITECTURE.md`; open release prerequisites in `docs/release-blockers.md`.

---

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
