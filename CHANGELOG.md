# Changelog — Astronomy Open Night 2026 (`aon2026`)

Human-readable release log. Entries are newest first and use the `Raouf:`
template (date in Australia/Sydney, scope, summary, files, verification,
follow-ups). Commit-level history lives in `git log`; the architecture is in
`ARCHITECTURE.md`; open release prerequisites in `docs/release-blockers.md`.

---

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
