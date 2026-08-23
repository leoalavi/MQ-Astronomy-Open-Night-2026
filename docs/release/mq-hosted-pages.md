# The three MQ-hosted pages — ready-to-publish copy

App Store Connect will not accept a submission without a **Privacy Policy URL**
and a **Support URL**. Google Play requires the same. Both must be live,
publicly reachable, and stable — App Review follows them.

This file contains the finished copy. Nothing here needs writing; it needs
**hosting**, on a `mq.edu.au` address, plus the URLs pasted into App Store
Connect.

> **Every factual claim below was checked against the code**, not assumed. Where
> a claim would have been convenient but false, it has been left out — the app's
> privacy copy is already held to that standard by
> `test/unit/privacy_copy_test.dart` and friends, and this page must not
> contradict the in-app text in `settingsPrivacyBody`.

---

## Page 1 — Privacy Policy *(mandatory)*

Suggested URL: `https://www.mq.edu.au/astronomy-open-night/app-privacy`

```text
Astronomy Open Night app — Privacy Policy
Last updated: [DATE]

Macquarie University publishes the Astronomy Open Night app to help visitors
find their way around campus during the Astronomy Open Night event.

WHAT WE COLLECT
Nothing. The app has no account, no sign-in and no server of its own. We do
not collect, transmit or store any personal information about you, and the app
contains no analytics, advertising or tracking software of any kind.

WHAT THE APP STORES ON YOUR DEVICE
The app saves a small amount of information on your phone so it can remember
your choices between screens and between visits:
  - which Astronomy Passport stamps you have collected
  - which activities you have saved to your plan
  - your favourite places
  - your language, theme, motion and text-size preferences
  - whether you agreed to load Google Maps

This information never leaves your device. It is not backed up to us, it is
not linked to you, and we cannot see it. Deleting the app removes it. You can
also erase it at any time from the Settings tab, using "Delete my data".

LOCATION
Location is optional and the app works fully without it. If you allow it, your
device's location is used on the device itself to show where you are on the
campus map and to point the compass toward a venue. We do not receive it and
it is not stored.

CAMERA
The camera is used for one purpose only: reading a QR code at a venue sign for
the Astronomy Passport. It starts only when you tap "Scan QR code". Images are
processed on your device, are never saved, and are never sent anywhere.

GOOGLE MAPS AND WALKING DIRECTIONS
The app is designed to work offline, and the campus map is an image stored
inside the app. There is one exception, and the app asks you before using it.

If you choose to load a Google map, or ask for walking directions, Google
receives the information it needs to answer that request. When you ask for
walking directions, that includes the start and end points of the route you
asked for. Google handles this information under its own privacy policy:
https://policies.google.com/privacy

Until you agree, no Google map is loaded and no request is sent. You can
change your mind at any time in the Settings tab, under Privacy.

CHILDREN
The app is intended for general audiences attending a public university event.
Because it collects no personal information from anyone, it collects none from
children.

CHANGES
If this policy changes, we will update this page and the date above.

CONTACT
[CONTACT NAME OR TEAM]
[CONTACT EMAIL @mq.edu.au]
Macquarie University, Balaclava Road, Macquarie Park NSW 2109, Australia
```

---

## Page 2 — Support *(mandatory)*

Suggested URL: `https://www.mq.edu.au/astronomy-open-night/app-support`

App Review checks that this page is live and that the contact details work.
A page that only says "email us" is acceptable; a dead link is a rejection.

```text
Astronomy Open Night app — Support

Need help with the app? Email [CONTACT EMAIL @mq.edu.au] and we'll get back to
you. On the night itself, the fastest help is at any information point in the
Central Courtyard — look for the staff in event shirts.

COMMON QUESTIONS

The map doesn't show where I am.
Location is optional, and the app works without it. If you'd like the blue dot,
allow location access for the app in your device settings. If you're not on
campus yet, turn on "Preview from anywhere" in the Settings tab to see how the
map will look on the night.

The Astronomy Passport says it opens on event night.
The stamp codes go live for the event. Before then, you can try the passport
using "Preview the Astronomy Passport" in the Settings tab.

Do I need internet?
No. The map, programme, venue information and 360° tours all work offline. Only
walking directions on a Google map need a connection, and the app asks first.

How do I delete what the app has saved?
Settings tab → Privacy → "Delete my data".

ACCESSIBILITY
The app supports VoiceOver, larger text up to 200%, and Reduce Motion. If you
hit an accessibility barrier, please tell us at the address above — we want to
fix it.

EVENT DETAILS
Astronomy Open Night, Saturday 19 September 2026, 4pm – 10pm
Macquarie University, Balaclava Road, Macquarie Park NSW 2109
```

---

## Page 3 — Terms of Use *(needed for the Google Maps flow-down)*

Suggested URL: `https://www.mq.edu.au/astronomy-open-night/app-terms`

Not an App Store Connect field, but the Google Maps Platform terms require you
to pass certain terms through to end users when you embed Google Maps.

```text
Astronomy Open Night app — Terms of Use
Last updated: [DATE]

The Astronomy Open Night app is provided free by Macquarie University to help
visitors navigate the Astronomy Open Night event.

EVENT INFORMATION MAY CHANGE
Times, locations and activities are as published at the time of release and may
change. On the night, event signage and staff instructions take precedence over
anything shown in the app.

WALKING DIRECTIONS AND THE MAP
Walking directions are a guide, not a survey. Follow paths, lighting and event
signage, and take care after dark. The app tells you where a route has not yet
been checked on foot.

GOOGLE MAPS
Parts of this app use Google Maps. By using those parts you agree to the Google
Maps/Google Earth Additional Terms of Service
(https://maps.google.com/help/terms_maps/), which incorporate the Google Privacy
Policy (https://policies.google.com/privacy).

NO WARRANTY
The app is provided "as is". Macquarie University does not warrant that it will
be uninterrupted or error-free, and is not liable for any loss arising from
reliance on the information it contains, to the extent permitted by law.

CONTACT
[CONTACT EMAIL @mq.edu.au]
```

---

## What to do with these

1. Fill in `[DATE]`, `[CONTACT NAME OR TEAM]` and `[CONTACT EMAIL @mq.edu.au]`.
2. Have MQ publish all three at stable `mq.edu.au` URLs.
3. Paste the Privacy Policy URL and Support URL into App Store Connect
   (*App Information* and the version's *App Review Information*).
4. Request all three in **one** approval round — that is the longest-lead item
   on the whole release.

## Claims deliberately NOT made

- The policy does **not** say location is never sent anywhere. It is sent to
  Google when you request walking directions — `google_routes_service.dart`
  posts an origin and destination. Saying otherwise would be false.
- It does **not** claim the wayfinding screen reads your location. It does not:
  that screen's routes are hand-authored and offline, and its Google map is
  requested without a position.
- It does **not** promise the passport will work on the night. The station codes
  are still `AON-*-TBC`; the support page says the codes "go live for the
  event", which is the truthful version of that sentence.
