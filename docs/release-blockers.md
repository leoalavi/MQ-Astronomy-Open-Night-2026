# Release blockers — Astronomy Open Night 2026

The canonical running register of **unresolved whole-app release prerequisites**.
It exists so product/legal/infra/QA blockers stay out of feature commits and the
final release audit has one checklist to read.

This document is **documentation only**. Adding a blocker here changes no code,
configuration, permissions, consent behaviour, GCP setup or store copy — those
are tracked as their own separate changes when a blocker is actually closed.

---

## Status vocabulary

Use **only** these statuses:

| Status | Meaning |
|---|---|
| `OPEN` | Known, unresolved, no fix in progress that we are tracking here. |
| `BLOCKED` | Cannot progress until an external dependency (a person, an account, a decision) is provided. |
| `UNVERIFIED` | Behaviour cannot be confirmed in the current environment (e.g. needs a physical device). |
| `RESOLVED — AWAITING VERIFICATION` | A change was made that should close it, but the closing evidence has not yet been captured. |
| `CLOSED — VERIFIED` | The required evidence has been obtained and recorded below. |
| `CLOSED — OWNER DECISION (accepted risk)` | No evidence was obtained; the project owner decided to proceed anyway, with the decision, the date and the residual risk recorded. Never a substitute for `CLOSED — VERIFIED`. |

### The evidence rule (non-negotiable)

> A blocker may only be marked **CLOSED — VERIFIED** when the required evidence
> has actually been obtained. Code completion, configuration intent, verbal
> confirmation, or a proposed fix is **not** sufficient.

---

## Release Decision Rule

The final whole-app release audit **must read this file before issuing GO / NO-GO.**

A final **`GO — RELEASE READY`** must **not** be issued while any blocker
classified as release-blocking remains `OPEN`, `BLOCKED`, `UNVERIFIED`, or
`RESOLVED — AWAITING VERIFICATION`. Only `CLOSED — VERIFIED` (or a blocker
explicitly downgraded to non-release-blocking, with the rationale recorded here)
clears the path to GO.

---

## Register

| ID | Release blocker | Category | Owner | Status |
|----|-----------------|----------|-------|--------|
| B1 | iOS `NSLocationWhenInUseUsageDescription` says location is "never sent anywhere", but Google Routes can transmit the user's origin after Maps consent | Store disclosure / privacy | Product/legal | `CLOSED — VERIFIED` |
| B2 | Maps Directions currently uses implicit auto-accept on first use rather than an explicit disclosure; wording referring to "after you agree" must be reconciled with the intended consent posture | Privacy / product decision | Product/legal | `CLOSED — VERIFIED` |
| B3 | Live Google walking routes answer HTTP 200. **Re-verified 2026-09-07: BOTH the iOS and the Android Routes keys are unrestricted** — six live probes all returned 200, including with no identity header and with a deliberately wrong app id. The Android key had never been tested before | Infrastructure / security | Infra | `OPEN` — billing/abuse exposure |
| B4 | Real-device validation remains outstanding for GPS field accuracy, magnetometer/compass behaviour and live Google route rendering | Physical-device QA | QA | `UNVERIFIED — PHYSICAL DEVICE REQUIRED` |
| B5 | Passport station codes (were placeholders, now live in-app); the generated signs must be the ones printed and installed | Event configuration | Organisers | `CLOSED IN APP — SIGNAGE INSTALL PENDING` |
| B6 | Redistribution permission — three University asset sets settled by the owner's attestation (2026-09-05); the **Home hero photograph** ships on its existing credit by the owner's explicit decision, with the residual 5.2 risk accepted | Asset rights | Owner (decided) | `CLOSED — OWNER DECISION (accepted risk)` |
| B7 | **Support URL found** (`event.mq.edu.au/astronomy-open-night/`, verified live 2026-09-05); the in-app policy surface exists offline; the **Privacy Policy URL is still unhosted** — and MQ's own institutional policy cannot substitute | Store publishing / privacy | Organisers / product | `OPEN` — Privacy Policy URL only |

---

## B1 — iOS location purpose string contradicts the Routes path

