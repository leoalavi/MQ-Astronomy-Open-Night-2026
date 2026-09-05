# App Store product page — ready-to-paste copy

Every field App Store Connect asks for, filled in. Character limits are Apple's
and are respected; the count is given so you can see the headroom.

Guideline **2.3.1** requires metadata to describe what the app actually does.
Nothing below promises a feature the shipped build does not have. The station
codes are live as of 2026-09-04 and the passport is enabled in release builds,
but the description still does **not** claim the passport works on the night:
that depends on the generated signs being printed and installed at the nine
venues, which is not something the build can guarantee.

---

## Name — 30 characters max

```
Astronomy Open Night
```
*(20 characters.)* Matches `CFBundleDisplayName`, so the Home-screen name and
the store name agree — a mismatch is a common 2.3.1 flag.

## Subtitle — 30 characters max

```
Macquarie University event
```
*(26 characters.)*

## Promotional text — 170 characters max, editable without a new build

```
Everything you need for the night: the official campus map offline, the full programme, 360° venue tours, and walking directions from the car parks.
```
*(147 characters.)*

## Description — 4000 characters max

```
Astronomy Open Night is the free visitor companion for Macquarie University's
public astronomy night in Sydney.

Saturday 19 September 2026, 4pm – 10pm.

Built to work when the network doesn't. The campus map, the programme, venue
details and the 360° tours are all stored in the app, so they load in a crowded
field after dark with no signal.

THE OFFICIAL MAP, OFFLINE
The same map that's printed in the event programme — the same A–I lettering, the
same registration and information points, the same shuttle and pedestrian
routes. Pins sit on the printed markers, so the app and the paper agree. Find
telescopes, talks, planetariums, kids' activities, food, toilets and first aid.

THE WHOLE PROGRAMME
Every talk, show and activity, with times and places. See what's on now, search
by name or venue, and save the ones you want to your own plan for the night.

FIND YOUR WAY IN THE DARK
Written walking directions from each car park, with distances and times, plus a
compass that points you at a venue using absolute bearings. The compass uses a
red, night-vision palette so it doesn't wreck your dark adaptation — or anyone
else's near the telescopes.

LOOK INSIDE BEFORE YOU GO
360° photographic tours of several venues, so you know what a building looks
like before you walk to it.

ASTRONOMY PASSPORT
A stamp trail around the venues. Collect a stamp at each stop and unlock a piece
of astronomy along the way. The codes on the venue signs go live for the event;
before then you can try the whole trail in preview mode from Settings.

IN ENGLISH AND PERSIAN
Every screen, in both languages.

BUILT TO BE HONEST
Where a detail hasn't been confirmed by the organisers yet, the app says so
instead of guessing. Where a walking route hasn't been checked on foot at night,
it tells you that too.

PRIVACY
No account. No sign-in. No analytics. No advertising. No tracking. Your stamps,
favourites and plan stay on your phone, and you can erase them at any time from
Settings. Location is optional and used on your device. The one thing that
leaves your phone is a request for walking directions on a Google map — and the
app asks you first, every time, and lets you take it back.

ACCESSIBILITY
VoiceOver, larger text up to 200%, and Reduce Motion.

Macquarie University, Balaclava Road, Macquarie Park NSW 2109.
```
*(~2,300 characters.)*

## Keywords — 100 characters max, comma-separated, no spaces after commas

