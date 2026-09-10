> **10 September 2026 policy update:** use `https://aon.syllabus-sync.app/privacy`
> for Astronomy Open Night's canonical policy. It covers iOS, Android and web,
> credits Leo Alavi and Mohammad Raouf Abedini as the developers for the
> Astronomy Night - FSE Outreach Team, and retains the Google
> Maps/ML Kit disclosures below. App privacy and data requests:
> `leo@leoalavi.dev`; event support: `astronomyopennight@mq.edu.au` and
> `https://event.mq.edu.au/astronomy-open-night/`. Updating these source files
> does not update the store console or an already uploaded binary.

# App Store Connect — final pre-submission checklist

**Original checklist:** 2026-09-05 · **Current reconciliation:** 2026-09-11 · **Branch:** `main`
**Previously uploaded build:** `1.0.0` **Build 3** — **approved for external
TestFlight** · Bundle `au.edu.mq.astronomy.aon2026` · Team `94273WB4G3`
· Availability: **Australia only**

> ## CURRENT STATE (reconciled 2026-09-11) — read this first
>
> Several rows below predate the final hosting/identity decisions and are kept
> for history. The **current** release-facing values are:
>
> | Field | Current value |
> |---|---|
> | App name | **Astronomy Open Night 2026** |
> | Developed by | **Leo Alavi and Mohammad Raouf Abedini** |
> | For | **Astronomy Night – FSE Outreach Team** |
> | **Privacy Policy URL** | **`https://aon.syllabus-sync.app/privacy`** — canonical static readable HTML generated from the in-app policy. Local artifact verified; public DNS/hosting verification remains a human release action. The old `hosted-pages.md` / MQ-hosted plan is **superseded**. |
> | Privacy contact (in the policy) | **Leo Alavi — `leo@leoalavi.dev`** |
> | Support URL | **`https://event.mq.edu.au/astronomy-open-night/`** (event support: `astronomyopennight@mq.edu.au`) |
> | **App Review contact** | **Leo Alavi — `leo@leoalavi.dev`, `+61451519624`** (developer contact; matches the privacy contact). Never the event mailbox. |
> | Copyright | **`© 2026 Astronomy Night – FSE Outreach Team`** (implemented app-wide). |
> | Current repository candidate | **`1.0.0+4`** — Build 4 is required because the shared source changed after uploaded Build 3. It is not signed or uploaded. |

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
| 1 | **Privacy Policy URL** | `BLOCKED` | **`https://aon.syllabus-sync.app/privacy`** — local static, readable, JS-free HTML is generated from the in-app policy (`tool/privacy/gen_privacy_html.py`). Public DNS/hosting was not reachable on 2026-09-10; deploy and verify it before entering the URL. |
| 2 | **Support URL** | `READY TO ENTER` | `https://event.mq.edu.au/astronomy-open-night/` — official MQ event site, public, HTTPS, no login, lists `astronomyopennight@mq.edu.au` for enquiries. Fetched and read 2026-09-05. |
| 3 | **Marketing URL** | `NOT APPLICABLE` | Optional per Apple. The Support URL already is the event site. |
| 4 | **Terms of Use / EULA** | `VERIFIED` — **Apple standard EULA sufficient** | See §2 below. No custom EULA needed for Apple; the Google Maps flow-down is carried in-app. |
| 5 | **App Privacy questionnaire** | `READY TO ENTER` | **Not** "Data Not Collected" — see §3. Precise Location, App Functionality, not linked, not tracking. |
| 6 | **Privacy manifest consistency** | `VERIFIED` | `ios/Runner/PrivacyInfo.xcprivacy` now declares PreciseLocation to match the ASC answer; `ios_privacy_manifest_test.dart` 6/6. |
| 7 | **Age rating questionnaire** | `READY TO ENTER` | Every answer *None* / *No*; table in `app-store-listing.md`. Re-checked against the shipped build 2026-09-05: no UGC, no messaging, no IAP, no ads, no unrestricted web (the WebView loads bundled files over `http://localhost`). |
| 8 | **Content rights** | `LEGAL/ORG DECISION` — owner has decided | Three MQ asset sets are the project's own (owner attestation 2026-09-05). The Home hero is Aleix Roig's; the owner has chosen to ship on the existing credit. Residual 5.2 risk recorded in blocker B6. |
| 9 | **Export compliance** | `VERIFIED` | `ITSAppUsesNonExemptEncryption` = `false` in Info.plist; audited per-dependency in `export-compliance.md` — every networked dependency uses OS TLS and bundles no cryptography. ASC will not re-ask while the key is present. |
| 10 | **DSA trader status** | `NOT APPLICABLE` | **Australia-only distribution** decided by the owner (2026-09-06). No EU territories, so App Store Connect does **not** require a DSA trader-status declaration. Revisit only if EU availability is ever added. See §5. |
| 11 | **Screenshots — 6.9" iPhone** | `VERIFIED` — **recaptured 2026-09-05** | All 6 at 1320×2868 from a build of this branch. See §4. |
| 12 | **Screenshots — 13" iPad** | `VERIFIED` | Six screenshots at 2064×2752: Home, Program, My Night, Map, panorama and Passport. See §4. |
| 13 | **App name** | `READY TO ENTER` | `Astronomy Open Night 2026` (25 chars). |
| 14 | **Subtitle** | `READY TO ENTER` | In `app-store-listing.md`, within 30 chars. |
| 15 | **Description** | `READY TO ENTER` | `app-store-listing.md`, within 4000 chars. |
| 16 | **Keywords** | `READY TO ENTER` | The committed string is **exactly 100 characters** — at Apple's limit, not over it. The doc's old "101 → trim guide" note was a miscount and has been corrected. |
| 17 | **Categories** | `READY TO ENTER` | Primary **Education**, secondary **Navigation**. |
| 18 | **Copyright** | `READY TO ENTER` | **`© 2026 Astronomy Night – FSE Outreach Team`**, implemented consistently app-wide. |
| 19 | **Price / availability** | `READY TO ENTER` | Free, no in-app purchases. Availability: **Australia only** (owner decision 2026-09-06) — deselect all other territories in ASC. |
| 20 | **App Review notes** | `READY TO ENTER` | `app-review-notes.md`, corrected 2026-09-05 to match the binary (both directions paths, what is sent to Google). |
| 21 | **App Review contact** | `READY TO ENTER` | Supplied by Leo 2026-09-06: **Leo Alavi**, `leo@leoalavi.dev`, `+61451519624`. In `app-review-notes.md`. |
| 22 | **Current build** | `BLOCKED — SIGNING/ASC` | Build 3 (`1.0.0+3`) remains approved for external TestFlight but predates the current shared source. The repository candidate is Build 4 (`1.0.0+4`); archive, sign and upload it using the correct Apple team. |
| 23 | **ITMS-90683 cleared** | `CLOSED — VERIFIED` | Fixed in the Build 3 binary (both location purpose strings present, no `UIBackgroundModes`) **and validated by Apple**: Build 3 was accepted for upload and passed external TestFlight beta review without the ITMS-90683 warning recurring. |

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

