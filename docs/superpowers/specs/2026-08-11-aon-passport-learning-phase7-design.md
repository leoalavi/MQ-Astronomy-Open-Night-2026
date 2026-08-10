# Astronomy Passport 2.0 — learning layer + polish (Phase 7 design)

Extends the shipped Phase 6 Astronomy Passport with a focused learning layer and
targeted interaction polish. Phase 7 pays the educational half of the Phase 6
IOU by connecting each collected stamp to one short astronomy idea related to
what the attendee just experienced at that venue.

Status: **revised after gauntlet, ready for approval before implementation
planning.** Flutter API claims (`AnimationStyle.noAnimation`,
`showModalBottomSheet(sheetAnimationStyle:)`, `AonAnimations.easeOutCubic`,
`AonHaptics.light`) verified against the installed Flutter 3.44.7 SDK before
adoption.

Scope posture: **local-only**. Signed check-ins, Ed25519 verification, Supabase,
accounts, backend sync, new runtime permissions, new dependencies, and new
bundled media remain out of scope.

---

## 1. Intent

The passport should become more than a checklist. A successful stamp should
answer a tiny question:

> "What did I just experience, and what astronomy idea sits behind it?"

Phase 7 adds exactly **one short learning moment per station**. It is revealed
when the stamp is collected, remains available from the passport afterwards, and
**never blocks** the core Phase 6 stamp trail if learning content is unavailable.

Deliberately small: one venue · one activity connection · one astronomy idea ·
one short reveal · one reviewable source trail. No quiz, points, branching
narrative, social sharing, or online content system.

---

## 2. Non-negotiable inherited contracts

Phase 7 inherits all Phase 1–6 production contracts:

- No backend, account, or secret.
- Phase 6 remains the source of truth for stamp collection and completion. The
  learning layer never changes whether a stamp is valid.
- Text scale 2.0 is a permanent app-wide contract.
- Reduced motion is respected through `MediaQuery.disableAnimationsOf`.
- No sixth navigation tab.
- No new runtime permission.
- No new package dependency.
- No new bundled image/audio/video asset.
- Dense educational content is **content-tier UI**, not decorative shader glass.
- The Phase 6 human-gate posture is unchanged. Facts are educational content,
  not part of reward verification.

---

## 3. Scope

**In**
- One activity-linked astronomy fact for each of the 9 passport stations.
- Reveal after a successful collection for stamps 1–8.
- Revisit a learned fact by tapping a collected passport cell.
- Small collect feedback: exactly one light haptic on a real new stamp; one
  restrained stamp-success animation.
- Near-complete and empty-state progress copy.
- Reduced-motion-safe reveal behavior.
- Fact-review metadata and release-safe publication behavior.
- Permanent text-scale, semantics, and motion regression tests.

**Out**
- Date-specific observing targets / "find this object tonight" prompts.
- Ephemeris calculations.
- Multiple facts per venue.
- Quiz or trivia scoring.
- Share cards.
- Images, diagrams, audio, or video.
- Narrative/quest wrapper.
- Backend review workflow.
- New dependencies or permissions.

---

## 4. Decisions

| # | Decision | Frozen choice |
|---|---|---|
| D1 | Extension | Learning layer + targeted polish |
| D2 | Reveal timing | Reveal on collect for stamps 1–8; revisit anytime |
| D3 | Ninth stamp | Reward wins; do not stack fact sheet + reward |
| D4 | Content shape | One short activity-linked idea per venue |
| D5 | Accuracy posture | Draft locally, astronomer/organiser review before public publication |
| D6 | Reveal surface | Modal bottom sheet with scrollable solid content |
| D7 | Haptic | Existing light haptic, exactly once on `StampCollected` |
| D8 | Collect animation | Small 300 ms stamp pop for stamps 1–8 only |
| D9 | Reduced motion | No scale/translate and no sheet-route animation; content appears instantly |
| D10 | Publication safety | Placeholder draft text is never presented as public settled fact |
| D11 | Source model | Reviewer source reference is structured data, not loose prose |
| D12 | Disabled passport copy | Phase 7 fixes the "scan to start" mismatch when collection is disabled |

