# Public store release program — design

**Date:** 2026-08-22
**Status:** proposed — revision 2 (awaiting user review)
**Revisions:** r1 `f9b5747`; r2 folds in design review 2026-08-22 (§5a Play App Signing + Routes restriction model, D1/§8 redistribution contradiction, Terms of Use dependency, revocation invariant, manifest ownership, attribution split, three release gates)
**Baseline:** `main@ea59d90`
**Target:** App Store + Google Play, public download, live before **Sat 19 Sep 2026**

---

## 0. What this is

`aon2026` has never been published. It is a complete, gate-green Flutter app with
no release identity: it signs Android with the debug key, has no privacy manifest,
no hosted privacy policy, no store record, and one feature (M4 Google nav) that has
never run on hardware.

This spec covers everything between that state and "a member of the public can
download it from both stores". It is a release-and-compliance program, not a
feature program — but four feature changes fall out of the compliance analysis and
are in scope because the release cannot ship without them.

**Two-track sequencing.** The compliance track owns the early deadlines and starts
first because its longest-lead item is external (§2d). The feature track runs
concurrently, not after.

---

## 1. Decisions already taken

Recorded so the plan does not relitigate them.

| # | Decision | Made by | Consequence |
|---|---|---|---|
| D1 | Ships under **Macquarie University's own Apple Developer Program organisation account** | user | Resolves publisher identity and brand provenance under 5.2.1 / 4.1(c). It does **not** by itself grant redistribution rights over `buildings.json` or the vendored AON artwork — written MQ approval remains a release blocker under §8.6. Publishing **is** the redistribution event the standing IOU gated. |
| D2 | **Both stores, public, before 19 Sep 2026** | user | ~3 weeks. Schedule risk is review latency plus one rejection cycle, not engineering. |
| D3 | **Bundle ID stays `au.edu.mq.astronomy.aon2026`** | user, after the 4.3 risk was raised | Accepted trade-off — see §7. |
| D4 | **Google walking nav ships live** | user | GCP keys become a hard release blocker for the whole app, not one feature. |
| D5 | **Wayfinding's OSM tiles are replaced with Google Maps** | user | Removes the last OSM dependency; moves the third-party data-sharing surface onto Google. Forces §2b. |
| D6 | **iPad is supported properly** | user | 13" screenshots required; iPad layout must be verified. |
| D7 | **"Preview from anywhere" mode ships in 1.0** | user | The Guideline 2.1 answer. See §3c. |
| D8 | GCP keys available this week | user | Unblocks D4/D5. The credential model and its two chains are in §5a; the Android fingerprint chain is the longest internal dependency in the plan. |

---

## 2. Privacy & data — the hard gate

Amended per design review 2026-08-22. This section is architectural: getting it
wrong changes code, not just copy.

### 2a. Truthful privacy copy (EN + FA)

`app_en.arb:308` / `app_fa.arb:128` currently assert "collects no analytics and
tracks no location" and "the only thing it fetches from the internet is map
imagery". Both statements become false with this release, in both languages.

Rewrite `settingsPrivacyCardTitle` and `settingsPrivacyBody` against this
invariant, which is the normative statement of app behaviour:

**Before Google-wayfinding consent resolves positively:**
- QR scanning is local; the camera image is not retained.
- Passport, favourites and My Night stay on the device.
- Location is processed locally to place the user on the campus map.
- **No Google-powered map, route request, or other Google location surface is
  initialised.**

**After explicit consent:**
- Google Maps and the Routes API may receive location and the request/device
  information those services require to function.

Real Persian, never machine-fill (repo convention). Both languages ship together.

### 2b. No Google surface may initialise before consent

> **Normative:** no Google wayfinding surface capable of transmitting user or
> location data may initialise before `consentNeedsDisclosure` has resolved
> positively.

This is stronger than "consent before the Routes call" and stronger than "consent
before the map renders", and both weaker forms are already violated by the code:

`ios/Runner/AppDelegate.swift` calls `GMSServices.provideAPIKey(key)` inside
`didFinishLaunchingWithOptions` — at app launch, before any UI exists. The
`!key.isEmpty` guard made this harmless only while the app shipped keyless. Under
D4 the keys ship, so the Maps SDK would initialise on every cold start for every
user, including users who never open wayfinding.

**Required change:** move `provideAPIKey` out of `didFinishLaunchingWithOptions`
and behind a method channel invoked only once consent has resolved positively.
Android binds later (the SDK reads `com.google.android.geo.API_KEY` when a map view
is constructed) but must be held to the same invariant.

