# Navigation and wayfinding strategy

## The problem

The organisers' specific request: **attendees become disoriented walking
between the car parks and the event venues after dark.**

This is a night event on a large campus. People arrive in daylight and leave in
the dark, often with children, often having parked somewhere they have never
parked before. The Observatory end of campus is *deliberately* unlit to protect
telescope viewing.

## The decision

**Predefined, hand-authored campus walking routes with written instructions.
No live turn-by-turn navigation, no GPS.**

### Why not reuse MQ Journey's routing?

MQ Journey has a complete routing stack — `MapRoute`, `NavInstruction`,
`CampusRoutesRemoteSource`, `MapsRoutesRemoteSource`. The brief allowed reusing
it "if MQ Journey already provides a safe and reliable reusable solution".

It does not, for this use case:

| Property | Consequence here |
|---|---|
| It is an HTTP client for the **Google Routes / Directions API** | Requires a billed API key. This repository has no credentials and adding one is a meaningful change to its security posture |
| It needs a network round-trip per request | Thousands of people on campus mobile data on one evening, and the answer arrives only if the request succeeds |
| It returns generic turn-by-turn text | The routing engine has no idea which campus paths are **lit**, which gates are open at 9pm, or where the marshals are standing. Those are the only facts that actually matter here |
| It optimises for shortest | At night the best route is the *well-lit* one, which is often not the shortest |

The failure mode is what settles it: an approach that returns nothing when the
network drops is unacceptable for someone standing in a dark car park.

### Why not GPS?

Between campus buildings, consumer GPS accuracy is roughly ±20 m — not enough
to distinguish two parallel paths. A blue dot would cost a runtime permission
prompt and a privacy obligation, and return an arrow that is wrong often
enough to erode trust. Start-point *selection* ("I parked at West 6") is more
reliable than start-point *detection*, and costs nothing.

## The design

### Written instructions are the primary output

The map line is supporting material. The words work at arm's length, on a dying
battery, with no signal, and can be read aloud to someone else.

Each `RouteStep` has an `instruction` and an optional `landmark` — something
you can *see* to confirm you are still right, because compass bearings are
useless to someone without a map.

### Routes are data, not computation

`lib/data/routes_data.dart` holds `WalkingRoute` records keyed by
(`fromId`, `toId`). They are bundled offline and, crucially, **reviewable** —
an organiser can read them and correct them, which is not true of a routing
API's output.

Routes are **directional**. `A → B` does not imply `B → A`; walking directions
do not simply reverse. Return routes must be authored deliberately.

### Honest geometry

Where both endpoints have coordinates, the polyline is exactly two points:
origin and destination. It is rendered **dashed**, with the caption:

> Straight line shown — this is the general direction, not the exact path.
> Follow the written directions below.

Drawing an invented curve through campus would imply precision we do not have.
Where an endpoint has no coordinate — West 6 — there is **no line at all**, and
the route is text-only.

### Unknown is not "no"

`WalkingRoute.isAccessible` is `bool?`. `null` means *unknown* and renders as
"Step-free access has not been confirmed yet. Ask at an information point."
It must never render as "not step-free" — telling a wheelchair user a viable
route is unusable is worse than admitting ignorance.

## Current state

All nine routes are `DataConfidence.placeholder`:

| From | To |
|---|---|
| West 5 | Central Courtyard · Sport and Aquatic Centre · Observatory |
| West 6 | Central Courtyard *(text only — no coordinate)* |
| South 2 | Central Courtyard · 17 Wally's Walk |
| Central Courtyard | Observatory · Sport and Aquatic Centre |
| Metro Station | Central Courtyard |

The directions were composed from coordinates, not from walking the campus.
Every one displays a draft warning.

## Before the event

1. **Walk each route after sunset.** Confirm the landmarks are visible and
   correctly named.
2. **Record lighting** into `lightingNotes` — the single most valuable field.
3. **Record step-free status** into `isAccessible` / `accessibilityNotes`.
4. **Capture a GPX trace** while walking. Drop the points into `WalkingRoute.points`
   and flip `pathConfidence` to `confirmed`; the line renders solid automatically.
5. **Get organiser sign-off**, then remove the draft warning by changing the
   confidence value.

## Deliberately out of scope

- Live position tracking / blue dot
- Turn-by-turn voice guidance
- Off-route detection and re-routing
- Indoor navigation (MQ Journey has floorplans; not needed for a six-hour event)
- Accessibility-optimised route *variants* — worth considering for v2 once
  step-free status is known