---

## 5. Content model

Facts are **separate** from `StampStationsData`. Sign codes and educational
content have different owners, change cycles, and release risks. A code change
must never rewrite a fact, and a fact-review change must never alter stamp
validity.

```dart
// lib/models/passport_fact.dart
class PassportFact {
  const PassportFact({
    required this.venueId,
    required this.activityLabel,
    required this.title,
    required this.fact,
    this.confidence = DataConfidence.placeholder,
    this.sourceRef,
  });
  final String venueId;
  final String activityLabel;
  final String title;
  final String fact;
  final DataConfidence confidence;

  /// Stable reviewer reference, e.g. `MQ-AON-2026-LGS`.
  /// Not required to be rendered to attendees.
  final String? sourceRef;
}
```

```dart
// lib/data/passport_facts_data.dart
abstract final class PassportFactsData {
  static const List<PassportFact> all = [/* exactly 9 */];
  static PassportFact? byVenueId(String venueId);
  static Set<String> get venueIds => all.map((fact) => fact.venueId).toSet();
}
```

### 5.1 Reviewer source registry

Keep source details outside the runtime model in `docs/passport-fact-sources.md`.
Each `sourceRef` maps to: source title · publisher/owner · page or publication ·
what claim it supports · review note · date checked. This avoids turning the app
model into a citation database while preserving traceability.

### 5.2 Integrity invariants

Permanent tests must prove:

```
PassportFactsData.venueIds == StampStationsData.stationVenueIds
                           == VenuesData.eventVenues ids
```

and: exactly 9 facts; unique venue IDs; non-empty `activityLabel`; non-empty
`title`; non-empty draft `fact`; every `derived` fact has a non-null `sourceRef`;
every `sourceRef` used by runtime data exists in the review-source registry.

A new event venue therefore cannot silently appear without a deliberate Passport
2.0 content decision.

---

## 6. Publication and confidence policy

### 6.1 Draft state
During development all nine drafts may remain `DataConfidence.placeholder`. This
is honest internal state, but Phase 7 does **not** use a confidence note as
permission to publish unreviewed factual copy to attendees.

### 6.2 Public presentation rule
A fact is publicly publishable only when its confidence is **reliable** under the
existing `DataConfidence` model:

```
placeholder        → draft exists for review
                   → release UI does NOT present draft as astronomy fact
confirmed / derived → fact body may be shown publicly
```

### 6.3 Release fallback
If a collected venue still has a `placeholder` fact in a release build, the fact
sheet remains safe and useful:

> **Astronomy fact awaiting review**
> We're confirming the learning note for this activity with the astronomy team.
> Your stamp is safely collected and you can come back later.

The unreviewed draft sentence is **not shown in release**. Debug/profile builds
may show the draft plus the existing `ConfidenceNote` to support review and
demonstrations.

### 6.4 Why this is per-fact, not all-or-nothing
A single late review should not disable eight already-approved learning moments.
Publication is evaluated **per fact**. The Phase 7 closeout report must still
state exactly how many of the 9 facts are confirmed, derived, or placeholder.

---

## 7. Draft fact set for astronomy-team review

Drafts until reviewed. Wording favors evergreen concepts over brittle
event-night numbers.