Consent is presently enforced at exactly one site, `google_nav_screen.dart:76`.
It must also gate the wayfinding route.

**Acceptance is network-based, not inferred.** Whether `provideAPIKey` transmits
anything by itself is not established here; Google documents that application and
version information, authentication information and an anonymous cross-app
identifier accompany SDK *requests*. Deferring the call is defence-in-depth, not
the proof. The gate is a packet-level observation:

| Scenario | Required result |
|---|---|
| Cold launch, consent never given | **Zero** Google traffic |
| Consent accepted | Google traffic permitted |
| Consent revoked | **Zero** further Google traffic |

### 2c. Delete local data + revoke consent

Not an Apple requirement — 5.1.1(i) governs what the *policy* must explain, and
5.1.1(v)'s in-app deletion rule is conditional on account creation, which this app
does not have. It is in scope as good engineering: the data is local, so the
control is cheap, transparent and testable.

Clears passport, favourites, My Night and consent state. Behind a destructive
confirmation: *"This permanently deletes data stored by this app on this device."*
The control and the policy must **not** claim to erase information already
transmitted to third-party services.

Today Settings offers only a consent revoke (`settings_screen.dart:330`).

**Revocation is a runtime invariant, not merely stored state.** On revoke the app
must dispose any active Google map surface, cancel or block in-flight Routes
requests, block all subsequent Google requests, and require fresh consent before
Google functionality is reconstructed. Do not depend on being able to
un-initialise `GMSServices` — the invariant is enforced by the app, above the SDK.

### 2d. Live privacy policy + support URLs — **start first**

- **Apple requires:** a Privacy Policy URL in App Store Connect, the policy
  reachable from inside the app, and a Support URL in the app-version metadata.
- **Google Maps Platform terms require:** the application's own terms notify users
  that Google Maps features and content are present, and that their use is subject
  to Google Maps' additional terms and Google's privacy policy. This flow-down
  language needs somewhere to live, so a **Terms of Use URL** is a third hosted
  document, not an optional extra.
- **Project/Macquarie requires:** all three hosted on approved `mq.edu.au` URLs.

Apple does not mandate the domain; MQ does. Request **all three URLs in one go** —
Privacy Policy, Support, Terms of Use — rather than discovering the third after the
first two clear approval. This item is first in the schedule
because university CMS and approval lead times are the one thing on this plan that
cannot be compressed by engineering.

Policy must cover: what is collected (nothing, by MQ), location shared with Google
under D4/D5 and when, retention and deletion, and how consent is withdrawn.

### 2e. Release privacy-manifest and third-party SDK audit

Performed against the **actual release archive**, not predicted:

```
Release IPA / AAB
      |
      +-- Xcode Privacy Report
      +-- app PrivacyInfo.xcprivacy
      +-- embedded SDK privacy manifests
      +-- runtime network audit
      |
      v
 observed + declared data flows
```

`ios/Runner/PrivacyInfo.xcprivacy` does not exist and must be created.

**Ownership rule.** A third-party SDK supplies its **own** privacy manifest; the
app manifest does not duplicate what a linked SDK already declares, and Xcode
aggregates them into the privacy report. Every declaration is therefore attributed
to the component actually responsible — Runner's manifest covers first-party app
code, and the Flutter engine, `shared_preferences`, `google_maps_flutter` and the
Maps SDK each answer for themselves. Runner's manifest may end up close to empty;
that is a correct outcome, not a missing one.

**Expected declarations — expectations, not a freeze.** The aggregated archive
report is the authority; any deviation is adopted and justified in writing, not
argued away.

- `NSPrivacyTracking`: `false`
- `NSPrivacyTrackingDomains`: omit unless a domain genuinely needs declaring
- Collected data types: Precise Location → App Functionality, not linked to
  identity, not used for tracking
- Required-reason APIs: attributed per component and read off the built binary,
  never predicted from the dependency list

### 2f. Cross-surface privacy reconciliation

These five surfaces must agree, and are reconciled as one gate after §2e:

1. Hosted privacy policy (§2d)
2. In-app disclosure copy (§2a)
3. App Store Connect privacy labels
4. Google Play Data Safety
5. `PrivacyInfo.xcprivacy` (§2e)

