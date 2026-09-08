# Changelog — Astronomy Open Night 2026 (`aon2026`)

Human-readable release log. Entries are newest first and use the `Raouf:`
template (date in Australia/Sydney, scope, summary, files, verification,
follow-ups). Commit-level history lives in `git log`; the architecture is in
`ARCHITECTURE.md`; open release prerequisites in `docs/release-blockers.md`.

---

## Raouf: 2026-09-08 — Pouya's device pass: six UI defects fixed, two escalated

**Scope:** Triage and fix of the bug batch Pouya sent over WhatsApp on 8 Sep
(nine screenshots, five Persian voice notes). Full triage, including his own
words per item, in `docs/reviews/2026-09-08-pouya-bug-batch.md`.

**Fixed**
- **Program search: the keyboard could not be dismissed.** Flutter's default
  tap-outside action deliberately does not unfocus for *touch* pointers on iOS
  and Android, so the keyboard covered the results with no way out but the
  system back gesture. The field now handles `onTapOutside`/`onSubmitted`, and
  the programme scroll view dismisses on drag.
- **The formatting locale went stale.** Persian → "Match my device" left
  `TimeFormat.locale` pinned to `fa`, giving an English UI with Persian times
  and digits ("Previewing ۴ب.ظ. on event night", "Up next ۱۴"). Cause:
  `TimeFormat.locale` was assigned inside `localeResolutionCallback`, which
  Flutter only consults while `MaterialApp.locale` is non-null — on a null
  override `LocalizationsResolver` returns a cached locale. Now read from the
  resolved locale in `MaterialApp.builder`, which cannot go stale.
- **"Happening now" appeared twice on Home.** `phaseHappeningNow` and
  `timingHappeningNow` were the same words, and the hero pill sat directly
  above the rail header using the other one. `EventPhase.running` now
  contributes no hero pill; every other phase still does, because each says
  something the rail cannot. The orphaned ARB key is gone from both locales.
- **Sheet actions sat under the floating tab bar.** Not a padding bug: the
  sheets were pushed on the *branch* navigator, inside the shell's `Scaffold`,
  so the glass island painted over them **and stayed tappable through the modal
  barrier** — on the simulator a tap aimed at "Show on map" switched tabs and
  dismissed the sheet. Now `useRootNavigator: true`, which four of the chooser
  sheets already used; the guard test asserts it for every sheet in the shell's
  files. (The first attempt added `AonNavMetrics.clearance` padding and passed
  a green gate; running the app is what showed it was the wrong fix.)
- **The sheet drag handle did not drag the sheet.** `VenueSheet` and
  `VenueInfoSheet` nest a `DraggableScrollableSheet` inside
  `showModalBottomSheet`; Material's handle belongs to the outer modal and
  cannot move the inner sheet's extent, so only dragging the *contents* worked.
  Those two now pass `showDragHandle: false` and render a new `SheetDragHandle`
  inside their own scroll view.
- **Haptics did nothing.** The plumbing was correct — the coverage was not.
  Only five widget types ever called `AonHaptics`, so every plain Material
  button, switch, radio and filter was silent while Settings promised "a gentle
  vibration when you tap buttons". Added `AonHaptics.tap()`/`select()` and wired
  the shared surfaces. `setHapticsEnabled` now updates the master switch
  eagerly, so turning haptics on demonstrates them on the spot instead of
  staying silent for a frame.

**Found on the second pass, after re-reading the audio line by line**
- **The provenance line was shipping to attendees.** Every activity showed
  `Source: …`; on Solar system walk that meant *"Liz 2026-08-31 — …so classified
  openAllNight (not an exact session)"* — an organiser named, an internal email
  quoted, the internal timing enum exposed. `sourceNote` is a data-integrity
  artefact (`data_integrity_test` requires one per event) and the screen's own
  comment says "for the team rather than attendees"; it rendered unconditionally
  regardless. Now behind `AON_SHOW_SOURCE_NOTES`, matching the `qa_mode.dart`
  pattern adopted after a `kDebugMode` control reached an App Store screenshot.
  Pouya did not report this — it was found by opening the screen he complained
  about.

**Not defects — left alone deliberately**
- The amber notes on **Solar system walk** encode the `openAllNight` case (Liz:
  "no set opening times") and an unconfirmed position. Removing them breaks
  invariants #2/#5 and `liz_update_2026_08_31_test.dart`. They resolve when the
  organisers confirm — an organiser question, not a code change.
- The **`MACQUARIE UNIVERSITY`** line in his hero screenshot predates `91d5f14`;
  already removed.
- The clipped action row on **Solar system walk** is ordinary mid-scroll —
  confirmed on the 6.9" simulator that both buttons are reachable.
- The **drag handle on the chooser sheets** was never broken: those are plain
  modals where Material's handle correctly drags to dismiss (verified on
  Toilets). Only the two nested `DraggableScrollableSheet`s were affected.

**Escalated, not touched**
- Pouya asked for the **Privacy Policy to be rewritten from scratch**. It is
  legal copy naming Leo Alavi as publisher, and the in-app dialog is only the
  fallback shown while `EventConfig.privacyPolicyUrl` is null. Raouf's and
  Leo's call.

**Files:** `lib/main.dart`, `lib/screens/{program,settings,map,event_detail}_screen.dart`,
`lib/services/app_settings.dart`, `lib/utils/{haptics,timing_labels}.dart`,
`lib/widgets/{sheet_drag_handle,venue_info_sheet,building_sheet,place_action_buttons,map_mode_toggle,map_category_filter_bar}.dart`,
`lib/l10n/app_{en,fa}.arb`, `docs/reviews/2026-09-08-pouya-bug-batch.md`.

**Verification:** `./scripts/check.sh` → **CHECK PASSED, exit 0**, 7/7. Two new
test files (`locale_switch_formatting_test.dart`,
`pouya_2026_09_08_regressions_test.dart`) plus a new sheet guard in
`bottom_nav_clearance_test.dart`. The locale, keyboard and sheet-layering
tripwires were each verified RED against the pre-fix source before being
accepted, not merely green after it. The sheet fixes were also confirmed on the
6.9" simulator: the venue sheet and the parking sheet now cover the tab bar with
both actions reachable, and the drag handle expands the sheet.

