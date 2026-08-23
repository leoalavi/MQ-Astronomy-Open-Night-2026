# App Store submission checklist — aon2026

Audited against the Apple developer documentation current on **2026-08-23**.
Sources are linked per section. Items are marked:

- **DONE** — implemented and verified in this repo, with the evidence named.
- **YOU** — cannot be done from the codebase; needs an account, a person, or
  a decision. These are the real critical path.

> **No one can promise "100% accepted".** App Review is a human process. What
> this checklist does is remove every *known* rejection cause that is under our
> control, and name the ones that are not.

---

## 1. Build requirements

| Item | Status | Evidence |
|---|---|---|
| Built with **Xcode 26+ / iOS 26 SDK** (mandatory since 28 Apr 2026) | **DONE** | `xcodebuild -version` → Xcode 26.6; SDK iOS 26.5 |
| iOS release build succeeds | **DONE** | `flutter build ios --release --no-codesign` → exit 0 |
| App icon incl. 1024×1024 marketing icon, no alpha | **DONE** | `AppIcon.appiconset`, 19 entries, all with filenames |
| `ITSAppUsesNonExemptEncryption` declared | **DONE** | `Info.plist` → `false`; rationale in `export-compliance.md` |
| Version/build bumped past the spent `1.0.0+1` | **YOU** | `1.0.0+1` was consumed by the Play App Signing bootstrap AAB. Bump before the release candidate. |

Source: <https://developer.apple.com/news/upcoming-requirements/>

---

## 2. Privacy

| Item | Status | Evidence |
|---|---|---|
| App-level `PrivacyInfo.xcprivacy` present and **bundled** | **DONE** | `ios/Runner/PrivacyInfo.xcprivacy`, wired into the Runner Resources phase; verified present in `build/ios/iphoneos/Runner.app/`. Guarded by `test/unit/ios_privacy_manifest_test.dart` (negative-verified: the test fails if the pbxproj wiring is removed). |
| Required-reason APIs declared | **DONE** | The app target calls none. Engine/plugins declare their own: `Flutter.framework` (FileTimestamp, SystemBootTime), `shared_preferences_foundation` (UserDefaults). |
| No third-party SDK on Apple's manifest-required list | **DONE** | Pods are Flutter, `flutter_inappwebview_ios`, `google_maps_flutter_ios`, `GoogleMaps`, `Google-Maps-iOS-Utils`, `OrderedSet` — none listed. |
| Purpose strings for camera / location / motion | **DONE** | All three present in `Info.plist`, each stating use *and* that data stays on device. |
| **Privacy Policy URL** in App Store Connect | **YOU** | 5.1.1(i) makes this mandatory metadata. MQ-hosted. **Blocking — nothing can be submitted without it.** |
| App Privacy questionnaire ("Nutrition Label") | **YOU** | Answer in ASC. For this app the honest answer is *Data Not Collected* on every category. |

Sources: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files> ·
<https://developer.apple.com/support/third-party-SDK-requirements/>

---

## 3. App Review completeness — guideline 2.1 / 2.3.1

Apple: *over 40% of unresolved issues are guideline 2.1*.

| Item | Status | Evidence |
|---|---|---|
| **No dormant features** | **DONE** | The Astronomy Passport was inert in every release build (all nine codes `AON-*-TBC`). Now reachable via a user-visible preview — `lib/services/passport_preview.dart`, Settings → Preview. 6 tests in `test/unit/passport_preview_test.dart`. |
| Review notes written, with **verified** navigation steps | **DONE** | `docs/release/app-review-notes.md`. Steps verified against the actual widget tree: six tabs (Home, Program, Night, Map, Info, Settings); the passport is **not** a tab — it is the Home card / Info button. |
| Demo account | **N/A** | No account, no sign-in, no server. Stated in the notes. |
| Backend live during review | **N/A** | Offline-first; no backend. |
| **Support URL** in App Store Connect | **YOU** | Required. MQ-hosted. **Blocking.** |
| App Review contact name/email/phone | **YOU** | Placeholders `<NAME>/<EMAIL>/<PHONE>` in the notes. |

Source: <https://developer.apple.com/distribute/app-review/>

---

## 4. Product page

| Item | Status |
|---|---|
| Screenshots — 6.9" iPhone (1320×2868 or 1290×2796) **required**; 13" iPad (2064×2752 or 2048×2732) **required if the app runs on iPad** — no alpha channel | **YOU** |
| Name, subtitle, description, keywords, promotional text | **YOU** |
| **Age rating questionnaire** under the new system | **YOU** — mandatory since 31 Jan 2026; unanswered blocks update submission |
| Accessibility Nutrition Labels | **YOU** — *voluntary for now*, becoming mandatory later. The app supports VoiceOver, Dynamic Type to 200% and Reduce Motion, so this is worth claiming. |
| Category, copyright, pricing (free), availability | **YOU** |

