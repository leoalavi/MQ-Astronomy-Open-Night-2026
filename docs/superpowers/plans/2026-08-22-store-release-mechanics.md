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
merged**.

**Plan A's product and compliance implementation is complete, but Plan B still
carries narrowly scoped release deltas**, each identified below: **A5a** (stamp
codes), **A6** (attribution wording), **D5** (cleartext networking config) and
**E7** (in-app privacy link, definite). An earlier draft claimed "nothing here
depends on further app-code work" — that was wrong, and it hid a sequencing hole.
**Any delta invalidates the previous binary**: new build number, full gate, fresh
release candidate, and the archive/privacy/network/smoke verification repeated.
See **Final Binary Cut** before Phase E.

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
| **Passport collection is DISABLED in every release build** | `stamp_service.dart:54-55` — `if (!isRelease) return true; return stations.every((s) => s.codeConfidence.isReliable)`. All **9** stations are `AON-*-TBC` and take the model's default `placeholder` confidence | **submission-affecting** — see A5. The app shows the honest *"Astronomy Passport opens on event night"* (`passport_screen.dart:25`) |
| Panorama viewer ships on a **local HTTP server** | `panorama_server.dart:8,20` — `InAppLocalhostServer`, `http://localhost:$kPanoramaServerPort`; route `/panorama/:venueId` | **likely already broken on Android** — see D5 |
| **Android denies cleartext by default** | `AndroidManifest.xml` sets neither `usesCleartextTraffic` nor `networkSecurityConfig`, there is no `res/xml/`, and `targetSdk` is 36 (≥28 ⇒ cleartext denied) | **D5 is a bug hunt, not a formality** |
| iOS has no ATS exceptions | 0 hits for `NSAppTransportSecurity` in `Info.plist` | same |
| The vendored PDFs are **not** shipped | `pubspec.yaml:58-64` ships `assets/{images,web,data,maps}`; the PDFs live in `docs/source-materials/` and `tools/aon_map/source/` | **A4 narrows** — publishing does not redistribute them |

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
  *Evidence, and 200 is not enough — a login wall, a stub and a "page under
  construction" all return 200. Each URL must be **public HTTPS, no
  authentication, naming this app, readable on a phone, carrying actual
  policy/terms text**; the Support URL must offer usable contact or help
  information.*

  **Word the policy precisely.** "MQ collects nothing" will sit beside an App
  Store privacy label that almost certainly declares Location (E5). Say instead:
  *Macquarie University does not receive or retain account, analytics, passport
  or favourites data. Google receives the disclosed Maps and Routes information
  when those features are used.*

- [ ] **A2. MQ Apple Developer Program organisation account** (D1), with your
  account added as **App Manager or Admin** — not merely a role that can upload.
  A Developer can upload builds but cannot create the app record or submit for
  review; discovering that at submission costs a day of account admin.
  *Evidence: you can (a) create the app record, (b) manage TestFlight, (c) submit
  for review, and (d) reach Certificates, Identifiers & Profiles for signing.*

- [ ] **A3. MQ Google Play Console organisation account**, including developer
  verification and D-U-N-S.
  *Evidence: organisation verification complete, identity and contact details
  accepted, developer website verified where required, and the developer profile
  shows **no outstanding verification action**. A red "complete verification"
  banner discovered at E10 is a self-inflicted delay.*

- [ ] **A4. Written MQ sign-off on redistribution** (spec §8.6) for
  `assets/data/buildings.json` and `assets/maps/aon_event_map.png`.

  **Narrowed by the gauntlet.** `pubspec.yaml:58-64` ships only
  `assets/{images,web,data,maps}`. The vendored PDFs live in
  `docs/source-materials/` and `tools/aon_map/source/` and are **not packaged
  into the IPA or AAB**, so publishing the app does not redistribute them. They
  stay a repo-visibility question, not a release blocker.

  Publishing the two shipped assets **is** the redistribution event; the repo
  being private was never permission.
  *Evidence: an email or ticket filed and linked from the spec, plus a listing of
  the built bundle confirming no PDF is packaged.*