**Follow-ups:** privacy-policy copy decision; Solar system walk position and
times from the organisers; **the first half of voice note 5 is undecodable** and
describes a second preview-mode problem — ask Pouya rather than guessing (see
the triage doc). The keyboard, locale, duplicate-pill and haptics
fixes are unit-verified only — they have **not** been exercised on hardware, and
haptics cannot be felt on a simulator at all. That needs Pouya's next build.


## Raouf: 2026-09-07 — Play Console has no app; the "bootstrap AAB" never existed

**Scope:** Attempting the last B3 step (register the Play App Signing SHA-1 on
`aon2026-android`) in Play Console via Claude in Chrome, from Raouf's session.

**Finding**
- The only developer account visible is **Leo Alavi (personal,
  7729261909793792976)** and it reads **"Create your first app"**.
- On the Create-app form, `au.edu.mq.astronomy.aon2026` → **"Package name
  available"** — definitive: the package has never been registered on Play under
  any account. `GOOGLE_PLAY_RELEASE_AUDIT.md`, `play-store-listing.md` and
  `CLAUDE.md` all asserted a "Play App Signing bootstrap AAB" and that `1.0.0+1`
  was spent on Play. **All three were false** and are now corrected.
- Consequence: **no Play App Signing certificate exists**, so the Android key is
  (correctly) restricted to the upload SHA-1 only. That is right for every
  sideloaded/internal build and will 403 for Play installs until the cert
  exists and is added.

**State left in the browser:** the Create-app form is filled with the name and
package (availability confirmed); the permission classifier stopped automation
at the language dropdown. Remaining by hand: language en-AU → App → Free →
declarations → *Create app*; upload the signed AAB to *Internal testing*; copy
the SHA-1 from *Setup → App signing*; then add it to `aon2026-android` in GCP
and re-run the check script.

**Files:** `docs/release-blockers.md` (B3), `GOOGLE_PLAY_RELEASE_AUDIT.md`,
`docs/release/play-store-listing.md`, `CLAUDE.md` (git-ignored).

---

## Raouf: 2026-09-07 — B3: per-platform restricted keys live, and a latent Android 403 fixed

**Scope:** Closing the unrestricted-key blocker. Two keys created in the GCP
console via Claude in Chrome (Raouf's session), values moved clipboard→file
without ever being printed, and the restriction verified against the live API.

**Summary**
- `aon2026-android` (Android apps: package + upload SHA-1; Maps SDK for
  Android + Routes API) and `aon2026-ios` (iOS apps: bundle id; Maps SDK for
  iOS + Routes API). Neither service-account-bound. The old `Astronomy` key —
  unrestricted, **35 APIs**, the whole Maps Platform catalogue — stays until
  cut-over is confirmed, then gets deleted.
- Keys placed so each platform resolves the right one: `.env` holds the two
  Routes keys plus `MAPS_API_KEY`=iOS (iOS prefers the Dart define);
  `android/secrets.properties` (new) pins the Android manifest key and beats
  `.env` in `build.gradle.kts`; `Secrets.xcconfig`=iOS. Confirmed with `aapt2`
  on a keyed release build: the manifest carries the Android key.
- **Verification:** `tools/security/check_routes_key_restrictions.sh` →
  **iOS 200/403/403, Android 200/403/403.**

**The bug this surfaced — would have broken Android on cut-over**
The Android "correct identity" probe first returned **403**. Google requires
`X-Android-Cert` **without colons**; `MainActivity.signingCertSha1()` sent the
colon-separated display form, and its comment claimed the format had been
"confirmed at T10 against a live accept/reject verification" — it had not.
Against an unrestricted key the header is ignored, so the defect was invisible
for the project's whole life. Fixed in both layers: native emits plain
uppercase hex; Dart adds `normaliseAndroidCert()` so a stale native build
cannot reintroduce it. `routes_client_identity_test` now asserts the plain form.

**Files:** `android/.../MainActivity.kt`, `lib/services/routes_client_identity.dart`,
`test/unit/routes_client_identity_test.dart`, `tools/security/check_routes_key_restrictions.sh`,
`docs/google-maps-setup.md`, `docs/release-blockers.md`.

**Verification:** `./scripts/check.sh` → `CHECK PASSED`, exit 0; 18/18 in the
two Routes test files; keyed `flutter build apk --release
--dart-define-from-file=.env` → 137.8 MB.

**Follow-ups (hand, GCP/Play consoles):** add the **Play App Signing SHA-1** to
`aon2026-android` (without it real Play installs get 403); delete `Astronomy`;
confirm a live route on a device (B4).

---

## Raouf: 2026-09-07 — B3 re-verified: BOTH Google keys are unrestricted, not just iOS

**Scope:** Re-checking release blocker B3 against the live API. No GCP console
change was made — that is an infra action — but the blocker is now measured
rather than assumed, and it is **wider than recorded**.

**Finding**
- The 2026-09-05 check tested only the **iOS** Routes key. Both keys were
  re-probed on 2026-09-07 and **all six probes returned HTTP 200**:

  | Key | correct identity | no identity header | wrong identity |
  |---|---|---|---|
  | iOS Routes | 200 | **200** | **200** |
  | **Android Routes** | 200 | **200** | **200** |

  The **Android Routes key is unrestricted too** — never previously tested.
  Neither key enforces the identity headers the client goes to real trouble to
  send (`routes_client_identity.dart`, and `MainActivity.signingCertSha1()`
  reading the live signing cert at runtime).
- **The Maps SDK key ships in plaintext.** Confirmed with
  `aapt2 dump xmltree --file AndroidManifest.xml` on the release APK:
  `com.google.android.geo.API_KEY` carries the literal key. This is normal and
  unavoidable in a mobile client — **an API key in a shipped app is not a
  secret.** Google's protection model is application + API restriction, not
  secrecy. That is precisely why B3 matters: today anyone who pulls a key out of
  the APK or IPA can bill this project's GCP account from anywhere.

**The trap that would have broken production, documented in the close condition**
`MainActivity.signingCertSha1()` reports the **live** `apkContentsSigners`, so a
Play-installed build sends the **Play App Signing** certificate while a locally
built release APK sends the **upload** certificate. Restricting the Android key
to the upload key alone therefore **works on every build you test and fails for
every real user**. The close condition now lists all the SHA-1s that must be
registered, and records the upload key's:
`A4:26:BD:18:EF:21:BC:FD:05:FA:95:A2:D5:EF:C3:03:A5:CD:92:6D` (its SHA-256
matches the fingerprint already recorded for the keystore).

**Added** `tools/security/check_routes_key_restrictions.sh` — runs all six
probes and prints **status codes only**, never a key. It is the verification
evidence B3 asks for, so closing the blocker is now a one-command check.

**Status:** B3 remains `OPEN`. It is not an App Review blocker; it is a billing
and abuse exposure that should be closed before the app is public, and
certainly before event night. Owner: infra (GCP console).

---

## Raouf: 2026-09-07 — the last Play Console graphic: 1024 × 500 feature graphic

**Scope:** The only Play listing asset still missing. Play requires a feature
graphic for **every** listing, so this was a hard submission blocker.

**Summary**
- Built `docs/release/play-graphics/feature-graphic-1024x500.png` — 1024 × 500,
  RGB, **no alpha**, 212 KB. Verified with `sips` *and* by looking at it.
- Generated by **`tools/marketing/build_feature_graphic.py`**, committed so it
  can be regenerated. **Byte-reproducible**: a fixed seed (the event date) means
  re-running it yields an identical SHA-256.
- **No third-party photograph.** The starfield is procedural — this project's
  own pixels. The obvious source, the Home hero, is Aleix Roig's and is
  *credited, not licensed*; `play-store-listing.md` had explicitly warned
  against building the graphic from it.
- **No university branding**, per ARCHITECTURE §14 invariant 18. Layout uses the
  app's own tokens: `#05070F` ground, `#FFB945` accent, the shipping app icon.
  Nothing that matters sits within 64 px of an edge, since Play crops and
  overlays this image in several placements.

**Three stale claims in the release docs, found while closing this out**
- `GOOGLE_PLAY_RELEASE_AUDIT.md` still recommended the short description
  *"The official guide to Macquarie University's Astronomy Open Night"* — and
  its "safer" alternative also named the university. Following either would have
  put the branding straight back into the listing. **Superseded**, pointing at
  the live value.
- The same file's **Graphics** bullet and **P2-5** row still listed the feature
  graphic and Android screenshots as outstanding. Both are done.
- `play-store-listing.md`'s icon row now records *why* it read "DONE" while
  being wrong: the size and alpha checks passed, and nobody opened the image.

**Play graphic assets are now complete:** 512 × 512 icon, 1024 × 500 feature
graphic, six 1080 × 2160 phone screenshots (exactly 2:1).

**Verification:** `sips` → 1024 × 500, `hasAlpha: no`; PIL → mode RGB, no alpha
band; SHA-256 identical across two runs. `./scripts/check.sh` → `CHECK PASSED`,
exit 0, 7/7, coverage 90.86 %.

**Still HUMAN on Play Console** (none is a graphics or code task): the hosted
Privacy Policy URL, the Data safety form, Play App Signing registration of the
new upload key, the content rating (IARC) questionnaire, the target-audience
answer, and the **14-day closed test with 12 opted-in testers** required because
the publishing account is a personal one created after 13 Nov 2023.

---

## Raouf: 2026-09-07 — second independent compliance sweep (`93812e3`)

**Scope:** Re-audit of the branding removal, run as if the first pass were
untrusted: the repository was re-inventoried from scratch and pass 1's search
results, file list, conclusions and `PASS` status were all treated as unverified.

**Two real defects pass 1 missed — both fixed**
- **BLOCKER — the Play Store icon was the stock Flutter logo.**
  `docs/release/play-graphics/icon-512.png` was Flutter's own mark (81.9 % of
  the image was pure white), while `play-store-listing.md` recorded it as
  *"DONE — verified 512 × 512, `hasAlpha: no`"*. **Both of those checks passed.
  Neither looked at the content.** Regenerated from the approved artwork
  (`assets/branding/app_icon_source.png`), alpha flattened onto `#05070F`,
  LANCZOS to 512 × 512, 32-bit PNG, no transparency.