**Consequence of D4/D5 that predates any manifest key:** with the Maps SDK shipping
live, the App Store nutrition label almost certainly can no longer read "Data Not
Collected", because Apple's label covers third-party SDK collection and Google's
SDK manifests disclose automatic collection that the app developer must then
reconcile.

**Do not infer tracking from an identifier.** An Identifiers disclosure and
Apple-defined *tracking* are separate determinations: tracking is a use-purpose
test, not a consequence of declaring an identifier. Answer both from §2e's
aggregated report, not by reasoning forward from one to the other.

### 2g. Age rating

Complete the current App Store Connect questionnaire truthfully. **Expected result:
4+** (no UGC, no messaging or social feed, no advertising, no objectionable
content). Do not hard-code a rating; the questionnaire's output is the rating.
Play's IARC questionnaire likewise.

---

## 3. Reviewability — Guideline 2.1

App Review is not on Macquarie campus, and the event post-dates review. Without
this section a reviewer sees a map with no position dot, a compass pointing across
the Pacific, walking directions to a place 12,000 km away, a QR scanner with
nothing to scan, and an empty "What's On Now".

### 3a. Honest off-campus states

- `map_screen.dart:77` — a valid fix that `project()` maps to null currently makes
  the dot silently vanish. Show a quiet banner: *"You're not on campus — showing
  the full map."* A fact, not an error.
- `nearby_targets.dart:88` — `nearestTargets` has no distance ceiling; it sorts and
  takes N. Add a ceiling (~5 km) beyond which it returns empty, and have
  `nearby_list` explain the app guides you around campus on the night.
- `program_screen` — before the event, "What's On Now" reads *"Doors open 4:00 pm,
  Saturday 19 September"* rather than blank.

EN + FA. These serve real users who open the app the week before; the 2.1 benefit
is a side effect.

### 3b. Sample stamp codes in Notes for Review

Manual entry already ships as a first-class peer to scanning
(`passport_scan_screen.dart:16`, `_Mode.manual`). Supplying three or four real
codes lets a reviewer drive the passport to a reward with no engineering at all.

### 3c. Preview from anywhere (D7)

A user-visible Settings toggle, clearly labelled as a simulated position, that
seeds a plausible campus fix so the map dot, compass and nearby list come alive
off-campus. The seam exists (`FakeLocationService`, `locationServiceProvider`
override in `test/widget/map_platform_wiring_test.dart`).

Visible and documented, therefore not a 2.3.1(a) hidden or dormant feature. Off by
default. Never presents a simulated fix as a real one.

It also strengthens the Guideline 4.2 argument: the app is useful *before* you
arrive, not only on the night.

---

## 4. Release engineering

**Acceptance criteria:**

- **Built with Xcode 26 or later against the iOS 26 SDK or later** — mandatory for
  App Store uploads since 28 Apr 2026. *Verified satisfied:* Xcode 26.6, iOS 26.5
  SDK.
- Android target API 36. *Verified satisfied:* Flutter 3.44.7 defaults to
  `targetSdkVersion = 36` / `compileSdk = 36` / `minSdk = 24`, and
  `android/app/build.gradle.kts` uses `flutter.targetSdkVersion`. The 31 Aug 2026
  Play deadline needs no action.
- **Android release signing.** `build.gradle.kts:38` currently reads
  `signingConfig = signingConfigs.getByName("debug")` — cannot ship. Introduce an
  MQ-held upload keystore with a git-ignored `key.properties` and a committed
  `.sample`, matching the existing `secrets.properties` pattern.
- `ITSAppUsesNonExemptEncryption` set in `Info.plist` — absent today, so every
  upload stalls on the export-compliance prompt. The value is an **audited
  conclusion, not an assumption**: the key covers the app *and its linked
  third-party libraries*, so `false` is only correct once those have been checked
  for non-exempt encryption. HTTPS-only use is exempt.
- **iOS production signing and provisioning** under MQ's Developer Team, proven by
  a successful archive and export against the registered bundle ID — not just a
  local debug run.
- Version `1.0.0+1` for the first upload, and **build numbers are monotonic**: any
  replacement binary is `+2`, `+3`, … Numbers are never reused, even for a build
  that was rejected or never released.
- `./scripts/check.sh full` green, **exit-gated**, never through a pipe.
- App Store Connect and Play Console records created under MQ's organisation
  accounts (D1).
- First build to TestFlight internal before any public App Store submission.
- **Google Play Internal testing using the Play-signed artifact** before
  Production, mirroring the TestFlight gate. This is not ceremony: it is the only
  way to verify §5a's app-signing fingerprint actually works for delivered
  builds.

