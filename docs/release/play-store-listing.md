# Google Play — requirements, listing copy, and the Data safety answers

Audited against Google Play documentation current on **2026-08-23**.

Sources:
- <https://support.google.com/googleplay/android-developer/answer/11926878> (target API)
- <https://support.google.com/googleplay/android-developer/answer/10787469> (Data safety)
- <https://support.google.com/googleplay/android-developer/answer/10144311> (User Data policy)
- <https://support.google.com/googleplay/android-developer/answer/17134731> (policy announcement, 15 Jul 2026)

---

## ⚠️ The deadline that matters

> **From 31 August 2026, new apps and app updates must target Android 16
> (API level 36) or higher** to be submitted to Google Play.

That is **eight days** from this audit. An extension to 1 November 2026 can be
requested in Play Console, but it is not needed here:

| Setting | Value | Meets the 31 Aug 2026 rule? |
|---|---|---|
| `targetSdk` | **36** | ✅ |
| `compileSdk` | **36** | ✅ |
| `minSdk` | 24 (Android 7.0) | ✅ no minimum imposed |

`android/app/build.gradle.kts` delegates to `flutter.targetSdkVersion`, which is
`36` in the pinned Flutter 3.44.7 (`FlutterExtension.kt:34`). **Do not hardcode
these** — the delegation is what keeps them current on a toolchain bump.

**Verified from a built artifact, not from the source constant** —
`aapt2 dump badging` on `app-debug.apk`:

```
package: name='au.edu.mq.astronomy.aon2026' versionCode='1' versionName='1.0.0'
         platformBuildVersionName='16' platformBuildVersionCode='36'
         compileSdkVersion='36' compileSdkVersionCodename='16'
targetSdkVersion:'36'
uses-permission: android.permission.INTERNET
uses-permission: android.permission.CAMERA
uses-permission: android.permission.ACCESS_FINE_LOCATION
uses-permission: android.permission.ACCESS_COARSE_LOCATION
uses-permission: android.permission.ACCESS_NETWORK_STATE
uses-permission: au.edu.mq.astronomy.aon2026.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
```

That permission list **is** the Data safety declaration. There is no `AD_ID`, no
storage or media permission, no `GET_ACCOUNTS`, no `ACTIVITY_RECOGNITION`, and no
background location — which is precisely why the answers below can be "no".
`test/unit/android_permissions_policy_test.dart` now fails if any of that
changes; it was negative-verified by injecting `AD_ID` and watching it fire.

---

## Store listing copy

### App name — 30 characters

```
Astronomy Open Night
```

### Short description — 80 characters

```
The official guide to Macquarie University's Astronomy Open Night. Works offline.
```
*(80 characters — exactly at the limit; do not add a full stop.)*

### Full description — 4000 characters

Reuse the App Store description from `app-store-listing.md` verbatim. It is
within Play's limit and contains no Apple-specific wording. Two Play-specific
notes:

- Play forbids referencing other app stores in the listing. The description does
  not mention the App Store, so it is safe as written.
- Play forbids promotional wording about performance/rank ("#1", "best"). The
  description makes no such claim.

### Graphics — all mandatory

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit, **no transparency** | **DONE** — `docs/release/play-graphics/icon-512.png`, verified 512×512, `hasAlpha: no` |
| Feature graphic | 1024 × 500 JPG/PNG, no transparency | **TODO** — required for every listing. **Do not build it from the Home hero image**: rights to that photograph remain with Aleix Roig, not MQ. See `organiser-requests.md`. |
| Phone screenshots | 2–8, min 320 px, max 3840 px, ratio ≤ 2:1 | The 1320 × 2868 iPhone captures are ratio 2.17:1 and **will be rejected**; capture on an Android emulator instead |
| Tablet screenshots | Optional but strongly recommended | Same |

> **The iPhone screenshots cannot be reused on Play.** Play caps the aspect ratio
> at 2:1 and 1320 × 2868 is 2.17:1. Capture Android screenshots from an emulator
> — `Fresh_API34` exists in this machine's AVD list, though it should be replaced
> with an API 36 image to match the shipped target.

### Category and tags

- Application type: **Applications** (not Games — the passport is a trail, not a game)
- Category: **Education**
- Tags: education, maps & navigation, events

### Contact details

- Email: `[CONTACT EMAIL @mq.edu.au]` — **mandatory and shown publicly**
- Website: the MQ event page
- Privacy Policy: **mandatory** — see `mq-hosted-pages.md`

---

## Data safety form — every answer

**Mandatory even for apps that collect nothing.** Play states explicitly that a
developer whose app collects no data must still complete the form and supply a
privacy policy URL.

### Section 1 — Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing is transmitted off the device. Passport stamps, favourites, the saved plan and settings are written to `SharedPreferences` and never leave. There is no account, no analytics SDK, no advertising SDK, no crash reporter. |

That single answer closes the form. The sections below exist so the reasoning is
recorded and can be defended if Play's automated binary scan queries it.

### Why "No" is correct, per data type

Play's definition of *collected* is **data transmitted off the device** that you
or a service provider can access for longer than needed to service the request
in real time. Against that definition:

