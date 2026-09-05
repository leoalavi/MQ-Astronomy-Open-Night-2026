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
| B3 | Live Google walking-route rendering still requires production GCP Routes API enablement, billing/key restrictions and successful end-to-end verification | Infrastructure | Infra | `OPEN` |
| B4 | Real-device validation remains outstanding for GPS field accuracy, magnetometer/compass behaviour and live Google route rendering | Physical-device QA | QA | `UNVERIFIED — PHYSICAL DEVICE REQUIRED` |
| B5 | Passport station codes (were placeholders, now live in-app); the generated signs must be the ones printed and installed | Event configuration | Organisers | `CLOSED IN APP — SIGNAGE INSTALL PENDING` |
| B6 | Redistribution permission remains unresolved for four panorama asset sets | Asset rights | Organisers | `OPEN` |
| B7 | Production Privacy Policy / Support store URLs are not yet provisioned (the in-app policy surface was added 2026-09-05 by `46dc81e` and works offline) | Store publishing / privacy | Organisers / product | `OPEN` |

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
  (`docs/release/mq-hosted-pages.md`). Full gate `CHECK PASSED`, exit 0, coverage
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
  hosted policy (`docs/release/mq-hosted-pages.md`) and the EN/FA in-app copy are
  reconciled to the explicit model ("asks you before"; "sent to Google only … and
  only after you agree"). Full gate `CHECK PASSED`, exit 0, coverage 91.01%.

## B3 — Live Google walking routes need production GCP configuration

- **Exact problem.** Walking-route requests are code-correct but do not render a
  live route; the Google Routes API returns HTTP 401 in the current environment
  because the API is not enabled / the key is not scoped for it. This is external
  GCP configuration, not an app-code defect.
- **Why it matters for release.** Walking directions are a headline navigation
  feature; without the configuration they never produce a route for users
  (the app degrades honestly to "temporarily unavailable" / external hand-off,
  so it is shippable, but the feature is inert until closed).
- **Evidence / source.** `docs/map-audit-2026-08-30.md` §11 (GCP checklist);
  `ARCHITECTURE.md` Risk R2; on-device 401 field logs.
- **Owner.** Infra.
- **Exact condition to close.** On the same GCP project as the key: Routes API
  enabled, billing on, the key's API restrictions allow Routes API (+ Maps SDK
  iOS/Android), region scoped, and all three Play App Signing fingerprints
  registered for Android.
- **Status.** `OPEN`.
- **Verification evidence required.** A live walking route rendering
  end-to-end on device after accepting consent (screenshot or passing
  `map-wayfinding` accept-path E2E), with a real HTTP 200 from
  `routes.googleapis.com`. No secrets pasted.

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
  route rendering.
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

## B6 — Panorama asset redistribution permission unresolved

- **Exact problem.** Redistribution permission is unconfirmed for four of the
  360° panorama asset sets bundled in the app.
- **Why it matters for release.** Shipping imagery without redistribution rights
  is a legal/store-compliance risk that blocks public release.
- **Evidence / source.** `docs/panorama-image-provenance.md`;
  `ARCHITECTURE.md` Risk R4.
- **Owner.** Organisers (rights holders / photographer sign-off).
- **Status.** `OPEN`.
- **Exact condition to close.** Written redistribution permission obtained for
  each of the four asset sets (or the unlicensed assets removed).
- **Verification evidence required.** The written permission recorded per asset
  set, or confirmation the affected assets are no longer bundled.

## B7 — Store privacy/support publishing prerequisites

- **Exact problem.** The production Privacy Policy / Support store-metadata URLs
  are not yet provisioned. The finished policy/support copy exists in
  `docs/release/mq-hosted-pages.md` but is not hosted.
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
  `docs/release/mq-hosted-pages.md` (ready, unhosted copy);
  Apple App Store Connect privacy/URL fields + App Review Guidelines; Google
  Play policy requirements.
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
      data "collection" under each store's definitions). **LEGAL/POLICY REVIEW
      REQUIRED — do not self-answer this classification.** B1/B2 closure settles
      the app's own disclosures (truthful purpose string + explicit consent); it
      does **not** decide the store-form classification, which remains open.
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