Source: <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/>

The app runs on iPad (`Info.plist` allows all four iPad orientations), so **iPad
screenshots are required**, not optional.

---

## 5. Legal / account — the items that are genuinely blocking

These are not code. They are the critical path.

1. **Three MQ-hosted URLs, requested in one round**: Privacy Policy, Support,
   Terms of Use (the last carries the Google Maps flow-down). Privacy and
   Support are hard ASC requirements.
2. **Apple Developer Program membership.** The bundle ID is
   `au.edu.mq.astronomy.aon2026` — an `au.edu.mq` namespace. Publishing under
   it needs Macquarie University's Apple Developer account, or written
   authority to publish on their behalf. Apple applies guideline **5.1.1.1 /
   4.1** to apps that represent an institution: an app branded as a university
   event, submitted by an unaffiliated individual, is a rejection risk on
   impersonation grounds independent of everything else in this document.
3. **Redistribution permission** for the vendored assets: the official AON
   programme map artwork (`assets/maps/aon_event_map.png` + the source PDF),
   `buildings.json`, and the 360° photographs. The repo being private is why
   committing them was fine; it is **not** publication permission. Guideline
   **5.2** (intellectual property).
4. **Real stamp codes**, or a decision to ship with the preview as the only
   path. Without them the passport cannot work on the night itself, even
   though it now reviews correctly.

---

## 6. Verified on a simulator, 2026-08-23

Run on an iPhone 17 Pro Max (iOS 26.5) with the release-configuration Dart code.

| Claim | Result |
|---|---|
| **The 360° tours render** | **YES — first time ever observed.** Tour A loads its equirectangular image in the WKWebView over `http://localhost` and the scene rail switches Entrance ↔ Theatre foyer. |
| The passport is reachable by a reviewer | **YES.** Settings → Preview → on, then `AON-A-TBC` → "Stamp collected!", fact sheet opens, "Preview stamps" badge shows, progress reads 1 / 9. |
| Wayfinding renders no OSM tiles | **Confirmed gone.** Choosing a destination raises the Google consent disclosure *before* any map is drawn. |
| The consent gate holds on a device | **YES** for the UI half of spec §2b — declining leaves no map and says "Map not shown. The written directions below are complete on their own." A packet capture is still the only thing that can prove zero traffic. |
| Map E2E suite | **6/6 flows, 130 commands.** |

### Defects this found and fixed

- **The whole Maestro suite was silently broken.** `flows/open-map.yaml` taps the
  Map tab at `68%`, correct while the app had five tabs. Settings became a sixth
  tab, so 68% landed on **Info** and every map flow ran against the wrong screen.
  Now `58%`, verified from the hierarchy.
- **The panorama title was covered by the back button** — "Macquarie Theatre"
  rendered as "◄acquarie Theatre", because the floating back button and the title
  island were positioned at the same top/left. Fixed with
  `PanoramaTourView.titleLeadingInset`; the back button now ends at x=64 and the
  title starts at x=88. No widget test could have seen this.
- **Two stale E2E assertions** expected `Campus map © Macquarie University`; the
  `©` was deliberately removed and a unit test forbids it.

## 7. Known limitations to state honestly

- **On-device smoke tests on real hardware are still outstanding** — everything
  above is a simulator. The M5 compass heading proof still needs a magnetometer,
  and the M4 live Google Maps render still needs the GCP keys.
- **iPad screenshots are incomplete.** One home shot at the correct 2064×2752
  exists; the Maestro driver stopped connecting to the iPad part-way through.
- `EventFeatures.scan` and `EventFeatures.stamps` are `false` in
  `event_config.dart` and documented as meaning "hidden, not stubbed" — but
  **neither flag is read anywhere in `lib/`**. They are dead config. They do
  not hide the passport (verified), so they did not affect this audit, but the
  comment is misleading and should be reconciled.
- **A copyright claim was contradicting itself.** `mapAttributionCampus`
  deliberately avoids `©` because MQ's ownership of the cartographic master is
  unconfirmed (spec §8.6), while a newer Credits line asserted
  "campus map … © {host}". The Credits line no longer names the campus map, which
  is still credited as a source in `creditsMapDataBody`; a new test in
  `map_attribution_test.dart` now enforces the rule across every shipped string.
  **Reverse this if the ownership sign-off lands** — see
  `docs/release/organiser-requests.md`.