- **MEDIUM — Persian said "university" where English says "campus."**
  Four *shipped* `app_fa.arb` strings, including the privacy copy twice as
  *"the university map"* — which reads closer to an ownership claim in Persian
  than the English does. The file's own established word for campus was already
  used in eight other keys, so this was internal inconsistency as well as
  drift. **An English-only sweep cannot find this class of defect.**

**Two claims pass 1 made without checking, now corrected**
- Not "17 venue pins": **16** venues are pinned from `artworkX/Y` (the exact set
  is asserted by `venue_artwork_placement_test.dart`); the Metro station is the
  17th and is placed by **GPS projection** with `artworkX == null`.
- Pass 1's sweep deltas used `git grep -c`, which counts matching **lines**, not
  occurrences. True figures are **450 → 410**, not "434 → 283".

**No over-correction.** Verified byte-identical to the pre-audit baseline:
`venues_data.dart`, `buildings.json` (SHA-256, 170 entries), all 39 panoramas
and 9 manifests, and `campus_projection.dart` / `map_placement.dart` /
`map_config.dart` / `panorama_data.dart`. ARB keys 410 → 410, EN/FA parity exact.

**Verified in the packaged binary, not just the source.** The release APK
contains exactly three files matching "macquarie" — `AssetManifest.bin`,
`buildings.json` and the theatre panorama manifest — and **zero** matching
`CRICOS|00002J|MQPhysAstro|MQAstroOpen`. The compiled Dart snapshot
(`libapp.so`) holds **14** Macquarie strings, every one a venue name, place
name, id or asset path; all 14 are classified individually in the report.
(`meta:Macquarie` in `libflutter.so` is Flutter's own CLDR timezone id for
Macquarie *Island*.)

**Verification:** `./scripts/check.sh` → `CHECK PASSED`, exit 0, 7/7, coverage
90.86 %. `flutter analyze` clean. APK 137.8 MB, AAB 128.9 MB, iOS-simulator and
web builds green. **iOS release archive: NOT VERIFIED** — `flutter build ipa`
cannot run in this shell for the pre-existing signing-team reason.

**Files:** `docs/release/play-graphics/icon-512.png`, `lib/l10n/app_fa.arb`
(+ generated), `BRANDING_AUDIT.md`, `BRANDING_AUDIT_PASS2.md` (new).

**Follow-ups:** unchanged — the copyright field, the Support/Privacy hosting
domain and the bundle identifier all need a person. Note the shipped Android
privacy copy already states *"published on Google Play by Leo Alavi, an
independent developer"*, which may settle the publisher question for both stores.

---

## Raouf: 2026-09-07 — recapture all 18 store screenshots (`4fe4c13`)

