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

HOW TO REVIEW THE ASTRONOMY PASSPORT
The passport is a QR stamp trail across nine campus venues. The station
codes are final and fully enabled in this build. The physical QR signs are
installed on campus for the event, so away from campus please use manual
code entry — every step is reachable without a sign:

  1. Open the passport: tap the "Astronomy Passport" card on the "Home" tab.
     (The passport is reached only from Home — it is not a tab, and it is not
     on the Info tab.)
  2. Tap "Scan or enter a code", then "Enter a code".
  3. Type any of these station codes and tap "Add stamp":
        AON-A-FL3R   AON-B-HFUM   AON-C-MU4T
        AON-D-H3HA   AON-E-CJQX   AON-F-UF37
        AON-G-YHVN   AON-H-3WNQ   AON-I-JRYL
     These are the live codes printed on the nine venue signs. Each adds one
     stamp and reveals an astronomy fact. Entering all nine opens the
     completion reward screen.
  4. The QR scanner can be reviewed with the same values encoded as a QR
     code with the prefix "AON2026:" (for example: AON2026:AON-A-FL3R).

  No preview switch is needed — the passport is fully enabled in this build.
  Settings › Preview › "Preview the Astronomy Passport" still exists and is
  harmless; it only ever opens the capture gate, never closes it.

NAVIGATION NOTE
The app has six tabs: Home, Program, Night, Map, Info, Settings. The
passport is not a tab — it is reached from the "Astronomy Passport" card on
the Home tab.

While preview is on, a "Preview stamps" badge is shown on the passport so a
practice stamp is never mistaken for one earned at a venue. The switch is
session-only and resets when the app is closed.

FIRST LAUNCH
There is no onboarding, sign-in or welcome flow. The app opens directly on
the Home tab (event name, date, what's on, the passport card and the map
shortcut). No permission dialog is shown at launch.

LOCATION
Location is optional. The app is fully usable without granting it. Location
is used on-device to draw your position on the campus map and to point the
compass. It is not required to review any feature.

Opening the "Map" tab never shows a permission dialog. The permission is
requested only when you tap the on-map "Show my location" control (or open
the compass / ask for walking directions). If you decline, the Map still opens
and works normally; tapping the control again is the deliberate path to try
again or re-enable location later.

The app only ever requests "When In Use". Info.plist also carries
NSLocationAlwaysAndWhenInUseUsageDescription because the linked location
plugin (geolocator) compiles a requestAlwaysAuthorization call that Apple's
static scan attributes to the app bundle (ITMS-90683 on Build 2). That code
path is unreachable here — the plugin requests Always only when the When In
Use string is absent, and it is present. There is no location background
mode, no allowsBackgroundLocationUpdates, and no Always prompt.

If you are not physically on the Macquarie University campus, the map's
position marker will naturally be off-screen. To review location-dependent
screens from anywhere, turn ON the Settings tab → Preview → "Preview from anywhere".
This substitutes a clearly-labelled simulated on-campus position; a
"Simulated location" badge is shown wherever that position is drawn.

GOOGLE MAPS AND NETWORK USE
The app is offline-first and makes NO network requests at launch. The single
exception is walking directions, which use the Google Maps SDK and Google
Routes API. The Google Maps SDK is not initialised, and no request is made,
until directions are used: nothing about Google runs on the tabs, and the
campus map itself is a bundled image asset that needs no network at all.

Two directions paths, with two disclosure shapes:
  - "Walking directions" from a venue or building opens directions inside the
    app. Google Maps is the app's only directions provider, so opening
    Directions is itself the choice to use it; there is no provider to pick
    and no modal.
  - The car-park wayfinding screen shows an explicit "Use Google Maps for
    directions?" disclosure with Accept / Not now before anything loads.
In both cases the visitor can turn directions data-sharing off at any time in
the Settings tab → Privacy, which stops the SDK initialising and shows an
in-app panel with a one-tap re-enable. The app never hands off to the external
Google Maps app.

WHAT IS SENT TO GOOGLE, AND WHEN
Only when the visitor opens walking directions: their current coordinates as
the route origin, and the destination coordinates. Nothing else — no name, no
account (there is none), no device identifier added by the app. This is
declared in the privacy manifest as Precise Location, collected for App
Functionality, not linked to identity and not used for tracking.

The 360° venue tours are rendered in a WKWebView from files bundled inside
the app, served over http://localhost only. No remote content is loaded.

PRIVACY
No account, no analytics SDK, no advertising, no tracking. Passport stamps,
favourites and the saved plan are stored only on the device and never leave
it. The one thing that does leave is the pair of coordinates described above,
and only when directions are opened. The Settings tab → Privacy explains this
in full and offers "Delete my data".

CAMERA
The camera is used only to read a QR code for the passport, and only after
the user taps "Scan QR code". Opening the passport screen never starts the
camera. Images are processed on-device and never stored or transmitted.

ACCESSIBILITY
Supports Dynamic Type to 200%, VoiceOver, and Reduce Motion.

CONTACT
Leo Alavi, leo.alavi.dev@gmail.com, +61451519624
```

---

## App Review contact — supplied

| Field | Value |
|---|---|
| First name | Leo |
| Last name | Alavi |
| Email | leo.alavi.dev@gmail.com |
| Phone | +61451519624 |

Supplied by Leo 2026-09-06 and pasted into the CONTACT line above. This is the
reviewer contact for App Store Connect → *App Review Information*. It must stay
reachable during the review window.

The codes above are the live ones as of 2026-09-04 and must stay in step with
`lib/data/stamp_stations_data.dart`. If a code changes there, update this list,
re-run `tools/passport/build_station_qr.py`, and re-print the venue signs — the
app accepts these codes and nothing else. `test/unit/passport_preview_test.dart`
carries a canary that fails if any station goes back to a placeholder.

---

## Why the passport preview exists (rationale, not for pasting)

Guideline **2.3.1(a)**: *"Don't include any hidden, dormant, or undocumented
features in your app; your app's functionality should be clear to end users
and App Review… and accessible for review."*

Before the codes landed, `PassportPolicy.isCollectionEnabled` refused all
collection in any release build while a station code was still
`AON-*-TBC` — which was all nine of them. A reviewer opening the passport
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
