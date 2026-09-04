# Data sources and provenance

Where every piece of data in this repository came from, and what still needs
confirming before the event.

## Sources

| # | Source | Location |
|---|---|---|
| S1 | **Astronomy Open Night 2026 Program and Map** (official, A3 digital) | `docs/source-materials/FSE26193_AON_2026_Program_and_Map_A3_FA_DIGITAL.pdf` |
| S2 | **MQ Journey campus building dataset** — `assets/data/buildings.json`, 170 buildings with surveyed GPS coordinates | The MQ Journey repository (read-only reference; not a runtime dependency) |
| S3 | **Direct instruction from the event organisers** — via the project brief | — |
| S4 | **OpenStreetMap** | Map tiles only. Not used as a source for any data in `lib/data/` |

## Confidence levels

Defined in `lib/models/data_confidence.dart` and carried on the data itself:

| Level | Meaning |
|---|---|
| `confirmed` | Taken verbatim from S1 |
| `derived` | Real, verified data from S2, linked to an event venue by name-matching that **we** performed |
| `placeholder` | Not available in any source. Must be replaced before the event. Rendered with a visible warning in the UI |

---

## Events — `lib/data/events_data.dart`

All 36 programme items are transcribed verbatim from **S1** pages 2–3:
20 activities, 12 short talks, 3 featured presentations, 1 keynote.

Titles, descriptions, presenters, room numbers, map-reference letters and
booking requirements are `confirmed`. Each event carries a `sourceNote`
quoting the line it came from.

### Times marked `placeholder`

S1 gives some entries a start time but no finish, and a few no time at all.
Those sessions end at the 10pm event close and are flagged in the UI.

| Event | What S1 says | What we assumed |
|---|---|---|
| Stories Across Worlds | "4.15pm start" | ends 10pm |
| Space exploration with the Junior Science Academy | "4.15pm start" | ends 10pm |
| Kids' space | "4.15pm start" (Room 109 per Liz 2026-08-31, was 106) | ends 10pm |
| Planetariums | "Sessions run about every 20 minutes, starting at 4.15pm" | ends 10pm |

**→ Ask the organisers for finish times for these four.**

### Resolved by Liz's 2026-08-31 update (supersedes S1)

Liz confirmed the following, which now override the older "no times" placeholders:

