# Panorama image provenance

The app ships 360° tours across **nine locations** — the eight A–I legend
venues and the **Solar system walk** route along Gymnasium Road — from **39
distinct bundled images** (46 scene entries, since the 13-scene walk reuses
8 images the legend venues already carry). This records the rights basis for
every bundled image, and for the viewer that renders them.

Nothing bundled is placeholder or demo content any more. The SP1 "Demo 360° —
sample imagery, not this venue" tour on `macquarie-theatre` (two scenes of
10 Hadenfeld Ave, borrowed from MQ_Journey) has been **deleted**, and
`test/unit/panorama_data_test.dart` fails if any tour is flagged
`placeholder` again.

## Software

- **Pannellum** (`assets/web/pannellum/pannellum.{js,css}`) — MIT licence,
  © 2011–2019 Matthew Petroff. Full text: `assets/web/pannellum/LICENSE`.

## What ships

One tour per official-map legend venue that has photography. The published
**AON 2026 Program and Map** is the source of truth for which places qualify:
a scene ships only if its venue carries an A–I legend letter.

| Legend | Venue | Scenes | Photography |
|---|---|---|---|
| A | Macquarie Theatre | 2 | MQ_Journey set |
| B | Mason Theatre | 1 | MQ_Journey set |
| D | 14 Sir Christopher Ondaatje Avenue | 6 | 3 AON shoot + 3 MQ_Journey |
| E | 1 Central Courtyard | 12 | AON shoot |
| F | Macquarie University Sport and Aquatic Centre | 3 | AON shoot |
| G | Macquarie University Astronomical Observatory | 2 | AON shoot |
| H | 11 Wally's Walk | 3 | AON shoot |
| I | 17 Wally's Walk | 4 | MQ_Journey set |
| — | Solar system walk (Gymnasium Road route) | 13 | AON shoot (8 reuse E/F/G images; 5 new) |

C (Food and drink) is the only legend venue with no tour, and is intentionally
excluded from the 360° catalogue because no panorama is planned for it. No card
in the D–I picker reads "Coming soon" any more.

The Solar system walk is a **route, not a legend venue**, so it carries no map
letter and is not part of the D–I letter list; the picker pins it as a card at
the top instead (shipped 2026-09-01 — see the section below).

**G shipped on 2026-08-31.** It had been carried as "Coming soon" — the
telescopes, the headline activity of the night — on the belief that photography
was "planned but not available yet". Both originals had in fact been in the AON
source set since 2026-08-23, unused. They were found by listing the source
folder rather than re-reading the note that said they did not exist. Scene order
is the photographer's own "Entrance 1"/"Entrance 2" naming, which the GPS
capture stamps agree with (15:18 then 15:22 on 2026-08-23).

Note on the source set: the EXIF GPS *positions* on this shoot are unreliable
(21 m to 1377 m off the true venue, measured against `buildings.json`), so they
must not be used to place or order a scene. The GPS *timestamps* are sound and
were used instead.

The 1 Central Courtyard Stairs scene remains part of the E tour. The
`1-central-courtyard_downstairs.jpg` photograph is intentionally absent from the
E manifest, but it is **no longer a spare**: it is scene 4 of the Solar system
walk (reached by alias, not duplicated).

## Sources

| Set | Origin | Owner | Basis |
|---|---|---|---|
| AON shoot | `Astronomy_Assets` — commissioned for this event | Macquarie University | Supplied for use in this app |
| MQ_Journey set | `Journey_Assets/3D pictures` — the Open Day app's panoramas | Macquarie University / MQ_Journey project (same owner as aon2026) | Reuse within the same owner's sibling project |

Both sets are 8192×4096 equirectangular JPEG. `tools/panorama/build.py`
re-encodes them to the 4096×2048 q85 progressive JPEGs the bundle carries and
pins the **sha256 of every original**, so a re-shot or
swapped source is detectable even though the 180 MB of originals is too large
to vendor. That table is the authoritative scene→photograph mapping.

## Held out on purpose

- **12 Wally's Walk (Jim Piper Centre) — "Laser Transmission Hologram".** One
  panorama exists, but the official map letters no activity at 12 Wally's
  Walk, and `pdftotext` over the sheet finds no "Jim Piper", no "hologram" and
  no entry for that address. Either the demo is not public, or the map is
  missing it — an **organiser question**, alongside the four-toilet-discs-vs-
  three-in-the-legend discrepancy. Not shipped until answered.