The repository instead generates Astronomy Open Night's own semantic policy at
`web/privacy.html`, directly from the same localisation source used by the
in-app privacy screen. Its canonical URL is
`https://aon.syllabus-sync.app/privacy`. The artifact is complete and parity
tested; deploying it and verifying public DNS remain external release actions.

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
control), which is where a no-account event app can honestly carry it. The
information site also provides the app-specific Terms page at
`https://info.syllabus-sync.app/astronomy-open-night/terms`.

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

### The authoritative App Privacy answer set (current Build 4 candidate)

This is the **single source of truth** for the App Store Connect App Privacy
answers. Every row is "collected"; every row is **not linked to identity** and
**not used for tracking** (the app has no account, no ATT, no advertising SDK and
no cross-app tracking — consistent with `NSPrivacyTracking = false` in
`PrivacyInfo.xcprivacy`). Purpose is **App Functionality** throughout: every item
exists only to draw the map and return walking directions.

| Data type | Collected? | Purpose | Linked to user? | Tracking? | Whose collection |
|---|---|---|---|---|---|
| **Precise Location** | **Yes** | App Functionality | No | No | The app — Routes origin/destination on the walking-directions path |
| **Coarse Location** | **Yes** | App Functionality | No | No | Google Maps SDK |
| **Identifiers** (device / Maps SDK id) | **Yes** | App Functionality | No | No | Google Maps SDK |
| **Product Interaction** | **Yes** | App Functionality | No | No | Google Maps SDK (map interactions) |
| **Other Usage Data** | **Yes** | App Functionality | No | No | Google Maps SDK |
| **Crash Data** | **Yes** | App Functionality | No | No | Google Maps SDK diagnostics |
| **Performance Data** | **Yes** | App Functionality | No | No | Google Maps SDK diagnostics |

