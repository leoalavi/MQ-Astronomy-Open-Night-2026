# Final Independent Compliance Sweep — second pass

**Date:** 2026-09-07 · **Auditor:** Claude Opus 5 · **Tree audited:** `4fe4c13` + working tree
**Method:** repository re-inventoried from scratch. The first pass's search results,
file list, conclusions and PASS status were treated as unverified.

Companion to [BRANDING_AUDIT.md](BRANDING_AUDIT.md) (first pass).

**Standard applied:** remove unauthorised university *branding, marks and
ownership/endorsement claims*; **keep** authorised artwork, factual geography and
all functionality. Authorised assets are never treated as copyright blockers.

---

## 1. Previous-pass omissions found

**FILES/DIRECTORIES NOT INSPECTED DURING THE FIRST PASS:**

| Not inspected in pass 1 | Result on inspection |
|---|---|
| `docs/release/play-graphics/icon-512.png` | **DEFECT FOUND — it is the Flutter logo.** See §2.1 |
| App icons: `assets/branding/`, `mipmap-*`, `AppIcon.appiconset` (21 files) | Inspected visually — clean, observatory artwork, no crest |
| `pubspec.yaml` **asset declarations** | Never checked in pass 1. Now verified — see §11 |
| `assets/web/indoor_viewer.html`, `assets/web/pannellum/` | Inspected — `mq-*` CSS/JS identifiers only, §13 |
| `assets/data/indoor/*.json` (9 runtime manifests) | Inspected — one filename match only |
| `buildings.json` **field taxonomy** (`facultyGroup` etc.) | Inspected — §7 |
| `tool/`, `coverage/`, `.idea/`, `macos/` (103 files) | Inspected — no branding |
| The two source PDFs | Inspected — do not ship, §11 |

**Assertions the first pass made without verifying:**

| Claim | Truth |
|---|---|
| "all **17** venue pins" | **16** venues are pinned from `artworkX/Y` (`venue_artwork_placement_test.dart` asserts the exact set). The Metro station is the 17th, placed by **GPS projection** with `artworkX == null`. "17 venue pins" is right in aggregate but was repeated from the brief, not checked. |
| Sweep deltas "434 → 283" | Wrong arithmetic: `git grep -c` counts matching **lines**. True occurrences: **450 → 410**. Corrected in `BRANDING_AUDIT.md` §16 during pass 1. |

---

## 2. New issues found

### 2.1 Play Store icon is the default Flutter logo — **BLOCKER**

```
SEVERITY:     BLOCKER (Play submission)
FILE:         docs/release/play-graphics/icon-512.png
LOCATION:     the whole image
ISSUE:        The 512x512 Play Store listing icon was the stock Flutter logo,
              not the app icon. 81.9% of the image was pure white.
              docs/release/play-store-listing.md:87 marked it
              "DONE - verified 512x512, hasAlpha: no". Both those checks
              passed. Neither looked at the content.
FIX:          Regenerated from the approved artwork
              (assets/branding/app_icon_source.png, 1024x1024), alpha
              flattened onto #05070F, LANCZOS to 512x512, saved as 32-bit
              PNG with no transparency.
VERIFICATION: sips -> pixelWidth 512, pixelHeight 512, hasAlpha: no.
              Rendered and visually confirmed as the observatory icon.
              Pure-white fraction now 0.00006 (was 0.819).
```

This is the archetype the second pass exists to catch: a verification that
checked the easily-checkable property and reported PASS on the wrong artefact.

### 2.2 Persian says "university" where English says "campus" — **MEDIUM**

```
SEVERITY:     MEDIUM (user-facing, both stores, Persian locale)
FILE:         lib/l10n/app_fa.arb
LOCATION:     mapNavOffCampusOrigin, wayfindingDraftRoute,
              settingsPrivacyBody, settingsPrivacyPolicyBody
ISSUE:        English is uniformly "on campus" / "the campus map". Persian had
              drifted to دانشگاه ("university") in four SHIPPED strings,
              including twice in the privacy copy as "the university map",
              which in Persian reads closer to an ownership claim than the
              English does. The file's own established word for campus is
              پردیس, already used in eight other keys - so this was internal
              inconsistency as well as drift.
FIX:          محوطهٔ دانشگاه -> پردیس ; شب‌هنگام در دانشگاه -> شب‌هنگام در پردیس ;
              نقشهٔ دانشگاه -> نقشهٔ پردیس (x2)
VERIFICATION: 0 shipped FA strings now contain دانشگاه. EN/FA key parity
              410/410 preserved. flutter gen-l10n clean; gate green.
```