- **Exact problem.** `ios/Runner/Info.plist` (`NSLocationWhenInUseUsageDescription`)
  reads: *"Shows where you are on the campus map so you can find your way between
  venues at night. Your location stays on your device and is never sent
  anywhere."* The final sentence is false: when the visitor requests Google
  walking directions, the live origin `latLng` is POSTed to the Google Routes
  API after Maps consent.
- **Why it matters for release.** An inaccurate App Store privacy disclosure is a
  review-rejection risk and contradicts the app's own in-app privacy copy and
  hosted policy. It is a truthfulness issue, not a cosmetic one.
- **Evidence / source.** `ios/Runner/Info.plist:8` vs
  `lib/services/google_routes_service.dart:58` (origin in the request body);
  `ARCHITECTURE.md` §10.3 / Risk R1 (re-verified present 2026-09-01).
- **Owner.** Product / legal (store-facing copy).
- **Status.** `CLOSED — VERIFIED` (2026-09-01).
- **Exact condition to close.** The purpose string is reworded to truthfully
  describe the Routes transmission (e.g. drop "and is never sent anywhere", or
  state "…sent to Google only when you ask for walking directions"), consistent
  with `settingsPrivacyBody` and the hosted policy.
- **Verification evidence required.** The shipped `Info.plist` string, quoted,
  showing the corrected wording in the build that is submitted; confirmation it
  matches the in-app and hosted privacy copy.
- **Closure evidence (2026-09-01).** Implementation commit `0266e6e`. A
  current-HEAD iOS build succeeded (`flutter build ios --simulator`), and the
  packaged `build/ios/iphonesimulator/Runner.app/Info.plist` — an Apple binary
  property list, not a source copy — was inspected with `PlistBuddy`:
  `NSLocationWhenInUseUsageDescription` reads *"Shows where you are on the campus
  map and points the compass toward venues at night. Your location is sent to
  Google only when you choose walking directions."* The old "never sent anywhere"
  claim is absent and the Google / walking-directions transmission is stated
  truthfully. Guarded by `test/unit/ios_location_purpose_test.dart`; consistent
  with `settingsPrivacyBody` (EN + FA) and the hosted policy
  (`docs/release/hosted-pages.md`). Full gate `CHECK PASSED`, exit 0, coverage
  91.01%. (Recommend a final spot-check of the submission archive's Info.plist at
  store-submission time; the string is build-invariant.)

## B2 — Implicit consent vs the "after you agree" wording

- **Exact problem.** The live Directions path auto-accepts a first-run `unknown`
  Maps consent (`google_nav_screen.dart` `_autoAcceptOnce()`) instead of showing
  an explicit pre-draw disclosure modal; the old `MapsNavDisclosure` dialog is
  reachable only from the dead `wayfinding_screen.dart`. Privacy copy that says
  location is sent "only … after you agree" now effectively means *asking for
  directions is agreeing*.
- **Why it matters for release.** Implied consent for transmitting location to a
  third party is a privacy-posture decision with legal/store implications; the
  copy and the mechanism must agree.
- **Evidence / source.** `lib/screens/google_nav_screen.dart` (auto-accept),
  `lib/services/maps_nav_providers.dart` (`ConsentGuardedRoutesService`),
  `ARCHITECTURE.md` §10; tests `google_nav_screen_test.dart`
  ("first-run auto-proceeds no modal"), `settings_google_consent_test.dart`.
  Note: the §2b technical boundary (no Google surface initialises before
  `consent == accepted`) still holds — this is about the *posture and copy*, not
  a leak.
- **Owner.** Product / legal.
- **Status.** `CLOSED — VERIFIED` (2026-09-01).
- **Exact condition to close.** A recorded decision that the implicit-accept
  model is intended (or a change back to explicit consent), with all
  user-facing consent/privacy copy reconciled to whichever model ships.
- **Verification evidence required.** The decision recorded here; the shipped
  consent flow and the shipped copy quoted and shown to agree.
- **Decision (2026-09-01).** Ship **explicit first-use consent** (Option B), not
  implicit auto-accept. The auto-accept path was removed and the
  `MapsNavDisclosure` dialog restored on the live Directions path.