**Every other Apple category is *Data Not Collected*:** no contact info, no
health/fitness, no financial info, no contacts, no user content, no search
history, no browsing history, no purchases, no sensitive info. The passport,
favourites, saved plan and settings never leave the device. The app itself
collects only Precise Location (above); the remaining rows are the embedded
Google Maps SDK's own collection, declared here because the SDK ships no privacy
manifest of its own and the app's in-app copy already discloses exactly this.

**Why the Google Maps SDK rows are declared (resolved, not open).** The embedded
**Google Maps SDK 8.4.0** is statically linked into Runner and ships **no privacy
manifest of its own** (verified: no `PrivacyInfo.xcprivacy` anywhere under
`ios/Pods/GoogleMaps`, and 41 `GMS*` symbols in the Runner binary). Google's own
published guidance for Maps SDK on iOS asks developers to declare the SDK's
collection — Identifiers, Product Interaction, Crash and Performance Data (plus
Coarse Location) — and this app's own privacy copy already tells users exactly
that ("Google Maps also collects technical data, identifiers, crash diagnostics
and map interactions"). Since the in-app copy and the hosted policy already take
the broad position, the ASC answers **match it**: the SDK rows are declared, as
in the matrix above. This closes the earlier open question — there is nothing
left for the owner to decide here, and the register's B7 condition 10
(location→Google classification) is answered by that matrix. All rows are App
Functionality, not linked, not tracking.

## §4 — Screenshots

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

**Current committed sets, verified at store dimensions:**

- **iPhone 17 Pro Max, 6 of 6**, all exactly 1320×2868 — Home, Map, Program,
  Passport, the Observatory 360° tour, and Settings → Credits (replacing the old
  Settings → Preview shot, which no longer earns a slot now that the passport is
  live and needs no preview to demonstrate).
- **iPad Pro 13-inch, 6 of 6**, all exactly 2064×2752 — Home, Program,
  My Night, Map, panorama and Passport.

## §5 — DSA / territories

**Decided: Australia-only distribution** (owner decision, 2026-09-06). The app is
a companion to a one-night event on one campus in Sydney, and the owner has set
availability to **Australia only** — in App Store Connect, deselect every other
territory so that only Australia is checked.

The direct consequence is that **no DSA trader-status declaration is required**.
Apple asks for that declaration only when an app is distributed in EU
territories; with no EU territory selected, App Store Connect does not present or
require it. The question of whether Macquarie University (or Leo Alavi as the
publishing account) is a "trader" under the EU Digital Services Act is therefore
not reached, and this audit makes no such legal determination.

**Revisit only if EU availability is ever added.** If a later release selects any
EU territory, the DSA trader-status declaration becomes mandatory again, and the
"trader vs. non-trader" determination — a legal question, not a technical one —
must be made before that release can ship. Until then there is nothing to do
here, and row 10 is `NOT APPLICABLE`.