An EN-only sweep would never have found this. It is why Pass 4 exists.

### 2.3 Documented screenshot size never matched the files — **LOW** *(fixed with the recapture)*

`app-store-listing.md` claimed `1320 × 2868 | iPhone 17 Pro Max (6.9")` while the
committed files were **1284 × 2778** — Apple's **6.5"** size. The set was
documented against a slot it did not fit. New set is **1290 × 2796**, an
accepted 6.9" size; table and files now agree.

### 2.4 A stash on this machine is not fully represented on main — **INFORMATIONAL**

`stash@{0}` "On main: android-audit-wip" (2026-09-06). Its substantive code is
already on `main` (`shouldRestartScannerOnResume`, `app_icon_assets_test.dart`,
`android-back.yaml`). One `.maestro/README.md` note — that the Maestro **MCP**
driver session goes stale after an emulator reboot — is **not** on main. It is a
stash, not a branch, and not mine: **left untouched**, flagged for a decision.

---

## 3. Over-corrections found

**NONE.** Actively checked for destructive over-removal:

| Asset / data | Check | Result |
|---|---|---|
| `lib/data/venues_data.dart` | `git diff` vs pre-audit `3bc1f07` | **byte-identical** — no venue name, id, lat/lon or `artworkX/Y` changed |
| `assets/data/buildings.json` | SHA-256 vs baseline | **identical**, 170 entries |
| 39 panoramas + 9 manifests | SHA-256 of every file | **all byte-identical** |
| `campus_projection.dart`, `map_placement.dart`, `map_config.dart`, `panorama_data.dart` | `git diff` vs baseline | **unchanged** |
| ARB keys | count + parity | 410 → 410, **zero removed, zero added**, EN/FA parity perfect |
| Every deleted line in `lib/` | manual read of the full diff | all branding-related; no functional code removed |

Nothing was restored, because nothing needed restoring.

---

## 4. Branding verification

| Item | Status | Evidence |
|---|---|---|
| MQ crest | **ABSENT** | painted out; asserted by test on the packaged and source PNG |
| Macquarie wordmark | **ABSENT** | same |
| Macquarie logo elsewhere | **ABSENT** | all 23 icon/launch images visually inspected; raw-byte scan of every bundled image |
| Ownership claims | **ABSENT** | `EventInfo.host`/`faculty`/`cricosProvider` deleted; 0 hits in `libapp.so` |
| Endorsement claims | **ABSENT** | store copy rewritten; explicit non-affiliation added |
| Copyright statements naming a university | **ABSENT** in app; **WITHDRAWN + blocked** in store metadata |

---

## 5. Basemap verification

```
Dimensions expected:   2048 x 1448
Actual (source):       2048 x 1448  RGBA
Actual (in the APK):   2048 x 1448  RGBA
Cropped / resized:     NO
17-pin alignment:      PASS  - venue_artwork_placement_test.dart green;
                       16 artwork-pinned venues match the expected set exactly,
                       Metro station placed by GPS projection (artworkX null)
Georeference:          PASS  - aon_basemap_georef_test.dart green; similarity
                       params unchanged (scale 1.024017937, tx -252.463703,
                       ty -74.694819); projection source files byte-identical
MQ crest:              ABSENT
MQ wordmark:           ABSENT
Underlying artwork:    PRESERVED - 16,780 px changed, 0 outside the lockup rect
Visible remnants:      NONE - fill is #FFFFFF, matching uniform opaque white on
                       all four margins, so the reconstruction is exact
```

Guarded by `no_university_branding_test.dart`, which decodes the PNG and asserts
the rect `x1750-1976, y50-265` is pure white at 2048 × 1448.

## 6. 360° panorama verification

```
Expected: 39      Present: 39      Manifests: 9
Functionality: PASS - tours opened on iPhone, iPad and Android during the
               screenshot capture; panorama tests green
Branding overlays: NONE - full-frame contact sheet of all 39, plus a separate
               nadir-strip sheet (where 360 rigs brand the tripod cap), plus a
               raw-byte scan for embedded XMP/EXIF. No hits.
Incidental real-world signage: LEFT UNTOUCHED, per instruction
Modified: NO - all 39 byte-identical to baseline
```

