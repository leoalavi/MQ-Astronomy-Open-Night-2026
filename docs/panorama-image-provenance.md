# Panorama image provenance

The app ships **33 mapped 360° panoramas** across eight venues, plus one
retained route-area image that is not currently mapped. This records the
rights basis for every bundled image, and for the viewer that renders them.

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

C (Food and drink) is the only legend venue with no tour, and is intentionally
excluded from the 360° catalogue because no panorama is planned for it. No card
in the D–I picker reads "Coming soon" any more.

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
`1-central-courtyard_downstairs.jpg` photograph remains bundled for a future
road/route flow and is intentionally absent from the E manifest.

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

## Reserved for the Solar system walk

Six AON originals are **not** unused leftovers — they are the route of the
programme's *Solar system walk* ("a walk from the Central Courtyard to our
Telescope Park… every metre you walk represents 37.3 million kilometres",
Gymnasium Road). The GPS timestamps show them as one continuous southbound
traverse on 2026-08-23, 15:18 → 16:03, which matches the north-to-south order
of the same buildings in `buildings.json`:

`1 CC- Downstairs` · `1 CC close to stairs` ·
`Sport and Aquatic Centre — 10 Gymnasium Road — entrance` ·
`Next Sense— North 3 Parking - optional` · `1 Gymnastic road - optional 1` ·
`1 Gymnasium road- Optional`, terminating at the two Observatory scenes.

The walk runs **Courtyard → Telescope Park**, i.e. the reverse of the capture
order. It is a designed feature, not a manifest edit: `gymnasium-road` carries
`mapReference: null`, so it cannot enter the D–I picker without a decision.
Specified in `docs/superpowers/specs/2026-08-31-solar-system-walk-tour-design.md`;
not built. `1 CC- Downstairs.JPG` stays bundled for it.

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
  scene order and the planned Solar system walk order.
- **Scene labels are English only.** Descriptions live in the manifest JSON,
  which is not localised. Pre-existing; the picker's card titles ARE localised.
- **Rights are for a private repo, not for publication.** Committing these to
  a private repository is not the same as permission to ship them to the App
  Store or Google Play. This sits with the same unresolved redistribution IOU
  as `buildings.json` and the official basemap artwork, and it is now the
  largest of the three by volume. **Confirm before any public release.**
