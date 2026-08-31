# Solar System Walk — 360° Route Tour — Design

**Status:** design, awaiting user review. **No code written.** Forked from
`main@19d82d9`; sits on top of the G/Observatory tour shipped on branch
`feat/panorama-observatory-tour`. Branch (at execution): `feat/solar-system-walk-tour`.

**Goal:** Ship the programme's **Solar system walk** as a 360° route tour — eight
scenes running Central Courtyard → Gymnasium Road → Telescope Park, in the
direction visitors actually walk it — using six AON originals that already exist
and are currently unused.

> **This is a walk, not a building.** Every existing tour is a set of rooms
> inside one venue. This one is a *linear route between two venues*, which is why
> it cannot simply be appended to `PanoramaData.tours` and left to the picker.
> §4 is the only genuinely open design question.

---

## 1. Why this exists

The official **AON 2026 Program and Map** lists, under Gymnasium Road:

> Solar system walk — Join us on a walk from the Central Courtyard to our
> Telescope Park, passing the planets of our solar system in our scale model.
> Every metre you walk represents 37.3 million kilometres. Think you can make it
> all the way?

It is one of only three activities on the sheet with no fixed room, and the only
one whose *content is the journey*. Six photographs of that journey were shot on
2026-08-23 and have sat unused ever since, three of them labelled "optional" by
the photographer — which is how they came to be read as spares rather than as a
sequence.

`tools/panorama/build.py` already anticipated this: `1 CC- Downstairs.JPG` is
parked in `HELD_OUT_ROUTE_SCENES` with the comment *"Retained for the future
road/route panorama."* This design is that route.

## 2. The evidence for the order (and what must NOT be used)

### 2.1 EXIF GPS position is unusable — do not order by it

All 30 AON originals carry a GPS IFD. Measured against the venue coordinates in
`assets/data/buildings.json`, the error runs from **21 m to 1377 m**; six
photographs are more than 180 m out. `1 CC- Downstairs.JPG` places a shot taken
beside 1 Central Courtyard **945 m** away.

**Any ordering derived from these coordinates is fiction.** This is recorded in
`docs/panorama-image-provenance.md` under Known limitations.

### 2.2 GPS timestamps ARE sound, and reconstruct the shoot

`GPSDateStamp` + `GPSTimeStamp` (UTC; +10 h for AEST) survive on every file and
put the six route photographs in one continuous session:

| AEST (23 Aug) | Photograph | Place |
|---|---|---|
| 15:18 | `Astronomical Observatory Entrance 1.JPG` | Observatory, 5 Gymnasium Rd |
| 15:22 | `Astronomical Observatory Entrance 2.JPG` | Observatory gate |
| 15:32 | `1 Gymnasium road- Optional.JPG` | Gymnasium Rd |
| 15:36 | `1 Gymnastic road - optional 1.JPG` | Gymnasium Rd |
| 15:40 | `Next Sense— North 3 Parking - optional.JPG` | NextSense, 2 Gymnasium Rd |
| 15:45 | `Sport and Aquatic Centre — 10 Gymnasium Road — entrance.JPG` | SAC, 10 Gymnasium Rd |
| 16:03 | `1 CC close to stairs.JPG` | back at the Courtyard |

`1 CC- Downstairs.JPG` is from the 26 Aug session (15:33), immediately before
that day's walk to the planetarium.

### 2.3 The timestamps agree with the map, independently

Sorting the same buildings by `campusY` in `buildings.json` (lower = further
north) gives: Observatory **480** → NextSense **957** → Lighthouse/Crunch
**~1140** → SAC **1289** → Student Accommodation **1495** → Courtyard. The
photographer walked that line **north → south**. Two independent sources, same
order.

### 2.4 Therefore the tour is the reverse of the capture order

The programme says the walk runs *"from the Central Courtyard to our Telescope
Park"* — south → north. **Capture order is backwards relative to the visitor.**
Reversing it is the single most important thing this design gets right.

## 3. The proposed sequence

Venue id `gymnasium-road`, manifest `assets/data/indoor/gymnasium-road.json`.