---

## 5. Feature completion

### 5a. Credentials — two restriction models, and the plan's longest chain

Revision 1 described "four restricted keys" with a single ordering note. Both
halves were wrong in ways that would have surfaced only after a real user
installed a real build.

#### Maps SDK keys (Android, iOS) — application restrictions

The correct model. iOS restricts on bundle ID `au.edu.mq.astronomy.aon2026`.
Android restricts on package name plus certificate fingerprint — and **that
fingerprint is not the upload key.**

Under Play App Signing, which new apps are enrolled in automatically, the upload
keystore only authenticates uploads to Play. Google re-signs the artifact
delivered to users with a separate **app-signing key** that Google holds. A Maps
key restricted to the upload certificate works on locally-signed builds and fails
for every user who installs from Play — a defect invisible to every test that does
not go through Play.

The real chain:

```
Play app record
   -> upload keystore (§4)
   -> first AAB upload / Play App Signing enrolment
   -> read the Google-held app-signing certificate fingerprint(s) from Play Console
   -> restrict the Maps Android key to package + EVERY certificate that can sign
      a distributed APK
   -> verify against a Play-DELIVERED build (§4 internal testing), never a
      locally-signed one
```

Where internal or local builds must also work, register the upload certificate
alongside the app-signing certificate. If Play exposes more than one applicable
signing certificate, register all of them.

This — not the keystore alone — is the longest internal dependency in the plan.

#### Routes API — direct call retained, with conditions

Google's security guidance groups Routes API with web services and prefers either
an IP-restricted key or a proxy. It also documents the direct-call fallback
explicitly: if a secure proxy is not available, secure the client with the
`X-Android-Package` + `X-Android-Cert` headers on Android and
`X-Ios-Bundle-Identifier` on iOS. `google_routes_service.dart:44-50` already sends
exactly that header map, assembled by `routesClientIdentityProvider`.

The caveat Google attaches — that application restrictions "may not be fully
supported on older legacy Google Maps Platform services" — does not describe
Routes v2, which is the current service rather than a legacy one.

So the direct call stays. It is a documented path, and standing up an
MQ-controlled proxy service inside a three-week window on the strength of a stated
preference would buy schedule risk, not safety. Three conditions attach:

1. **Enforcement is proven, not assumed.** A Routes request carrying a wrong
   bundle ID, or a wrong package/certificate pair, must be **rejected**. This is
   already part of the M4 on-device IOU; it is now a release gate.
2. **Cap the blast radius.** The key ships inside the binary and is extractable —
   inherent to the documented fallback, not a flaw in it. Set Routes API quota
   limits and a GCP budget alert on MQ's project so an extracted key cannot run up
   a bill against the university.
3. **The proxy is a costed contingency, not the plan.** If (1) fails, fall back to
   an MQ-hosted Routes proxy behind an IP-restricted server key — and note that
   doing so puts MQ infrastructure into the location-data path, which re-opens
   §2d, §2e and §2f.

### 5b. Move Maps SDK init behind consent

Per §2b. Architectural, and the highest-priority feature change.

### 5c. Wayfinding onto Google (D5)

`_RouteMap` (`wayfinding_screen.dart:348`) is a self-contained `FlutterMap`
drawing a polyline and two endpoint markers. `EmbeddedMap` already accepts exactly
`origin` / `destination` / `route`. A ~90-line replacement of one private widget.

Then: delete `DarkTileLayer` (its last user); extend the consent gate to the
wayfinding route (§2b).

### 5d. Attribution cleanup — closes the open P1 audit finding

OSM attribution currently sits on Credits (`info_screen.dart:253`) and Settings
(`settings_screen.dart:420`) — screens that render no OSM tiles — while the screen
that did render them said nothing. With §5c removing OSM entirely, both claims
must go. `map_screen.dart`'s `_MapAttribution` prints a hardcoded, un-l10n'd string
and must use the orphaned `mapAttribution` ARB key.

Google's attribution is **three distinct requirements**, not one blanket rule:

1. **Map UI.** When Google Maps content is displayed on a Google map, the SDK's
   built-in attribution is sufficient and no second attribution is added. The
   obligation is that it must not be hidden, obscured or clipped — which is a
   layout constraint on anything drawn over `EmbeddedMap`.
