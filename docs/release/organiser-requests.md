# The things only a person can unblock

Everything in the codebase that can be fixed has been. What is left needs a
decision, a permission, or an account. Each item below is written as a message
you can send as-is.

> **Updated 2026-09-07 (Raouf) — branding restriction.** The project
> supervisor (Charanya Ramakrishnan) has instructed that the University's name
> must not be used for anything, because the University has not approved the
> project: *"These are your projects."* This does **not** withdraw the asset
> permission recorded below — the basemap, `buildings.json` and the 39
> panoramas remain authorised for use and all of them still ship. What it
> withdraws is **university branding and any implication of endorsement**. The
> app has been stripped accordingly (see §5). One consequence is new and
> unresolved: the **bundle identifier**, §6.
>
> **Updated 2026-09-05 (Raouf).** Two of the four are now answered by the
> project owner: the Apple Developer account is in hand (item 4), and the
> University material is the project's own (item 1). **One asset is not
> covered** — the Home hero photograph is a third party's, and the app credits
> it rather than licensing it. Attribution is not permission. That is now the
> only live item in section 1.

---

## 1. Redistribution permission for the vendored assets *(guideline 5.2)*

The repository is private, which is why committing these was fine. **That is not
permission to publish them in an app store.** Apple guideline 5.2 makes the
submitter responsible for third-party content, and App Review asks for written
authorisation when an app carries an institution's material.

Four assets are affected. **Three are settled; one is not.**

| Asset | What it is | Whose permission | Status |
|---|---|---|---|
| `assets/maps/aon_event_map.png` + `tools/aon_map/source/*.pdf` | Page 1 of the published AON 2026 Program and Map A3 PDF, used as the app's basemap | Macquarie University | Settled — owner's attestation, 2026-09-05 |
| `assets/data/buildings.json` | 170 campus buildings with names and coordinates, ported from the university's Open Day app | Macquarie University | Settled — same |
| `assets/data/indoor/*.jpg` (39 images) | 360° photographs of nine campus locations | Macquarie University | Settled — same |
| `assets/images/hero_deep_triangulum_galaxy.jpg` | "A Deep Triangulum Galaxy" — the Home screen hero | **Aleix Roig (the photographer), not MQ** | **OPEN — see below** |

**The attestation, recorded verbatim so the basis is auditable.** On 2026-09-05
the project owner (Raouf) stated: *"all the assets and material are ours. And if
it's not ours, we already cited."* That settles the three University sets — they
are the project's own material to publish, produced for this event or ported
from the same owner's sibling app.

**It does not settle the fourth**, and the difference matters:

> **Citing a photograph is not a licence to redistribute it.** A credit line
> says who made the work; permission is what lets you ship it. The app does
> credit Aleix Roig on the Home screen, and this repo's own README is explicit
> that this is not a licence: *"Not covered by any licence applied to this
> repository's source code. Rights remain with the photographer. Do not reuse it
> outside this project without permission."*

> Publishing the app is arguably still "this project"; using the image on a
> **store listing** is not obviously within it. Two concrete consequences:
>
> 1. The App Store screenshot `01-home.png` and the iPad `01-home.png` both show
>    the hero image. A store listing is a marketing surface, not the app.
> 2. It must **not** be used for the Play Store's 1024 × 500 feature graphic.
>
> Get the photographer's written permission covering (a) distribution inside a
> free public app on both stores and (b) appearance in store screenshots — or
> substitute a different hero. Do not decide this by assuming.

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
> Separately: the Home screen hero photograph ("A Deep Triangulum Galaxy" by
> Aleix Roig) was supplied by the organisers, but our records say the rights
> remain with the photographer. Could you put us in touch, or confirm that the
> permission you obtained covers publishing the app on the App Store and Google
> Play and showing the image in store screenshots?
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

## 4. The Apple Developer account — *answered 2026-09-05*

The owner has confirmed the account is in hand, and TestFlight Builds 1 and 2
were uploaded from team `94273WB4G3` ("Leo Alavi"), so this is no longer a
blocker.

