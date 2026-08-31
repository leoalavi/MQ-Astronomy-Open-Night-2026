# Project scope

## The event

| | |
|---|---|
| Event | Astronomy Open Night 2026 |
| Host | Macquarie University, Faculty of Science and Engineering |
| Date | Saturday 19 September 2026 |
| Time | 4:00 PM – 10:00 PM |
| Audience | General public, families, students, astronomy enthusiasts |

## The need

Two things, in priority order:

1. **Event discovery** — 36 programme items across 9 venues in 6 hours. People
   need to know what is on, where, and whether they can still get to it.
2. **Campus navigation after dark** — the organisers' explicit request. See
   `docs/navigation-strategy.md`.

## MVP — in scope

| # | Feature | State |
|---|---|---|
| 1 | **Home** — branding, hero, date/time, quick links to Program / Map / What's On Now / Parking | Built |
| 2 | **Program** — browse activities, short talks, keynote, featured presentations; filter by time, category, location, booking; free-text search | Built |
| 3 | **Activity detail** — title, description, session times, venue, building, room, map reference, navigation action | Built |
| 4 | **What's On Now** — happening now / starting soon / later tonight, with a mockable clock | Built |
| 5 | **Map** — event venues, information points, registration, toilets, first aid, food, parking, Metro, shuttle | Built |
| 6 | **Parking and wayfinding** — start/destination selection, written directions, highlighted route line | Built, routes are draft |
| 7 | **Useful information** — toilets, first aid, Metro, shuttle, parking, event guidance | Built |

Foundation delivered alongside: design system, data model, offline event data,
109 tests, documentation, git workflow.

## Explicitly out of scope

Per the brief. Each of these was available to inherit from MQ Journey and was
deliberately left behind:

| Excluded | Note |
|---|---|
| Authentication / user accounts | Not needed for a public one-night event |
| Backend infrastructure | All data is offline and compiled in |
| Analytics / tracking | Not added, by instruction |
| Push notifications | Would require Firebase and a credential |
| QR scanning / stamp trail | MQ Journey Open Day gamification |
| Live GPS position | See `docs/navigation-strategy.md` |
| Turn-by-turn routing | Same |
| Indoor floorplans | MQ Journey has them; unnecessary for six hours |
| ~~Favourites / personal schedule~~ | **SHIPPED** (2026-08-31 review) — `favorites_store.dart`, My Night |
| Timetable / transit APIs | Would require a Transport for NSW key |
| ~~Light theme~~ | **SHIPPED** — `AonTheme.light()`; the visitor chooses. Dark remains the event default |

## Known incomplete

Tracked in `docs/data-sources.md`, all visibly flagged in the app:

1. **West 6 has no coordinate.** The official map labels it twice.
2. **First aid has no location.** Marked on the map, not stated in text.
3. **Shuttle bus has no stops or timetable.**
4. **Seven activities have no published finish time.**
5. **All walking routes are drafts** — not yet walked at night.
6. **Registration/information point positions** are courtyard-level.

## Definition of done for v1.0

- [ ] All six items above resolved with the organisers
- [ ] Every route walked after dark; lighting and step-free status recorded
- [ ] Route geometry captured as GPX and `pathConfidence` set to `confirmed`
- [ ] Organiser review of programme data against the final printed programme
- [ ] Accessibility pass — contrast, screen reader, large text
- [ ] Decision on the campus map raster (licensing) and tile hosting at scale
- [ ] Licensing position confirmed — see README
- [ ] Tested on a real phone, outdoors, at night

## Possible v2

Not committed, listed so they are not accidentally designed out:

- Personal schedule / favourites (MQ Journey has a favourites feature to draw on)
- Offline map tiles bundled for the campus bounding box
- Accessibility-optimised route variants
- Live programme updates (cancellations on the night) — needs the `FutureProvider`
  seam described in `docs/architecture.md`
- Reuse for Astronomy Open Night 2027 — the data files are the only thing that
  should need to change