**Scope:** Every listing image was taken before the branding removal, so all 18
showed the `MACQUARIE UNIVERSITY` Home eyebrow and/or the crested basemap — they
would have put the branding straight back into the store listings.

**Summary**
- Added **`.maestro/store-screenshots.yaml`**, which drives all six listing
  screens, so this is reproducible instead of ad hoc. It encodes the traps: the
  cold-boot `swipe: DOWN` after a `clearState` launch, tabs tapped **by label**
  never by point, waiting on the tour **title** rather than the picker row, and
  dismissing the full-screen tour with its own back control — Maestro's `back`
  is **Android-only** and silently does nothing on iOS.
- **iPhone 6.9": 1290 × 2796**, Maestro CLI on an iOS 26.5 simulator. The
  listing table claimed `1320 × 2868` while the committed files were actually
  **1284 × 2778** — Apple's **6.5"** size, so the old set was documented against
  a slot it did not fit. 1290 × 2796 *is* an accepted 6.9" size; table and files
  now agree.
- **iPad 13": 2064 × 2752.** **Maestro crashes outright on iPad** (the
  unreliability `CLAUDE.md` already warned about, now confirmed as a hard
  crash), so these were driven with the iOS-Simulator control tool and captured
  with `xcrun simctl io … screenshot`.
- **Android phone: 1080 × 2160**, exactly 2:1, from the **signed release APK**
  with `adb shell wm size 1080x2160` (reset afterwards).

**Two host problems worth recording**
- The emulator ANR'd repeatedly (`systemui`, then the launcher) because a
  **stuck `qemu-system` process survived `adb emu kill` while holding 5.6 GB** —
  the host was down to 1.6 GB free. `kill -9` on that PID plus a cold boot
  (`-no-snapshot-load`) fixed it.
- No iOS simulators existed at all; both devices had to be created with
  `xcrun simctl create`.

**Verified in every shot:** no university eyebrow on Home, no crest or wordmark
on the basemap, the map credits *"Campus map: Astronomy Open Night programme"*,
and the Passport screens carry **no QA-only reset control** — so the
`kDebugMode` leak fixed on 2026-09-06 stays fixed in a release build.

**Verification:** `./scripts/check.sh` → `CHECK PASSED`, exit 0, 7/7, 90.86 %.

---

## Raouf: 2026-09-07 — remove Macquarie University branding; the app stands as an independent project (`91d5f14`)

**Scope:** Repository-wide branding audit acting on the supervisor's
instruction (Charanya Ramakrishnan, 2026-09-07): *"do not use 'Macquarie' for
anything… We don't have the university's approval for any of these. These are
your projects."* Branding, institutional identifiers and ownership/affiliation
claims out; **authorised artwork, factual geography and every feature stay in.**

**Summary**
- **The crest was in the basemap, not the strings.** `assets/maps/aon_event_map.png`
  carried the University crest + wordmark in its top-right corner — the most
  visible branding in the app, on the Map tab, and invisible to every text
  search this repo has ever run. Painted out in place: rect x1750–1976,
  y50–265 filled with the surrounding `#FFFFFF` panel colour. **16 780 pixels
  changed, zero outside that rect.** Still 2048 × 1448 RGBA, no crop/resize/
  rotate — the fitted-similarity georeference and all 17 venue pins are
  untouched. The event title block ("ASTRONOMY OPEN NIGHT / 19 SEPTEMBER 2026")
  is deliberately kept.
- **Identifiers a grep for "Macquarie" cannot find.** `EventInfo.cricosProvider`
  = `CRICOS Provider 00002J` is the University's *government registration
  number* and it was rendering in Settings → Credits inside
  *"Event materials and branding © {host}, {faculty}. {cricos}."* Deleted,
  along with `faculty`, `socialHandle` `@MQPhysAstro`, `hashtag` `#MQAstroOpen`
  and `materialReference` `FSE26193` (the last three were declared but never
  rendered).
- **Three render sites for `EventInfo.host`, not one:** the Home hero eyebrow
  (uppercase `MACQUARIE UNIVERSITY`, the first thing the app showed), the Info
  screen event block, and Settings → About. The constant is gone and all three
  sites removed; `EventConfig.host`/`.faculty` dropped with it.
- **Two shipped event descriptions spoke in the University's first person** —
  *"The Faculty of Science and Engineering presents…"* and *"…built by
  Australian Astronomical Optics here at Macquarie University"* — rewritten.
- **Attribution now credits the source document, not an institution:**
  *"Campus map: Astronomy Open Night programme"* (EN + FA, map overlay,
  Settings credits, Info credits). Still asserts `©` for nobody.
- **Store + legal copy:** subtitle *"Macquarie University event"*, Play's
  *"official guide to Macquarie University's…"*, the `macquarie` keyword and
  `© 2026 Macquarie University` are withdrawn. `mq-hosted-pages.md` →
  `hosted-pages.md`: the Privacy Policy, Support and Terms pages were drafted
  in the University's voice (publisher, data controller, warranty disclaimer)
  and are now `[PUBLISHER]`, with hosting on an `mq.edu.au` domain explicitly
  ruled out.
- **New tripwire** `test/unit/no_university_branding_test.dart` (4 tests): no
  shipped ARB string names the University (one allowlisted entry — the Metro
  station — with its reason), no shipped string or non-comment Dart line
  carries an institutional identifier, and the basemap's top-right corner
  decodes to pure white at 2048 × 1448. That last one catches the realistic
  regression: someone restoring the original PNG.

**Deliberately NOT changed**
- **All authorised artwork ships unaltered otherwise** — basemap, `buildings.json`
  (170 buildings), the 39 panoramas, the 17 venue pins. Permission is on record
  (`organiser-requests.md`); the audit removed marks, not content. All 39
  panorama nadirs and raw bytes were checked: no watermarks, no logo caps, no
  embedded XMP/EXIF branding.
- **Real place names** — `Macquarie Theatre`, `Macquarie University Metro
  Station`, `Macquarie Park`, `Macquarie Walk`. Physical signage and Transport
  for NSW facts visitors navigate by at night; the next Metro stop is
  "Macquarie Park", so genericising would misdirect people.
- **Engineering provenance comments** — the audit trail proving what is
  authorised.
- **The bundle identifier `au.edu.mq.astronomy.aon2026`** — spent on TestFlight
  Builds 1–3 and the Play bootstrap AAB. Changing it forfeits both store
  identities. Written up as an open decision in `organiser-requests.md` §6.

