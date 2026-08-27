# On-campus test checklist — Astronomy Open Night

For the physical walk-around at Macquarie University. Designed to be followed on a
phone. Tick as you go; note anything that differs.

**Before you leave:** install a build made with `--dart-define-from-file=.env`.
Do **not** pass `AON_ALLOW_OFF_CAMPUS_TESTING` — on campus you want production
behaviour, and the flag would mask a real scope bug.

---

## A. GPS dot position — the single most important test

Stand still ~10 s at each point, then check the blue dot on the **Campus Map**.

| # | Stand at | Dot lands on the right building/area? | Notes |
|---|---|---|---|
| 1 | **Central Courtyard** (1 CC) | ☐ | the busiest reference point |
| 2 | **Macquarie Theatre** entrance | ☐ | west side |
| 3 | **Mason Theatre** entrance | ☐ | east of Central Courtyard |
| 4 | **Astronomical Observatory** (telescopes) | ☐ | far north — the extreme of the artwork |
| 5 | **Sport & Aquatic Centre** (planetariums) | ☐ | west — the other extreme |

Points 4 and 5 matter most: they sit near the edges of the illustrated map, where
any projection error is largest and most visible.

**What "wrong" looks like:** dot consistently offset in one direction (calibration
drift), dot pinned to the artwork edge (clamping — should never happen), or dot
absent while you are clearly on campus.

## B. Recenter and follow

- ☐ Tap the **recenter** button → camera moves to your dot
- ☐ Walk ~50 m → dot follows without needing a manual recenter
- ☐ Pan the map away by hand → follow releases (dot stays, camera does not snap back)
- ☐ Tap recenter again → camera returns

## C. Walking between locations (do this while actually walking)

Walk **Central Courtyard → Observatory** (the longest useful leg).

- ☐ Dot moves smoothly, roughly along the path you are on
- ☐ No wild jumps between buildings
- ☐ Standing still for ~30 s: dot does **not** jitter around excessively
- ☐ Map stays responsive while moving

## D. Google walking directions

From **Central Courtyard**, tap **Directions** to the **Observatory**.

- ☐ Embedded Google map opens **inside the app** (not the Google Maps app)
- ☐ Your location marker appears
- ☐ Destination marker appears
- ☐ Walking route line is drawn
- ☐ Distance + ETA shown, and plausible (a few hundred metres, several minutes)
- ☐ Route follows walkable paths, not roads/driveways

Then **walk the route** and watch:

- ☐ Route does **not** visibly re-request on every step (should be throttled)
- ☐ Map remains usable throughout

Repeat once for a short leg: **Central Courtyard → Mason Theatre**.

## E. Show on Map

From **Program**, open any activity → **Show on map**.

- ☐ Map tab opens with the correct venue selected
- ☐ Marker is highlighted
- ☐ Compact sheet opens with the venue name + Directions
- ☐ **Marker is visible above the sheet**, not hidden behind it
- ☐ Map still occupies most of the screen
- ☐ Only **one** Directions button visible (in the sheet — the floating one hides)

Then:

- ☐ Leave Map tab → return → clean map, nothing selected
- ☐ Show on map for venue A, then venue B → only B selected, no stacked sheets

## F. Parking (do on arrival if you can)

- ☐ **West 5** appears on the map in a sensible spot
- ☐ **South 2** appears in a sensible spot
- ☐ **West 6** shows an honest "location to be confirmed" state — **not** a pin
- ☐ Parking → Directions opens the walking route

## G. Outdoor readability (ideally near dusk)

- ☐ Map labels readable at the default zoom in daylight
- ☐ Dark theme readable outdoors
- ☐ Text large enough at arm's length
- ☐ Screen usable at reduced brightness (you will want this near the telescopes)

## H. Anything else worth noting

- ☐ Battery drain over the session
- ☐ Behaviour with patchy campus wifi / mobile data
- ☐ Location permission prompt wording felt reasonable

---

**If the GPS dot is systematically offset**, capture: where you stood, where the dot
appeared, and roughly how far off. That maps directly onto the affine calibration in
`CampusProjection` and is fixable — but only with real measurements.
