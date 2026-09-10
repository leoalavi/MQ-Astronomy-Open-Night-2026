# App Store submission checklist — aon2026

> **Authoritative pre-submission source: [`app-store-connect-final-checklist.md`](app-store-connect-final-checklist.md).**
> That file holds the single, current answer set (App Privacy, Age Rating,
> availability, contact). This document is the older 2026-08-23 requirements
> audit; where the two ever differ, the final checklist wins. Rows below have
> been reconciled to the current Build 4 candidate (`1.0.0+4`). Build 3 remains
> approved for external TestFlight but predates the current shared source.

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
| Version/build set to `1.0.0+4` | **DONE IN SOURCE; UPLOAD REQUIRES HUMAN SIGNING/ASC** | `pubspec.yaml` → `version: 1.0.0+4`. Build 3 is approved for external TestFlight but predates the current shared-source changes; Build 4 is the next candidate and has not been signed or uploaded. |

Source: <https://developer.apple.com/news/upcoming-requirements/>

---

## 2. Privacy

| Item | Status | Evidence |
|---|---|---|
| App-level `PrivacyInfo.xcprivacy` present and **bundled** | **DONE** | `ios/Runner/PrivacyInfo.xcprivacy`, wired into the Runner Resources phase; verified present in `build/ios/iphoneos/Runner.app/`. Guarded by `test/unit/ios_privacy_manifest_test.dart` (negative-verified: the test fails if the pbxproj wiring is removed). |
| Required-reason APIs declared | **DONE** (re-audited 2026-09-05) | The app manifest declares **SystemBootTime 35F9.1** and **FileTimestamp C617.1**: `sensors_plus` (`systemUptime`) and `package_info_plus` (`fileModificationDate`) are statically linked into Runner via SwiftPM and ship *empty* manifests, so their use is attributed to the Runner executable. `shared_preferences_foundation` (UserDefaults 1C8F.1) and `Flutter.framework` declare their own. Guarded by `test/unit/ios_privacy_manifest_test.dart`. |
| No third-party SDK on Apple's manifest-required list | **DONE** | Pods are Flutter, `flutter_inappwebview_ios`, `google_maps_flutter_ios`, `GoogleMaps`, `Google-Maps-iOS-Utils`, `OrderedSet` — none listed. |
| Purpose strings for camera / location / motion | **DONE** (re-audited 2026-09-05) | **Four** keys, not three: camera, motion, `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription`. The last was added after App Store Connect returned **ITMS-90683** against Build 2 — `geolocator_apple`'s `requestAlwaysAuthorization` is statically linked into Runner, so Apple's scan demands the string even though the app only ever requests When In Use. Camera and motion say the data stays on device; **the two location strings must not** — the Routes call sends the origin to Google. Guarded by `test/unit/ios_location_purpose_test.dart` (4 tests). |
| **Privacy Policy URL** in App Store Connect | **YOU, after deployment** | 5.1.1(i) mandatory metadata. Canonical value: `https://aon.syllabus-sync.app/privacy`. The local static artifact is ready; public DNS/hosting was not reachable during the 2026-09-10 audit. Deploy and verify it before pasting into ASC. |
| App Privacy questionnaire ("Nutrition Label") | **READY TO ENTER** | **Not** "Data Not Collected" — the app sends Precise Location to Google Routes and embeds the Google Maps SDK. The single authoritative answer set is in [`app-store-connect-final-checklist.md`](app-store-connect-final-checklist.md) §3: Precise Location + Coarse Location, Identifiers, Product Interaction, Other Usage Data, Crash Data, Performance Data — all App Functionality, not linked, not tracking. |

Sources: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files> ·
<https://developer.apple.com/support/third-party-SDK-requirements/>

---

## 3. App Review completeness — guideline 2.1 / 2.3.1

Apple: *over 40% of unresolved issues are guideline 2.1*.

| Item | Status | Evidence |
|---|---|---|
| **No dormant features** | **DONE** | The Astronomy Passport was inert in every release build (all nine codes `AON-*-TBC`). The live codes landed 2026-09-04, so the domain gate now opens on its own and the passport works unaided; the user-visible preview in Settings → Preview remains as a try-it-anywhere control. 6 tests in `test/unit/passport_preview_test.dart`. |
| Review notes written, with **verified** navigation steps | **DONE** | `docs/release/app-review-notes.md`. Steps verified against the actual widget tree: six tabs (Home, Program, Night, Map, Info, Settings); the passport is **not** a tab — it is the Home card / Info button. |
| Demo account | **N/A** | No account, no sign-in, no server. Stated in the notes. |
| Backend live during review | **N/A** | Offline-first; no backend. |
| **Support URL** in App Store Connect | **YOU (paste only)** | Required. **Ready:** `https://event.mq.edu.au/astronomy-open-night/` — the official event/support page (event support: `astronomyopennight@mq.edu.au`). Its being on the MQ event domain is intentional. |
| App Review contact name/email/phone | **DONE** | Supplied by Leo 2026-09-06: **Leo Alavi**, `leo@leoalavi.dev`, `+61451519624`. In `app-review-notes.md`. |

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

1. **URLs:** Privacy Policy `https://aon.syllabus-sync.app/privacy` (local static
   artifact ready; deploy and verify), Support
   `https://event.mq.edu.au/astronomy-open-night/` (official event page), Terms
   `https://info.syllabus-sync.app/astronomy-open-night/terms` (carries the
   Google Maps flow-down). Privacy and Support are hard ASC requirements.
2. **Apple Developer Program membership — REOPENED 2026-09-07.** The bundle
   ID is `au.edu.mq.astronomy.aon2026`, an `au.edu.mq` namespace. This entry
   used to say publication needed the University's Apple Developer account or
   written authority to publish on their behalf. **That is now withdrawn:** the
   supervisor has confirmed the University has not approved this project, so it
   must NOT be published under a University account or presented as theirs.
   Apple's guideline **5.1.1.1 / 4.1** still applies, but the risk has flipped
   direction — the exposure is now an app *sitting in a university's reverse-DNS
   namespace* while disclaiming any affiliation with it. All university branding
   has been removed from the binary (2026-09-07); the identifier itself is a
   separate, unresolved decision — see `organiser-requests.md`.
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
| The passport is reachable by a reviewer | **YES.** Open the passport and enter `AON-A-FL3R` → "Stamp collected!", fact sheet opens, progress reads 1 / 9. No preview switch needed; the nine live codes are listed in `docs/release/app-review-notes.md`. |
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