| Venue / 2026 activity | Draft learning moment | Intended confidence after review | Source direction |
|---|---|---|---|
| Central Courtyard: Laser Guide Star | **Why make an artificial star?** Earth's shifting atmosphere bends incoming starlight and blurs telescope images. Adaptive optics measures that distortion and changes optical surfaces in real time; laser guide stars provide bright reference points when the sky does not offer a suitable natural one nearby. | derived | MQ AON 2026 + AAO/MAVIS |
| Astronomical Observatory / Telescope Park | **A telescope is also a time machine.** Light takes time to travel, so a star 1,000 light-years away is seen as it was 1,000 years ago. Looking farther into space also means looking farther into the past. | confirmed | astronomy-team review |
| Sport and Aquatic Centre: Planetarium | **A sky indoors.** A planetarium can simulate the night sky and guide an audience through planets, constellations, star clusters and nebulae even when weather hides the real sky outside. | derived | MQ AON 2026 |
| 17 Wally's Walk: Astrophotography | **Pictures can become measurements.** Astronomical images are not only beautiful: measurements made from images can be used to investigate things such as lunar features, planetary motion and Earth's rotation. | derived | MQ 2026 Astrophotography presentation |
| Mason Theatre: Chemistry Magic / Destination Moon | **Stars carry chemical fingerprints.** Spectroscopy separates light by wavelength; characteristic patterns in a spectrum let astronomers identify atoms and molecules without physically sampling the star. | confirmed | astronomy-team review |
| Macquarie Theatre: Physics Magic Show | **Gravity can bend light.** A massive foreground object can deflect light from something farther away, producing gravitational-lensing magnification and distortion. | confirmed | astronomy-team review |
| 1 Central Courtyard: Kids' Space / space activities | **Orbit is continuous free fall.** An orbiting spacecraft moves sideways fast enough that Earth's curved surface keeps falling away beneath it while gravity continually pulls it downward. | confirmed | astronomy-team review |
| 11 Wally's Walk: Laser Challenge | **Why does a laser form such a tight beam?** Laser light occupies a narrow range of wavelengths and has strong coherence, allowing it to remain highly directional compared with ordinary light sources. | confirmed | astronomy-team review |
| 14 Sir Christopher Ondaatje Avenue: Exhibition Hall | **Modern astronomy is also engineering.** Optics, detectors, electronics and software are what turn faint incoming light into measurements scientists can actually use. | derived | AAO-Macquarie + astronomy-team review |

### 7.1 Reviewer notes
The astronomy team should explicitly check: whether the Central Courtyard wording
matches the 2026 Laser Guide Star demonstration; whether "1,000 light-years" is
the preferred simple example for Telescope Park; the spectroscopy wording for the
Mason Theatre activity mix; the coherence wording for the Laser Challenge;
whether the 14 SCO Avenue fact is sufficiently tied to the Exhibition Hall rather
than a separate engineering presentation.

### 7.2 Numerical claims
The AAO-Macquarie MAVIS material currently supports figures such as 6–8 laser
guide stars and about 15 milli-arcsecond imaging performance, but those figures
are **reviewer metadata** in Phase 7, **not attendee copy**. This keeps the
learning moment short and reduces dependence on instrument-design numbers that
may be revised.

---

## 8. Fact reveal surface

Create one reusable surface `PassportFactSheet` and one presentation helper:

```dart
showPassportFactSheet(
  context,
  venueId,
  reason: FactRevealReason.collected | FactRevealReason.revisit,
)
```

### 8.1 Content hierarchy
Venue/activity context · short fact title · fact body **or** release-safe
"awaiting review" fallback · confidence/review note when appropriate · dismiss
affordance.

### 8.2 Visual governance
This is dense educational text. Use the existing **solid/content-tier** sheet
treatment. Do **not** introduce shader glass behind the fact body.

### 8.3 Layout
`showModalBottomSheet<void>` with `isScrollControlled: true`, `useSafeArea:
true`, a scrollable body, content-driven height, no fixed fact-body height. A
direct widget test **plus** a real modal integration test must both cover
320×568 / `TextScaler` 2.0.

---

## 9. Reduced motion for the fact sheet

When `MediaQuery.disableAnimationsOf(context) == true`, the helper uses
`sheetAnimationStyle: AnimationStyle.noAnimation` and the fact content appears in
its final state immediately.

With motion enabled: standard bottom-sheet route animation is retained; the fact
content may use a short opacity reveal; no additional translation/parallax. The
learning content does not need movement to communicate meaning. No `Duration.zero`
helper is introduced.

---

## 10. Accessibility semantics