| Event | Liz 2026-08-31 | Model timing |
|---|---|---|
| Exhibition Hall (14 SCO) | "open from 4.15pm to 10pm" | `exactTime` 4.15pm–10pm |
| Capture the cosmos (17 WW foyer) | "just open all night" (Liz's "astrophotography display") | `fullEventConfirmed` → "Open all night" |
| Solar system walk (Gymnasium Road) | "no set opening times … present throughout" | `openAllNight` → "Open all night" (no scheduled start/finish) |
| Featured astro talk (17 WW G25) | "5.00pm to 5.45pm" | already `exactTime` (`featured-astrophotography`) |

There is **no separate "Astrophotography Display"** in S1 — it is Capture the
Cosmos — so none was added.

### Deliberate exclusion

**The Huntsman Telescope Exploratorium (Room 109, 1 Central Courtyard) is
absent.** It appears on S1 page 2 and on the printed map, but per **S3** the
organisers confirmed it is not going ahead.

This is the one place where the source material is the *wrong* answer, so it
is guarded by `test/unit/huntsman_exclusion_test.dart`. If you are reconciling
`events_data.dart` against the PDF and notice Room 109 missing — that is
intentional. Do not add it back.

---

## Venues — `lib/data/venues_data.dart`

| Venue | Map ref | Coordinates | Confidence |
|---|---|---|---|
| Macquarie Theatre | A | S2 `MQTH` | `derived` |
| Mason Theatre | B | S2 `14SCO` | `derived` |
| Central Courtyard | C | S2 `UBAR` | `derived` |
| 14 Sir Christopher Ondaatje Avenue | D | S2 `14SCO` | `derived` |
| 1 Central Courtyard | E | S2 `1CC` | `derived` |
| Sport and Aquatic Centre | F | S2 `SPORT` | `derived` |
| Astronomical Observatory | G | S2 `OBS` | `derived` |
| 11 Wally's Walk | H | S2 `11WW` | `derived` |
| 17 Wally's Walk | I | S2 `17WW` | `derived` |
| Toilets (×3) | — | Their building's coordinate | `derived` — building-level, not room-level |
| Food and drink | C | S2 `UBAR` | `derived` |
| Gymnasium Road | — | **none** | It is a road, not a point. A single marker would mislead |
| Registration point | 1 | Courtyard coordinate | `placeholder` — S1 marks a point inside the courtyard; we have the courtyard, not the point |
| Information points | 2, 3 | Courtyard coordinate | `placeholder` — same |
| **First aid** | — | **none** | `placeholder` — S1 shows a symbol on the map but gives no address |
| Macquarie University Metro Station | — | Approximated | `placeholder` — taken from the adjacent "Macquarie University Stn" bike-rack record in S2. Close, but not the station entrance |
| Complimentary shuttle bus | — | **none** | `placeholder` — S1 lists it in the legend with no stops, route or timetable |
| Transport NSW bus stop | — | **none** | `placeholder` — legend only |

**→ Ask the organisers for: the first aid location, shuttle stops and
timetable, and confirmation of the registration/information point positions.**

---

## Parking — `lib/data/parking_data.dart`

S1 marks free event parking at **West 5**, **West 6** and **South 2**.

| Car park | Coordinates | Confidence |
|---|---|---|
| West 5 | S2 `Carpark P West 5` | `derived` |
| South 2 | S2 `Carpark P South 2` | `derived` |
| **West 6** | **none** | `placeholder` |

### Why West 6 has no coordinate

It does not exist in the S2 dataset, and **the S1 map prints the "West 6"
label twice, in two different places** — so reading it off the map would be a
coin flip. Sending a family to the wrong car park at 10pm is the worst failure
this app could have, so it ships with no pin and an explicit warning instead.

`test/unit/data_integrity_test.dart` pins this, so adding a coordinate
requires deliberately changing a test.

**Lead for verification:** OpenStreetMap labels a "West 6" car park
immediately south-west of West 5, visible on the app's own map. That is
suggestive, **not** authoritative — OSM is not the event organiser. Confirm
with the organisers before using it.

**→ Ask the organisers which West 6 is the event car park.**

---

## Walking routes — `lib/data/routes_data.dart`

**Status: DRAFT. All nine routes are `placeholder`.**

The written directions were composed from campus coordinates, not from walking
the campus. Distances and walking times are straight-line estimates. Polylines
are two-point direct lines — rendered dashed, with an on-screen caption saying
so — because we have no surveyed path geometry.

Before the event, each route needs someone to walk it after sunset and confirm:

1. the named landmarks are visible and correctly named;
2. whether the path is lit (`lightingNotes` is currently a question, not an answer);
3. whether it is step-free (`isAccessible` is `null`, meaning *unknown*, which
   the UI renders as "not yet confirmed" — never as "no").

See `docs/navigation-strategy.md`.

---

## Open questions for the organisers

1. Finish times for the four activities listed above (Stories Across Worlds,
   Junior Science Academy, Kids' space, Planetariums). Liz's 2026-08-31 update
   resolved the other formerly-unpublished entries (Exhibition Hall, Capture the
   cosmos, Solar system walk).
2. Exact **first aid** location.
3. Which of the two mapped positions is the **West 6** event car park.
4. **Shuttle bus** stops, route and timetable.
5. Positions of the **registration point** and **information points** 2 and 3.
6. Sign-off on the **walking route directions**, ideally after a dusk walk-through.
7. Lighting and step-free status for each route.
8. Whether the **Macquarie University campus map raster** may be used in this
   app (it would give a much better basemap than OSM — see README limitations).
9. The **9 Astronomy Passport station codes** (Phase 6). These are the tokens
   printed on each venue sign that an attendee scans or types to collect a
   stamp. They are **low-friction event tokens, not secrets or proof of
   attendance** — staff redemption at the prize booth is the actual control
   (see the Phase 6 design §4.1). **Resolved 2026-09-04:** rather than wait on
   an external list, the codes are minted in the app
   (`AON-A-FL3R` … `AON-I-JRYL`, all `DataConfidence.confirmed`) and
   `tools/passport/build_station_qr.py` generates the printed signs from that
   same list, so sign and app cannot disagree. The domain release gate no
   longer disables collection (design §10). The standing condition is
   operational, not technical: **the signs installed at the venues must be the
   ones that generator produces**, because the app accepts these codes and
   nothing else. They must also be
   available in an accessible form (staff assistance, large high-contrast print,
   or a spoken/tactile alternative) for attendees who cannot read the sign
   unaided (design §14).
