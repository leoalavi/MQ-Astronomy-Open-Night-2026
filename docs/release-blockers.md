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
| B1 | iOS `NSLocationWhenInUseUsageDescription` says location is "never sent anywhere", but Google Routes can transmit the user's origin after Maps consent | Store disclosure / privacy | Product/legal | `OPEN` |
| B2 | Maps Directions currently uses implicit auto-accept on first use rather than an explicit disclosure; wording referring to "after you agree" must be reconciled with the intended consent posture | Privacy / product decision | Product/legal | `OPEN` |
| B3 | Live Google walking-route rendering still requires production GCP Routes API enablement, billing/key restrictions and successful end-to-end verification | Infrastructure | Infra | `OPEN` |
| B4 | Real-device validation remains outstanding for GPS field accuracy, magnetometer/compass behaviour and live Google route rendering | Physical-device QA | QA | `UNVERIFIED — PHYSICAL DEVICE REQUIRED` |
| B5 | Passport production codes remain placeholders, so Passport is disabled in release builds | Event configuration | Organisers | `OPEN` |
| B6 | Redistribution permission remains unresolved for four panorama asset sets | Asset rights | Organisers | `OPEN` |

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
- **Status.** `OPEN`.
- **Exact condition to close.** The purpose string is reworded to truthfully
  describe the Routes transmission (e.g. drop "and is never sent anywhere", or
  state "…sent to Google only when you ask for walking directions"), consistent
  with `settingsPrivacyBody` and the hosted policy.
- **Verification evidence required.** The shipped `Info.plist` string, quoted,
  showing the corrected wording in the build that is submitted; confirmation it
  matches the in-app and hosted privacy copy.

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
- **Status.** `OPEN`.
- **Exact condition to close.** A recorded decision that the implicit-accept
  model is intended (or a change back to explicit consent), with all
  user-facing consent/privacy copy reconciled to whichever model ships.
- **Verification evidence required.** The decision recorded here; the shipped
  consent flow and the shipped copy quoted and shown to agree.

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

## B5 — Passport production codes are placeholders

- **Exact problem.** All nine Astronomy Passport station codes ship as
  `AON-*-TBC` placeholders; the domain release gate keeps prize collection
  disabled in release builds while any code is a placeholder.
- **Why it matters for release.** The Passport stamp rally is a headline
  engagement feature and is inert on the night until real codes are supplied.
- **Evidence / source.** `docs/data-sources.md` open question 9;
  `ARCHITECTURE.md` Risk R3.
- **Owner.** Organisers.
- **Status.** `OPEN`.
- **Exact condition to close.** The organisers supply the nine real station
  codes (and confirm an accessible redemption alternative), the codes are
  compiled in, and the release gate no longer disables collection.
- **Verification evidence required.** The nine confirmed codes recorded by the
  organisers; a release build showing Passport collection enabled and a stamp
  successfully redeemed.

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

---

## Change log

- 2026-09-01 — Register created with B1–B6 from the Home/Program and Map
  release-readiness audits. All items OPEN or UNVERIFIED; none CLOSED — VERIFIED.
