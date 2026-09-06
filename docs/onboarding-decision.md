# Onboarding decision — NOT IMPLEMENTED (deliberate)

**Decision (2026-09-05):** the app ships **without** an onboarding /
introduction flow. First launch opens directly on the Home tab. Guarded by
`test/widget/first_launch_test.dart`.

This was evaluated, not skipped. The evaluation asked one question: *would a
2–3 screen introduction get a first-time visitor to "understand → find an
activity → navigate" faster than the screens themselves?* The answer, from the
current UI, is no.

## Who opens this app, and when

A member of the public, on one Saturday night, probably standing on a dark
campus with a cold phone, wanting to know **what is on now and where it is**.
Many will install it on the night. Every screen between the tap and that answer
is a cost paid by every visitor, on every launch that iOS decides is "first"
(reinstall, new phone, family member's device). An introduction is a fixed cost
for a benefit that only accrues if the UI genuinely fails to explain itself.

## The first-launch UX, as it actually is

| Question a newcomer asks | Where the current UI answers it | Onboarding needed? |
|---|---|---|
| What is this app? | Home hero: host, "Astronomy Open Night 2026", date/time pill, event-phase badge | No |
| What's happening tonight? | Home: *Happening now* / *Up next* rails, "See the whole night" → Program | No |
| How do I save activities? | Star icon on every activity card; **My Night** tab empty state: *"Tap the star on any activity to plan your night"* | No |
| Where is the map? | Home full-width "Open the map — venues, toilets, parking and walking directions" card + the **Map** tab | No |
| Where are directions? | Every venue sheet and Info tile carries a **Directions** button; the map has a Directions FAB | No |
| What are the 360° views? | Map tab mode toggle **Map / 360° / Compass** (the label *is* the explanation); venue sheets: *"Look inside in 360°"* | No |
| What does "Passport" mean? | Home card *"Astronomy Passport — 0 of 9 stamps"*. **Gap found:** the passport screen said only *"Scan or enter a venue code to start"* — it never said the codes are on QR signs at the venues | **Fixed in place**, not with onboarding (below) |
| How do I collect stamps? | Passport screen button *"Scan or enter a code"* → scanner opens with the camera prompt in context | No |

The only genuine comprehension gap was the passport. A carousel slide would
have explained it once, on first launch, to a visitor who may not open the
passport for another three hours. Explaining it **on the passport screen
itself, at zero stamps** puts the sentence exactly where and when it is needed,
and removes it once the first stamp makes it redundant
(`passportHowItWorks`, EN + FA, `lib/screens/passport_screen.dart`).

## Why not "just a light one"

- **Speed is the product.** A 3-screen intro with Skip is still one extra tap
  and a read for 100% of visitors to serve the ~1 feature that needed a
  sentence.
- **It would restate the tab bar.** "Plan your night / Find your way / Collect
  stamps" is literally the label set of Program, Map and the Passport card.
- **Apple does not want it.** Nothing in the App Review Guidelines asks for
  onboarding; 2.1/2.3.1 ask that features be *discoverable and documented in
  review notes*, which they are. Permission timing (5.1.1) is already
  contextual: location on the first Locate tap, camera on entering the scanner,
  never at launch.
- **It adds state and a Settings row** ("View introduction") whose only job is
  to replay something the app didn't need.

## Permissions — unchanged by this decision

| Permission | When it is asked | Never |
|---|---|---|
| Location (When In Use) | The first *Show my location* tap on the Map, compass entry, or a directions request. Entering the Map tab only restores an existing grant — no dialog (changed 2026-09-05, `46dc81e`) | at launch, on Map entry, on Home/Program/My Night/Info/Settings |
| Camera | On entering the **QR scanner** (after tapping *Scan or enter a code*) | at launch, on opening the passport screen |
| Motion | Compass mode | at launch |
| Notifications / Photos / ATT | not used | — |

## Revisit if

- Field feedback on the night shows visitors failing to find the map, the
  passport or the 360° mode. That would be evidence; none exists today.
- A future event drops the Home card / tab labels that currently do the
  explaining.

If onboarding is ever added, `first_launch_test.dart` will fail — that is the
point: re-make this decision in the open, with the same table.