```
astronomy,macquarie,campus,map,stargazing,telescope,observatory,event,sydney,planetarium,night,guide
```
*(Exactly **100** characters — at Apple's limit, not over it. Counted 2026-09-05; the earlier "101" note was a miscount. Do not add anything without removing something.)*

Do **not** repeat words already in the Name or Subtitle — Apple indexes those
separately, so "Open Night" and "University" would be wasted characters.

## Support URL / Privacy Policy URL / Marketing URL

- **Support URL — decided:** `https://event.mq.edu.au/astronomy-open-night/`
  (official MQ event site, public, HTTPS, no login, enquiries address on the
  page). Verified live 2026-09-05.
- **Privacy Policy URL — still needed.** Mandatory, and Macquarie's own
  institutional policy cannot stand in for it: see
  `docs/release/app-store-connect-final-checklist.md` §1. The app-specific copy
  is ready in `docs/release/mq-hosted-pages.md` Page 1 and needs hosting.
- **Marketing URL — optional**, and not needed: the Support URL is already the
  event site.

## Category

- Primary: **Education**
- Secondary: **Navigation**

Education fits the event's purpose and the university publisher. Navigation is
the honest second, given the map, compass and wayfinding.

## Copyright

```
© 2026 Macquarie University
```

## Price

Free. No in-app purchases.

---

## Age rating questionnaire *(mandatory since 31 Jan 2026)*

Apple replaced the old ratings with a more granular system, and unanswered
questions **block** submission. For this app every answer is *None* / *No*:

| Question | Answer |
|---|---|
| Violence (cartoon, fantasy, realistic, prolonged/graphic) | None |
| Sexual content or nudity | None |
| Profanity or crude humour | None |
| Alcohol, tobacco, or drug use or references | None |
| Simulated gambling / contests | None |
| Horror or fear themes | None |
| Mature or suggestive themes | None |
| Medical or treatment information | None |
| Unrestricted web access | **No** — the only web view loads files bundled in the app over `http://localhost`; it does not browse the internet |
| User-generated content | **No** |
| Messaging or user-to-user communication | **No** |
| User-generated content moderation | N/A |
| Does the app share user location with other users? | **No** |
| In-app purchases | **No** |
| Advertising | **No** |
| Loot boxes / randomised items | **No** |

Expected result: the lowest available rating (4+ equivalent).

**Do not overstate the passport as a "game" or "contest".** It is a
self-directed trail with no prizes of chance, no leaderboard and no other
players, so the gambling and contest questions are genuinely *None*.

---

## Screenshots

Captured at exact device resolution and committed under
`docs/release/screenshots/`.

| Size | Device | Required | Status |
|---|---|---|---|
| 1320 × 2868 | iPhone 17 Pro Max (6.9") | **Yes** | **6 recaptured 2026-09-05** ✓ |
| 2064 × 2752 | iPad Pro 13-inch (M5) | **Yes** — the app runs on iPad | **1 recaptured 2026-09-05** ✓ · 3 removed as stale — see below |

**Why the 2026-08-23 set was replaced.** It showed copy the app no longer ships:
`iphone-6.9/01-home.png` had the map card reading *"Venues, toilets, first aid —
and walking directions from the car parks"*, while the shipped string is now
*"Venues, toilets, parking and walking directions"*. The fortnight after that
capture also brought the redesigned Program filters, the removed Compass mode,
the West 6 parking pin, the Toilets chooser and the reordered 360° picker — all
visible in the new set.

**The iPad set is incomplete on purpose.** `01-home.png` was recaptured and is
current. The other three could not be: Maestro reports success against the iPad
simulator's UDID while the taps land somewhere else (the screen never changes —
three consecutive captures came back byte-identical), which is the iPad session
trap already recorded in `.maestro/README.md`. Rather than ship images of an
older UI, they were removed. Apple requires **at least one** iPad screenshot for
an iPad-capable app, so the single current Home shot satisfies the minimum;
capture Map, a 360° tour and Settings by hand in Simulator (`xcrun simctl io
<udid> screenshot`) if you want the full set.

No alpha channel, no transparency — `simctl io screenshot` produces opaque PNGs.

### The iPad set

| File | Screen |
|---|---|
| `01-home.png` | Hero and multi-column layout — the iPad gets a genuinely different grid, not a stretched phone: four "Up next" cards in a row and the eight-tile "Find your way to" grid |

*(`02-map.png`, `03-panorama.png` and `04-settings-preview.png` were removed on
2026-09-05 — see the note above.)*

### What the iPhone set shows

| File | Screen |
|---|---|
| `01-home.png` | Hero, event date, passport card, "Up next" |
| `02-map.png` | Official AON basemap with the A–I pins, the P parking pins, category filters and the Directions CTA |
| `03-settings-credits.png` | Settings → Credits: the hero credit, the MQ event-materials line, the map-data attribution and the two developers |
| `04-passport.png` | The passport at zero stamps, with the "each of the nine venues has a QR sign" explainer that stands in for onboarding |
| `05-program.png` | The programme: search, "Filter by time" / "Filter by activity", the Tonight / Sections toggle, 36 items |
| `06-panorama.png` | The Observatory 360° tour — the dome, with the scene rail |

Apple's rule (2.3.3) is that screenshots show the app in use. These are
unretouched captures, so they comply by construction. If marketing wants text
overlays later, keep the device frame honest and do not show a feature the build
does not have.
