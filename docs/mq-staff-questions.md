# Facts to confirm with MQ staff — Astronomy Open Night 2026

Generated from the timing/source audit (post-campus-test pass, 2026-08-28).
Every item below is something the **official programme / map does not state** —
so the app must not invent it. Nothing here should be answered from the app's
own placeholder data.

The app now shows **"Time not published"** (never a fabricated "4pm–10pm") for
the unscheduled activities, and shows a real start with a "finish not published"
qualifier for the start-only ones, so the UI is honest while these remain open.

## 1. Activities with no published time at all (3)

Source note in the data: *"Programme p.2 — no times published for this entry."*
The app currently classifies these as `timeUnpublished` and keeps them out of
"Happening now" / "Up next".

| Activity | Venue | What we need |
| --- | --- | --- |
| **Capture the cosmos** (`capture-the-cosmos`) | 14 Sir Christopher Ondaatje Ave (D) | Does it run the whole event (4pm–10pm), or specific hours? |
| **Exhibition Hall** (`exhibition-hall`) | 17 Wally's Walk (I) | Same — full-event or specific hours? |
| **Solar system walk** (`solar-system-walk`) | Gymnasium Road | Same — full-event or specific hours? |

**Question to send:** *"For Capture the cosmos, the Exhibition Hall and the
Solar system walk — do these run for the full event (4pm–10pm), or do they have
their own start/finish times? The printed programme lists no times for them."*

If MQ confirms any of these runs the full event, we reclassify it as
`fullEventConfirmed` (a real 4pm–10pm block) rather than "Time not published".

## 2. Activities with a published START but no published FINISH (4)

Source note: *"Programme p.2 — '4.15pm start'. No finish time published."* The
start (4.15pm) is a fact; the finish is not, so the app shows "4.15pm · finish
time not published" rather than a made-up end.

| Activity | Venue | What we need |
| --- | --- | --- |
| **Stories Across Worlds** (`stories-across-worlds`) | — | Confirmed finish time |
| **Space exploration with the Junior Science Academy** (`junior-science-academy`) | — | Confirmed finish time |
| **Kids' space** (`kids-space`) | 1 Central Courtyard, Room 106 | Confirmed finish time |
| **Planetariums** (`planetariums`) | Sport & Aquatic Centre | Finish time, and the exact session cadence ("about every 20 min from 4.15pm" is our current wording) |

**Question to send:** *"These four activities list a 4.15pm start but no finish
in the programme — what time do they end? For the Planetariums, can you confirm
the session cadence and the last session?"*

## 3. Parking — West 6 location

Source note in `parking_data.dart`: the official event map prints the **"West 6"
label in more than one position**, and West 6 has no coordinate in the MQ dataset.
The app therefore does **not** drop a map pin for West 6 (it would be a guess);
it routes visitors to West 5 (the confirmed free car park) instead.

**Question to send:** *"The event map shows the 'West 6' label in two different
places. Which is the actual free-parking entrance for Open Night, and can you
give a rough location/pin? Right now we only pin West 5 and South 2."*

---

### What we are NOT asking (already sourced)

- The overall event window **4pm–10pm** and date **Saturday 19 September 2026**
  are confirmed and shown on Home.
- Every other activity has an exact published start and finish and needs no
  confirmation.
- West 5 and South 2 car parks are confirmed and pinned.