**Files changed:** 38. `lib/data/event_info.dart`, `lib/config/event_config.dart`,
`lib/screens/{home,info,settings}_screen.dart`, `lib/data/events_data.dart`,
`lib/l10n/app_{en,fa}.arb` (+ generated), `assets/maps/aon_event_map.png`,
`docs/fixtures/aon_basemap_provenance.json`, `pubspec.yaml`, `web/*`,
`.env.example`, `.maestro/map-{basemap,modes}.yaml`, `README.md`,
`docs/release/*` (listings, review notes, checklists, `hosted-pages.md`,
`organiser-requests.md`), 5 test files + 1 new.

**Verification**
- `./scripts/check.sh` → **`CHECK PASSED`, exit 0**, 7/7, coverage **90.86 %**
  (6620/7286, floor 90.4 %). The provenance step *failed first* on the basemap
  SHA drift — the guard working — and passed after the pin and the
  `modifications` field were updated with the reason.
- `flutter analyze` → **No issues found.**
- `flutter build appbundle --release` → **128.9 MB signed AAB**;
  `flutter build apk --release` → **137.8 MB**; `flutter build web --release`
  → OK.
- **Packaged binary checked, not just the tree:** the map extracted from
  `app-release.apk` is 2048 × 1448 RGBA with the logo region pure white. Only
  three APK entries contain "Macquarie" — `AssetManifest.bin`,
  `buildings.json` and the theatre panorama manifest, all authorised venue
  data. (`meta:Macquarie` in `libflutter.so` is Flutter's own CLDR timezone id
  for Macquarie *Island*.)
- **Rendered proof** (release web build, 375 × 812): Home opens straight into
  "Astronomy Open Night 2026" with no eyebrow; the Map shows every pin in place
  and reads "Campus map: Astronomy Open Night programme".

**Follow-ups (all need a person, not code)**
1. **App Store copyright field — blocker.** `© 2026 Macquarie University` is
   withdrawn; `© 2026 Astronomy Night - FSE Outreach Team` is *not* a safe
   substitute (FSE is a University faculty unit). Whoever owns the app must
   name themselves.
2. **Support URL reopened.** It was `https://event.mq.edu.au/astronomy-open-night/`.
   A support URL on a university domain presents the University as publisher.
3. **Privacy Policy / Terms hosting** must move off any `mq.edu.au` domain, and
   `[PUBLISHER]` must be filled in.
4. **Bundle identifier** — keep or migrate, before first public release.
5. **Store screenshots must be recaptured**: all 18 in
   `docs/release/screenshots/` show the old Home eyebrow and the crested map.

---

## Raouf: 2026-09-05 — Google Play release audit → signed AAB, closed-test candidate

**Scope:** Android release readiness on top of Leo's `46dc81e` (privacy
disclosures, contextual location, scanner UX). Publisher confirmed as Leo
Alavi's personal Play account.

**Summary**
- `GOOGLE_PLAY_RELEASE_AUDIT.md`: verdict CONDITIONALLY READY — code and
  bundle pass every local check; production is gated on the hosted Privacy
  Policy URL, the Data safety form, Play App Signing registration of the new
  upload key, the 14-day/12-tester closed test (personal account created after
  13 Nov 2023) and the asset rights.
- **Reverted** the iOS project/scheme downgrade that rode along in `46dc81e`
  (`objectVersion 60→54`, `LastUpgradeCheck 2660→1510`, custom prepare script)
  back to the Build 1 configuration.
- **Liquid-glass surfaces were a vertical mirror on Android** (P1, reported by
  Raouf 2026-09-06): the refraction shader un-flipped Y under
  `IMPELLER_TARGET_OPENGLES`, double-flipping the backdrop that
  `FlutterFragCoord()` already orients correctly. Flip removed; verified by
  before/after captures on the API 36 emulator; iOS (Metal) unaffected.
- **Camera denial re-prompted on Android** (P1): the OS dialog's own
  `inactive → resumed` restarted the scanner, and `MobileScannerController.start()`
  does not throw on refusal. The view now restarts only what it stopped for the
  background (or on return from app Settings); refusal is read from
  `controller.value`. `shouldRestartScannerOnResume` + 5 unit tests.
- Locate control read "Location unavailable" on a fresh install after the
  contextual-location change: a passive `checkPermission` answer of `denied`
  (which also means "never asked") was being stored on Map entry. Only
  `granted`/`serviceOff` are adopted now; a refusal is learned from the tap.
- Adaptive launcher icon (`mipmap-anydpi-v26`, dark background, no monochrome
  layer); `app_icon_assets_test` extended.
- Upload keystore generated outside the repo; `android/key.properties`
  (ignored) wired; `flutter build appbundle --release` → signed AAB, final
  artefact `1.0.0 (3)` (build 2 was inspected first; the tree merged to
  `1.0.0+3` before commit).
- Play listing doc: Data safety answers rewritten to the Maps SDK / ML Kit
  disclosures; publisher/contact corrected.
- Maestro: `android-back.yaml` (predictive back); cold-boot/restart guards in
  `open-map`, `program`, `my-night`, `settings`; `map-location` rewritten for
  the tap-initiated permission; cross-platform dialog regex in `passport`.
- Docs reconciled to the contextual-location model (review notes,
  ARCHITECTURE, onboarding decision, Apple audit, CLAUDE.md).
- The passport's "Reset passport" action is now behind an explicit per-run
  define (`AON_PASSPORT_RESET_TOOL`, `qa_mode.dart`) instead of `kDebugMode`:
  it had appeared in a store screenshot taken from a debug simulator build.
  Release is unchanged (never shown); tests opt in via the provider.
- Store screenshots recaptured (2026-09-06) from the current build: iPhone
  6.9" ×6 (1320×2868), iPad 13" ×6 (2064×2752), Android phone ×6 (1080×2160,
  exactly 2:1 for Play). Old sets deleted.

**Verification:** see `GOOGLE_PLAY_RELEASE_AUDIT.md` (Build Results): AAB
signed and verified; all 64-bit `.so` 16 KB-aligned + `zipalign -P 16`
successful; merged manifest audited; `lintRelease` 0 errors; Android 16
emulator flows; full gate before commit.

- Branch hygiene (2026-09-06): all 18 side branches, the
  `aon2026-wt-ios-location` worktree and the remote
  `fix/ios-always-location-purpose-string` were verified as strict ancestors
  of `main` (0 commits ahead) and deleted; `origin` now has `main` only.