Do **not** merge the entire fact sheet into one giant semantics node. Preferred
structure: venue/activity heading (header semantics) · fact title (separate
meaningful text) · fact body (readable text node) · confidence/review note
(separate text node) · dismiss control (button semantics). This gives
screen-reader users useful navigation rather than one long announcement.

### 10.1 Passport grid semantics after Phase 7
Collected cells become interactive. A collected cell exposes: `<venue name>,
stamp collected`, `button` role, hint `Opens astronomy fact`. An uncollected cell
remains non-interactive and must **not** announce a button role. Tests assert
both states.

---

## 11. Collect and revisit flow

### 11.1 Stamps 1–8
On `StampCollected(venueId)` with `justCompleted == false`, the capture
presentation layer: records the successful Phase 6 result; fires exactly one
existing light haptic; opens the venue fact sheet with `reason: collected`; the
sheet presents the small stamp-success visual; after dismissal the Phase 6
capture flow owns scanner/manual re-arm. **The learning layer must never take
ownership of scanner lifecycle.**

### 11.2 Ninth stamp
On `StampCollected` with `justCompleted == true`: fire the collect haptic once;
do **not** open a fact sheet; do **not** run the small per-stamp pop; navigate to
the existing completion reward. The reward is the visual payoff. The ninth fact
remains accessible later from the collected grid cell.

### 11.3 Duplicate / unknown / disabled
For `StampAlreadyHave`, `StampUnknown`, or disabled collection: no collect
haptic, no stamp pop, no fact sheet. Existing Phase 6 feedback remains
authoritative.

### 11.4 Revisit
Collected passport cell tap → fact lookup → fact sheet (`reason: revisit`). No
haptic and no collect animation. Uncollected passport cell tap → nothing.

### 11.5 Missing fact
`PassportFactsData.byVenueId` remains nullable defensively. If lookup returns
null: no crash, no empty modal, no invented copy, normal Phase 6 stamp state
intact. A test covers this failure path.

---

## 12. Collect visual feedback

### 12.1 Location
The small "stamp" visual lives inside the **fact-sheet header** when
`reason == collected`. This is an upgrade from animating the capture screen
immediately before covering that animation with a modal.

### 12.2 Motion-enabled behavior
Use existing design tokens only: `duration: AonAnimations.slow` (300 ms); `curve:
AonAnimations.easeOutCubic`; scale settles into the final stamp icon; a subtle
opacity reveal may accompany it. No new animation token is added for one feature.

### 12.3 Reduced motion
When reduced motion is enabled: no scale animation, no sheet-route animation, no
content fade; final stamp state appears instantly; haptic remains governed
separately by the existing haptics-enabled behavior.

---

## 13. Haptic ownership

Phase 7 must not create a second haptic system. Reuse the existing
`AonHaptics.light` path and its current enabled flag. Exactly **one** haptic
occurs for a real `StampCollected`. No haptic for: duplicate, unknown, disabled
collection, fact revisit, or fact-sheet dismissal. The haptic assertion is
platform-channel/test-seam evidence, not a visual check.

---

## 14. Passport progress copy

Phase 7 changes the progress line, so it also fixes the existing disabled-state
copy mismatch instead of carrying it forward. Priority order:

- collection disabled → "Astronomy Passport opens on event night"
- `count == 0` → "Scan or enter a venue code to start"
- `count 1–7` → "N / 9 stamps"
- `count == 8` → "Just 1 more to go!"
- `count == 9` → existing completed state + "View your reward"

This avoids inviting the user to perform an action the release gate currently
refuses. All copy must remain valid at text scale 2.0 without ellipsis of
critical information.

---

## 15. Testing plan

### 15.1 Content integrity
Permanent unit tests: exactly 9 facts; fact venue IDs == station venue IDs ==
event-venue IDs; unique fact venue IDs; non-empty titles/activity labels/fact
drafts; every `derived` fact has `sourceRef`; every referenced source exists in
the reviewer source registry.