| # | Scene id | Label | Source original | Confidence |
|---|---|---|---|---|
| 1 | `courtyard-stairs` | Leaving the Central Courtyard | `1 CC- Downstairs.JPG` | High |
| 2 | `courtyard-exit` | Courtyard exit | `1 CC close to stairs.JPG` | High |
| 3 | `sport-and-aquatic-centre` | Sport and Aquatic Centre (10 Gymnasium Road) | `Sport and Aquatic Centre — 10 Gymnasium Road — entrance.JPG` | High |
| 4 | `nextsense` | NextSense (2 Gymnasium Road) | `Next Sense— North 3 Parking - optional.JPG` | High |
| 5 | `gymnasium-road-south` | Gymnasium Road | `1 Gymnastic road - optional 1.JPG` | Medium |
| 6 | `gymnasium-road-north` | Gymnasium Road | `1 Gymnasium road- Optional.JPG` | Medium |
| 7 | `observatory-approach` | Observatory approach | `Astronomical Observatory Entrance 1.JPG` | See §6.1 |
| 8 | `observatory-entrance` | Telescope Park | `Astronomical Observatory Entrance 2.JPG` | See §6.1 |

Scenes 5 and 6 are **Medium**: their relative order rests on the 4-minute capture
gap alone. Neither shows signage that fixes it independently (5 is a colonnaded
building at dusk, 6 a grey shed between two car parks). Getting them the wrong
way round is a minor cosmetic error on an otherwise correct route; it is called
out here rather than presented as certain.

### 3.1 Asset reuse needs a build.py change (corrected 2026-08-31)

Three of the eight scenes are photographs the bundle **already carries**: scene 1
is `1-central-courtyard_downstairs.jpg`, and scenes 7–8 are the G tour's
`astronomical-observatory_approach.jpg` / `_entrance.jpg`.

An earlier draft of this design claimed those could simply be pointed at, "so one
encode serves both tours". **That is not true of `build.py` as written.**
`asset_name()` is `f"{venue_id}_{scene_id}.jpg"` and `write_manifests()` hard-codes
`f"indoor/{asset_name(venue_id, scene_id)}"`, so a `gymnasium-road` tour would
emit `gymnasium-road_observatory-approach.jpg` and two more — **three byte-identical
duplicates**, ~6 MB of bundle for nothing, and two copies of an image that must
stay in sync if a photo is ever re-shot.

**Requirement:** before building this tour, give `TOURS` a way to alias an
existing asset instead of encoding a new one — e.g. an optional 5th tuple field
carrying an explicit `indoor/...` path that `write_manifests()` uses verbatim and
the encoder skips. Add a test that no two manifest entries reference different
paths for the same source photograph.

## 4. THE open question: how does a letterless route enter the picker?

`gymnasium-road` has `mapReference: null` (`venues_data.dart:206`) — deliberately,
because the printed sheet letters no disc there. The picker
(`panoramaPickerVenuesProvider`) selects on `_panoramaPickerMapReferences =
{'D','E','F','G','H','I'}` and sorts by letter, and
`panorama_building_picker.dart` does `v.mapReference!` — a **non-null assertion**.
A letterless venue in that list crashes the picker.

`test/unit/panorama_picker_venues_test.dart` explicitly asserts `gymnasium-road`
is excluded. That test encodes a real decision and must be consciously revised,
not quietly deleted.

Three options, for the user to choose:

- **(a) A separate "Walks" section below the lettered catalogue.** The picker
  renders the D–I list, then a labelled group holding the walk. Honest — it is
  not a legend venue and does not pretend to be. Costs a section header, an ARB
  string pair, and a change to the picker's flat `ListView`. **Recommended.**
- **(b) A pinned first card, before D.** Cheapest visually, but it puts an
  unlettered card at the top of a list whose entire premise is "these are the
  paper map's letters", weakening the mapping the picker exists to teach.
- **(c) Reachable only from the Solar system walk event detail / the
  `gymnasium-road` venue sheet.** No picker change at all, so zero risk to the
  D–I contract — but effectively undiscoverable, which wastes the content.