**Follow-ups:** host the policy, enter Data safety verbatim, register the
upload cert, restrict the Maps key, make the feature graphic (screenshots are
done), start the closed test today.

---
## Raouf: 2026-09-05 — final pre-submission pass; `1.0.0+3` is the Build 3 candidate

**Scope:** the whole App Store submission surface — privacy answers, hosted-page
decisions, Routes verification, screenshots, review notes, blocker register, and
the version bump. Branch `fix/ios-always-location-purpose-string`.

**Summary**
- **Google Routes: the 401 is gone.** A real request with the shipped iOS key
  and the app's own headers returned **HTTP 200** and a real walking route —
  West 6 parking → Macquarie Theatre, 581 m / 476 s. B3's original cause is
  closed.
- **A worse finding in its place: the shipped Routes key has no application
  restriction.** The same request succeeded with **no** bundle-id header and
  again with a *wrong* bundle id. The key ships inside the binary and is
  extractable — `routes_client_identity.dart` says so itself and calls the
  identity headers "load-bearing", which they are only if the server enforces
  them. Anyone can bill this GCP project. Not an App Review blocker; fix it in
  the GCP console before the app is public. B3 stays OPEN on this.
- **App Privacy cannot be answered "Data Not Collected".** Apple's definition of
  *collect* covers transmission to a third-party partner, and the app POSTs the
  visitor's live latLng to Google. `PrivacyInfo.xcprivacy` now declares
  **PreciseLocation — App Functionality, not linked, not tracking**; the old
  empty array contradicted the app's own privacy copy. The test that guarded the
  empty array said "if that changes, declare it here" — so it was changed, not
  deleted, and now pins exactly one collected type.
- **Macquarie's own Privacy Policy cannot be the store URL** — checked, not
  assumed. `policies.mq.edu.au/document/view.php?id=107` scopes itself to staff,
  students and researchers, addresses no mobile app, and says nothing about the
  Routes transmission or ML Kit. MQ *hosting the app's own policy* is the right
  shape and is what `hosted-pages.md` was written for.
- **Support URL found and verified live:** `https://event.mq.edu.au/astronomy-open-night/`
  — official, public, no login, event-specific, with `astronomyopennight@mq.edu.au`
  on the page. It also confirms the date the app shows.
- **Terms of Use: Apple's standard EULA is sufficient.** No custom EULA is
  required. Page 3 of the hosted pages exists for the Google Maps flow-down, not
  for Apple.
- **Screenshots were stale and are now recaptured.** The 2026-08-23 set showed
  *"Venues, toilets, first aid — and walking directions from the car parks"*,
  copy the app no longer ships. 6 of 6 iPhone (1320×2868) and 1 of 4 iPad
  (2064×2752) recaptured from this branch; the three remaining iPad shots were
  removed rather than shipped stale — Maestro reports success against the iPad
  UDID while the taps land elsewhere (three captures came back byte-identical).
- **App Review notes corrected to match the binary.** They claimed directions sit
  behind "an explicit in-app consent screen". Only the car-park wayfinding path
  shows one; the venue Directions path takes opening Directions *as* the choice.
  Both are now described, along with exactly what is sent to Google.
- **B6 closed by owner decision** (ship the hero photo on its existing credit),
  recorded as an accepted risk under a new register status rather than as
  `CLOSED — VERIFIED`, because no permission exists.
- **New:** `docs/release/app-store-connect-final-checklist.md` (23 rows, every
  ASC field with its evidence or its blocker) and
  `docs/release/device-qa-checklist.md` (the physical-device pass that closes B4).
- `pubspec.yaml` → **`1.0.0+3`**. Build 2 is spent.

**Files changed:** `ios/Runner/PrivacyInfo.xcprivacy`,
`test/unit/ios_privacy_manifest_test.dart`, `pubspec.yaml`,
`docs/release/app-store-connect-final-checklist.md` (new),
`docs/release/device-qa-checklist.md` (new), `docs/release-blockers.md`,
`docs/release/app-review-notes.md`, `docs/release/app-store-listing.md`,
`docs/release/screenshots/**`, `ARCHITECTURE.md`.

**Verification**
- `./scripts/check.sh` → **CHECK PASSED, 7/7, exit 0**; coverage 91.10%.
- `flutter build ios --release --no-codesign` ✓, then
  `flutter build ios --config-only --release` → `FLUTTER_BUILD_NUMBER=3`.
- Built bundle inspected: `CFBundleVersion 3`, `CFBundleShortVersionString
  1.0.0`, bundle id `au.edu.mq.astronomy.aon2026`, **4** purpose strings, **0**
  of the keys that must not appear (photo library, microphone, tracking,
  contacts, background modes, ATS exceptions), privacy manifest carrying
  PreciseLocation. `App.framework` contains exactly one network host —
  `https://routes.googleapis.com`.
- One `AIza…` string does appear in the `Runner` binary. It is **not ours**: the
  same string is inside the vendored `GoogleMaps.framework` slice, and this
  worktree has no `Secrets.xcconfig` and was built without
  `--dart-define-from-file`. Recorded so it is not re-raised as a leak.

**Follow-ups**
- Restrict the GCP keys (B3), host the Privacy Policy (B7), fill the App Review
  contact, answer App Privacy / age rating / DSA in ASC, capture the three
  remaining iPad screenshots, and run `device-qa-checklist.md` on a real iPhone
  (B4). Then archive Build 3 from the Xcode signed into team `94273WB4G3`.

## Raouf: 2026-09-05 — record the owner's answers on assets, the account and policy hosting

**Scope:** release blockers B6 and B7, organiser requests, provenance. Docs only
— no code, no behaviour change.

**Summary**
- **Assets (B6).** The owner attested: *"all the assets and material are ours.
  And if it's not ours, we already cited."* That settles three of the four sets
  — the basemap artwork, `buildings.json`, and the 39 360° photographs. B6 is
  narrowed from four assets to **one**.
- **The exception is the Home hero photograph**, and it is not a technicality:
  "A Deep Triangulum Galaxy" is Aleix Roig's, and the app *credits* it. A credit
  says who made a work; a licence is what permits shipping it. The repo's own
  README already states *"Rights remain with the photographer. Do not reuse it
  outside this project without permission."* Two surfaces are affected — the
  bundled app and the store screenshots, where `01-home.png` (iPhone and iPad)
  shows the hero, and a store listing is marketing rather than "this project".
  Closing needs the photographer's written yes for **both**, or a different hero.