## 7. buildings.json verification

```
Present: YES        Functional: YES (Map search, Nearby, Favourites)
Entries: 170        Unexpected modification: NO - SHA-256 identical to baseline
```

Inspected its field taxonomy: `facultyGroup` holds generic slugs
(`science_engineering`, `arts`, `business`, `mhhs`), **not parsed by `lib/`** —
dead weight in the bundled JSON, not branding. Left untouched: instructed to
preserve, and the file is SHA-pinned by the test suite.

## 8. Android verification

`android/**` re-searched for macquarie / MQ / CRICOS / university / official /
sponsored / endorsed: **no branding hits.** `android:label="Astronomy Open
Night"`. Adaptive icon and all mipmaps visually clean. Release APK **and** AAB
rebuilt and inspected (§11). `applicationId`/`namespace` remain
`au.edu.mq.astronomy.aon2026` — unchanged by design, §17.

## 9. iOS verification

`ios/**` re-searched with the same term set: **no branding hits.**
`CFBundleDisplayName` / `CFBundleName` = `Astronomy Open Night`. Asset catalog
(21 images) visually clean; `LaunchImage` is 1×1 (the launch screen is the flat
dark ground, as designed). No pbxproj, entitlement, privacy-manifest or signing
change was made in either pass.

**iOS release archive: NOT VERIFIED.** `flutter build ipa` cannot run in this
macOS user's shell — its Xcode is signed into a different individual team
(`3L5A4R7JNY`) than the project's `94273WB4G3`. Pre-existing, not a project
defect. **However the iOS project does compile:** `flutter build ios --simulator
--debug` succeeded and that build produced the iPhone and iPad screenshots.

## 10. Localisation verification

Both supported locales inspected, not English only.

```
EN keys 410   FA keys 410   removed 0   added 0   EN-only [] FA-only []
Shipped FA strings containing دانشگاه ("university"): 0  (was 4 - fixed, §2.2)
Shipped strings naming the university: 2 - homeFactMetroBody EN + FA only
Generated locale files regenerated and committed; l10n gate step green
```

## 11. Packaged asset verification

`pubspec.yaml` declares: `assets/images/`, `assets/web/indoor_viewer.html`,
`assets/web/pannellum/`, `assets/data/indoor/`, `assets/data/buildings.json`,
`assets/maps/`. Two are **directory wildcards** (`assets/maps/`,
`assets/data/indoor/`), so anything dropped there ships — both were enumerated
and contain only the intended files.

- **`assets/branding/app_icon_source.png` is NOT declared → does not ship.**
- **Neither source PDF ships** (both live outside `assets/`).
- No `.bak` / `.old` / `.orig` / duplicate / orphaned asset exists anywhere.

Release APK unzipped and inspected in full:

```
Files inside the APK containing "macquarie":
  assets/flutter_assets/AssetManifest.bin              (asset paths)
  assets/flutter_assets/assets/data/buildings.json     (real place names)
  assets/flutter_assets/assets/data/indoor/macquarie-theatre.json  (venue manifest)
Files containing CRICOS / 00002J / MQPhysAstro / MQAstroOpen:  NONE
Packaged basemap: 2048x1448 RGBA, lockup rect pure white
Bundled images matching "macquarie" in raw bytes: NONE
```

**Compiled Dart snapshot (`libapp.so`)** — the strings that actually reach the
running UI — contains **14** Macquarie strings, every one a venue name, place
name, id or asset path (full list in §15). `CRICOS|00002J|MQPhysAstro|
MQAstroOpen`: **0**. `Faculty of Science`: **0**.

> `meta:Macquarie` appears in `libflutter.so`. It is Flutter's own CLDR
> timezone id for **Macquarie Island**, between `meta:Macau` and `meta:Magadan`.
> Not ours, not the university, not removable.

## 12. Store metadata verification

Re-read every release document. No metadata implies university ownership,
publication, sponsorship or endorsement. The copyright field is explicitly
**blocked pending a human decision** rather than filled with a guess.
All 18 screenshots recaptured from the post-branding build (`4fe4c13`) and
visually confirmed: no Home eyebrow, no crest, correct map attribution, and no
QA-only reset control on the Passport screens.