| Data type | Collected? | Reasoning |
|---|---|---|
| **Location** | **No** | `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` are declared and location *is* read — but only on-device, to draw the position marker and orient the compass. It is never transmitted or stored. **See the caveat below.** |
| Personal info | No | No account, no sign-in, no name/email/phone anywhere in the app. |
| Financial info | No | No purchases, no payment SDK. |
| Health and fitness | No | No `ACTIVITY_RECOGNITION` or `BODY_SENSORS`. |
| Messages | No | No SMS permissions. |
| Photos / videos | No | The camera is used only to decode a QR code in-memory. No image is written to storage or transmitted, and no media permissions are declared. |
| Audio | No | No `RECORD_AUDIO`. |
| Files and docs | No | No external-storage permissions. |
| Calendar / Contacts | No | Not declared, not used. |
| App activity | No | No analytics of any kind. |
| Web browsing | No | The WebView loads only files bundled in the app over `http://localhost`; it cannot browse. |
| App info and performance | No | No crash reporter, no diagnostics upload. |
| Device or other IDs | No | No GAID, no `Settings.Secure.ANDROID_ID`, no instance IDs. *(Google's April 2025 update made Android ID explicitly declarable — this app reads neither.)* |

### ⚠️ The one judgement call — settle it before submitting

Walking directions send an **origin and destination to Google's Routes API**
(`google_routes_service.dart`), after explicit in-app consent.

Two defensible readings:

1. **Not "collected"** — the coordinates are a route request, are not the user's
   device location (the wayfinding screen reads no location at all; the pair is
   chosen from a fixed list of car parks and venues), and are processed to
   service the request.
2. **"Location → Approximate location", shared with a third party, purpose
   "App functionality"** — because coordinates do reach Google.

**The safer answer is 2**, and Play's July 2026 announcement specifically says it
is adding guidance on precise-vs-approximate location disclosure. Over-declaring
is not penalised; under-declaring is. Recommendation:

- Declare **Location → Approximate location**
- Collected: **No** · Shared: **Yes** (with Google)
- Purpose: **App functionality**
- Processed ephemerally: **Yes**
- Required or optional: **Optional** — the user must consent, and can decline

This is consistent with the in-app consent copy and with the privacy policy
in `mq-hosted-pages.md`, which already discloses it. **Consistency between the
Data safety form and the privacy policy is itself a policy requirement**; the two
must not disagree.

### Section 4 — Security practices

| Question | Answer |
|---|---|
| Is all collected data encrypted in transit? | **Yes** — the only outbound request is HTTPS to `routes.googleapis.com`. The `http://localhost` panorama server never leaves the device and is confined to loopback by `network_security_config.xml`. |
| Do you provide a way for users to request data deletion? | **Yes** — Settings → Privacy → "Delete my data" clears everything on the device. |

### Account deletion requirement

**Not applicable.** Play's account-deletion policy applies to apps that let users
*create an account*. This app has none. "Delete my data" is offered anyway.

---

## Content rating (IARC questionnaire)

Same substance as the Apple age-rating answers in `app-store-listing.md`: every
content question is *None* / *No*. Expected outcome: **PEGI 3 / ESRB Everyone /
USK 0 / ACB G**.

Two Play-specific questions worth getting right:

| Question | Answer |
|---|---|
| Does the app share the user's location with other users? | **No** |
| Does the app allow users to interact or exchange content? | **No** |
| Does the app contain a web browser or allow unrestricted internet access? | **No** — the WebView renders bundled files over loopback only |

---

## Other Play Console sections

| Section | Answer |
|---|---|
| Ads | **No ads** |
| App access | All functionality available without special access; no credentials needed |
| Government apps | **No** — published by a university, not a government body |
| Financial features | **None** |
| Health apps | **No** |
| Data safety | See above |
| Target audience and content | **13+** is the honest choice — the app is for a general-audience public event, and choosing a child-directed audience would pull in the Families policy and its ads/SDK rules for no benefit |
| News app | **No** |
| COVID-19 apps | **No** |

---

## Signing and the version trap

Both are already handled in the repo; both are easy to get wrong:

- **Play App Signing gives new apps quantum-ready hybrid signing = THREE
  fingerprints.** Register **every one** with the Maps API key restriction. A key
  restricted to the upload certificate works on every build you test and fails
  for every real Play user. This is documented in the release program and is the
  single most expensive mistake available here.
- **`1.0.0+1` is spent** on the Play App Signing bootstrap AAB. Bump before the
  release candidate.
- Android release signing **fails closed** — the check lives in
  `gradle.taskGraph.whenReady`, not in `buildTypes { release { } }`, because the
  latter is evaluated at configuration time and throwing there breaks debug
  builds too. Don't "simplify" it.

---

## What is still blocked

Same three as the App Store, plus one:

1. **Privacy Policy URL** — mandatory, and Play adds constraints Apple does not:
   a live, publicly accessible, **non-geofenced**, **non-PDF**, non-editable URL
   that names either the app or the publishing entity. The copy is written; it
   needs hosting.
2. **Redistribution permission** for the map artwork, `buildings.json` and the
   photographs.
3. **Real stamp codes.**
4. **A Google Play developer account under Macquarie University**, for the same
   reason as the Apple one — the package is `au.edu.mq.astronomy.aon2026`.

Plus two Play-only production tasks: the **512 × 512 icon**, the
**1024 × 500 feature graphic**, and **Android screenshots at ≤ 2:1**.
