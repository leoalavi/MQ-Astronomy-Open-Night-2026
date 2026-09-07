# Branding Audit — removing university branding from `aon2026`

**Date:** 2026-09-07 · **Auditor:** Claude Opus 5 (Claude Code) · **Base commit:** `3bc1f07`
**Instruction:** Charanya Ramakrishnan, 2026-09-07 — *"do not use 'Macquarie' for
anything, please? We don't have the university's approval for any of these.
These are your projects."*

**Operating rule applied** (per Raouf's clarification the same morning):

> Remove Macquarie **branding, marks and ownership/affiliation claims**.
> **Keep** authorised artwork, factual geography, and all Map / Search / Nearby /
> Directions / 360° functionality. The authorised assets — the FSE26193 basemap,
> `buildings.json`, the 39 panoramas, the 17 venue pins — are **not** copyright
> blockers and were **not** removed.

---

## 1. Executive summary

The app no longer presents itself as, or implies endorsement by, a university.
**Nothing a visitor sees, and nothing a store listing says, names the
university, carries its marks, or claims its approval.**

The finding that mattered was not text. The **university crest and wordmark
were baked into `assets/maps/aon_event_map.png`**, the bundled campus basemap —
the single most visible piece of branding in the app, sitting on the Map tab,
and invisible to every text search this repository has ever run. It was removed
in place at identical pixel dimensions, so the georeference and all 17 venue
pins are untouched.

Three further classes of finding would also have survived a "Macquarie" grep:

| Hidden class | Example |
|---|---|
| Institutional registration codes | `CRICOS Provider 00002J` — a government registration number identifying the university — was **rendering in Settings → Credits**. |
| University first-person voice in shipped copy | *"The **Faculty of Science and Engineering** presents…"*, *"…built by Australian Astronomical Optics **here at Macquarie University**"*. |
| Legal pages drafted in the university's voice | The hosted Privacy Policy, Support and Terms named the university as **publisher, data controller and warranty-disclaiming party**. |

Everything that can be fixed in code has been. What remains is a short list of
**decisions only a person can make** (§15) — chiefly the App Store copyright
field, the support/privacy hosting domain, and the bundle identifier.

**Gate: `CHECK PASSED`, exit code 0, 7/7 steps, coverage 90.86%.**

---

## 2. Macquarie references found

Baseline sweep of tracked files at `3bc1f07`: **450 occurrences of "macquarie"
(case-insensitive) across 119 files.**

| Category | Where | Count (approx.) | Disposition |
|---|---|---|---|
| **A. User-facing branding** | Home eyebrow, Info, Settings About + Credits, map overlay, EN/FA ARB | 20 | **Removed** |
| **B. Store / release metadata** | App Store + Play listings, review notes, checklists | 25 | **Removed / withdrawn** |
| **C. Legal & copyright** | `mq-hosted-pages.md`, `© 2026 Macquarie University`, CRICOS | 15 | **Removed → `[PUBLISHER]` + blockers** |
| **D. Technical configuration** | bundle id `au.edu.mq.astronomy.aon2026` | 10 | **Unchanged — flagged, §15** |
| **E. URL / domain / email** | `event.mq.edu.au`, `www.mq.edu.au`, `@mq.edu.au` | 8 | **Removed / reopened as blockers** |
| **F. Location information** | venue, street, suburb, Metro-station names | ~180 | **Kept — wayfinding facts, §4** |
| **G. Documentation / comments** | provenance notes, design specs, audit history | ~150 | **Kept — audit trail, §4** |
| **H. Asset / logo / image** | **crest + wordmark in the basemap PNG** | 1 lockup | **Removed, §5** |
| **I. Bundle / package identifiers** | Android namespace + applicationId, iOS/macOS bundle ids | 10 | **Unchanged — flagged, §15** |
| **J. Historical material** | CHANGELOG, past audits | ~15 | **Kept — history** |

---

## 3. Macquarie references removed

### Shipped application
| File | Was | Now |
|---|---|---|
| `lib/data/event_info.dart` | `host = 'Macquarie University'`, `faculty`, `cricosProvider = 'CRICOS Provider 00002J'`, `socialHandle '@MQPhysAstro'`, `hashtag '#MQAstroOpen'`, `materialReference 'FSE26193'` | **all six constants deleted** |
| `lib/screens/home_screen.dart` | hero eyebrow `EventInfo.host.toUpperCase()` → **`MACQUARIE UNIVERSITY`**, the first text in the app | line removed; hero opens on the event title |
| `lib/screens/info_screen.dart` | host printed under the event date | line removed |
| `lib/screens/settings_screen.dart` | **About card** printed the host; **Credits** printed *"Event materials and branding © {host}, {faculty}. {cricos}."* | host line removed; credit replaced |
| `lib/config/event_config.dart` | `host` + `faculty` fields | fields removed |
| `lib/data/events_data.dart` | *"The Faculty of Science and Engineering presents…"*; *"…here at Macquarie University"* | rewritten out of the university's voice |
| `lib/l10n/app_en.arb` / `app_fa.arb` | `mapAttributionCampus`, `settingsMapDataAttribution`, `creditsMapDataBody`, `creditsEventMaterialsBody`, `creditsAcknowledgement` | rewritten in **both** locales |
| `assets/maps/aon_event_map.png` | **university crest + wordmark** | painted out — see §5 |
| `pubspec.yaml`, `web/index.html`, `web/manifest.json` | *"for Macquarie University's Astronomy Open Night"* | neutral + explicit non-affiliation |
| `.env.example` | *"scoped to the Macquarie University campus"* | *"scoped to the event campus"* |

**String changes, verbatim:**

| Key | Before | After |
|---|---|---|
| `mapAttributionCampus` | `Campus map: Macquarie University` | `Campus map: Astronomy Open Night programme` |
| `settingsMapDataAttribution` / `creditsMapDataBody` | `Campus map: Macquarie University. Walking directions…` | `Campus map: Astronomy Open Night 2026 programme. Walking directions…` |
| `creditsEventMaterialsBody` | `Event materials and branding © {host}, {faculty}. {cricos}.` | `Programme content follows the published Astronomy Open Night 2026 event materials.` |
| `creditsAcknowledgement` | `Two Macquarie University student app developers, in appreciation…` | `Two student app developers, in appreciation…` |

Persian equivalents changed to match (`دانشگاه مکواری` → `برنامهٔ شب باز نجوم`).

### Printed event material
`tools/passport/build_station_qr.py` generated the **physical station posters
and passport flyers** with `EVENT_META = "MACQUARIE UNIVERSITY · SATURDAY 19
SEPTEMBER · 4 – 10 PM"` printed on every one. Now `"SATURDAY 19 SEPTEMBER 2026
· 4 – 10 PM"`.

### Store, legal and project documentation
- **App Store:** subtitle `Macquarie University event` → `Public astronomy night guide` (28/30 chars); description opener rewritten + explicit non-affiliation sentence; `THE OFFICIAL MAP` → `THE EVENT MAP`; keyword `macquarie` → `offline` (98/100 chars); event address keeps `Balaclava Road, Macquarie Park NSW 2109` (geocodable) without the institution; **copyright field is now a blocker, not a guessed value**.
- **Play:** short description *"The official guide to Macquarie University's Astronomy Open Night"* → *"Your offline guide to Astronomy Open Night: map, programme, tours, directions."* (78/80 chars).
- **`mq-hosted-pages.md` → `hosted-pages.md`** (filename itself was branded; all 17 inbound references updated, including a test). Publisher identity → `[PUBLISHER]`; hosting on an `mq.edu.au` domain explicitly ruled out.
- **`app-review-notes.md`** (read by Apple reviewers): *"event held by Macquarie University"* → *"held on a university campus… This app is an independent project, not published by, affiliated with or endorsed by that university."*
- **`app-store-submission-checklist.md`**: the instruction to publish under the university's Apple account is **withdrawn and inverted**.
- **README:** tagline, acknowledgements, author "University" field and footer disclaimer rewritten.

---

## 4. Remaining references — and exactly why each remains

**Zero unauthorised university branding remains in production-facing content.**
Post-audit sweep: **283 `Macquarie` occurrences**, every one in a kept category:

| # | What | Why it stays |
|---|---|---|
| 1 | **`homeFactMetroBody`** — *"Sydney Metro stops at Macquarie University Metro Station, on campus."* (EN + FA) | The registered **Transport for NSW** station name. Visitors navigate by it at night, and the next station along is **Macquarie Park** — genericising it would send people to the wrong platform. Explicitly allowlisted, with this reason, in `no_university_branding_test.dart`. |
| 2 | **Venue names** — `Macquarie Theatre`, `Macquarie University Sport and Aquatic Centre`, `Macquarie University Astronomical Observatory` | Names on the physical signage attendees look for, and on the printed programme map. Removing them breaks wayfinding. |
| 3 | **`buildings.json`** — street/suburb/facility names (`16 Macquarie Walk`, `Macquarie Park NSW`, `MQ Village`, `MUSE (MQ University Study Experience)`) | Authorised dataset of real geography, powering Map search, Nearby and Favourites. Instructed to keep. |
| 4 | **Internal ids & asset paths** — `macquarie-theatre`, `toilets-macquarie-theatre`, `assets/data/indoor/macquarie-theatre.json` | Not user-visible. They are also **persistence keys** — Favourites and passport stamps are stored by `venueId`, so renaming them orphans saved user data. |
| 5 | **Incidental signage inside the 360° photographs** | Real-world signage in a photograph, explicitly out of scope per instruction. |
| 6 | **Engineering provenance comments** (`lib`, `tools`, `docs`, design specs) | The audit trail recording *what is authorised and where it came from*. Deleting it would make the rights position worse, not better. |
| 7 | **Two README rights lines** *(judgement call — see below)* | |
| 8 | **`FSE26193…pdf`** in source references | The **filename** of the authorised source document. |
| 9 | **`meta:Macquarie` in `libflutter.so`** | Flutter's own CLDR timezone id for **Macquarie *Island***. Not ours, not the university. |

**Judgement call flagged for your override — README §Attribution & Rights.**
Two lines still name the university, deliberately:
- *"…originate with the event organisers at Macquarie University and are used with their permission. Rights remain with them; this project claims none."*
- *"…confirm the position with Macquarie University and with Aleix Roig."*

I kept these because they are **third-party notices that disclaim affiliation
rather than claim it**, and deleting them would leave the repo redistributing
university-derived material with no attribution at all. I removed the CRICOS
code, the "names, logos and branding" clause and the `mq.edu.au` link from that
section, and strengthened the independence disclaimer. **If you want a literal
zero, these two lines are a one-minute change — say the word.**

---

## 5. Branding / asset changes

### The basemap — `assets/maps/aon_event_map.png`

The artwork is authorised and **ships**. Only the lockup was removed.

| Requirement | Result |
|---|---|
| Preserve exact dimensions | ✅ **2048 × 1448**, RGBA, before and after |
| No crop / resize / rotate / distort | ✅ none |
| Preserve the map coordinate system | ✅ pixel grid untouched |
| Preserve all 17 venue pin alignments | ✅ `artworkX/Y` resolve against the same frame; fitted similarity (scale 1.024017937) unchanged |
| Don't redraw unrelated portions | ✅ **0 pixels changed outside the lockup box** |
| Clean, professional removal | ✅ crest, wordmark and `SYDNEY·AUSTRALIA` rule all gone |
| Reconstruct underneath | ✅ the four margins around the lockup were **uniform opaque `#FFFFFF`**, so the fill is an exact reconstruction — no patch, no artefact |
| Confirm pin/georeference behaviour identical | ✅ §13 |
| No FSE26193 blocker | ✅ not classified as one |

Rect `x 1750–1976, y 50–265`; **16 780 pixels changed, 0 outside**. The event
title block (`ASTRONOMY OPEN NIGHT / 19 SEPTEMBER 2026 / 4PM – 10PM`) is
deliberately preserved. SHA-256 re-pinned in
`docs/fixtures/aon_basemap_provenance.json`, whose `modifications` field now
records the reason, the rect, the pixel count and the previous SHA.

### The 39 panoramas — inspected, **no changes needed**
- Full-frame contact sheet of all 39: **no overlaid watermarks, logos or burned-in copyright text.**
- **Nadir strip of all 39** checked separately (where 360° tools brand the tripod cap): all bare floor/ground.
- **Raw-byte scan** of every panorama, the hero image, the basemap and the app icon for embedded XMP/EXIF branding: **no hits.**
- Real-world signage visible inside a photograph (e.g. a wall sign reading "Macquarie Theatre") left untouched, per instruction.

### Other assets
`assets/branding/app_icon_source.png` (the approved artwork) and
`assets/images/hero_deep_triangulum_galaxy.jpg` carry no university marks.

---

## 6. Android review
- `android:label="Astronomy Open Night"` — already clean.
- No `Macquarie` anywhere under `android/`.
- Adaptive icon, permissions and cleartext policy unchanged.
- **`applicationId` / `namespace` = `au.edu.mq.astronomy.aon2026` — unchanged, flagged (§15).**
- Signed release AAB and APK both rebuilt and verified.

## 7. iOS review
- `CFBundleDisplayName` / `CFBundleName` = `Astronomy Open Night` — already clean.
- No `Macquarie` anywhere under `ios/`; `PrivacyInfo.xcprivacy` untouched (still exactly `35F9.1` + `C617.1`).
- Launch screens unchanged.
- **`PRODUCT_BUNDLE_IDENTIFIER` unchanged, flagged (§15).** No pbxproj or signing changes — `DEVELOPMENT_TEAM 94273WB4G3` untouched.

## 8. Flutter / Dart review
- `flutter analyze` → **No issues found.**
- Six `EventInfo` constants deleted; two `EventConfig` fields removed; **three** `host` render sites removed (the third, Settings → About, used `config.host` and would have been missed by an `EventInfo.host` search).
- No feature, route, provider or persistence key touched.

## 9. Localisation review
- EN and FA changed **together**; no key left half-translated.
- `flutter gen-l10n` clean; `l10n_coverage_test` and the gate's l10n step green.
- `creditsEventMaterialsBody` lost its three placeholders (`host`, `faculty`, `cricos`); the generated API and its one call site were updated.
- No new `int` placeholders, so no `decimalPattern` obligations.

## 10. Privacy & permissions review
- **No permission added or removed**; `android_permissions_policy_test` green, so the Play Data-safety declaration is unaffected.
- iOS purpose strings unchanged — they never mentioned the university.
- The hosted Privacy Policy no longer speaks as the university (§3), which also removes a false **data-controller** claim.
- Pre-existing, unrelated: `NSLocationWhenInUseUsageDescription` still says location "is never sent anywhere" while `google_routes_service.dart:58` POSTs it (risk **R1**, out of scope here).

---

## 11. Release issues found

| Sev | Issue | Status |
|---|---|---|
| **BLOCKER** | University crest + wordmark shipped in the basemap, on the Map tab | **FIXED** |
| **BLOCKER** | `CRICOS Provider 00002J` (a government institutional registration code) rendered in Settings → Credits | **FIXED** |
| **BLOCKER** | Hosted Privacy/Support/Terms named the university as publisher, data controller and warranty party | **FIXED** (→ `[PUBLISHER]`) |
| **BLOCKER** | `© 2026 Macquarie University` staged for the App Store copyright field | **WITHDRAWN → needs a decision (§15)** |
| **BLOCKER** | Play short description: *"The official guide to Macquarie University's Astronomy Open Night"* | **FIXED** |
| **HIGH** | `MACQUARIE UNIVERSITY` as the Home hero eyebrow — the first text in the app | **FIXED** |
| **HIGH** | Support URL on `event.mq.edu.au` presents the university as publisher | **REOPENED → §15** |
| **HIGH** | Shipped event copy written in the university's first person | **FIXED** |
| **HIGH** | Physical station posters/flyers printed `MACQUARIE UNIVERSITY` | **FIXED** |
| **HIGH** | Submission checklist instructed publishing under the university's Apple account | **FIXED (inverted)** |
| **MEDIUM** | Bundle id in the `au.edu.mq` namespace | **FLAGGED — §15** |
| **MEDIUM** | All 18 store screenshots show the removed eyebrow and the crested map | **STALE — must recapture (§15)** |
| **LOW** | `@MQPhysAstro`, `#MQAstroOpen`, `FSE26193` declared but never rendered | **FIXED (deleted)** |
| **INFO** | 255 files differ from `dart format` | pre-existing; informational, not a gate |

---

## 12. Files modified

**38 files** (37 modified + 1 new + 1 renamed).

`lib/`: `data/event_info.dart`, `data/events_data.dart`, `config/event_config.dart`,
`screens/{home,info,settings}_screen.dart`, `l10n/app_{en,fa}.arb`, `l10n/generated/*` (3).
`assets/`: `maps/aon_event_map.png`.
`test/`: `unit/no_university_branding_test.dart` **(new)**, `unit/map_attribution_test.dart`,
`unit/android_permissions_policy_test.dart`, `widget/credits_placement_test.dart`,
`widget/integration_seams_test.dart`, `widget/settings_screen_test.dart`.
Root: `pubspec.yaml`, `README.md`, `CHANGELOG.md`, `ARCHITECTURE.md`, `.env.example`,
`APPLE_RELEASE_AUDIT.md`, `GOOGLE_PLAY_RELEASE_AUDIT.md`, `BRANDING_AUDIT.md` **(new)**.
`web/`: `index.html`, `manifest.json`. `.maestro/`: `map-basemap.yaml`, `map-modes.yaml`.
`tools/`: `passport/build_station_qr.py`, `marketing/README.md`.
`docs/`: `release/mq-hosted-pages.md` → **`release/hosted-pages.md`**, plus
`release/{app-store-listing,play-store-listing,app-review-notes,app-store-connect-final-checklist,app-store-submission-checklist,organiser-requests}.md`,
`release-blockers.md`, `data-sources.md`, `project-scope.md`, `fixtures/aon_basemap_provenance.json`.

---

## 13. Tests executed

```
./scripts/check.sh                    → CHECK PASSED   exit 0   7/7   coverage 90.86%
flutter analyze                       → No issues found!
flutter test (full suite, in gate)    → all pass
```

Gate steps: pub get ✓ · analyze ✓ · **vendored asset provenance ✓** · l10n (EN+FA) ✓ ·
test+coverage ✓ · coverage policy ✓ (90.86%, floor 90.4%) · reskin transforms ✓.

**The provenance step failed first, correctly**, on basemap SHA drift
(`asset=8862d6c7… provenance=53f45043…`) — the guard doing its job. It passed
once the pin and the `modifications` rationale were updated.

**New tripwire — `test/unit/no_university_branding_test.dart` (4 tests, all green):**
1. no shipped ARB value names the university (one allowlisted key, with its reason);
2. no shipped ARB value carries an institutional identifier (`CRICOS`, `00002J`, faculty, handles);
3. no non-comment line in `lib/` carries one;
4. **the basemap decodes at 2048 × 1448 and its top-right rect is pure white** — catching the realistic regression, someone restoring the original PNG.

**Georeference/pin proof:** `venue_artwork_placement_test`, `aon_basemap_georef_test`,
`map_focus_route_test` and the `map_*` widget tests all pass unchanged, and the
Map screenshot (§14) shows every pin in position.

---

## 14. Build results

| Target | Result | Detail |
|---|---|---|
| **Android APK** (`--release`) | **PASS** | 137.8 MB |
| **Android AAB** (`--release`) | **PASS** | 128.9 MB, signed with the upload keystore |
| **Web** (`--release`) | **PASS** | used for rendered verification |
| **iOS** | **NOT TESTED** | `flutter build ipa` fails in *this* macOS user's shell only, because its Xcode is signed into a different individual team (`3L5A4R7JNY`). Pre-existing and **not a project defect** — archive from the Xcode session that uploaded Build 1. No iOS file was modified. |

**Packaged-binary verification** (not just the working tree): the basemap
extracted from `app-release.apk` is **2048 × 1448 RGBA with the lockup region
pure white**. Only three APK entries contain "Macquarie" — `AssetManifest.bin`,
`buildings.json` and the theatre panorama manifest, all authorised venue data.

**Rendered proof** (release web build @ 375 × 812):
- **Home** opens directly on *"Astronomy Open Night 2026"* — no eyebrow.
- **Map** renders every pin (A–I, P, transport, numbered) in place, attributed *"Campus map: Astronomy Open Night programme"*.
- **Settings → Credits** verified by `credits_placement_test` + `settings_screen_test`, which pump the screen and assert the real rendered text tree. *(No screenshot: no iOS simulator runtime is installed, and the Android emulator ANR'd on a host loaded by two release builds — the failure mode already recorded in `CLAUDE.md`.)*

---

## 15. Manual actions required

| # | Item | Why it needs a person |
|---|---|---|
| 1 | **App Store copyright field — BLOCKER** | `© 2026 Macquarie University` is withdrawn. `© 2026 Astronomy Night - FSE Outreach Team` is **not** a safe substitute: "FSE Outreach Team" is a university faculty unit, so it re-asserts the affiliation. **Whoever owns the app must name themselves.** I did not guess. |
| 2 | **Support URL — REOPENED** | Was `https://event.mq.edu.au/astronomy-open-night/`. A support URL on a university domain presents the university as the app's publisher and support channel. Needs a non-university HTTPS page. |
| 3 | **Privacy Policy + Terms hosting** | `[PUBLISHER]` must be filled in, and the pages must **not** be hosted on `mq.edu.au`. |
| 4 | **Bundle identifier** — `au.edu.mq.astronomy.aon2026` | Untouched by design. It is spent on TestFlight Builds 1–3 and the Play bootstrap AAB; changing it means a new App Store Connect record, a new Play listing, loss of TestFlight history and re-registration of the upload key and all three Play App Signing fingerprints. Both options written up in `docs/release/organiser-requests.md` §6. **Only cheap to change before first public release.** |
| 5 | **Recapture all 18 store screenshots** | Every one shows the removed Home eyebrow and/or the crested map. |
| 6 | **Re-run the Maestro E2E suite** | Two flows had their attribution assertion updated; not re-run (needs a booted device, and the emulator was unhealthy). |
| 7 | **Confirm the retained README rights lines** (§4) | My judgement call; trivially reversible. |
| 8 | **Tell Charanya what changed** | She asked a specific question about the copyright field; items 1–3 are the honest answer. |

Not affected, no action: Firebase (none), OAuth (none), analytics (none), push (none), deep links (none).

---

## 16. Final Macquarie search

Sweep of all tracked files after the audit. Counts are **occurrences**, not
matching lines, and exclude this report's own prose and the CHANGELOG entry
(both of which necessarily quote what was removed):

```
macquarie (case-insensitive) .... 406      (baseline 450)
macquarie university ............ 129
MACQUARIE (uppercase) ............. 2      → buildings.json ids "MACQUARIEU" / "MACQUARIEC"
MQ University ..................... 1      → "MUSE (MQ University Study Experience)", a real facility
CRICOS ............................ 4      → 1 provenance doc-comment + 3 in this audit trail
MQU / MacquarieUniversity ......... 0
```

**Read that 450 → 406 correctly.** It is not a 10% job. The overwhelming
majority of the 450 were always *kept* categories — `buildings.json` alone
holds ~180 street, suburb and facility names, the test suite ~40 venue-name
assertions, and the docs ~150 provenance notes. The 44 that went were
concentrated almost entirely in the branding surface, which is now **empty**:

```
shipped UI strings naming the university .......... 2  (the Metro station, EN + FA)
university marks in any bundled asset .............. 0
institutional identifiers in shipped code .......... 0
university name in android/ ios/ macos/ web/ ....... 0
university name in store listing copy .............. 0
```

**Platform identity:**

```
iOS CFBundleDisplayName / CFBundleName ... Astronomy Open Night
Android android:label .................... Astronomy Open Night
```

Every remaining occurrence falls into one of the nine kept categories in §4.

---

## 17. Release verdict

## **READY AFTER MINOR FIXES**

The branding requirement is **met in the software**. The binary carries no
university crest, wordmark, name-as-owner, copyright claim, registration code or
endorsement, and this is now enforced by a test rather than by vigilance. Every
feature is intact, the gate is green at 90.86% coverage, and both Android
release artefacts build and were verified *as packaged*.

It is not **READY FOR RELEASE**, for reasons that are not code:

1. The **App Store copyright field** has no correct value yet, and guessing one would re-create the problem this audit exists to remove.
2. The **Support and Privacy Policy URLs** still point at, or presume, a university domain.
3. The **18 store screenshots are stale** and would ship the removed branding straight back into the listings.

None is more than a short task once the ownership question in §15.1 is answered.
That single answer unblocks 1, 2 and 3.

**One caveat worth stating plainly:** this audit removed *branding*. It did not,
and could not, settle **who owns the app** — and Charanya's email raises that
question without answering it. Until it is answered in writing, the copyright
and publisher fields stay blocked.
