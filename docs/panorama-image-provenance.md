# Panorama image provenance

The app ships **28 real 360° panoramas** across six venues. This records the
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
| H | 11 Wally's Walk | 3 | AON shoot |
| I | 17 Wally's Walk | 4 | MQ_Journey set |

C (Food and drink), F (Sport and Aquatic Centre) and G (Astronomical
Observatory) have no imagery and therefore no tour. **G is the telescopes** —
the headline activity of the night — and is the most valuable gap to fill.

## Sources

| Set | Origin | Owner | Basis |
|---|---|---|---|
| AON shoot | `Astronomy_Assets` — commissioned for this event | Macquarie University | Supplied for use in this app |
| MQ_Journey set | `Journey_Assets/3D pictures` — the Open Day app's panoramas | Macquarie University / MQ_Journey project (same owner as aon2026) | Reuse within the same owner's sibling project |

Both sets are 8192×4096 equirectangular JPEG. `tools/panorama/build.py`
re-encodes them to the 4096×2048 q85 progressive JPEGs the bundle carries
(37.3 MB total) and pins the **sha256 of every original**, so a re-shot or
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

## Known limitations

- **Daytime imagery for a night event.** Every photograph is bright, sunlit
  and empty; the event runs 4–10pm. The tours will not resemble the night
  people attend. Accepted knowingly, the same trade-off as the un-dimmed
  basemap.
- **No pose metadata.** The XMP carries `ProjectionType=equirectangular` and
  nothing else — no `PoseHeadingDegrees`, no GPS. There is no honest way to
  know which direction a scene faces, so the manifests carry **no
  `neighbours`** and tours are navigated by the scene rail. Do not add
  hotspots by eye; a bearing that looks plausible is still invented.
- **Scene labels are English only.** Descriptions live in the manifest JSON,
  which is not localised. Pre-existing; the picker's card titles ARE localised.
- **Rights are for a private repo, not for publication.** Committing these to
  a private repository is not the same as permission to ship them to the App
  Store or Google Play. This sits with the same unresolved redistribution IOU
  as `buildings.json` and the official basemap artwork, and it is now the
  largest of the three by volume. **Confirm before any public release.**