### 15.2 Publication policy
Test **separately from widget rendering** (pure function):
- placeholder + public mode → unreviewed draft body not publishable
- confirmed / derived + public mode → publishable
- placeholder + review/debug mode → draft available with review warning

Avoid burying build-mode behavior inside an untestable widget branch.

### 15.3 Fact sheet
reliable fact renders title + body; placeholder in public mode hides draft and
shows awaiting-review fallback; placeholder in review mode shows draft +
`ConfidenceNote`; confirmed/derived does not show placeholder note; source
metadata not accidentally required for attendee rendering; no overflow at
320×568 / 2.0; long content genuinely scrollable; reduced motion uses no
route/content animation; semantics expose heading, body, note and dismiss control
coherently.

### 15.4 Reveal flow
stamps 1–8 open the correct venue fact; the 9th goes to reward and does not open a
fact sheet; duplicate does not reveal; unknown does not reveal; disabled
collection does not reveal; missing fact no-ops safely.

### 15.5 Revisit
collected cell is a button and opens its venue fact; uncollected cell has no
button role and does nothing; revisit performs no collect haptic or stamp
animation.

### 15.6 Collect feedback
one real collect invokes light haptic exactly once; duplicate/unknown/disabled
invoke zero collect haptics; motion enabled: stamp animation exists for stamps
1–8; reduced motion: no scale/translate animation; ninth stamp: no small stamp
animation.

### 15.7 Progress copy
Boundary tests: disabled, 0, 1, 7, 8, 9.

### 15.8 Phase 5 regression inheritance
At minimum, 320×568 / 2.0 for: PassportScreen; PassportGrid with collected
interactive cells; fact sheet in a real modal; near-complete copy; release-safe
placeholder fallback. **No existing Phase 1–6 regression may be weakened to make
Phase 7 pass.**

---

## 16. Verification gate

Complete only when all recorded.

**Static/automated:** `flutter analyze` + `flutter test`, both green.

**Platform builds** (record PASS / FAIL / NOT AVAILABLE): `flutter build ios
--simulator --debug`; `flutter build apk --debug`; `flutter build web`.

**Runtime iOS pass:** collect a non-final stamp → exactly one collect haptic →
fact sheet opens for the correct venue → stamp visual is restrained → close sheet
and continue the existing capture flow → revisit the fact from the grid → collect
the ninth stamp → reward opens instead of fact sheet → enable Reduce Motion →
repeat a collect/reveal with no sheet-route or stamp movement → inspect long fact
text at effective scale 2.0.

**Content closeout:** record confirmed N/9, derived N/9, placeholder N/9; source
registry complete PASS/FAIL. A public release should aim for all nine reviewed;
if any remain placeholder, the release-safe fallback must be visually verified.

**Final re-gate:** after any runtime/content fix — `flutter analyze`, `flutter
test`, `git diff --check`, `git status --short` — then a hostile read of the
final diff before finishing the branch.

---

## 17. Scorecard

| Axis | Current | Target at closeout | Evidence |
|---|---:|---:|---|
| Educational value | 6 | 9 | 9 activity-linked reviewed facts + reveal/revisit flow |
| Activity relatedness | 7 | 9 | 2026 venue/activity alignment + reviewer sign-off |
| Content honesty | 8 | 10 | per-fact release publication gate + confidence/source trail |
| Accessibility / 2.0 | 8 | 10 | modal + grid + copy regression, structured semantics |
| Reduced-motion fidelity | 7 | 10 | no added route/scale movement when preference is enabled |
| Footprint discipline | 9 | 10 | zero new deps/assets/permissions/backend |
| Testability | 7 | 9 | pure publication policy + deterministic reveal/haptic tests |
| Ambition | 4 | 5 | intentionally small learning layer, not inflated |

---

## 18. IOU ledger

- **IOU-A: event-night observing targets.** A future layer can add "look up and
  find X tonight" prompts for the actual September 2026 Sydney sky — requires a
  verified event-date ephemeris, deliberately separate from evergreen facts.