- [ ] **A5. Real stamp codes — a submission-affecting decision, not a chase.**

  **Gauntlet finding (P0).** `stamp_service.dart:54-55` disables passport
  collection in any release build while *any* station's code is a placeholder.
  All 9 are `AON-*-TBC`. So TestFlight and App Review both get a passport that
  cannot be used, showing *"Astronomy Passport opens on event night"*. That state
  is honest and deliberate — but it decides what E3 can truthfully tell a
  reviewer, so choose before submitting:

  - **A5a — codes land.** Organisers supply the 9 real codes; update
    `stamp_stations_data.dart` with `codeConfidence: confirmed`; collection turns
    on in release and a reviewer can drive the passport to a reward. **Requires an
    app-code change and a rebuild**, so it must land before the binary is cut.
  - **A5b — codes do not land. This is NOT a "ship it gated and it's fine" path.**
    The gate reads compiled-in data, so a binary shipped with placeholder codes
    rejects stamps **for ever**, including on 19 September — while the screen
    promises *"Astronomy Passport opens on event night"*. That promise becomes a
    lie the app tells, not merely a plan defect. A5b is therefore only viable
    with one of:
    - **A5b-i** — a committed **1.0.1 containing the real codes, submitted with
      enough review lead time to be approved and distributed before 19 Sep**
      (assume 5-10 days). Which means the codes must land ~a week early anyway,
      so A5b-i buys very little over A5a.
    - **A5b-ii** — **remove the passport from 1.0** (hide the tab/route) and
      reintroduce it when codes exist. Honest, and it removes a dead feature from
      App Review's path.
    - **A5b-iii** — keep it gated but **change the copy** so it stops promising a
      date the binary cannot honour. An app-code delta.

    Choosing "gated, unchanged copy" is choosing to ship a false statement.

  Also ask the two open artwork questions (spec §7): the sheet draws four toilet
  `T` discs while its legend lists three, and the legend's `C` prints over 1CC
  rather than the courtyard. Neither is a code bug.

  *Evidence: the codes, or a written decision to ship A5b.*

- [ ] **A6. Confirm whether MQ owns the cartographic master.** Plan A ships
  `Campus map: Macquarie University` — source, not copyright — because ownership
  is unconfirmed, and `map_attribution_test.dart` forbids the `©` symbol until
  this lands. If MQ confirms ownership, change the copy and the test together.
  *Evidence: a written answer either way.*

  **A6 must never hold the release.** The shipped wording is already the
  conservative one. **No answer by Final Binary Cut → keep the neutral source
  attribution and ship.** A `©` symbol is not worth a slipped launch.

---

## Phase B — Release engineering (start now, ~1 day)

