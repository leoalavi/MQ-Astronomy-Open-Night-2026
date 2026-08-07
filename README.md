# Astronomy Open Night 2026

Event discovery and night-time campus wayfinding for **Macquarie University
Astronomy Open Night 2026**.

> **Status: technical foundation.** The app runs, all 36 official programme
> items are loaded, and every screen in the MVP is present and working. Several
> pieces of event data are still unconfirmed and are visibly flagged in the UI.
> See [Project status](#project-status).

---

## Event context

| | |
|---|---|
| **Event** | Astronomy Open Night 2026 |
| **Host** | Macquarie University, Faculty of Science and Engineering |
| **Date** | Saturday 19 September 2026 |
| **Time** | 4:00 PM – 10:00 PM |
| **Audience** | General public, families, students, astronomy enthusiasts |

Two needs drive the product: **finding what is on** across 36 items in 9 venues
over 6 hours, and **getting around campus in the dark** — the organisers
specifically asked for clearer guidance between the car parks and the venues,
because attendees get disoriented at night.

---

## MVP

| | Screen | What it does |
|---|---|---|
| 1 | **Home** | Branding, hero, date and time, live "happening now" strip, quick links, practical guidance |
| 2 | **Program** | All 36 items grouped by section. Filter by time band, category, venue and booking requirement; free-text search across titles, presenters, rooms and tags |
| 3 | **Activity detail** | Description, all session times, venue, building, room, printed-map reference, and a "Walk there" action |
| 4 | **What's On Now** | Happening now / open all evening / starting soon / later tonight, driven by an injectable clock with an in-app time simulator |
| 5 | **Map** | Venues (with printed-map legend letters), information points, registration, toilets, first aid, food, parking, Metro and shuttle — on a dark basemap |
| 6 | **Parking & wayfinding** | Pick where you parked and where you're going; get written directions, walking time, lighting notes and a route line |
| 7 | **Useful information** | Toilets, first aid, transport, parking and event guidance |

---

## Architecture overview

**Flutter 3.44 · Riverpod 3 · go_router · flutter_map** — the MQ Journey stack,
minus everything this product does not need.

```
lib/
├── app/         theme + router
├── models/      types (Event, Venue, ParkingArea, WalkingRoute, DataConfidence)
├── data/        the event data, compiled in
├── services/    clock, filtering, what's-on logic, Riverpod providers
├── utils/       formatting, category styling
├── widgets/     shared components
└── screens/     the seven screens above
```

Three decisions worth knowing up front:

- **Offline first.** Event data is `const` Dart compiled into the binary — no
  asset load, no JSON parse, no cache, no network. Only map tiles need
  connectivity.
- **Time is injected.** Nothing calls `DateTime.now()`; everything reads
  `currentTimeProvider`. That is what makes "What's On Now" testable and
  demonstrable before September 2026.
- **Confidence is a type.** `DataConfidence` (`confirmed` / `derived` /
  `placeholder`) is a field on the data, and the UI renders a visible warning
  wherever a placeholder appears.

Full detail: [`docs/architecture.md`](docs/architecture.md).

### Zero credentials

| | |
|---|---|
| API keys required | **None** |
| Backend | **None** |
| Runtime permissions | **None** |
| Direct dependencies | 6 |

`flutter_map` renders OpenStreetMap tiles without an SDK key, and there is no
auth, no analytics and no push. `.env.example` documents this absence
deliberately, so a missing key is never mistaken for the cause of a bug.

---

## Reused from MQ Journey

MQ Journey was inspected **read-only**. Nothing in it was modified, and this
project has **no runtime dependency** on it — everything reused was copied or
rewritten in.

| Reused | How |
|---|---|
| **The stack** — Flutter 3.44 + Riverpod 3 + go_router + flutter_map | The highest-value reuse. Known team, proven version matrix, minimal technical risk |
| **Design token structure** | Same `abstract final class` pattern; every value replaced for a night palette, larger type and 56pt tap targets |
| **`Building` → `Venue`** | 448 lines cut to ~120. Kept the entrance-vs-centroid coordinate split and aliases; dropped faculty/services/hub grouping and the search index |
| **Campus coordinates** | Real surveyed GPS for the ten event venues, from MQ Journey's 170-building dataset |
| **`go_router` shell structure** | Per-tab navigation stacks |
| **Lint config** | So both codebases read identically |

**Deliberately not reused:** Supabase, Firebase, auth, QR scanning, timetable,
transit, notifications, favourites, indoor floorplans, the campus map raster,
and — most significantly — **MQ Journey's Google Routes API routing**, which
needs a billed key, a network round-trip, and has no idea which campus paths
are lit.

Full analysis with REUSE / MODIFY / DO NOT REUSE / REBUILD classifications:
[`docs/mq-journey-reuse-analysis.md`](docs/mq-journey-reuse-analysis.md).

---

## Setup

Requires Flutter `3.44.0` (Dart `3.11+`).

```bash
flutter pub get
```

```bash
flutter run
```

No `.env`, no keys, no backend.

### Other commands

```bash
flutter test
```

```bash
flutter analyze
```

```bash
flutter run -d chrome
```

```bash
flutter build apk --release
```

```bash
flutter build ios --release
```

---

## Development workflow

| Branch | Purpose |
|---|---|
| `main` | Stable |
| `develop` | Integration — default PR target |
| `feature/*` | New work |
| `fix/*` | Bug fixes |

`flutter analyze && flutter test` must be clean before pushing.

House rules — including *never re-add the cancelled Huntsman session* and
*never invent a coordinate* — are in [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Project status

**Working:** all seven MVP screens, the full official programme (36 items),
9 venues with real coordinates, 3 car parks, 9 draft walking routes, dark
design system, 109 passing tests, documentation.

**Unconfirmed** — all visibly flagged in the app and tracked in
[`docs/data-sources.md`](docs/data-sources.md):

| # | Open question |
|---|---|
| 1 | **West 6 car park has no coordinate.** The official map prints the label twice, in two places. Ships with no pin, on purpose |
| 2 | **First aid location.** Marked on the printed map, not stated in text |
| 3 | **Shuttle bus** stops, route and timetable — legend only |
| 4 | **Seven activities have no published finish time** — assumed to run to 10pm |
| 5 | **All nine walking routes are drafts** — composed from coordinates, not walked at night |
| 6 | **Registration and information points** are positioned at courtyard level |

---

## Known limitations

- **Route geometry is indicative, not surveyed.** Route lines are two-point
  direct lines, rendered dashed with an on-screen caption saying so. Replace
  with a GPX trace and flip `pathConfidence` to get solid lines.
- **Map tiles need connectivity.** Event data is fully offline; the basemap is
  not. Worth considering bundled offline tiles for the campus bounding box.
- **OSM public tile servers at event scale.** Thousands of devices on one
  evening is a lot to ask of a donated service, and the OSMF Tile Usage Policy
  applies. Before the night, consider self-hosting or a commercial provider —
  `MapConfig.tileUrlTemplate` is the single point of change.
- **The basemap is generic OpenStreetMap.** Macquarie's own campus map raster
  would be far better, and MQ Journey already has it with an affine projection.
  Not used here pending a licensing decision.
- **No offline fallback map.** If tiles fail, the map is empty. Written
  directions still work, which is why they are the primary output.
- **Times are naive local `DateTime`.** Correct for an in-person single-day
  event; would need the `timezone` package to be correct elsewhere.
- **No accessibility audit yet.** Contrast ratios are documented in
  `aon_colors.dart` but not asserted, and no screen-reader pass has been done.
- **Not yet tested on a real phone, outdoors, at night.** This is the single
  most valuable outstanding test.

---

## Attribution

### Hero image

> **"A Deep Triangulum Galaxy" — Aleix Roig, 2026**

Supplied for this project by the event organisers. Used as the Home screen hero
image. **Not covered by any licence applied to this repository's source code.**
Rights remain with the photographer. Do not reuse it outside this project
without permission.

The original full-resolution file is preserved at
`docs/source-materials/hero_deep_triangulum_galaxy_ORIGINAL.jpg`; the bundled
asset is a resized derivative.

### Event materials

Programme content, activity names, descriptions, times, venue names, the campus
event map and the map legend are © **Macquarie University**, Faculty of Science
and Engineering. CRICOS Provider 00002J. Source material:
`docs/source-materials/FSE26193_AON_2026_Program_and_Map_A3_FA_DIGITAL.pdf`.

Macquarie University names, logos and branding are the property of Macquarie
University.

### Map data

Map tiles and data © **OpenStreetMap contributors**, available under the
[Open Database License](https://www.openstreetmap.org/copyright). Attribution
is displayed in-app on every map.

### Campus coordinates

Building coordinates were sourced from the MQ Journey project's campus dataset,
a separate internal project.

### Third-party packages

Flutter, Riverpod, go_router, flutter_map, latlong2 and intl remain under their
own licences. Run `flutter pub deps` for the full tree.

---

## Licensing

**No licence has been applied to this repository yet. This is deliberate.**

Until a licensing decision is made and confirmed with all rights-holders, treat
this repository as **all rights reserved**.

What we can state:

- **Original source code** written for this project may later be released under
  an open-source licence. That decision has not been made.
- **Macquarie University logos, branding, maps, campus imagery and event
  materials are not covered** by any licence that may later apply to the source
  code. They belong to Macquarie University.
- **Supplied photography and artwork** — including the hero image — is **not
  covered**. Rights remain with the photographer.
- **Third-party assets and packages** remain under their original licences.
- **OpenStreetMap data** is under the ODbL and carries its own attribution
  requirements, independent of anything decided here.

No claim is made beyond what is confirmed above. Before publishing this
repository or reusing any part of it, confirm the position with Macquarie
University and with Aleix Roig.

---

## Documentation

| Document | Contents |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Stack, layout, key decisions, timezone handling |
| [`docs/mq-journey-reuse-analysis.md`](docs/mq-journey-reuse-analysis.md) | Full reuse classification and rationale |
| [`docs/project-scope.md`](docs/project-scope.md) | MVP, exclusions, definition of done, possible v2 |
| [`docs/data-sources.md`](docs/data-sources.md) | Provenance of every data item; open questions |
| [`docs/navigation-strategy.md`](docs/navigation-strategy.md) | Why predefined routes and not turn-by-turn |
| [`docs/testing-strategy.md`](docs/testing-strategy.md) | What is tested, what is not, and why |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Setup, branches, house rules |