One thing to keep in view rather than act on: the bundle identifier is
`au.edu.mq.astronomy.aon2026`. The app is no longer University-branded (§5),
which removes the impersonation reading, but the identifier itself is still in
the University's namespace — see §6.

---

## 5. University branding removed from the app — *done 2026-09-07*

Acting on the supervisor's instruction. The **artwork was not touched** beyond
the branding itself: the basemap, `buildings.json`, the 39 panoramas and all 17
venue pins are authorised and all still ship.

| What | Where it was | Action |
|---|---|---|
| University crest + wordmark | `assets/maps/aon_event_map.png`, top-right | Painted out in place. Image stays **2048 × 1448**, RGBA; **zero** pixels changed outside the lockup box, so the georeference and every venue pin are byte-for-byte unaffected. Guarded by `test/unit/no_university_branding_test.dart`. |
| `EventInfo.host` (`"Macquarie University"`) | Home hero eyebrow (uppercase), Info screen, Settings → About | Constant deleted; all three render sites removed. |
| `EventInfo.faculty` + `cricosProvider` (`CRICOS Provider 00002J`) | Settings → Credits, as *"Event materials and branding © {host}, {faculty}. {cricos}"* | Constants deleted. The credit now reads *"Programme content follows the published Astronomy Open Night 2026 event materials."* — no ©, no institution, no provider code. |
| `socialHandle` `@MQPhysAstro`, `hashtag` `#MQAstroOpen`, `materialReference` `FSE26193` | Declared in `EventInfo`, never rendered | Deleted. |
| *"The Faculty of Science and Engineering presents…"* / *"…here at Macquarie University"* | Two shipped event descriptions | Rewritten out of the University's first person. |
| *"Campus map: Macquarie University"* | Map overlay, Settings credits, Info credits (EN + FA) | Now credits the **source document**: *"Campus map: Astronomy Open Night programme"*. |
| *"Two Macquarie University student app developers…"* | Settings → Credits acknowledgement (EN + FA) | Now *"Two student app developers…"*. |
| Store copy: *"official guide to Macquarie University's…"*, subtitle *"Macquarie University event"*, keyword `macquarie`, `© 2026 Macquarie University` | App Store + Play listings | Rewritten; the copyright field is now a **blocker**, not a guess. |
| Privacy Policy / Support / Terms written in the University's voice | `hosted-pages.md` | Rewritten to `[PUBLISHER]`; must not be hosted on an `mq.edu.au` domain. |

**Not changed, deliberately:** real venue, street, suburb and Metro-station
names (`Macquarie Theatre`, `Macquarie University Metro Station`, `Macquarie
Park`) — these are physical signage and Transport for NSW facts visitors
navigate by at night, not branding. Incidental real-world signage inside the
360° photographs is likewise untouched. Engineering provenance comments are
kept: they are the audit trail proving what is authorised.

---

## 6. The bundle identifier — *OPEN, needs a decision*

`au.edu.mq.astronomy.aon2026` sits in the University's reverse-DNS namespace
(`au.edu.mq` ⇄ `mq.edu.au`) while the app now disclaims any affiliation. The two
facts sit awkwardly together.

**It has not been changed, on purpose.** The identifier is spent on both stores
— TestFlight Builds 1–3 and the Play bootstrap AAB. Changing it creates a new
app identity: a new App Store Connect record, a new Play listing, loss of
TestFlight history, and re-registration of the upload key and all three Play
App Signing fingerprints. That is a release-level decision, not an audit fix.

**The two options, honestly:**

1. **Keep it.** The identifier is not visible to visitors — it appears in
   Settings → Apps and in store URLs. Cheapest, and nothing in the supervisor's
   instruction is obviously about internal identifiers. Risk: a reviewer or the
   University notices an `au.edu.mq` package published by an individual.
2. **Change it** to a neutral namespace before first public release, and burn
   the existing store records. Only worth doing *now* — after public launch it
   is not reversible at all.

Ask the supervisor which they want, and record the answer here.