- [ ] **B1. Android upload keystore.**
  Generate a keystore held by MQ (not in the repo, not in a personal password
  manager). Create `android/key.properties` — already git-ignored at
  `.gitignore:68` — and commit a `android/key.properties.sample` beside the
  existing `secrets.properties.sample`.

  **Gauntlet finding (P0): an earlier draft failed OPEN to the debug key.** Its
  comment claimed "a release BUILD asserts below" and no assertion existed — the
  exact comment-versus-code lie this project refuses everywhere else. A release
  build with missing credentials must **fail**, never silently produce a
  debug-signed artifact that looks shippable, uploads, and then fails every Maps
  key restriction for every real user.

  Replace `android/app/build.gradle.kts:42-45`:

  ```kotlin
      val keyProps = Properties().apply {
          val f = rootProject.file("key.properties")
          if (f.exists()) f.inputStream().use { load(it) }
      }

      // All four are required. Presence of the FILE proves nothing — a
      // half-filled key.properties is how a release gets signed wrong.
      val releaseSigningReady = listOf(
          "storeFile", "storePassword", "keyAlias", "keyPassword",
      ).all { !keyProps.getProperty(it).isNullOrBlank() }

      signingConfigs {
          if (releaseSigningReady) {
              create("release") {
                  storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                  storePassword = keyProps.getProperty("storePassword")
                  keyAlias = keyProps.getProperty("keyAlias")
                  keyPassword = keyProps.getProperty("keyPassword")
              }
          }
      }

      buildTypes {
          release {
              if (!releaseSigningReady) {
                  // FAIL CLOSED.
                  throw GradleException(
                      "Release signing is not configured. Create android/key.properties " +
                      "from key.properties.sample with storeFile, storePassword, " +
                      "keyAlias and keyPassword. Debug signing is never used for release.",
                  )
              }
              signingConfig = signingConfigs.getByName("release")
          }
      }
  ```

  `import java.util.Properties` is already at the top of the file.
  `flutter run --release` now needs real credentials locally — that is the point.

  *Evidence: (a) with `key.properties` absent, `flutter build appbundle --release`
  **fails** with that message; (b) with it present the build succeeds and
  `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
  shows the MQ certificate, not `CN=Android Debug`; (c) the upload certificate's
  **SHA-1 and SHA-256** are recorded at generation time — C3 needs them and a
  keystore cannot be regenerated.*

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
  observed use is HTTPS, which is exempt — but that is a conclusion, not the
  working.
  *Evidence: a table — **dependency → version → encryption capability → uses
  OS-provided TLS/crypto or bundles its own → conclusion** — filed with the
  submission.*

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

- [ ] **C1. Create the Play app record and upload a BOOTSTRAP AAB** (internal
  testing track) to enrol the app in Play App Signing.

  **Gauntlet finding (P0): this consumes a version code.** B3 sets `1.0.0+1`, and
  this upload happens *before* C3/C5 install the final Maps and Routes
  credentials — so the bootstrap AAB can never be the release candidate, and Play
  will not accept `+1` twice. Treat `1.0.0+1` as **spent on the bootstrap**, and
  bump to `1.0.0+2` (or the next unused code) for the credentialled candidate at
  Final Binary Cut.

- [ ] **C2. Read EVERY Play App Signing fingerprint** from Play Console → Setup
  → App integrity, plus the upload certificate.

  **Gauntlet finding (P0): there is no longer exactly one production signer.**
  New apps are automatically enrolled in **quantum-ready hybrid signing**, and
  Google states that such apps have **three** keys whose fingerprints must each be
  registered with API providers: a classical key for older devices, a newer
  classical key, and an ML-DSA post-quantum key. Registering one and assuming the
  rest is how Maps fails for a subset of real devices while every build you test
  works.

  *Evidence: SHA-1 and SHA-256 for **every** certificate Play Console exposes,
  recorded — never "the app signing key" singular.*

- [ ] **C3. Create four restricted GCP keys** in MQ's project:
  - Maps SDK for **iOS** — restricted to bundle ID `au.edu.mq.astronomy.aon2026`
  - Maps SDK for **Android** — restricted to package + **every Play-distributed
    signing certificate from C2**. Prefer **two keys** over one: a *production*
    key carrying only the Play signers, and a separate *development/validation*
    key carrying the upload/local certificate. Mixing the upload certificate into
    the production identity set widens the blast radius for no benefit.
  - Routes API × iOS and Android — same restrictions, applied to the web-service
    key. Google's guidance prefers a proxy or an IP-restricted key for web
    services, but documents the direct-call fallback explicitly, and
    `google_routes_service.dart:44-50` already sends exactly the required headers
    (`X-Android-Package` + `X-Android-Cert`, `X-Ios-Bundle-Identifier`). Routes v2
    is the current service, not one of the "older legacy" services the caveat
    covers.

- [ ] **C4. Cap the blast radius — and do not confuse the two mechanisms.** The
  Routes key ships inside the binary and is extractable; that is inherent to the
  documented fallback, not a flaw in it.

  **API quota limits are the technical cap** — they bound request volume. A GCP
  **budget alert does NOT stop spending**; Google is explicit that alert-only
  budgets neither cap usage nor halt billing. An earlier draft implied the budget
  contained the incident. It does not.
  *Evidence: the quota configuration (the cap) and the budget alert (the warning),
  captured separately and described as what each actually is.*

- [ ] **C5. Install the secrets locally, without spilling them.**
  `android/secrets.properties` and `ios/Flutter/Secrets.xcconfig` from the
  committed `.sample` files.

  The Routes keys are extractable from the shipped binary anyway — which is no
  reason to *additionally* leak them into shell history, CI logs, process
  listings and pasted terminal transcripts. Use
  **`--dart-define-from-file=<git-ignored release json/.env>`** carrying
  `MAPS_API_KEY` (enables the native map + flips the capability gate),
  `GOOGLE_MAPS_ANDROID_ROUTES_KEY` and `GOOGLE_MAPS_IOS_ROUTES_KEY`, or masked CI
  secret injection — not inline `--dart-define=KEY=value` on the command line.
  (`MAPS_NATIVE_CONFIGURED` was retired: supplying `MAPS_API_KEY` is now the one
  action that both keys the native map and enables the flow — see
  docs/google-maps-setup.md.)

- [ ] **C6. Prove the restriction REJECTS — positively and negatively.** Not an
  assumption; the M4 IOU made a release gate.

  | Identity | Required result |
  |---|---|
  | correct bundle ID / package + cert | **accepted** |
  | wrong iOS bundle ID | rejected |
  | wrong Android package | rejected |
  | wrong Android certificate | rejected |

  A positive case matters as much as the negatives: a key that rejects
  *everything* also "passes" a negatives-only test, and then ships broken.
  *Evidence — and an earlier draft got this wrong twice.* `google_nav_screen.dart:206`
  reports the status via `debugPrint`, which is not dependable in release; but
  **`tcpdump` cannot read it either**, because the response is inside TLS. A
  packet capture proves *presence or absence* of traffic, never an HTTP status.
  Prove the status with an **instrumented direct request** (curl with the same
  headers) or a **TLS-intercepting test proxy**; keep packet capture for D1's
  traffic-absence question.

  **If C6 fails**, the fallback is not available: fall back to an MQ-hosted Routes
  proxy behind an IP-restricted server key — and note that this puts MQ
  infrastructure into the location-data path, re-opening §2d, §2e and §2f.

---

## Phase D — On-device verification (blocked on C)

Simulator-verified is the standing release IOU. These pay it.

- [ ] **D1. The network test Plan A cannot do.** Unit tests prove the
  architecture; only a capture proves reality.

  **Scope it to the APP, not the device.** An Android phone's OS and Play
  services talk to Google constantly, so "zero traffic to Google hosts" measured
  at device level fails while the app is perfectly compliant. Capture by app
  UID/process, an app-scoped VPN or proxy, or by watching the specific Maps and
  Routes endpoints correlated with deliberate interaction.

  **Four states, because the privacy copy distinguishes map display from
  directions** — this verifies what Plan A's copy actually claims, rather than a
  crude Google-yes/no:

  | State | Required observation |
  |---|---|
  | Cold launch, consent never given | **No** app-attributable Maps or Routes traffic |
  | Accept the map disclosure, open wayfinding | Maps traffic permitted; **no Routes request** |
  | Explicitly request walking directions | Routes traffic permitted |
  | Revoke consent in Settings, retry nav | **No new** Routes request; no new Google surface constructed |

  **State the revocation guarantee honestly.** `GMSServices` cannot be
  un-initialised, so the enforceable claim is *no new app-initiated Google
  surface and no new Routes request after revoke* — not "the SDK goes silent". If
  the capture shows an already-initialised SDK still emitting autonomous
  telemetry, **document it and reconcile the privacy model** (A1, E5) rather than
  pretending otherwise.

  *Evidence: the capture, saved, with each of the four states labelled. Until
  this runs, spec §2b is verified in the test suite and **unverified on a
  device** — say so rather than implying otherwise.*

- [ ] **D2. M4 IOU — live Google render.** Physical iOS and Android: the embedded
  map draws, a walking route returns, and C6's restriction rejection reproduces
  on-device.

  **Specifically: a PLAY-DELIVERED Android build must render Maps**, using the
  Play signer rather than your upload key. That is the whole point of C2's
  multi-fingerprint registration, and a locally-signed build cannot test it.

- [ ] **D3. M5 IOU — heading proof.** The arrow tracks true bearing including the
  12.752°E declination, and the red rose is legible in actual darkness. The
  simulator has no magnetometer, so it only ever exercised the honest
  `unavailable` → list fallback.

- [ ] **D5. Panorama viewer on BOTH platforms — likely already broken on
  Android.** `panorama_server.dart` serves the 360° viewer over
  `http://localhost:$kPanoramaServerPort` via `InAppLocalhostServer`, on a routed,
  reachable screen (`/panorama/:venueId`).

  **iOS:** `Info.plist` declares no `NSAppTransportSecurity` exceptions.
  *If it fails, add `NSAllowsLocalNetworking` — never weaken ATS globally.*

  **Android — this is a bug hunt, not a formality.** `AndroidManifest.xml` sets
  neither `usesCleartextTraffic` nor `networkSecurityConfig`, there is no
  `res/xml/`, and `targetSdk` is 36. Cleartext is **denied by default** at
  targetSdk ≥ 28, and WebView honours that policy. Test this **first**, on a
  physical Android device, before anything else in Phase D.
  *If it fails, add a Network Security Configuration with the **narrowest
  possible** localhost exception — never `android:usesCleartextTraffic="true"`
  globally.*

  **Status (2026-08-22): the Android fix is APPLIED, the on-device confirmation
  is NOT yet done.** `res/xml/network_security_config.xml` now permits cleartext
  to `localhost`/`127.0.0.1` only, with `base-config` still denying everything
  else, and `test/unit/android_cleartext_policy_test.dart` fails if anyone widens
  it to `usesCleartextTraffic="true"`. Verified only that the config **merges
  into the packaged manifest**.

  **Be precise about what that does and does not establish.** The fix rests on
  documented platform behaviour (cleartext denied by default at targetSdk ≥ 28,
  honoured by WebView) plus a verified manifest that carried no override — not on
  an observed failure. Nobody has yet watched a panorama fail without it or
  succeed with it. iOS is untouched, because nothing has shown it to be broken.

  *Evidence still owed: a panorama actually opening on physical iOS and physical
  Android, both from release builds. Any further fix is an app-code delta and
  re-triggers Final Binary Cut.*

