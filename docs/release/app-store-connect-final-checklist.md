# App Store Connect — final pre-submission checklist

**Date:** 2026-09-05 · **Branch:** `fix/ios-always-location-purpose-string`
**Target upload:** `1.0.0` **Build 3** · Bundle `au.edu.mq.astronomy.aon2026`
· Team `94273WB4G3`

The single page to work through in App Store Connect. Every row names its
evidence or says exactly who has to act. Statuses are the register's vocabulary
plus the three ASC-specific ones this pass needed.

| Status | Meaning |
|---|---|
| `VERIFIED` | Checked in this repo or against a live service, with the evidence named |
| `READY TO ENTER` | The value is decided and written down; someone has to paste it into ASC |
| `BLOCKED` | Cannot proceed until a person or an external service provides something |
| `NOT APPLICABLE` | Genuinely does not apply to this app |
| `ASC ACCESS REQUIRED` | Only visible from inside App Store Connect, which this pass could not reach |
| `LEGAL/ORG DECISION` | Not a technical question |

---

## The checklist

| # | Item | Status | Value / evidence |
|---|---|---|---|
| 1 | **Privacy Policy URL** | `BLOCKED` | Macquarie's own policy does **not** cover this app — see §1 below. The app-specific copy is written (`mq-hosted-pages.md` Page 1) and needs hosting at any stable HTTPS URL. |
| 2 | **Support URL** | `READY TO ENTER` | `https://event.mq.edu.au/astronomy-open-night/` — official MQ event site, public, HTTPS, no login, lists `astronomyopennight@mq.edu.au` for enquiries. Fetched and read 2026-09-05. |
| 3 | **Marketing URL** | `NOT APPLICABLE` | Optional per Apple. The Support URL already is the event site. |
| 4 | **Terms of Use / EULA** | `VERIFIED` — **Apple standard EULA sufficient** | See §2 below. No custom EULA needed for Apple; the Google Maps flow-down is carried in-app. |
| 5 | **App Privacy questionnaire** | `READY TO ENTER` | **Not** "Data Not Collected" — see §3. Precise Location, App Functionality, not linked, not tracking. |
| 6 | **Privacy manifest consistency** | `VERIFIED` | `ios/Runner/PrivacyInfo.xcprivacy` now declares PreciseLocation to match the ASC answer; `ios_privacy_manifest_test.dart` 6/6. |
| 7 | **Age rating questionnaire** | `READY TO ENTER` | Every answer *None* / *No*; table in `app-store-listing.md`. Re-checked against the shipped build 2026-09-05: no UGC, no messaging, no IAP, no ads, no unrestricted web (the WebView loads bundled files over `http://localhost`). |
| 8 | **Content rights** | `LEGAL/ORG DECISION` — owner has decided | Three MQ asset sets are the project's own (owner attestation 2026-09-05). The Home hero is Aleix Roig's; the owner has chosen to ship on the existing credit. Residual 5.2 risk recorded in blocker B6. |
| 9 | **Export compliance** | `VERIFIED` | `ITSAppUsesNonExemptEncryption` = `false` in Info.plist; audited per-dependency in `export-compliance.md` — every networked dependency uses OS TLS and bundles no cryptography. ASC will not re-ask while the key is present. |
| 10 | **DSA trader status** | `LEGAL/ORG DECISION` | Only required if the app is distributed in the EU. Nothing in this repo states the intended territories — see §5. |
| 11 | **Screenshots — 6.9" iPhone** | `VERIFIED` — **recaptured 2026-09-05** | All 6 at 1320×2868 from a build of this branch. See §4. |
| 12 | **Screenshots — 13" iPad** | `READY TO ENTER` (minimum met) / 3 outstanding | `01-home.png` recaptured at 2064×2752; the other three were removed as stale and need capturing by hand. Apple requires at least one. See §4. |
| 13 | **App name** | `READY TO ENTER` | `Astronomy Open Night` (20 chars). |
| 14 | **Subtitle** | `READY TO ENTER` | In `app-store-listing.md`, within 30 chars. |
| 15 | **Description** | `READY TO ENTER` | `app-store-listing.md`, within 4000 chars. |
| 16 | **Keywords** | `READY TO ENTER` | The committed string is **exactly 100 characters** — at Apple's limit, not over it. The doc's old "101 → trim guide" note was a miscount and has been corrected. |
| 17 | **Categories** | `READY TO ENTER` | Primary **Education**, secondary **Navigation**. |
| 18 | **Copyright** | `LEGAL/ORG DECISION` | `© 2026 Macquarie University` is the drafted line. Note the tension: `map_attribution_test.dart` deliberately forbids a `©` on the in-app campus-map credit until MQ sign-off. The owner's attestation resolves the substance; whether to assert `©` in ASC is still theirs to say. |
| 19 | **Price / availability** | `READY TO ENTER` | Free, no in-app purchases. Territories: see row 10. |
| 20 | **App Review notes** | `READY TO ENTER` | `app-review-notes.md`, corrected 2026-09-05 to match the binary (both directions paths, what is sent to Google). |
| 21 | **App Review contact** | `BLOCKED` | Still `<NAME>/<EMAIL>/<PHONE>`. Deliberately not invented. |
| 22 | **Build 3 uploaded** | `BLOCKED` on the archive | The repo side is ready; the archive must come from the Xcode signed into team `94273WB4G3`. |
| 23 | **ITMS-90683 cleared** | `RESOLVED — AWAITING VERIFICATION` | Fixed and verified in the built bundle; only the Build 3 delivery mail can confirm Apple agrees. |

