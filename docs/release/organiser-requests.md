# The four things only a person can unblock

Everything in the codebase that can be fixed has been. What is left needs a
decision, a permission, or an account. Each item below is written as a message
you can send as-is.

Send **1 and 2 together** — they go to overlapping people and both are on the
critical path.

---

## 1. Redistribution permission for the vendored assets *(guideline 5.2)*

The repository is private, which is why committing these was fine. **That is not
permission to publish them in an app store.** Apple guideline 5.2 makes the
submitter responsible for third-party content, and App Review asks for written
authorisation when an app carries an institution's material.

Three assets are affected:

| Asset | What it is |
|---|---|
| `assets/maps/aon_event_map.png` + `tools/aon_map/source/*.pdf` | Page 1 of the published AON 2026 Program and Map A3 PDF, used as the app's basemap |
| `assets/data/buildings.json` | 170 campus buildings with names and coordinates, ported from the university's Open Day app |
| `assets/panorama/**` (28 images) | Photographs of six campus venues |

> **Subject: Permission to publish MQ campus assets in the Astronomy Open Night app**
>
> Hello,
>
> We're preparing the Astronomy Open Night app for release on the App Store and
> Google Play. Before we can submit, we need written confirmation that we may
> publish three pieces of University material inside it:
>
> 1. The campus map artwork from page 1 of the published "AON 2026 Program and
>    Map" PDF. We use it unmodified as the app's map background, credited on
>    screen as "Campus map: Macquarie University".
> 2. A dataset of 170 campus building names and locations, originally produced
>    for the University's Open Day app.
> 3. Twenty-eight 360° photographs of six campus venues, used for in-app venue
>    tours.
>
> Apple and Google both hold the submitter responsible for third-party content,
> and App Review can ask us to produce this authorisation. A short written "yes,
> the University authorises publication of these assets in this app" is enough.
>
> Could you also confirm who owns the copyright line for the campus map? The app
> currently credits it as a source ("Campus map: Macquarie University") rather
> than asserting a copyright symbol, because we did not want to state ownership
> we hadn't had confirmed.
>
> Thank you,
> [NAME]

**Why the copyright question is in there:** `test/unit/map_attribution_test.dart`
deliberately **fails** if a `©` appears in the campus map attribution string,
precisely until this is answered. That test is a placeholder for this
conversation, not an oversight.

> **Note a tension worth resolving in the same reply:** the Credits screen now
> reads *"Event materials, campus map and branding © Macquarie University"*.
> That string asserts the very copyright the map attribution test refuses to
> assert. Both cannot be right. Either the sign-off arrives and both can say
> `©`, or the Credits line should drop the campus map from its `©` clause.

---

## 2. The nine Astronomy Passport codes

The app is built and tested; only the values are missing.

> **Subject: Astronomy Passport — the nine venue codes**
>
> Hello,
>
> The Astronomy Passport stamp trail is finished and tested. To switch it on for
> the night we need one thing: the code that will be printed on each of the nine
> venue signs.
>
> The app accepts a code either by scanning a QR code or by typing it in, so we
> need to agree the text value. Our suggestion is a short, unambiguous code per
> venue, avoiding characters people confuse when typing (no O/0, no I/1), for
> example `AON-MACTHEATRE`. If you'd rather we generate them, we can — we just
> need to know **who is printing the signs**, so the printed value and the app
> agree.
>
> The nine stops are:
>   A  Macquarie Theatre
>   B  Mason Theatre
>   C  Food and drink, Central Courtyard
>   D  14 Sir Christopher Ondaatje Avenue
>   E  1 Central Courtyard
>   F  Macquarie University Sport and Aquatic Centre
>   G  Astronomical Observatory (telescopes)
>   H  11 Wally's Walk
>   I  17 Wally's Walk
>
> QR codes should encode the code prefixed with `AON2026:` — for example
> `AON2026:AON-MACTHEATRE`. Typed entry is not case-sensitive.
>
> Thank you,
> [NAME]

**What changes in the code when they answer:** one file. Put the real values in
`lib/data/stamp_stations_data.dart` and mark each `codeConfidence` as reliable.
The release gate then opens by itself — `PassportPolicy.isCollectionEnabled`
already tests exactly that. A canary in
`test/unit/passport_preview_test.dart` fails the moment it happens, to remind
you to update the App Review notes and drop the preview paragraph.

---

## 3. Two questions about the printed map

Raised earlier and still unanswered. Neither is a code bug and neither should be
"fixed" in data.

1. The sheet **draws four toilet `T` discs but its legend lists three.** Which is
   right? The app follows the legend.
2. The legend's **`C` ("Food and drink, Central Courtyard") is printed over
   building 1CC, not the courtyard block.** The `central-courtyard` venue
   therefore carries `mapReference: null` rather than guessing.

There is also a third, smaller one: there is a 360° panorama of the **Jim Piper
Centre (12 Wally's Walk)**, but the official map letters no activity there, so it
is held out of the picker. If something is happening there, it should get a
letter; if not, the photographs go unused.

---

## 4. The Apple Developer account *(explicitly out of scope for now)*

Noted here only so the list is complete — you have said this is waiting on the
University. The bundle identifier is `au.edu.mq.astronomy.aon2026`, so the app
must be published from Macquarie University's Apple Developer account, or with
written authority to publish on the University's behalf. Submitting a
university-branded app from an unaffiliated individual account risks rejection
under guidelines 4.1 and 5.1.1.1 regardless of everything else in this document.