- [ ] **D4. Physical smoke test** of the Plan A changes most visible to a user:
  the wayfinding map now requires consent and shows a labelled placeholder when
  declined; Delete my data clears the session; preview mode shows its badge on
  map and compass.

---

## Phase E — Store metadata and submission

- [ ] **E1. Screenshots.** Provide the current **6.9" iPhone** set and, because
  `TARGETED_DEVICE_FAMILY = "1,2"`, the **13" iPad** set.

  **Gauntlet correction.** An earlier draft claimed Plan A Task 12 proved both.
  It proved **iPad only** (1032×1376 / 1376×1032). The largest phone size tested
  anywhere in the suite is **430×932** (`render_matrix_test.dart:62`); a 6.9"
  iPhone is **440×956**. Ten points wider and twenty-four taller is unlikely to
  break a layout that holds at 430×932 — but "unlikely" is not "proven", and that
  distinction is the whole point of this document. Add 440×956 to the render
  matrix, or capture on a 6.9" simulator and look.

- [ ] **E2a. App Store listing.** Name (≤30 chars), subtitle, description,
  keywords, category, copyright, Support URL, Privacy Policy URL, App Review
  contact and notes, availability/territories, price tier (free). Metadata must be
  4+ appropriate regardless of the app's own rating.

- [ ] **E2b. Google Play store listing — an earlier draft omitted this entirely.**
  Play will not publish without: app name, **short description**, full
  description, **512×512 icon**, **1024×500 feature graphic**, **at least two
  screenshots**, category and tags, and support contact details. None of these
  are Apple's fields under different names.

