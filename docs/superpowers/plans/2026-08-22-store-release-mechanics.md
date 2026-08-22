# Store Release — Release Mechanics Plan (Plan B)

> **Not a TDD plan.** Every item here is verified by *building, uploading or
> observing*, not by a failing test. Forcing it into red-green shape would be
> ceremony. Each step therefore states its **acceptance evidence** — the artefact
> or observation that proves it, which must be recorded, not asserted.

**Goal:** Take `main@ed10da3` (Plan A complete) to a public download on the App
Store and Google Play before Sat 19 Sep 2026.

**Spec:** `docs/superpowers/specs/2026-08-22-app-store-release-program-design.md`
(revision 4) — §4, §5a, §6, §2d-g.

**Companion:** `2026-08-22-store-release-app-code.md` (Plan A) — **done and
merged**. Nothing here depends on further app-code work.

## Verified starting state

Read off the tree at `ed10da3`, not assumed:

| Fact | Evidence | Status |
|---|---|---|
| Xcode 26.6 / iOS 26.5 SDK installed | `xcodebuild -showsdks` | **satisfies** the 28 Apr 2026 upload rule |
| Flutter 3.44.7 defaults `targetSdk 36` | `FlutterExtension.kt:34`; Gradle uses `flutter.targetSdkVersion` | **satisfies** Play's 31 Aug 2026 deadline — no action |
| Release signs with the **debug** key | `android/app/build.gradle.kts:42-45` | **blocker** |
| `android/key.properties` already git-ignored | `.gitignore:68` | ready; no `.sample` yet |
| `ITSAppUsesNonExemptEncryption` absent | 0 hits in `ios/Runner/Info.plist` | **blocker** (stalls every upload) |
| No app-level privacy manifest | no `*.xcprivacy` outside `Pods/` | **blocker** |
| Version `0.1.0+1` | `pubspec.yaml:6` | needs `1.0.0+1` |
| Bundle ID `au.edu.mq.astronomy.aon2026` | `project.pbxproj:513` | fixed by D3 |
| iPad support is real | `TARGETED_DEVICE_FAMILY = "1,2"` ×3 | 13" screenshots required; **layouts verified** by Plan A Task 12 (72 tests) |
| Stamp codes are placeholders | `stamp_stations_data.dart:11-14`, `AON-A-TBC` etc., `codeConfidence: placeholder` | usable by App Review **today**; organisers must supply real ones before the night |

---

## Sequencing

Two chains run in parallel. **Phase A is first because you do not control it.**

```
A. MQ web + accounts  ────────────────────────┐  (longest lead, not engineering)
                                              │
B. Release engineering ──┐                    │
                         ├── C. Credentials ──┴── D. On-device ── E. Submit
                         │   (needs B's keystore)
```

The **critical path** is A → C → D. B can start immediately and finish in a day.

---

## Phase A — External dependencies (start today, no code)

Nothing here is engineering, and nothing downstream can be finished without it.

- [ ] **A1. Request THREE MQ-hosted URLs in one approval round.**
  Requesting them separately is how the third one gets discovered in week three.
  - **Privacy Policy** — Apple requires the URL in App Store Connect *and* the
    policy reachable inside the app. Must cover: nothing collected by MQ; location
    sent to Google only on an explicit directions request, after consent; Google
    receives map/request/device information whenever a Google map loads;
    passport, favourites and consent stored on-device only; how to withdraw
    consent (Settings → revoke) and delete data (Settings → Delete my data);
    that deletion cannot recall anything already sent to Google.
  - **Support URL** — required per app version.
  - **Terms of Use** — carries Google Maps Platform's flow-down: the app's terms
    must notify users that Google Maps content is present and subject to Google's
    additional terms and privacy policy.
  - *Evidence: three live `mq.edu.au` URLs returning 200.*

- [ ] **A2. MQ Apple Developer Program organisation account** (D1), with your
  account added and a role that can upload builds.
  *Evidence: you can create the app record in App Store Connect.*

- [ ] **A3. MQ Google Play Console organisation account**, including developer
  verification and D-U-N-S.
  *Evidence: Play Console shows the org as verified.*