2. **Routes content outside a map.** `_RouteDetail` (`wayfinding_screen.dart:207`)
   renders distance, duration and step text outside any Google map surface. That
   content carries its own compliant Google Maps attribution requirement.
3. **SDK legal notices.** Expose the licence text from
   `GMSServices.openSourceLicenseInfo` in Legal/About — the natural home is the
   existing credits section of `info_screen.dart`.

### 5e. Reviewability features

§3a, §3b, §3c.

### 5f. Delete local data

§2c.

### 5g. iPad (D6)

`Info.plist` already declares all four iPad orientations, so Apple treats this as
an iPad app. Verify layout at iPad sizes under the repo's existing accessibility
bar (320×568 / textScale 2.0 must not overflow; prove the last actionable row is
reachable *and* tappable). Fix what overflows.

### 5h. On-device verification

Physical iOS and Android. Pays two standing IOUs: **M4** (live Google render,
restriction rejection) and **M5** (heading tracks true bearing with declination;
red rose legible in the dark — the simulator has no magnetometer and only
exercises the honest `unavailable` fallback).

Not optional. It is the repo's own rule: no "done" without fresh verification
evidence.

---

## 6. Store metadata & submission

- **Screenshots:** 6.9" iPhone (required) and 13" iPad (required under D6).
- App name (≤30 chars), subtitle, description, keywords, category.
- **Notes for Review** — carries the Guideline 4.2 and 2.1 defence explicitly:
  MQ-official app for a public astronomy night; offline campus basemap; live
  positioning; compass wayfinding; QR passport; EN + FA. Includes §3b's stamp
  codes and instructions for the §3c preview toggle. Generic notes are rejected
  under 2.3.1(a).
- Privacy labels, Data Safety and age rating per §2f/§2g.
- Privacy Policy and Support URLs per §2d.
- Play listing and IARC questionnaire.

---

## 7. Accepted risks and trade-offs

| Risk | Status |
|---|---|
| Bundle ID keeps `aon2026` (D3) | User's call after the 4.3(a)/(b) staleness risk was put to them. Mitigation: **one app record, updated annually**. The ID is not user-facing, though it is visible in developer and review tooling; the 4.3 exposure is behavioural — whether a second app appears next year — not the literal string. |
| Basemap ships bright, not night-reskinned | Pre-existing user decision (brand fidelity over scotopic dimming). If revisited, dim at runtime with a `ColorFiltered` over `CampusBasemapLayer` — never bake a darker asset. |
| Baked English legend on the artwork cannot be localised | Carried M0 IOU-P1. Disclosed, not fixed. |
| `Macquarie Centre` falls outside the AON crop (1 of 170) | Pinned by `test/unit/aon_basemap_georef_test.dart`. Honest, documented. |
| First aid has no GPS fix and is unroutable | Correct behaviour — organisers never supplied one and the data refuses to guess. Renders at the artwork marker. Belongs in the review notes. |
| Four `T` discs vs three in the artwork legend | Organiser question, not a code bug. Do not "fix" it in data. |
| Web runtime black-screens at bootstrap | Pre-existing, unrelated to this release, and web is not a release target. |

---

## 8. External dependencies (not engineering-controlled)

1. **MQ-hosted privacy policy URL** (§2d) — longest lead; start immediately.
2. **MQ-hosted support URL** (§2d).
3. **MQ-hosted Terms of Use URL** (§2d) — carries the Google Maps flow-down
   language. Request it in the same approval round as 1 and 2, not after them.
4. **MQ Apple Developer + Play Console organisation accounts** (D1), including
   Play's developer verification and D-U-N-S.
5. **Four restricted GCP keys** (D8), gated behind §5a's Play App Signing chain.
6. **Written MQ sign-off** on redistributing `buildings.json` and the official AON
   artwork publicly. D1 makes this an internal approval rather than a licence
   negotiation, but publishing from MQ's account is not itself the grant: the
   approval must be recorded. The repo being private was never permission.
7. **Contingent only:** MQ-hosted Routes proxy, if §5a condition (1) fails. Not
   scheduled; costed now so the decision is fast if it fires.

## 9. Out of scope

- Evergreen rename (rejected by D3).
- Porting wayfinding onto the AON basemap (superseded by D5).
- `latlong2` 0.9.1 → 0.10.1 (open P2), `go_router` 17.4→17.5, `intl` 0.20.2→0.20.3
  (open P3). Version bumps during a release freeze buy risk, not value.
- Web release.