- [ ] **E3. Notes for Review — the 4.2 and 2.1 defence.** Generic notes are
  rejected under 2.3.1(a). State plainly:
  - An official Macquarie University app for a public astronomy night on
    19 Sep 2026.
  - Reviewers are not on campus, so: **turn on Settings → "Preview from
    anywhere"** to see the map dot, compass and nearby list as they work on the
    night. Off campus the app deliberately shows "You're about N km from campus"
    rather than a fabricated position.
  - **The passport — write whichever of these is true**, per A5:
    - *A5a (codes landed):* give the reviewer 3 of the 9 real codes and note that
      manual entry is a first-class peer to the camera
      (`passport_scan_screen.dart:105`), so the passport is fully exercisable
      without a QR sign.
    - *A5b (codes did not land):* state that stamp collection is deliberately
      disabled until the venue codes are final, that the screen reads
      *"Astronomy Passport opens on event night"*, and that this is a designed
      state rather than a failure. **Do not offer `AON-*-TBC`** — a release build
      rejects them, and a reviewer who tries one sees a feature that looks broken.
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

  **Prove it is actually packaged.** A `PrivacyInfo.xcprivacy` sitting in
  `ios/Runner/` without target membership is invisible to the build and a classic
  Xcode trap. *Evidence: open the **archive**, confirm the file is inside the
  Runner product, and confirm it appears in Xcode's aggregated Privacy Report —
  not merely that it exists in the source tree.*

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