- [ ] **A4. Written MQ sign-off on redistribution** (spec §8.6) covering
  `assets/data/buildings.json`, `assets/maps/aon_event_map.png` and the vendored
  source PDF. Publishing **is** the redistribution event; the repo being private
  was never permission. D1 makes this an internal approval, not a licence
  negotiation — but it must be recorded.
  *Evidence: an email or ticket, filed and linked from the spec.*

- [ ] **A5. Ask the organisers the two open artwork questions** (spec §7): the
  sheet draws four toilet `T` discs but its legend lists three, and the legend's
  `C` prints over 1CC rather than the courtyard. Neither is a code bug. Also ask
  for the **real stamp codes** to replace `AON-*-TBC`.
  *Evidence: answers recorded; `stamp_stations_data.dart` updated with
  `codeConfidence: confirmed` if supplied.*

- [ ] **A6. Confirm whether MQ owns the cartographic master.** Plan A ships
  `Campus map: Macquarie University` — source, not copyright — because ownership
  is unconfirmed, and `map_attribution_test.dart` forbids the `©` symbol until
  this lands. If MQ confirms ownership, change the copy and the test together.
  *Evidence: a written answer either way.*

---

## Phase B — Release engineering (start now, ~1 day)

- [ ] **B1. Android upload keystore.**
  Generate a keystore held by MQ (not in the repo, not in a personal password
  manager). Create `android/key.properties` — already git-ignored at
  `.gitignore:68` — and commit a `android/key.properties.sample` beside the
  existing `secrets.properties.sample`.

  Replace `android/app/build.gradle.kts:42-45`:

  ```kotlin
      signingConfigs {
          create("release") {
              val props = Properties().apply {
                  val f = rootProject.file("key.properties")
                  if (f.exists()) f.inputStream().use { load(it) }
              }
              // Absent key.properties → fall back to debug so `flutter run
              // --release` still works locally. A release BUILD asserts below.
              val store = props.getProperty("storeFile")
              if (store != null) {
                  storeFile = rootProject.file(store)
                  storePassword = props.getProperty("storePassword")
                  keyAlias = props.getProperty("keyAlias")
                  keyPassword = props.getProperty("keyPassword")
              }
          }
      }

      buildTypes {
          release {
              val props = rootProject.file("key.properties")
              signingConfig = if (props.exists()) {
                  signingConfigs.getByName("release")
              } else {
                  signingConfigs.getByName("debug")
              }
          }
      }
  ```

  *Evidence: `flutter build appbundle --release` produces an AAB, and
  `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
  shows the MQ certificate — **not** `CN=Android Debug`.*

- [ ] **B2. Export compliance.**
  Add to `ios/Runner/Info.plist`:

  ```xml
  	<key>ITSAppUsesNonExemptEncryption</key>
  	<false/>
  ```

  **This value is an audited conclusion, not a default.** The key covers the app
  *and its linked third-party libraries*. Before setting `false`, confirm none of
  `google_maps_flutter`, `geolocator`, `mobile_scanner`, `flutter_inappwebview`,
  `shared_preferences`, `sensors_plus` or `http` uses non-exempt encryption. All
  observed use is HTTPS, which is exempt.
  *Evidence: a written note listing what was checked, filed with the submission.*

- [ ] **B3. Version.** `pubspec.yaml:6` → `version: 1.0.0+1`.
  **Build numbers are monotonic.** Any replacement binary is `+2`, `+3`, … Numbers
  are never reused, even for a build that was rejected or never released.

- [ ] **B4. iOS production signing.** Configure signing and provisioning under
  MQ's Developer Team for `au.edu.mq.astronomy.aon2026`.
  *Evidence: `flutter build ipa --release` completes and exports a signed IPA —
  not just a successful `flutter run`.*

- [ ] **B5. Exit-gate.** `./scripts/check.sh full` green, exit-gated, never piped.
  *Evidence: the log, with its own exit code.*

---

## Phase C — Credentials (blocked on B1; the longest internal chain)

> **The trap this phase exists to avoid.** Under Play App Signing — which new
> apps are enrolled in automatically — the upload keystore only authenticates
> uploads. Google re-signs the artifact delivered to users with an **app-signing
> key it holds**. A Maps key restricted to the upload certificate works on every
> build you test locally and fails for **every user who installs from Play**.

- [ ] **C1. Create the Play app record and upload the first AAB** (internal
  testing track), which enrols the app in Play App Signing.