- **Apple Developer account.** Confirmed in hand; TestFlight Builds 1 and 2 were
  uploaded from team `94273WB4G3`. No longer a blocker. The residual point, kept
  as a note rather than a blocker: a University-branded bundle id published from
  an individual account can draw a 4.1 request for written authority — worth
  keeping any MQ authorisation email with the review notes.
- **"Can we use Macquarie's privacy policy?" — no, but MQ can host ours.** MQ's
  institutional policy describes the University's services, not this app: it
  says nothing about the Routes origin, Google Maps' own collection, or ML Kit
  diagnostics. A policy that does not describe the app is a 5.1.1 defect of the
  same kind as B1. The right shape — and what `hosted-pages.md` was always
  for — is MQ **hosting the app's own policy** at an `mq.edu.au` URL. Any stable
  HTTPS URL works if that is slow; Android already does this with
  `android-privacy-policy.html` on Leo's Play account.
- **Terms of Use** is not an Apple requirement — apps without one fall under
  Apple's standard licence agreement. Page 3 exists because Google Maps Platform
  requires the app's terms to flow its Maps/Earth Additional ToS down to users.
- Fixed stale facts in `organiser-requests.md`: the panoramas are **39 images
  across nine locations in `assets/data/indoor/`**, not "28 images of six
  venues" under `assets/panorama/**`.

**Files changed:** `docs/release-blockers.md` (B6 rewritten and narrowed, B7
hosting decision), `docs/release/organiser-requests.md`, `docs/release/hosted-pages.md`,
`docs/panorama-image-provenance.md`, `ARCHITECTURE.md` (R4).

**Verification:** `./scripts/check.sh` → CHECK PASSED, 7/7, exit 0.

**Follow-ups**
- Still open and only a person can close them: the hero-image permission (B6),
  the hosted Privacy Policy / Support / Terms URLs (B7), the GCP Routes keys
  (B3), a physical-device pass (B4), and the App Store Connect metadata —
  age rating, App Privacy answers, screenshots, and the review contact, which
  is still `<NAME>/<EMAIL>/<PHONE>` in the notes.

## Raouf: 2026-09-05 — ITMS-90683: add the iOS Always-location purpose string