- [ ] **E6b. Play "App content" — complete every declaration.** IARC is only one
  item on it. Play also requires privacy policy, ads declaration, app access
  (including any gated content), target audience and content, Data Safety, and
  any sensitive-permission declarations.
  *Evidence: the App content page shows **no release-blocking "Needs attention"**
  item.*

- [ ] **E7. In-app privacy policy link — Apple AND Play.** Apple's 5.1.1(i)
  requires the policy reachable *inside* the app, not only in App Store Connect;
  Play requires an in-app privacy policy link for apps accessing personal or
  sensitive data, which includes location. Add it to Settings once A1
  lands. **This is the one Phase E item that needs app code**, and it is blocked
  on A1.

- [ ] **E8. TestFlight internal** before any public App Store submission.

- [ ] **E9. Play internal testing with the PLAY-SIGNED artifact** before
  Production. Not ceremony — it is the only way to verify C2's app-signing
  fingerprints actually work for delivered builds.

  **Do not substitute Internal App Sharing.** It re-signs uploads with its own
  separate internal-sharing certificate, so a Maps key restricted to the Play
  signers will fail there and tell you nothing about production. The two features
  have near-identical names; only the **Internal testing track** exercises the
  real signer.

- [ ] **E10. Submit.** App Store and Play, with A1's three URLs attached.

---

## Final Binary Cut

The gate that ties the rest together. Signing, credentials, stamp codes, the
privacy link and the networking config are spread across four phases; without a
freeze they get changed after verification and nobody notices.

```
FINAL BINARY CUT
        |
        +-- A5 resolved (codes in, or passport removed, or copy corrected)
        +-- A6 resolved or defaulted to neutral attribution
        +-- E7 privacy-policy URL compiled in
        +-- D5 cleartext config resolved on BOTH platforms
        +-- final Maps/Routes credentials installed (C5)
        +-- version bumped past the bootstrap AAB (C1)
        +-- ./scripts/check.sh full GREEN, exit-gated
        |
        v
   archive IPA + build final AAB
        |
   NO FURTHER CODE OR CONFIG CHANGES
        |
   TestFlight (E8) / Play internal testing (E9)
```

**Any change after the cut — code, asset, plist, Gradle, dart-define — invalidates
the candidate.** Increment the build number, rebuild, and repeat D1's capture,
D5's panorama check, E4's archive audit and D4's smoke test. Not "just this one
small fix".

## Done means

- A signed AAB whose certificate is MQ's, and a signed IPA exported under MQ's
  team.
- **Zero Google traffic before consent, observed on a physical device** (D1) —
  the one acceptance criterion no test suite can supply.
- The Routes key restriction **rejects** a wrong bundle ID / cert (C6).
- Three live `mq.edu.au` URLs, and the policy reachable from inside the app.
- Privacy labels, Data Safety, the privacy manifest, the policy and the in-app
  copy all saying the same thing.
- The panorama opens on physical iOS **and** physical Android release builds.
- Play's App content page shows no release-blocking item, and the Play listing
  carries its icon, feature graphic and screenshots.
- Both stores showing the app as available for public download.

## Risks, named

| Risk | Mitigation |
|---|---|
| **A1 lead time is unknown and unowned.** This is the single most likely cause of missing 19 Sep. | Requested day one, all three URLs together. |
| C6 fails → proxy needed | Costed contingency in §5a; re-opens §2d/§2e/§2f. Decide fast, do not improvise. |
| Review latency + one rejection ≈ 5-10 days | Submit as early as Phase E allows; treat any polish as 1.1. |
| Stamp codes are still `AON-*-TBC`, so the passport is **off in release** | Not fine for App Review *or* the night. A5 forces the choice before the binary is cut. |
| First submission is a 4.2/2.1 rejection | E3 argues it explicitly; Plan A built the reviewability features it points at. |
| **Panorama already broken on Android** (cleartext denied at targetSdk 36, no config) | D5 runs FIRST in Phase D. A routed, reachable screen that silently fails is a 2.1 finding. |
| Maps fails for a subset of real devices | C2 registers **every** quantum-ready Play signing fingerprint, not one; D2 verifies on a Play-delivered build. |
| A post-cut "small fix" ships unverified | Final Binary Cut: any change increments the build number and repeats D1, D4, D5 and E4. |