- [ ] **C2. Read the Google-held app-signing certificate fingerprints** from Play
  Console → Setup → App integrity. Record **both** the app-signing and upload
  certificate SHA-1s.

- [ ] **C3. Create four restricted GCP keys** in MQ's project:
  - Maps SDK for **iOS** — restricted to bundle ID `au.edu.mq.astronomy.aon2026`
  - Maps SDK for **Android** — restricted to package + **every certificate that
    can sign a distributed APK** (app-signing *and* upload, so internal builds
    work too)
  - Routes API × iOS and Android — same restrictions, applied to the web-service
    key. Google's guidance prefers a proxy or an IP-restricted key for web
    services, but documents the direct-call fallback explicitly, and
    `google_routes_service.dart:44-50` already sends exactly the required headers
    (`X-Android-Package` + `X-Android-Cert`, `X-Ios-Bundle-Identifier`). Routes v2
    is the current service, not one of the "older legacy" services the caveat
    covers.

- [ ] **C4. Cap the blast radius.** The Routes key ships inside the binary and is
  extractable — inherent to the documented fallback, not a flaw in it. Set Routes
  API quota limits and a GCP **budget alert** on MQ's project so an extracted key
  cannot run up a bill against the university.
  *Evidence: screenshots of the quota and the alert.*

- [ ] **C5. Install the secrets locally.** `android/secrets.properties` and
  `ios/Flutter/Secrets.xcconfig` from the committed `.sample` files, plus
  `--dart-define=MAPS_NATIVE_CONFIGURED=true`,
  `--dart-define=GOOGLE_MAPS_ANDROID_ROUTES_KEY=…` and
  `--dart-define=GOOGLE_MAPS_IOS_ROUTES_KEY=…`.

- [ ] **C6. Prove the restriction REJECTS.** Not an assumption — the M4 IOU made
  a release gate. Issue a Routes request with a wrong bundle ID (iOS) and a wrong
  package/cert pair (Android) and confirm it is **refused**.
  `google_nav_screen.dart` already surfaces `RouteApiFailure.status` to logs for
  exactly this.
  *Evidence: the rejected HTTP status, captured.*

  **If C6 fails**, the fallback is not available: fall back to an MQ-hosted Routes
  proxy behind an IP-restricted server key — and note that this puts MQ
  infrastructure into the location-data path, re-opening §2d, §2e and §2f.

---

## Phase D — On-device verification (blocked on C)

Simulator-verified is the standing release IOU. These pay it.

- [ ] **D1. The network test Plan A cannot do.** Unit tests prove the
  architecture; only a packet capture proves reality. On a physical device, with
  a proxy or `tcpdump`:

  | Scenario | Required observation |
  |---|---|
  | Cold launch, consent never given | **Zero** traffic to Google hosts |
  | Accept the disclosure | Google traffic permitted |
  | Revoke in Settings, then retry nav | **Zero** new Google traffic |

  *Evidence: the capture, saved. Until this runs, spec §2b is verified in the
  test suite and **unverified on a device** — say so rather than implying
  otherwise.*

- [ ] **D2. M4 IOU — live Google render.** Physical iOS and Android: the embedded
  map draws, a walking route returns, and the restriction rejection from C6 is
  reproduced on-device.

- [ ] **D3. M5 IOU — heading proof.** The arrow tracks true bearing including the
  12.752°E declination, and the red rose is legible in actual darkness. The
  simulator has no magnetometer, so it only ever exercised the honest
  `unavailable` → list fallback.

- [ ] **D4. Physical smoke test** of the Plan A changes most visible to a user:
  the wayfinding map now requires consent and shows a labelled placeholder when
  declined; Delete my data clears the session; preview mode shows its badge on
  map and compass.

---

## Phase E — Store metadata and submission

- [ ] **E1. Screenshots.** 6.9" iPhone (required) and 13" iPad (required —
  `TARGETED_DEVICE_FAMILY = "1,2"`). Plan A Task 12 proved the layouts hold at
  both, in EN and FA, so this is capture work, not fixing.

- [ ] **E2. Listing.** App name ≤30 chars, subtitle, description, keywords,
  category. Metadata must be 4+ appropriate regardless of the app's rating.