- **Closure evidence (2026-09-01).** Implementation commit `ae7d846`; closure
  tests + comment reconciliation in `20ae574`. `mapsSdkReadyProvider` returns
  false and never calls `ensureInitialized()` unless `consent == accepted`, so no
  Google surface can initialise before agreement (enforcement point verified in
  source + `maps_sdk_boundary_test.dart` / `routes_consent_guard_test.dart`).
  On-device runtime (iPhone 17 sim, Maestro MCP): Decline `map-wayfinding.yaml`
  16/16; Accept + persistence `privacy-consent.yaml` 16/16; Revoke → retry →
  explicit re-enable `privacy-revoke-retry.yaml` 25/25 (the retry is NOT silently
  re-accepted — it lands on the honest sharing-off panel); Persian RTL first-use
  disclosure `privacy-consent-fa.yaml` 17/17. 58 targeted privacy tests green. The
  hosted policy (`docs/release/hosted-pages.md`) and the EN/FA in-app copy are
  reconciled to the explicit model ("asks you before"; "sent to Google only … and
  only after you agree"). Full gate `CHECK PASSED`, exit 0, coverage 91.01%.

## B3 — Google Routes: 401 resolved; the shipped key is unrestricted

- **The 401 is gone. Verified 2026-09-05, against the live API.** A real
  `POST https://routes.googleapis.com/directions/v2:computeRoutes` with the
  shipped `GOOGLE_MAPS_IOS_ROUTES_KEY`, the app's own headers and the app's
  bundle identifier returned **HTTP 200** and a real walking route — West 6
  parking (`-33.773681, 151.1075241`) → Macquarie Theatre
  (`-33.7746334, 151.1122714`): `distanceMeters: 581`, `duration: "476s"`. The
  API is enabled, billing is live and the key is scoped for Routes. No secret
  was printed at any point.
- **A different problem was found in the same check, and it is the one that now
  matters.** The same request succeeded **with no `X-Ios-Bundle-Identifier`
  header at all**, and again with a deliberately wrong bundle id
  (`com.example.notours`). Both returned HTTP 200. The key therefore has **no
  application restriction** in the GCP console.
  - Why that is serious: the key ships inside the app binary and is trivially
    extractable — `routes_client_identity.dart` says so itself, and calls the
    identity headers "load-bearing". They are only load-bearing if the server
    enforces them. Right now anyone who pulls the key out of the IPA can bill
    this project's GCP account for Routes calls, from anywhere.
  - This is **not** an App Review blocker; it is a billing and abuse exposure
    that should be closed before the app is public, and certainly before the
    event night.
- **Why it matters for release.** Walking directions are a headline navigation
  feature. They now work. What is unproven is that they work *on a real device
  over real GPS* — that is B4, not this blocker.
- **Evidence / source.** Live API check 2026-09-05 (above);
  `docs/map-audit-2026-08-30.md` §11 (GCP checklist); `ARCHITECTURE.md` Risk R2.
- **Owner.** Infra (GCP console).
- **Status (2026-09-07 12:40).** `VERIFIED AT THE API — two manual steps left`.
  Both new keys probe **200 / 403 / 403**: correct identity accepted, missing and
  wrong identity rejected. Values are in `.env`, `android/secrets.properties`
  and `ios/Flutter/Secrets.xcconfig` (never printed; copied clipboard→file). A
  keyed release APK builds and its manifest carries the Android key.
  **Found and fixed on the way:** `MainActivity.signingCertSha1()` emitted the
  SHA-1 *with colons*; Google 403s that form (`"Requests from this Android
  client application … are blocked"`) and accepts plain hex. Against the old
  unrestricted key it never mattered; against the new one **every Android
  directions request would have failed on cut-over.** Native now emits plain
  hex and Dart normalises defensively (`normaliseAndroidCert`, unit-tested).
  **Still to do by hand:** add the Play App Signing SHA-1 to `aon2026-android`,
  and delete the old `Astronomy` key.
- **RE-VERIFIED 2026-09-07 — still open, and WIDER than recorded.** The
  2026-09-05 check tested only the iOS key. Both keys were re-tested against the
  live API; **all six probes returned HTTP 200**:

  | Key | correct identity | no identity header | wrong identity |
  |---|---|---|---|
  | iOS Routes | 200 | **200** | **200** (`com.example.notours`) |
  | **Android Routes** | 200 | **200** | **200** (wrong package) |

  So the **Android Routes key is unrestricted too** — that was never previously
  tested. Neither key enforces the identity headers the client carefully sends.

- **The Maps SDK key is embedded in plaintext and is trivially extractable.**
  Confirmed by `aapt2 dump xmltree --file AndroidManifest.xml` on the release
  APK: `com.google.android.geo.API_KEY` carries the literal key string. This is
  normal and unavoidable for a mobile client — **an API key in a shipped app is
  not a secret.** Google's protection model is application + API restriction,
  not secrecy, which is exactly why this blocker matters.

- **Exact condition to close.** In the GCP console, for **both** Routes keys and
  the Maps SDK key:
  1. **iOS key → Application restrictions → iOS apps**: bundle id
     `au.edu.mq.astronomy.aon2026`.
  2. **Android key → Application restrictions → Android apps**: package
     `au.edu.mq.astronomy.aon2026` plus **every SHA-1 that can sign an install**:
     - the **Play App Signing** SHA-1 (Play Console → Setup → App signing) —
       this is the one real users hit, because Play re-signs the AAB;
     - the **upload key** SHA-1
       `A4:26:BD:18:EF:21:BC:FD:05:FA:95:A2:D5:EF:C3:03:A5:CD:92:6D`
       — needed for locally built release APKs and internal testing;
     - the **debug** keystore SHA-1, only if debug builds are ever pointed at
       the live key.

     **Why all of them:** `MainActivity.signingCertSha1()` reads the *live*
     `apkContentsSigners` at runtime, so the header is the Play App Signing cert
     on a Play install and the upload cert on a local build. Registering only
     the upload key works on every build you test and fails for every real user.
  3. **API restrictions** on each key: Routes API for the Routes keys; Maps SDK
     for Android / Maps SDK for iOS on the Maps key. Nothing else.

- **Verification evidence required.** Re-run `b3_check.sh` (see below): the
  probes carrying a correct identity return **200**, and the four without a
  valid identity return **403**. Then a live route on a physical device (B4).

- **Repeatable check.** `tools/security/check_routes_key_restrictions.sh` runs
  all six probes and prints status codes only — it never echoes a key.

- **Console work done 2026-09-07 (Claude in Chrome, Raouf's session).** The
  keys live in GCP project **`gen-lang-client-0843778974` ("GitSwitch")** — a
  shared Gemini/gen-lang project, not an AON-specific one. It now holds three:

  | Key | Application restriction | API restriction | Status |
  |---|---|---|---|
  | `aon2026-android` | Android apps: `au.edu.mq.astronomy.aon2026` + upload SHA-1 `A4:26:…:92:6D` | Maps SDK for Android + Routes API (2) | **NEW** — Play App Signing SHA-1 still to add |
  | `aon2026-ios` | iOS apps: `au.edu.mq.astronomy.aon2026` | Maps SDK for iOS + Routes API (2) | **NEW** — complete |
  | `Astronomy` (Apr 22) | **none** | **35 APIs** — the whole Maps Platform catalogue | the old shared key; **retire after cut-over** |

  Neither new key was created service-account-bound (the org policy
  `iam.managed.disableServiceAccountApiKeyCreation` only governs those; plain
  Maps keys are unaffected). The old key's `35 APIs` is a wider blast radius than
  this blocker had recorded: Places, Roads, Solar, Aerial View, Street View and
  Navigation SDK are all callable with it today.

- **Remaining, in order.** (1) Copy the two new values into `.env`,
  `android/secrets.properties` (create it) and `ios/Flutter/Secrets.xcconfig` per
  `docs/google-maps-setup.md`; (2) add the **Play App Signing** SHA-1 to
  `aon2026-android`; (3) run the check script — want 200/403/403 on both;
  (4) rebuild with `--dart-define-from-file=.env` and confirm directions on a
  device; (5) **delete `Astronomy`** — while it exists the hole stays open.

## B4 — Physical-device validation outstanding

- **Exact problem.** GPS field accuracy, magnetometer/compass heading (the
  rotating rose), and live Google route rendering have only ever been exercised
  on the iOS Simulator, which has no magnetometer and no real GPS.
- **Why it matters for release.** A simulator cannot prove real-world heading,
  positional accuracy, or the on-the-night walking experience; these are exactly
  the behaviours a night-time campus visitor depends on.
- **Evidence / source.** `ARCHITECTURE.md` §16 ("Manual validation still
  required"); `docs/map-audit-2026-08-30.md` standing IOUs; Map audit 2026-09-01
  (compass rose + live route explicitly marked UNVERIFIED).
- **Owner.** QA.
- **Status.** `UNVERIFIED — PHYSICAL DEVICE REQUIRED`.
- **Exact condition to close.** A structured on-campus (or representative)
  physical-device pass covering: the location dot settling to a plausible real
  position, the compass rose orienting to a real heading, and a live walking
  route rendering. **The checklist is written and ready to work through:
  `docs/release/device-qa-checklist.md`** (2026-09-05) — location, directions,
  passport/camera/torch, haptics, Dynamic Type, 360°, Persian RTL and a
  night-conditions pass.
- **Verification evidence required.** Dated device notes plus screenshots /
  recording from a real iPhone (and ideally Android) on campus, naming the
  device and OS.

## B5 — Passport production codes (was: placeholders)

- **Exact problem (as raised).** All nine Astronomy Passport station codes
  shipped as `AON-*-TBC` placeholders; the domain release gate kept prize
  collection disabled in release builds while any code was a placeholder.
- **Why it mattered for release.** The Passport stamp rally is a headline
  engagement feature and was inert on the night until real codes existed.
- **Evidence / source.** `docs/data-sources.md` open question 9;
  `ARCHITECTURE.md` Risk R3.
- **Owner.** Organisers (print + install); product (codes).
- **Status.** `CLOSED IN APP — SIGNAGE INSTALL PENDING`.
- **What changed (2026-09-04).** Rather than wait on an external code list, the
  nine codes were minted in the app itself and the signs are generated from
  them, which removes the drift risk entirely: there is exactly one source.
  `lib/data/stamp_stations_data.dart` now carries live codes
  (`AON-A-FL3R` … `AON-I-JRYL`), every station is
  `DataConfidence.confirmed`, and `PassportPolicy.isCollectionEnabled` returns
  true for release builds. The suffix alphabet excludes `0/O`, `1/I`, `2/Z`,
  `5/S`, `6/G` and `8/B` so the printed manual-entry fallback survives being
  typed in the dark; a test enforces that.
- **Verification (2026-09-04).** `tools/passport/build_station_qr.py`
  regenerated the nine A4 signs. All nine bare QR PNGs and all nine PDF pages
  (rasterised at 300 dpi) decoded back to exactly the `AON2026:<CODE>` payload
  `StampService` accepts — 18/18 — and no page carries the DRAFT watermark.
  Dart side: `test/unit/stamp_service_test.dart` group *printed station signs*
  asserts every station's printed payload resolves to that station by scan and
  by hand.
- **What is genuinely left, and it is not code.** The app now accepts these
  nine codes and nothing else. **The signs the organisers print must be the ones
  this generator produces** (`build/passport-qr/AON2026-passport-stations.pdf`).
  If MQ has its own signage or its own code scheme, that list must replace these
  in `stamp_stations_data.dart` and the signs must be regenerated — the app is
  the source of truth, so a sign made anywhere else will scan to nothing.
- **Remaining evidence required.** Confirmation the nine generated signs are
  printed and installed at stations A–I, and one on-campus scan of a release
  build producing a stamp. Also still open: the accessible redemption
  alternative at the prize booth.

## B6 — Asset redistribution permission (narrowed to the Home hero photograph)

- **Exact problem.** Redistribution permission was unconfirmed for four bundled
  asset sets: the campus basemap artwork, `buildings.json`, the 39 360°
  photographs, and the Home hero photograph.
- **Narrowed 2026-09-05 by the owner's attestation.** Raouf stated: *"all the
  assets and material are ours. And if it's not ours, we already cited."* That
  settles the three University sets — basemap artwork, `buildings.json` and
  `assets/data/indoor/*.jpg` — which are the project's own material.
- **The fourth is not settled, and the reason is not a technicality.**
  `assets/images/hero_deep_triangulum_galaxy.jpg` ("A Deep Triangulum Galaxy")
  is Aleix Roig's photograph. The app **credits** it; a credit is not a licence.
  The repo README states the position itself: *"Rights remain with the
  photographer. Do not reuse it outside this project without permission."* Two
  surfaces are affected — the bundled app, and the store screenshots
  (`01-home.png` on both iPhone and iPad show the hero), which are marketing
  rather than "this project".
- **Why it matters for release.** Apple guideline 5.2 makes the submitter
  responsible for third-party content and App Review can ask for the written
  authorisation. This is also a straightforward copyright question independent
  of either store.
- **Evidence / source.** `docs/release/organiser-requests.md` §1;
  `docs/panorama-image-provenance.md`; `README.md` (hero image licence note);
  `ARCHITECTURE.md` Risk R4.
- **Owner's decision, 2026-09-05.** Asked to choose between obtaining the
  photographer's written permission, substituting an owned image, or shipping on
  the existing credit, Raouf chose **ship as-is on the credit**. Recorded here
  as made, by whom, and on what basis — this is a decision to accept a risk, not
  evidence that the risk is absent.
- **What that does and does not change.** It closes this blocker for release
  purposes. It does **not** create a licence. If App Review asks for
  authorisation for the hero photograph (guideline 5.2), or if the photographer
  objects, the answer will still have to be obtained then — so keep the
  ready-to-send request in `docs/release/organiser-requests.md` §1 rather than
  deleting it, and note that swapping the hero is a small, low-risk change if it
  is ever needed: one asset, `heroCredit` in `event_config.dart`, the Credits
  screen and the affected store screenshots.
- **Owner.** Decided by the project owner.
- **Status.** `CLOSED — OWNER DECISION (accepted risk)`. Deliberately **not**
  `CLOSED — VERIFIED`: the register's evidence rule says a decision is not
  evidence, and no written permission exists.
- **Would reopen this.** A request from App Review, contact from the
  photographer, or any use of the image beyond the app and its store listing.

## B7 — Store privacy/support publishing prerequisites

- **Exact problem.** The production Privacy Policy / Support store-metadata URLs
  are not yet provisioned. The finished policy/support copy exists in
  `docs/release/hosted-pages.md` but is not hosted.
- **Partly closed 2026-09-05 by `46dc81e`.** The *in-app* half is done: Settings
  now carries a Privacy Policy card (`settings_screen.dart:146`,
  `_PrivacyPolicyCard`) that opens `config.privacyPolicyUrl` when one is
  configured and otherwise shows the full policy **offline, in a dialog**
  (`settingsPrivacyPolicyBody`, EN + FA), so the requirement is met even before
  hosting exists. `test/widget/settings_privacy_policy_test.dart` covers both
  paths. Android ships `docs/release/android-privacy-policy.html` for the Play
  field. The old evidence line below — "no `url_launcher` / `launchUrl` anywhere
  in `lib/`" — is superseded: `lib/services/url_opener.dart` is now the single
  seam that opens external links. **Conditions 2 and 6 are met; the blocker stays
  `OPEN` on the hosted URLs and the store-metadata fields (1, 3, 4, 5, 7–10),
  which only the organisers can provide.**
- **Verified 2026 store requirements.**
  - Apple requires a **Privacy Policy URL for all apps**.
  - Apple's App Review Guidelines require the privacy policy to also be
    **accessible within the app**.
  - Apple requires a **Support URL** for the app version.
  - Apple's **Marketing URL is optional** — it must **not** be described as
    mandatory. (Do not claim any "three URLs are mandatory" figure unless a
    separate project requirement establishes a third required URL.)
  - Google Play requires every app to provide a **privacy policy in Play
    Console** and a **privacy-policy link or text within the app**.
- **Why it matters for release.** App Store Connect / Google Play will not accept
  a submission without the mandated policy/support metadata, and both stores
  require the privacy policy to be reachable from inside the app — which this
  build does not currently offer. This blocks store submission (it does not
  affect on-the-night in-app behaviour).
- **Evidence / source.** `lib/screens/settings_screen.dart:146` (policy card,
  online + offline paths) and `lib/services/url_opener.dart`;
  `docs/release/hosted-pages.md` (ready, unhosted copy);
  Apple App Store Connect privacy/URL fields + App Review Guidelines; Google
  Play policy requirements.
- **Support URL resolved 2026-09-05.** The official event site,
  <https://event.mq.edu.au/astronomy-open-night/>, is public HTTPS, needs no
  login, is Macquarie's own, is specific to this event, and carries the
  enquiries address `astronomyopennight@mq.edu.au`. Fetched and read on
  2026-09-05; it also states the event as Saturday 19 September 2026, 4pm–10pm,
  matching `EventConfig`. That satisfies condition 4. *(It also says the event
  is currently sold out and that no tickets are sold on the night — worth the
  organisers deciding whether the app should say so; the app currently does
  not, and that is a content question, not a store blocker.)*
- **Why Macquarie's own Privacy Policy cannot be used, checked rather than
  assumed.** `policies.mq.edu.au/document/view.php?id=107` scopes itself to
  employees, students, researchers and people handling information on the
  University's behalf, across its "learning and teaching, research, engagement,
  and associated administrative activities". Members of the public at an event
  are not in scope, and it addresses no mobile app, no location transmission to
  Google, and no ML Kit diagnostics. Pointing App Review at it would be an
  inaccurate disclosure — B1's defect, one layer out. Full reasoning:
  `docs/release/app-store-connect-final-checklist.md` §1.
- **Hosting decided 2026-09-05.** Asked whether the University's own privacy
  policy could be used: no — it does not describe this app's behaviour (Routes,
  Google Maps' own collection, ML Kit) and a policy that does not match the app
  is itself a 5.1.1 defect. What *is* right, and is what this blocker always
  wanted, is **MQ hosting the app's own policy** — the finished copy in
  `hosted-pages.md` — at an `mq.edu.au` URL. Any stable public HTTPS URL
  satisfies both stores if MQ hosting is slow. Reasoning recorded in
  `docs/release/hosted-pages.md`.
- **Owner.** Organisers (host the pages) + product (add the in-app entry point).
- **Status.** `OPEN`.
- **Exact conditions to close.**
  1. The production Privacy Policy page is hosted at a stable HTTPS URL.
  2. The app exposes the Privacy Policy in an easily accessible location
     (preferably Info or Settings).
  3. The App Store Connect Privacy Policy URL is configured.
  4. The App Store Connect Support URL is configured and leads to real
     support/contact information.
  5. The Google Play privacy-policy field points to the live policy.
  6. The Android app exposes the privacy-policy link/text as required.
  7. The hosted policy accurately matches actual app behaviour, including the
     Google Routes / location-sharing path (see B1).
  8. The links are tested from release builds.
  9. Store metadata is verified before submission.
  10. The App Store **App Privacy** answers and Google Play **Data safety**
      declarations are completed — including how the location transmitted to
      Google Routes for walking directions is classified (app "conduit" vs
      data "collection" under each store's definitions). **App Store: DECIDED
      2026-09-06.** The classification is "collection", declared as **Precise
      Location — App Functionality, not linked, not tracking**, alongside the
      embedded Google Maps SDK rows (Coarse Location, Identifiers, Product
      Interaction, Other Usage Data, Crash Data, Performance Data — all App
      Functionality, not linked, not tracking). This is the conservative answer
      and matches the app's own in-app privacy copy and hosted policy. The single
      authoritative answer set lives in
      `docs/release/app-store-connect-final-checklist.md` §3. Google Play **Data
      safety** mirrors the same set when the Android submission is prepared
      (out of scope for the current Australia-only App Store pass).
- **Required closure evidence.** Live production URLs; release-build
  screenshots / E2E proving the in-app privacy-policy entry works; App Store
  Connect metadata verification; Play Console metadata verification; a successful
  HTTP response for the production pages; and a final privacy-content
  consistency review.

---

## Info + Settings audit verdict (2026-09-01)

Recorded so a stored conclusion is not stale: the Info + Settings subsystem has
**no implementation defect** (privacy copy is truthful and test-guarded, erase is
scope-accurate and session-before-storage, preview is session-only and badged,
language/theme persist, RTL is correct). But because of **B7** (no accessible
in-app privacy-policy surface) it is not store-release-ready:

- **INFO → CONDITIONAL GO** — implementation is good, but the app lacks the
  required accessible privacy-policy surface (B7).
- **SETTINGS → CONDITIONAL GO** — implementation is safe; gated on B1 (iOS
  purpose string), B2 (consent posture) and B7.
- **COMBINED → CONDITIONAL GO — RELEASE DECISIONS/PREREQUISITES REMAIN.**

---

## Change log

- 2026-09-06 — **Build 3 shipped to TestFlight; App Review contact + App Privacy
  finalized.** Repo-side release prep completed against the actual state:
  **Build 3 (`1.0.0+3`) is uploaded to App Store Connect and approved for
  external TestFlight**; the external organiser testing group exists and the
  public TestFlight link is ready to share. **ITMS-90683 → `CLOSED — VERIFIED`**:
  the Build 3 binary carries both location purpose strings and no
  `UIBackgroundModes`, and Apple accepted the binary for external beta review
  without the warning recurring. **App Review contact supplied by Leo** (Leo
  Alavi, `leo.alavi.dev@gmail.com`, `+61451519624`) and pasted into
  `app-review-notes.md`. **App Privacy answer set finalized** as the single
  source of truth in `app-store-connect-final-checklist.md` §3 (see B7
  condition 10). No code changed; **no Build 4 required**. Stale text removed
  from the ASC checklist (Build-3-uploaded and ITMS rows) and the submission
  checklist. Remaining external items unchanged: Privacy Policy hosted URL,
  asset-rights and copyright (Liz/Macquarie); B3 GCP key restriction and B4
  device pass (Raouf); B5 signage install.
- 2026-09-06 — **Australia-only distribution decided by the owner.** The release
  ships to **Australia only**; all other App Store territories are deselected in
  App Store Connect. Consequence recorded across the release docs: **no DSA
  trader-status declaration is required** — Apple asks for it only for EU
  territories, none of which are selected, so the "trader vs. non-trader" legal
  determination is not reached. **This is not a blocker** and no DSA/EU blocker
  is added to the register. DSA must be **revisited only if EU availability is
  ever added** in a later release, at which point the trader-status declaration
  becomes mandatory again. See `docs/release/app-store-connect-final-checklist.md`
  §5 (row 10 `NOT APPLICABLE`) and the availability row (19). No code, config or
  consent behaviour changed. B3, B4, B7 remain as recorded.
- 2026-09-05 — Apple App Store release audit (`APPLE_RELEASE_AUDIT.md`). No
  new blocker. Closed in code: the iOS privacy manifest now declares the two
  required-reason APIs statically linked into Runner (SystemBootTime 35F9.1 via
  `sensors_plus`, FileTimestamp C617.1 via `package_info_plus`) — an
  ITMS-91053 upload risk; the App Review notes no longer claim the passport
  codes "do not exist yet"; the launch screen matches the dark first frame.
  The build-number bump to `1.0.0+2` is deliberately deferred to the commit
  that is archived as TestFlight Build 2 (Build 1 was uploaded 2026-09-05). Onboarding evaluated and
  deliberately **not** implemented (`docs/onboarding-decision.md`). B3, B4, B6,
  B7 remain as recorded — all four are people/infra, not code.
- 2026-09-01 — Register created with B1–B6 from the Home/Program and Map
  release-readiness audits. All items OPEN or UNVERIFIED; none CLOSED — VERIFIED.
- 2026-09-01 — Added **B7** (store privacy/support publishing prerequisites) from
  the Info + Settings audit: the app has no accessible in-app Privacy Policy
  surface and the production URLs are unhosted. Recorded the Info + Settings
  verdict as CONDITIONAL GO (no implementation defect; blocked by B7). Scoped to
  the verified 2026 store rules — a Marketing URL is optional, not mandatory.
- 2026-09-01 — **B1 and B2 → CLOSED — VERIFIED.** Privacy Release Audit
  (commits `0266e6e`, `ae7d846`, `1b0ca63`) + Privacy Closure Verification
  (commit `20ae574`). B1: current-HEAD iOS build + packaged `Runner.app`
  Info.plist inspected (truthful Google/walking-directions wording, old "never
  sent anywhere" gone). B2: explicit first-use consent; `mapsSdkReadyProvider`
  gates the SDK on `accepted`; on-device Maestro runtime — Decline 16/16, Accept +
  persistence 16/16, Revoke → retry 25/25, Persian RTL 17/17; 58 targeted privacy
  tests green; full gate `CHECK PASSED` at 91.01%. B7 stays OPEN. Store App
  Privacy / Play Data safety classification of location→Google flagged
  **LEGAL/POLICY REVIEW REQUIRED** (B7 condition 10).