## 13. Runtime content verification

Content loaded at runtime rather than compiled in was searched separately:
the 9 panorama JSON manifests, `buildings.json`, `indoor_viewer.html` and the
bundled `pannellum` library. No remote config, Firebase, API-served copy or
Markdown/HTML content source exists — the app has no backend.

`assets/web/indoor_viewer.html` uses `mq-hotspot`, `mq-hotspot-arrow`,
`mq-hotspot-label`, `mqCreateHotspot`, `mqViewer`. These are **CSS class names
and JS identifiers inherited from the sibling MQ Journey codebase**. They are
never rendered as text (the visible hotspot label comes from the manifest), are
invisible to users, and renaming them risks breaking the 360° viewer for no
compliance gain. **Category F — retained, documented.**

## 14. Commands executed and exact results

```
./scripts/check.sh                    CHECK PASSED   exit 0   7/7   coverage 90.86%
flutter analyze                       No issues found!
flutter test (full suite, in gate)    all pass
flutter test venue_artwork_placement + aon_basemap_georef
        + no_university_branding      All tests passed!  (17 tests)
flutter build apk --release           exit 0   137.8 MB
flutter build appbundle --release     exit 0   128.9 MB (signed)
flutter build ios --simulator --debug exit 0   Runner.app
flutter build web --release           exit 0
flutter gen-l10n                      exit 0
sips docs/release/play-graphics/icon-512.png
                                      pixelWidth 512, pixelHeight 512, hasAlpha: no
```

`flutter clean` was **deliberately not run**: it would discard the release
artefacts this audit inspects, and the gate runs `pub get` + a full rebuild
anyway. `dart format .` was **deliberately not run** — 255 files carry
pre-existing Dart 3.12 tall-style drift; the repo's standing rule is that format
is informational and a blanket reformat would bury every real diff. The gate
reports it as informational, and it did.

## 15. Final remaining search matches

Occurrence counts (case-insensitive, all tracked files; the second column
excludes this report and `CHANGELOG.md`, which necessarily quote what was removed):

```
macquarie              484 / 410        macquarieuniversity    1 / 0
macquarie university   164 / 131        MQ University          4 / 1
CRICOS                  21 / 7          MQPhysAstro            6 / 3
00002J                   8 / 3          MQAstroOpen            6 / 3
MQU                     38 / 37   -> all binary false positives inside PNG/JPG bytes
```

### Every occurrence that reaches a user, classified

These 14 strings are the complete set compiled into `libapp.so`, plus the 3
asset-file matches. Nothing else in the repository ships.

| # | Text | Category | User-facing | Ships | Safe to retain | Why it remains |
|---|---|---|---|---|---|---|
| 1 | `Macquarie Theatre` | D | Yes | Yes | **Yes** | Venue name on the building's physical signage and the printed programme map |
| 2 | `Macquarie University Sport and Aquatic Centre` | D | Yes | Yes | **Yes** | Real facility name, legend item F |
| 3 | `Macquarie University Astronomical Observatory` | D | Yes | Yes | **Yes** | Real facility name, legend item G |
| 4 | `Macquarie University Observatory` | D | Yes | Yes | **Yes** | Venue subtitle, same facility |
| 5 | `Macquarie University Metro Station` | D | Yes | Yes | **Yes** | Registered Transport for NSW station name |
| 6 | `Macquarie University Station` | D | No (search alias) | Yes | **Yes** | Search alias for the same station |
| 7 | `Sydney Metro stops at Macquarie University Metro Station, on campus.` | D | Yes | Yes | **Yes** | Wayfinding fact; the next stop is "Macquarie Park", so genericising misdirects |
| 8 | `Sydney Metro. The station sits at the south-eastern corner of campus, next to Macquarie Centre.` | D | Yes | Yes | **Yes** | Landmark for orientation; Macquarie Centre is a shopping centre, not the university |
| 9 | `Leave the Metro station and head north-west into the campus, away from Macquarie Centre.` | D | Yes | Yes | **Yes** | Walking direction using the same landmark |
| 10 | `A live physics magic show in the Macquarie Theatre…` | D | Yes | Yes | **Yes** | Programme copy naming the venue |
| 11 | `Join us in exploring the cosmos… telescopes from Macquarie University Observatory…` | D | Yes | Yes | **Yes** | Programme copy naming whose telescopes |
| 12 | `macquarie-theatre` | F | No | Yes | **Yes** | Venue id — also a **persistence key**; renaming orphans saved favourites and stamps |
| 13 | `toilets-macquarie-theatre` | F | No | Yes | **Yes** | Same |
| 14 | `assets/data/indoor/macquarie-theatre.json` | F | No | Yes | **Yes** | Asset path derived from the venue id |
| 15 | `buildings.json` place names (~180) | D | Yes (search) | Yes | **Yes** | Street, suburb and facility names; SHA-pinned, instructed to preserve |
| 16 | `AssetManifest.bin` entries | F | No | Yes | **Yes** | Generated index of the paths above |
| 17 | `meta:Macquarie` in `libflutter.so` | I | No | Yes | **Yes** | Flutter's CLDR timezone id for Macquarie **Island** |