- [ ] **E3. Notes for Review — the 4.2 and 2.1 defence.** Generic notes are
  rejected under 2.3.1(a). State plainly:
  - An official Macquarie University app for a public astronomy night on
    19 Sep 2026.
  - Reviewers are not on campus, so: **turn on Settings → "Preview from
    anywhere"** to see the map dot, compass and nearby list as they work on the
    night. Off campus the app deliberately shows "You're about N km from campus"
    rather than a fabricated position.
  - **Sample passport codes** — `AON-A-TBC`, `AON-B-TBC`, `AON-C-TBC` — entered
    via Passport → Scan → *Enter code*. Manual entry is a first-class peer to the
    camera, so the passport is fully exercisable without a QR sign.
  - Location is used on-device for the campus map and sent to Google **only**
    after the visitor accepts the walking-directions disclosure.
  - The app is offline-first apart from Google Maps; there is no account.

- [ ] **E4. Privacy manifest + archive audit** (spec §2e). Create
  `ios/Runner/PrivacyInfo.xcprivacy`, then reconcile against the **actual release
  archive**: Xcode's Privacy Report, plus the embedded SDK manifests, plus D1's
  network capture.

  **Ownership rule:** a third-party SDK supplies its *own* manifest and the app
  manifest does not duplicate it. Runner's manifest covers first-party code and
  may end up nearly empty — that is a correct outcome, not a missing one.

  Expected, as expectations the audit may overturn:
  `NSPrivacyTracking = false`; omit `NSPrivacyTrackingDomains`; Precise Location
  → App Functionality, not linked to identity, not used for tracking.

- [ ] **E5. Reconcile five surfaces.** Privacy policy (A1), in-app copy (shipped
  in Plan A Task 7), App Store privacy labels, Play Data Safety, and
  `PrivacyInfo.xcprivacy`. They must agree.

  **The label almost certainly cannot read "Data Not Collected"** — Apple's label
  covers third-party SDK collection and Google's SDK manifests disclose automatic
  collection. **Do not infer tracking from an identifier**: an Identifiers
  disclosure and Apple-defined *tracking* are separate determinations, and
  tracking is a use-purpose test. Answer both from E4's aggregated report.

- [ ] **E6. Age rating.** Complete the current App Store Connect questionnaire and
  Play's IARC questionnaire **truthfully**. Expected result **4+** — no UGC, no
  messaging or social feed, no advertising. Do not hard-code a rating; the
  questionnaire's output is the rating.

- [ ] **E7. In-app privacy policy link.** 5.1.1(i) requires the policy reachable
  *inside* the app, not only in App Store Connect. Add it to Settings once A1
  lands. **This is the one Phase E item that needs app code**, and it is blocked
  on A1.

- [ ] **E8. TestFlight internal** before any public App Store submission.

- [ ] **E9. Play internal testing with the PLAY-SIGNED artifact** before
  Production. Not ceremony — it is the only way to verify C2's app-signing
  fingerprint actually works for delivered builds.

- [ ] **E10. Submit.** App Store and Play, with A1's three URLs attached.

---

## Done means

- A signed AAB whose certificate is MQ's, and a signed IPA exported under MQ's
  team.
- **Zero Google traffic before consent, observed on a physical device** (D1) —
  the one acceptance criterion no test suite can supply.
- The Routes key restriction **rejects** a wrong bundle ID / cert (C6).
- Three live `mq.edu.au` URLs, and the policy reachable from inside the app.
- Privacy labels, Data Safety, the privacy manifest, the policy and the in-app
  copy all saying the same thing.
- Both stores showing the app as available for public download.

## Risks, named

| Risk | Mitigation |
|---|---|
| **A1 lead time is unknown and unowned.** This is the single most likely cause of missing 19 Sep. | Requested day one, all three URLs together. |
| C6 fails → proxy needed | Costed contingency in §5a; re-opens §2d/§2e/§2f. Decide fast, do not improvise. |
| Review latency + one rejection ≈ 5-10 days | Submit as early as Phase E allows; treat any polish as 1.1. |
| Stamp codes are still `AON-*-TBC` | Fine for App Review, **not** fine for the night. A5 chases the real ones. |
| First submission is a 4.2/2.1 rejection | E3 argues it explicitly; Plan A built the reviewability features it points at. |