- **IOU-B: narrative wrapper.** A future version may connect the nine facts into a
  small "nine corners of astronomy" story. Not required for Phase 7.
- **IOU-C: images and diagrams.** Deferred for asset weight, licensing,
  accessibility descriptions, and the repo's image-provenance discipline.

---

## 19. Organiser / astronomy-team sign-off checklist

For every fact: activity still matches the 2026 program; scientific wording
accurate; understandable to a general audience; no misleading simplification;
confidence promoted appropriately; source reference recorded where needed.

Specific review points: Central Courtyard (adaptive optics / laser guide star);
Observatory (light-travel-time example); MUSAC (planetarium); 17 Wally's Walk
(astrophotography-as-measurement); Mason Theatre (spectroscopy ↔ activity mix);
Macquarie Theatre (gravitational lensing); 1 Central Courtyard (orbit/free-fall);
11 Wally's Walk (laser coherence); 14 SCO Avenue (engineering/exhibition).

---

## 20. Source basis

Content sources checked for this revision: Macquarie University Astronomy Open
Night 2026 main event, activities, Magic Shows / Destination Moon, and Featured
Presentations pages; Australian Astronomical Optics at Macquarie — Current
Projects: MAVIS; ESO MAVIS instrument information.

Accessibility / Flutter behavior: W3C WCAG 2.2 SC 2.3.3 (Animation from
Interactions); W3C reduced-motion technique C39; Flutter
`MediaQuery.disableAnimationsOf`; Flutter `showModalBottomSheet` /
`AnimationStyle.noAnimation` (verified present in Flutter 3.44.7:
`material/bottom_sheet.dart:246`, `animation/animation_style.dart:35`).

The astronomy-team review remains authoritative for final attendee copy.

---

## 21. Next step

After approval: freeze the nine draft records and source registry → use the
writing-plans skill to create the TDD implementation plan → require a Task 0
clean-tree / baseline gate → implement content model and publication policy
before UI → implement fact sheet and reveal path → wire collected-cell revisit →
add collect haptic / stamp visual → update progress copy → complete 2.0,
reduced-motion, semantics and runtime gates → re-review the final diff before
branch completion. No production implementation begins before the plan is
reviewed.

---

## 22. Implementation verification (Phase 7 executed)

Branch `feature/passport-learning-phase7`, Flutter 3.44.7. Tasks 0–7 complete.

- **Dependencies:** none added — Flutter-native throughout (design intent §2).
- **Tests:** baseline **309 → 341** passing (+32 Phase 7); `flutter analyze` clean
  throughout; no Phase 1–6 regression (the Phase 6 grid test stayed green
  unchanged — the P1-5 "contradiction" was verified a non-issue).
- **Builds:** `flutter build web` ✅, `flutter build apk --debug` ✅,
  `flutter build ios --simulator --debug` ✅.
- **iOS runtime (simulator, iPhone 17 Pro):** collect a stamp (manual) → fact
  sheet opens for that venue showing **venue name + activity + a stamp pop in
  the sheet header** ✅; revisit by tapping a collected cell ✅; placeholder draft
  + review note shown in the debug build ✅. (9th→reward, reduced-motion, and
  forced-scroll are proven by the automated suite: reward-routing test,
  reduced-motion no-`TweenAnimationBuilder` test, real-modal `maxScrollExtent>0`
  drag test.)

### Two-gate status (design §16)

- **CODE COMPLETE: YES.** All functionality, tests and builds green; the
  release-safe fallback and per-fact publication gate are verified.
- **RELEASE READY: NO.** Content closeout is **0 confirmed / 0 derived / 9
  placeholder** — every attendee currently sees the "awaiting review" fallback.
  `sourceRegistry` documented in docs/passport-fact-sources.md: PASS. The
  learning layer is not shippable-to-attendees until the astronomy team reviews
  the 9 drafts (promoting each to `confirmed`/`derived`); until then it is an
  honest, working machine awaiting its content.