- **24 MQ_Journey buildings** (1 WW, 10 Hadenfeld, 23 WW, 25 WW, 27 WW,
  29 WW). Open Day venues; this event does not use them.

## Solar system walk (shipped 2026-09-01)

The programme's *Solar system walk* ("a walk from the Central Courtyard to our
Telescope Park… every metre you walk represents 37.3 million kilometres",
Gymnasium Road) now ships as a 13-scene route tour on venue `gymnasium-road`.

**Scene order is the organiser's own numbering (Raouf, 2026-09-01), 1 → 13,
Central Courtyard → Telescope Park** — the direction visitors walk it. This
supersedes the timestamp-inferred order in the original design spec and settles
its open questions (picker placement, the two Observatory scenes' arrival order,
and the relative order of the two mid-road scenes). Each numbered source was
verified byte-identical to its pinned original before encoding. The 13 scenes,
in order, with the source photograph behind each:

1. `1 CC entrance` · 2. `1 CC close to stairs` · 3. `1 CC - Stairs` ·
4. `1 CC- Downstairs` · 5. `Platiymrum before Entrance` ·
6. `Planetarium Entrance Gym` · 7. `Sport and Aquatic center` ·
8. `Sport and Aquatic Centre — 10 Gymnasium Road — entrance` ·
9. `Next Sense— North 3 Parking - optional` · 10. `1 Gymnastic road - optional 1` ·
11. `1 Gymnasium road- Optional` · 12. `Astronomical Observatory Entrance 2`
(the gate, arrived at first, northbound) · 13. `Astronomical Observatory
Entrance 1` (the wide approach with the dome).

**Bundle cost was kept to ~9.5 MB, not ~26.** Eight scenes (1, 3, 4, 5, 6, 7,
12, 13) are photographs E/F/G already encode; `build.py` **aliases** them (an
optional 5th tuple element = an explicit bundled path the encoder skips and the
manifest reuses verbatim), so only the five genuinely-new scenes (2, 8, 9, 10,
11) were encoded. A build-time check (`dangling_aliases()`) fails if any alias
points at a path no scene produces and no bundled asset provides.

The walk is a **route, not a legend venue**: `gymnasium-road` carries
`mapReference: null`, so it never enters the D–I letter list. The picker pins it
as a card at the **top**, above D. Design record:
`docs/superpowers/specs/2026-08-31-solar-system-walk-tour-design.md` (the order
and picker-placement questions it left open are now answered as above).

## Known limitations

- **Daytime imagery for a night event.** Every photograph is bright, sunlit
  and empty; the event runs 4–10pm. The tours will not resemble the night
  people attend. Accepted knowingly, the same trade-off as the un-dimmed
  basemap.
- **No pose metadata.** The XMP carries `ProjectionType=equirectangular` and
  nothing else — in particular **no `PoseHeadingDegrees`**. There is no honest
  way to know which direction a scene faces, so the manifests carry **no
  `neighbours`** and tours are navigated by the scene rail. Do not add
  hotspots by eye; a bearing that looks plausible is still invented.
- **EXIF GPS exists but its POSITION is not trustworthy** (corrected
  2026-08-31; this section previously said there was no GPS at all). All 30 AON
  originals carry a GPS IFD. Measured against the venue coordinates in
  `buildings.json`, the fix is off by 21 m at best and **1377 m at worst**, and
  six photographs are more than 180 m out — including `1 CC- Downstairs.JPG`,
  which places a shot taken beside 1 Central Courtyard 945 m away. **Never
  order or place a scene by these coordinates.** The GPS *date and time* stamps
  (`GPSDateStamp`/`GPSTimeStamp`, UTC — add 10 h for AEST) ARE sound and
  reconstruct the shoot sequence exactly; they are the evidence behind the G
  scene order. (The Solar system walk order is the organiser's own numbering,
  not the timestamps — see that section above.)
- **Scene labels are English only.** Descriptions live in the manifest JSON,
  which is not localised. Pre-existing; the picker's card titles ARE localised.
- **Rights are for a private repo, not for publication.** Committing these to
  a private repository is not the same as permission to ship them to the App
  Store or Google Play. This sits with the same unresolved redistribution IOU
  as `buildings.json` and the official basemap artwork, and it is now the
  largest of the three by volume. **Confirm before any public release.**