**Scope:** iOS Info.plist purpose strings, App Review notes, architecture doc.
Branch `fix/ios-always-location-purpose-string` (off `main@46dc81e`, worked in a
git worktree so a parallel session's staged Xcode changes were never touched).

**Summary**
- **The gate was already red on `main` before this branch existed, and is now
  green.** `settings_screen_test.dart:163` demanded the Settings privacy card
  read "no account and no sign-in" and "collects no analytics"; `46dc81e`
  (Leo, "Update privacy disclosures…") rewrote `settingsPrivacyBody` to "No
  account or advertising…" and added the Android ML Kit diagnostics
  disclosure, and `git show --stat 46dc81e` does not list that test. Worse, its
  "collects no analytics" assertion was in direct contradiction with
  `privacy_copy_truth_test.dart`, which `46dc81e` *did* update to forbid that
  exact phrase. The assertions now pin the substance of the shipped copy — no
  account, local storage, ML Kit diagnostics, and that walking directions send
  the origin and destination to Google — and the two tests no longer disagree.
- App Store Connect returned **ITMS-90683** for TestFlight **Build 2**
  (1.0.0+2): "the Info.plist file for the Runner.app bundle should contain a
  `NSLocationAlwaysAndWhenInUseUsageDescription` key". Delivery succeeded — this
  is a warning, not a rejection, and Build 2 remains installable — but it recurs
  on every upload until the key ships.
- **Cause, verified against the shipped binary, not inferred.**
  `strings build/ios/iphoneos/Runner.app/Runner` contains both
  `requestAlwaysAuthorization` and the literal
  `NSLocationAlwaysAndWhenInUseUsageDescription`, while that app's Info.plist
  declared only `NSLocationWhenInUseUsageDescription`. The symbols come from
  `geolocator_apple`'s `PermissionHandler.m`, which Flutter 3.47 links
  *statically* into Runner (the same mechanism as the privacy-manifest work
  above), so Apple's static scan attributes the API to the app bundle.
- **The app still never requests Always.** `PermissionHandler.m` calls
  `requestWhenInUseAuthorization` whenever `NSLocationWhenInUseUsageDescription`
  is present and only falls through to `requestAlwaysAuthorization` when it is
  absent — so the new key cannot change the prompt the user sees. There is no
  location background mode and no `allowsBackgroundLocationUpdates`
  (`location_service.dart` uses a plain `LocationSettings`).
- The new string is written for App Review and stays truthful on both counts
  that matter here: it discloses the Google walking-directions transmission
  (blocker B1's rule, now enforced for *both* location keys) and states that the
  app only uses location while it is open.
- `docs/release/app-review-notes.md` now pre-empts the obvious reviewer
  question — why an Always string exists for an app that only asks When In Use.
- Fixed a stale claim while in the file: `ARCHITECTURE.md` §10.3 still described
  the purpose string as saying location "is never sent anywhere", which was
  corrected on 2026-09-01. Rewritten to describe both keys as they now are.

**Files changed:** `ios/Runner/Info.plist`,
`test/unit/ios_location_purpose_test.dart`, `test/widget/settings_screen_test.dart`,
`docs/release/app-review-notes.md`,
`ARCHITECTURE.md` (§10.2 permissions row, §10.3 rewritten, new risk **R14**).

**Verification**
- `./scripts/check.sh` → **CHECK PASSED, 7/7, exit 0**; 1672 tests, coverage
  91.10% (floor 90.4%). The first run of this branch was **6/7**, and that
  failure was pre-existing on `main` — see the second bullet of the Summary.
- `test/unit/ios_location_purpose_test.dart` 4/4 pass (was 1 test, now 4: the
  When In Use string's truthfulness, the Always string's presence, its
  truthfulness, and that nothing in the bundle contradicts "only while open").
- `plutil -lint ios/Runner/Info.plist` → OK.
- `flutter build ios --release --no-codesign` ✓ (590.8s), and the *built*
  bundle was inspected — `plutil -p build/ios/iphoneos/Runner.app/Info.plist`
  now prints both location keys, and the bundle still declares no
  `UIBackgroundModes`. The **previous** build of that same path printed only
  `NSLocationWhenInUseUsageDescription`, which is precisely what Apple flagged.
- Cause evidence: `strings build/ios/iphoneos/Runner.app/Runner` on the old
  build matched both `requestAlwaysAuthorization` and
  `NSLocationAlwaysAndWhenInUseUsageDescription` — the API really is compiled
  into the app binary.

**Release-doc reconciliation (same branch)**
- `docs/release/app-store-submission-checklist.md`: the purpose-strings row said
  "all three present … each stating use *and* that data stays on device" — now
  four keys, and the two location strings must **not** claim the data stays on
  device. The version row still pointed at `1.0.0+2`; Build 2 is spent, so the
  next archive is `1.0.0+3`.
- `docs/release-blockers.md` **B7**: its "no accessible in-app Privacy Policy
  link or text … no `url_launcher`/`launchUrl` anywhere in `lib/`" evidence was
  overtaken by `46dc81e`, which added the Settings policy card (hosted URL when
  configured, full text offline otherwise) and `lib/services/url_opener.dart`.
  Conditions 2 and 6 are met; B7 stays `OPEN` on the hosted URLs and store
  metadata, which only the organisers can provide.

**Follow-ups**
- **Not yet verified end-to-end:** the warning can only be confirmed gone by the
  next upload. Bump to `1.0.0+3`, run
  `flutter build ios --config-only --release`, then archive **Build 3** from the
  Xcode session signed into team `94273WB4G3` and check the delivery mail.
- No l10n change: purpose strings are localised via `InfoPlist.strings`, which
  this app does not ship. The Persian UI shows the English system prompt today —
  a pre-existing gap, unchanged by this commit.

## Raouf: 2026-09-05 — Apple App Store release audit → TestFlight Build 2 candidate

**Scope:** iOS release readiness, privacy manifest, first-launch UX / onboarding
decision, E2E suite, release docs. Commits `12111f4..58577e0` on `main`.

**Summary**
- Full App Store audit recorded in `APPLE_RELEASE_AUDIT.md`: verdict
  CONDITIONALLY READY — no P0/P1 left in code; App Review still gated on hosted
  Privacy/Support URLs, asset redistribution rights, App Privacy answers and
  reviewer contact (people, not code). TestFlight is not gated by any of these.
- **Privacy manifest (P1):** `sensors_plus` (`systemUptime`) and
  `package_info_plus` (`fileModificationDate`) are statically linked into the
  Runner executable by Flutter 3.47's SwiftPM path and ship EMPTY manifests, so
  the app manifest now declares SystemBootTime `35F9.1` and FileTimestamp
  `C617.1`; the test asserts the exact list.
- **Onboarding: evaluated, deliberately NOT implemented**
  (`docs/onboarding-decision.md`). The one comprehension gap — what the passport
  is — is answered on the passport screen at zero stamps (`passportHowItWorks`,
  EN + FA). `first_launch_test.dart` fails if a first-launch gate is ever added.
- Launch screens (iOS storyboard + Android drawable) changed from white to the
  app's dark `surfaceBase` (#05070F) — the app opens dark by default.
- App Review notes no longer say the passport codes "do not exist yet";
  hosted-pages draft corrected (haptics, not text size); FIRST LAUNCH paragraph.
- Maestro: new `first-launch.yaml` and `passport.yaml`; `info`,
  `settings-persistence`, `program` fixed (post-restart tab taps by label,
  cold-boot swipe, redesigned "Filter by time" sheet).
- `pubspec.yaml` → `1.0.0+2`: Build 1 is spent on Play and on TestFlight
  (uploaded 2026-09-05). `58577e0` is the commit to archive as Build 2.

**Files changed:** `ios/Runner/PrivacyInfo.xcprivacy`,
`test/unit/ios_privacy_manifest_test.dart`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`,
`android/app/src/main/res/drawable/launch_background.xml`, `lib/l10n/app_en.arb`,
`lib/l10n/app_fa.arb`, `lib/l10n/generated/*`, `lib/screens/passport_screen.dart`,
`test/widget/first_launch_test.dart` (new), `docs/onboarding-decision.md` (new),
`lib/services/building_providers.dart`, `lib/widgets/glass_shader.dart`,
`lib/config/event_config.dart`, `lib/app/router/app_router.dart`,
`lib/widgets/app_shell.dart`, `.maestro/{first-launch,passport,info,program,settings-persistence}.yaml`,
`.maestro/README.md`, `APPLE_RELEASE_AUDIT.md` (new), `docs/release/app-review-notes.md`,
`docs/release/hosted-pages.md`, `docs/release/app-store-submission-checklist.md`,
`docs/release-blockers.md`, `ARCHITECTURE.md`, `pubspec.yaml`.

**Verification**
- `./scripts/check.sh` → CHECK PASSED, 7/7, exit 0 (three runs: before the
  upstream merge, after merging `ea63063`, and immediately before committing);
  `flutter test` 1667 passed; coverage 91.13%.
- `flutter build ios --release --no-codesign` ✓; built `Runner.app` inspected
  (Info.plist strings, no photo/mic/background/ATT keys, privacy manifests for
  the app + all 10 plugins, arm64 AOT, only `routes.googleapis.com` compiled in).
- Maestro on iPhone 17 Pro (iOS 26.5): 21/21 flows, 435 commands. iPad Pro 13
  Home verified by `simctl` screenshot, including light appearance at
  accessibility XXXL text (clamped at 2.0×, no overflow).
- Xcode-resolved Release settings after `flutter build ios --config-only`:
  `FLUTTER_BUILD_NAME=1.0.0`, `FLUTTER_BUILD_NUMBER=2`, team `94273WB4G3`.

**Follow-ups**
- Archive Build 2 from the Xcode session signed into team 94273WB4G3 (the one
  that uploaded Build 1); this audit's shell user is a different individual
  team, which is why `flutter build ipa` could not sign here — not a project defect.
- Before App Review: host Privacy Policy + Support pages and set
  `EventConfig.privacyPolicyUrl`; obtain written asset rights (B6); answer App
  Privacy with Location → App Functionality (consented Google Routes request);
  fill reviewer contact.
- Consider deleting the unreachable `WayfindingScreen` route after the event.

---

## Earlier (before this changelog existed)

See `git log` and the dated audits under `docs/` (`map-audit-2026-08-30.md`,
`home-program-audit-2026-08-30.md`, `settings-mynight-audit-2026-08-30.md`) and
`docs/release-blockers.md`'s change log for 2026-09-01 → 2026-09-04.