---

## §1 — Why Macquarie's own Privacy Policy cannot be the app's

Asked directly, and checked rather than assumed. Macquarie's Privacy Policy
(<https://policies.mq.edu.au/document/view.php?id=107>) states its own scope:

> "all employees of the University and its Controlled Entities; all students of
> the University including former students; all University researchers and
> graduate research candidates; and any person who handles Personal or Health
> Information for or on behalf of the University"

Members of the public attending an event are not in that list, and the document
addresses the University's "learning and teaching, research, engagement, and
associated administrative activities" — not a mobile app. It says nothing about:

- transmitting a visitor's precise location to the Google Routes API,
- Google Maps' own collection of identifiers, usage and diagnostics once
  directions open,
- ML Kit diagnostics on the Android build,
- what the passport, favourites and saved plan store on the device.

Pointing App Review at a policy that does not describe the app is the same
class of defect as blocker B1 — an inaccurate disclosure — one layer out. It
would also be the *University's* document answering for an app published from
an individual's team.

**What is right, and is what the repo already prepared:** MQ hosts *this app's*
policy. `mq-hosted-pages.md` Page 1 is finished copy, written against the code
and cross-checked against `settingsPrivacyBody`. Published at an `mq.edu.au`
URL it gives both the University association and an accurate document. If MQ
hosting is slow, any stable public HTTPS URL satisfies both stores — Android
already does exactly this with `android-privacy-policy.html` on Leo's Play
account. Once a URL exists, wire it into `EventConfig.privacyPolicyUrl` and the
Settings card opens it instead of the offline dialog.

## §2 — Terms of Use: Apple standard EULA is sufficient

**Verdict: `APPLE STANDARD EULA SUFFICIENT`.** Apple does not require a custom
EULA or a Terms URL; an app that supplies neither is covered by Apple's standard
licence agreement. Nothing in this app changes that: no account, no purchase, no
subscription, no user-generated content, no user-to-user contact.

Macquarie's public legal pages do not substitute. The closest is
<https://www.mq.edu.au/copyright-disclaimer>, a website copyright and disclaimer
notice — it governs the website, not an app, and carries no Google terms.

The one genuine terms obligation is the **Google Maps Platform flow-down**: the
app must bind its users to terms consistent with Google's Maps/Earth Additional
Terms of Service. This app discloses the Google surface in-app before and around
its use (the wayfinding disclosure, the Settings privacy card and its revoke
control), which is where a no-account event app can honestly carry it. Page 3 of
`mq-hosted-pages.md` remains the written version if MQ prefers a hosted page —
useful, not store-blocking.

## §3 — App Privacy: the recommended answers

The app has no backend, which is exactly the trap Apple's definition sets: to
*collect* is to transmit off the device where you **or your third-party
partners** can access it beyond servicing the request. Google is a third-party
partner here, so "Data Not Collected" would be wrong.

**Verified behaviour** (`google_routes_service.dart:39-80`): on the walking-
directions path only, the app POSTs `{origin latLng, destination latLng,
travelMode: WALK}` to `routes.googleapis.com/directions/v2:computeRoutes`. No
name, no account (there is none), no app-generated identifier travels with it.
The request happens after the visitor opens directions, and not at all if
directions sharing is off in Settings.

| Data type | Collected | Purpose | Linked to identity | Used for tracking |
|---|---|---|---|---|
| **Precise Location** | **Yes** | App Functionality | **No** | **No** |

Everything else stays *not collected*: no contact info, no identifiers, no
purchases, no contacts, no user content, no search history, no browsing history,
no health/fitness, no financial data. The passport, favourites, saved plan and
settings never leave the device.

**One question genuinely needs the owner, not this audit** — `LEGAL/POLICY
REVIEW`: the embedded **Google Maps SDK 8.4.0** is statically linked into Runner
and ships **no privacy manifest of its own** (verified: no
`PrivacyInfo.xcprivacy` anywhere under `ios/Pods/GoogleMaps`, and 41 `GMS*`
symbols in the Runner binary). Google's own published guidance for Maps SDK on
iOS asks developers to declare the SDK's collection — typically Identifiers,
Product Interaction, Crash and Performance Data — and this app's own privacy
copy already tells users exactly that ("Google Maps also collects technical
data, identifiers, crash diagnostics and map interactions"). Whether to add
those rows to the ASC answers is a disclosure decision, not a code one. The
safest answer is to declare them; the narrow answer is that they are the SDK's
collection, not the app's. **The in-app copy has already taken the broad
position, so the ASC answers should match it rather than contradict it.**

## §4 — Screenshots: the old set was stale; 7 of 10 have been recaptured

The committed set was captured on **2026-08-23** (`a9a79bb`) and showed copy the
app no longer ships: `iphone-6.9/01-home.png` had the map card reading *"Venues,
toilets, first aid — and walking directions from the car parks"*, while the
shipped string is now *"Venues, toilets, parking and walking directions"*. The
fortnight after that capture also brought the redesigned Program filters, the
removed Compass mode, the West 6 parking pin, the Toilets chooser and the
reordered 360° picker.

*(One thing that looked like a defect is not one. In both the old and the new
Home captures the tab bar shows content through it. That is the translucent
floating tab bar working as designed, not a mid-transition artifact — checked
against the running app rather than inferred from the image.)*

**Done 2026-09-05, from a simulator build of this branch:**

- **iPhone 17 Pro Max, 6 of 6**, all exactly 1320×2868 — Home, Map, Program,
  Passport, the Observatory 360° tour, and Settings → Credits (replacing the old
  Settings → Preview shot, which no longer earns a slot now that the passport is
  live and needs no preview to demonstrate).
- **iPad Pro 13-inch, 1 of 4**, at 2064×2752 — Home.

**Still to do: the three remaining iPad shots** (Map, a 360° tour, Settings).
They could not be automated: Maestro reports success against the iPad
simulator's UDID while the taps land elsewhere — three consecutive captures came
back byte-identical, the screen never having changed. That is the iPad session
trap already recorded in `.maestro/README.md`. Capture them by hand in
Simulator with `xcrun simctl io <udid> screenshot`. Apple requires at least one
iPad screenshot for an iPad-capable app, so submission is not blocked on them.

## §5 — DSA / territories

`ORGANISATIONAL / LEGAL DECISION REQUIRED`, and partly `ASC ACCESS REQUIRED`.
Nothing in this repository states the intended App Store territories. The app is
a companion to a one-night event on one campus in Sydney, which argues for
Australia-only availability — but that is the organisers' call, not this
audit's, and it has a direct consequence: if EU territories are selected, App
Store Connect requires a DSA trader-status declaration, and whether Macquarie
University (or Leo Alavi as the publishing account) is a "trader" is a legal
determination this pass must not make.

If distribution is Australia-only, no DSA declaration is required and this row
closes with no action.