Whichever is chosen, `label:` must stop calling `v.mapReference!` unguarded.

## 5. Scope of change

- `tools/panorama/build.py` — a `gymnasium-road` entry in `TOURS`; five new
  `SOURCE_SHA256` lines; scene 1 moves out of `HELD_OUT_ROUTE_SCENES` (delete the
  constant only if it ends up empty, and say so in the comment). Encode **only**
  the new scenes, then `--manifests-only`, so the 33 existing JPEGs do not churn.
- `lib/data/panorama_data.dart` — one `PanoramaTour`. Note in the doc comment
  that this entry is a route, not a legend venue.
- `lib/services/providers.dart` + `lib/widgets/panorama_building_picker.dart` —
  per §4.
- `lib/l10n/app_en.arb` + `app_fa.arb` — the section header and the walk's title.
  **Real Persian, never machine-fill.** Any `int` placeholder needs
  `"format": "decimalPattern"`.
- Tests: manifest order (the reversal in §2.4 is the regression worth pinning),
  picker rendering, the revised exclusion test, and `l10n_coverage_test`.
- `docs/panorama-image-provenance.md` — move the six from "Reserved for the Solar
  system walk" into the shipping table.

**Bundle cost** (corrected — an earlier draft said "+3.5 MB", which was wrong by
roughly 3×). The two G scenes encoded at 2.05 MB and 2.10 MB; these are outdoor
daylight panoramas and compress worse than the 1.43 MB mean across the current 34
assets, so budget **~2.05 MB per new scene**:

- with the §3.1 aliasing change: **5 new encodes ≈ +10 MB**
- without it: **8 new encodes ≈ +16 MB**, three of them duplicates

`assets/data/indoor/` is currently 48.7 MB across 34 files. Ten more megabytes is
a real download-size decision for a one-night event app, not a rounding error —
worth raising before building, and a reason to consider whether all six route
scenes earn their place or whether the walk reads well at four.

## 6. Honesty constraints (non-negotiable)

1. **No invented hotspots.** The originals carry no `PoseHeadingDegrees`, so
   `neighbours` stays `[]` on every node and navigation is the scene rail —
   exactly as every other tour. A route tour makes "just add a forward arrow"
   tempting; the bearing would still be guessed. Do not.
2. **Do not present the walk as showing the planets.** The scale-model planet
   markers are not identifiable in any of these photographs. The tour shows the
   *route*. Copy must not promise planets.
3. **Daytime imagery, night event** — the standing limitation applies here too.
4. **No coordinates from EXIF GPS.** §2.1.

### 6.1 Carried-over uncertainty: the two Observatory scenes

For the G tour the user chose **filename order** (Entrance 1 → 2), and that is
what shipped. But the capture order — 15:18 then 15:22, walking *south* — implies
Entrance 2 lies **south** of Entrance 1, so a visitor arriving northbound up
Gymnasium Road would reach **2 before 1**. Entrance 2 does show a gate with the
AON banner, which reads like an arrival marker.

This is **UNVERIFIED**. The walk arrives northbound, so it is the one tour where
the distinction actually bites. Resolve before building §3 scenes 7–8; a two-
minute look at the site, or one question to the photographer, settles it.

## 7. Open questions for the user

1. **§4** — which picker treatment: (a) Walks section, (b) pinned card, or (c) no
   picker entry?
2. **§6.1** — Observatory scenes 7–8: filename order or arrival order?
3. **Does the SAC entrance photograph belong to F as well?** It is the Aquatic
   Centre's street arrival, and F currently opens at the front plaza with no
   street-level scene. It can serve both tours from one encode. Adding it to F is
   a one-line `TOURS` change, independent of this design — worth doing either way?
4. **Scenes 5 and 6** (§3) are Medium confidence on relative order. Accept, or
   confirm on site?
5. Should the walk's card carry the programme's hook — *"every metre you walk
   represents 37.3 million kilometres"* — as its subtitle? It is the single best
   line on the sheet, and it is already in `events_data.dart`.
