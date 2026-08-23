# App Review notes — aon2026

Paste the **"Notes for Review"** block verbatim into App Store Connect →
your app version → *App Review Information* → *Notes*.

Apple's own guidance is that **over 40% of unresolved review issues are
guideline 2.1 (App Completeness)** — crashes, placeholder content, incomplete
information. Everything below exists to remove that category in advance.

Sources (fetched 2026-08-23):
- <https://developer.apple.com/distribute/app-review/>
- <https://developer.apple.com/app-store/review/guidelines/>
- <https://developer.apple.com/news/upcoming-requirements/>

---

## Notes for Review (copy this)

```text
ABOUT THIS APP
Astronomy Open Night is the free visitor companion for a public astronomy
event held by Macquarie University in Sydney on Saturday 19 September 2026,
4–10pm. It is offline-first: campus map, event programme, wayfinding, 360°
venue tours, and a QR "Astronomy Passport" stamp trail. English and Persian.

NO ACCOUNT IS REQUIRED
There is no sign-in, no account and no server. Every feature is reachable on
first launch with no credentials. Nothing needs a demo account.

HOW TO REVIEW THE ASTRONOMY PASSPORT (please read — this is the one
feature that is time-gated)
The passport is a QR stamp trail. The nine physical venue signs are printed
by the university closer to the event, so the final QR codes do not exist
yet. Rather than ship the feature dormant, we included a user-visible
preview so it is fully reviewable today:

  1. Open the app and tap the "Settings" tab (last of the six tabs).
  2. Scroll to the "Preview" section.
  3. Turn ON "Preview the Astronomy Passport".
  4. Open the passport: either tap the "Astronomy Passport" card on the
     "Home" tab, or tap the "Astronomy Passport" button on the "Info" tab.
  5. Tap "Scan or enter a code", then "Enter a code".
  6. Type any of these preview codes and tap "Add stamp":
        AON-A-TBC   AON-B-TBC   AON-C-TBC
        AON-D-TBC   AON-E-TBC   AON-F-TBC
        AON-G-TBC   AON-H-TBC   AON-I-TBC
     Each code adds one stamp and reveals an astronomy fact.
     Entering all nine opens the completion reward screen.
  7. The QR scanner can be reviewed with the same values encoded as a QR
     code with the prefix "AON2026:" (for example: AON2026:AON-A-TBC).

NAVIGATION NOTE
The app has six tabs: Home, Program, Night, Map, Info, Settings. The
passport is not a tab — it is reached from the "Astronomy Passport" card on
the Home tab, or the "Astronomy Passport" button on the Info tab.

While preview is on, a "Preview stamps" badge is shown on the passport so a
practice stamp is never mistaken for one earned at a venue. The switch is
session-only and resets when the app is closed.

LOCATION
Location is optional. The app is fully usable without granting it. Location
is used on-device to draw your position on the campus map and to point the
compass. It is not required to review any feature.

If you are not physically on the Macquarie University campus, the map's
position marker will naturally be off-screen. To review location-dependent
screens from anywhere, turn ON the Settings tab → Preview → "Preview from anywhere".
This substitutes a clearly-labelled simulated on-campus position; a
"Simulated location" badge is shown wherever that position is drawn.

GOOGLE MAPS AND NETWORK USE
The app is offline-first and makes NO network requests at launch. The single
exception is walking directions, which use the Google Maps SDK and Google
Routes API. This is behind an explicit in-app consent screen: the Google
Maps SDK is not initialised, and no request is made, until the user accepts.
Consent can be revoked in the Settings tab → Privacy. The campus map itself is a
bundled image asset and needs no network at all.

The 360° venue tours are rendered in a WKWebView from files bundled inside
the app, served over http://localhost only. No remote content is loaded.

PRIVACY
No account, no analytics, no advertising, no tracking. Passport stamps,
favourites and the saved plan are stored only on the device. The Settings
tab → Privacy explains this in full and offers "Delete my data".

CAMERA
The camera is used only to read a QR code for the passport, and only after
the user taps "Scan QR code". Opening the passport screen never starts the
camera. Images are processed on-device and never stored or transmitted.

ACCESSIBILITY
Supports Dynamic Type to 200%, VoiceOver, and Reduce Motion.

CONTACT
<NAME>, <EMAIL>, <PHONE>
```

---

## Fill these in before submitting

| Placeholder | Where it comes from |
|---|---|
| `<NAME>` / `<EMAIL>` / `<PHONE>` | The App Review contact. Must be reachable during review. |

If the organisers supply the **real** stamp codes before submission, replace
the `AON-*-TBC` list above with the real ones **and** delete the preview
paragraph — the release gate opens by itself once every code is marked
reliable, and `test/unit/passport_preview_test.dart` has a canary that fails
to remind you.

---

## Why the passport preview exists (rationale, not for pasting)

Guideline **2.3.1(a)**: *"Don't include any hidden, dormant, or undocumented
features in your app; your app's functionality should be clear to end users
and App Review… and accessible for review."*

Before this change, `PassportPolicy.isCollectionEnabled` refused all
collection in any release build while a station code was still
`AON-*-TBC` — which is all nine of them. A reviewer opening the passport
saw one sentence, "Astronomy Passport opens on event night", and had no way
to reach the feature. That is textbook dormant functionality, and the app
also *advertised* the passport, engaging guideline **2.3** (accurate
metadata) at the same time.

The fix follows the pattern this codebase already established for simulated
location, and for the same documented reason — see
`lib/services/preview_location.dart`, which cites 2.3.1(a) explicitly. Apple
also blesses this shape directly: *"you may include a built-in demo mode in
lieu of a demo account… Ensure the demo mode exhibits your app's full
features and functionality."*