**Category A (unauthorised branding), B (ownership statement) and C
(affiliation/endorsement implication): ZERO occurrences ship.**

Non-shipping remainder — engineering provenance comments in `lib/`, `tools/`,
`docs/` and the design specs, test venue-name assertions, and the audit trail
recording what was removed. Category **G**. Retained deliberately: it is the
record proving what is authorised.

## 16. Files modified during the second pass

| File | Change |
|---|---|
| `docs/release/play-graphics/icon-512.png` | Regenerated from the approved app artwork (was the Flutter logo) |
| `lib/l10n/app_fa.arb` | 4 shipped strings: "university" → "campus", matching English |
| `lib/l10n/generated/app_localizations_fa.dart` | Regenerated |
| `BRANDING_AUDIT_PASS2.md` | This report |

Pass-1 files are listed in `BRANDING_AUDIT.md` §12.

## 17. Manual decisions still required

Unchanged from pass 1, and none is a code problem:

1. **App Store copyright field — BLOCKER.** `© 2026 Macquarie University`
   withdrawn. `© 2026 Astronomy Night - FSE Outreach Team` is **not** a safe
   substitute: FSE is a university faculty unit. **New, relevant evidence:** the
   shipped Android privacy copy already states *"Astronomy Open Night is
   published on Google Play by Leo Alavi, an independent developer"* — so for
   Play the publisher is settled, and the same answer may serve Apple.
2. **Support URL** — was `event.mq.edu.au`; needs a non-university HTTPS page.
3. **Privacy Policy / Terms hosting** — fill `[PUBLISHER]`, not on `mq.edu.au`.
4. **Bundle identifier** `au.edu.mq.astronomy.aon2026` — keep or migrate. Only
   cheap before first public release. `organiser-requests.md` §6.
5. **`stash@{0}`** — carries one Maestro README note not on main (§2.4). Not a
   branch; left untouched pending your call.
6. **Two README rights lines** still name the university, deliberately (they
   disclaim affiliation rather than claim it). `BRANDING_AUDIT.md` §4.

## 18. Final release verdict

## **READY AFTER MINOR FIXES**

The second pass found **two real defects the first pass missed** — a Play Store
icon that was the stock Flutter logo while its checklist row read "DONE", and
Persian copy that said "university" where the English said "campus". Both are
fixed and verified.

Everything else held up under independent re-examination. The branding
requirement is met **in the shipped binary**, not merely in the source: the
packaged APK carries no crest, no wordmark, no institutional identifier and no
ownership claim, and the only Macquarie strings that reach a user are venue,
street, suburb and transport names people navigate by at night. No
over-correction occurred — venue data, `buildings.json`, the 39 panoramas and
every projection source file are byte-identical to the pre-audit baseline.

It is not READY FOR RELEASE only because of §17.1–17.3, which are ownership and
hosting decisions, not engineering work. **One answer — who owns and publishes
this app — unblocks all three.**

**NOT VERIFIED, stated plainly:** the iOS release **archive**
(`flutter build ipa`) could not be produced in this shell for a pre-existing
signing-team reason. The iOS project compiles and runs — the iPhone and iPad
screenshots came from that build — but no `.ipa` was produced or inspected in
either pass.
