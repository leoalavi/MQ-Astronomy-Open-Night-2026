# Astronomy Passport 2.0 (Phase 7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a learning layer to the shipped passport — one activity-linked astronomy fact per venue, revealed in a bottom sheet on collect (stamps 1–8) and re-openable by tapping a collected cell — plus restrained collect polish (one haptic, a small stamp pop) and corrected progress copy, with a per-fact publication gate that never shows unreviewed draft copy as fact in release.

**Architecture:** A content table (`PassportFactsData`) separate from the sign codes; a **pure** publication policy (`resolveFactPresentation`) that decides body-vs-fallback-vs-draft-note by confidence + build mode; one reveal surface (`PassportFactSheet`) shown by one helper (`showPassportFactSheet`) from both the capture screen (on collect) and the grid (on revisit). The learning layer never owns stamp validity or scanner lifecycle — Phase 6 remains the source of truth.

**Tech Stack:** Flutter `3.44.7`, Riverpod 3, go_router. **Zero new dependencies, assets, or permissions.** Reuses `showModalBottomSheet(sheetAnimationStyle:)`, `AnimationStyle.noAnimation`, `AonAnimations`, `AonHaptics`, `ConfidenceNote`, `DataConfidence`.

## Global Constraints

- **Local-only; no new deps/assets/permissions/backend** (spec §2).
- **Phase 6 owns stamp validity + scanner lifecycle.** The learning layer never changes whether a stamp is valid and never re-arms the scanner (spec §2, §11.1).
- **Per-fact publication gate** (spec §6): a `placeholder` fact is **never** shown as fact in a release build — it shows the release-safe fallback. `confirmed`/`derived` show the body. Debug/profile show the draft + `ConfidenceNote`.
- **Facts ship `DataConfidence.placeholder`** (drafts); promotion to `confirmed`/`derived` is a post-review data edit (spec §6.1, §7).
- **Numbers are reviewer metadata, not attendee copy** (spec §7.2) — no instrument figures in fact bodies.
- **Ninth stamp:** reward wins; no fact sheet, no per-stamp pop; haptic still fires once (spec §11.2).
- **Exactly one `AonHaptics.light` per real `StampCollected`**; none on duplicate/unknown/disabled/revisit/dismiss (spec §13).
- **Reduced motion** (`MediaQuery.disableAnimationsOf`): no scale/translate, and the sheet uses `AnimationStyle.noAnimation`; content appears instantly (spec §9, §12.3).
- **Text scale 2.0** on every new/changed surface (fact sheet, grid, progress copy, fallback) — the permanent Phase 5 contract.
- **Grid semantics** (spec §10.1): collected cell = button + hint "Opens astronomy fact"; uncollected = no button role.
- **Lint** (`analysis_options.yaml`): single quotes, `prefer_const_constructors`, `always_declare_return_types`, `unawaited_futures` (`unawaited(...)`).
- **Per-task gate:** `flutter analyze && flutter test` — clean + green. Never weaken a Phase 1–6 test.

---

## File Structure

**Create:** `lib/models/passport_fact.dart`, `lib/data/passport_facts_data.dart`, `lib/services/passport_fact_publication.dart`, `lib/widgets/passport_fact_sheet.dart` (sheet + `showPassportFactSheet` helper + `FactRevealReason`), `docs/passport-fact-sources.md`, and mirrored tests.

**Modify:** `lib/widgets/passport_grid.dart` (collected cells tappable + button semantics), `lib/screens/passport_screen.dart` (revisit wiring + progress copy), `lib/screens/passport_scan_screen.dart` (haptic + reveal-on-collect), `test/unit/data_integrity_test.dart` (fact coverage).

**Task order:** 0 preflight → 1 model+data+registry+integrity → 2 publication policy (pure) → 3 fact sheet + helper + collect pop → 4 reveal-on-collect wiring (haptic) → 5 grid revisit + semantics → 6 progress copy → 7 verification gate. The sheet (3) exists before the wiring (4) and grid (5) reference it — no dead intermediates.

---

## Task 0: Preflight & baseline

**Files:** none.

- [ ] **Step 1: Ensure the feature branch + clean tree** — Run:
```bash
git status --short          # expect empty (stop if dirty)
git rev-parse HEAD          # record base SHA
# create-or-switch (idempotent): the branch already exists from the spec commit
git checkout feature/passport-learning-phase7 2>/dev/null \
  || git checkout -b feature/passport-learning-phase7
git branch --show-current   # must print feature/passport-learning-phase7
```
Do not proceed on `main` or a dirty tree.

- [ ] **Step 2: Baseline analyze + tests** — Run: `flutter analyze && flutter test` — Expected: clean; **record the passing count** (Task 7 asserts the suite only grew).

- [ ] **Step 3: Baseline builds** — Run: `flutter build web && flutter build apk --debug && flutter build ios --simulator --debug` — Expected: all succeed (no new deps this phase; the iOS-simulator build is part of the final platform gate, so baseline it now to isolate any later breakage).

- [ ] **Step 4: No commit.**

---

## Task 1: Fact model + data + source registry + integrity

**Files:** Create `lib/models/passport_fact.dart`, `lib/data/passport_facts_data.dart`, `docs/passport-fact-sources.md`; Modify `test/unit/data_integrity_test.dart`.

**Interfaces:**
- Produces: `PassportFact({required String venueId, required String activityLabel, required String title, required String fact, DataConfidence confidence, String? sourceRef})`.
- `PassportFactsData.all` (`List<PassportFact>`, 9), `.byVenueId(String)` (`PassportFact?`), `.venueIds` (`Set<String>`), `.sourceRegistry` (`Set<String>` of valid `sourceRef`s).

- [ ] **Step 1: Write the failing test** — add to `test/unit/data_integrity_test.dart` (imports at top, group inside `main()`):

```dart
// Top-of-file imports:
import 'dart:io';
import 'package:aon2026/data/passport_facts_data.dart';
```

```dart
// Inside main():
group('passport facts', () {
  const facts = PassportFactsData.all;

  test('exactly 9 facts, unique venueIds', () {
    expect(facts.length, 9);
    expect(facts.map((f) => f.venueId).toSet().length, 9);
  });

  test('fact venueIds == station venueIds == event-venue ids', () {
    final eventVenueIds = VenuesData.eventVenues.map((v) => v.id).toSet();
    expect(PassportFactsData.venueIds, StampStationsData.stationVenueIds);
    expect(PassportFactsData.venueIds, eventVenueIds);
  });

  test('titles, activity labels and fact bodies are non-empty', () {
    for (final f in facts) {
      expect(f.title.trim(), isNotEmpty, reason: f.venueId);
      expect(f.activityLabel.trim(), isNotEmpty, reason: f.venueId);
      expect(f.fact.trim(), isNotEmpty, reason: f.venueId);
    }
  });

  test('every sourceRef used is registered; every derived fact has one', () {
    for (final f in facts) {
      if (f.sourceRef != null) {
        expect(PassportFactsData.sourceRegistry, contains(f.sourceRef),
            reason: '${f.venueId} uses unregistered sourceRef ${f.sourceRef}');
      }
      if (f.confidence == DataConfidence.derived) {
        expect(f.sourceRef, isNotNull, reason: '${f.venueId} derived w/o source');
      }
    }
  });

  test('the Markdown registry documents every registered source (C1)', () {
    // Gives "sourceRegistry complete" teeth: the human doc must actually
    // contain a row for each machine-checked ref. Requires `import 'dart:io';`.
    final md = File('docs/passport-fact-sources.md').readAsStringSync();
    for (final ref in PassportFactsData.sourceRegistry) {
      expect(md, contains(ref),
          reason: '$ref not documented in docs/passport-fact-sources.md');
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails** — Run: `flutter test test/unit/data_integrity_test.dart` — Expected: FAIL (`PassportFactsData` undefined).

- [ ] **Step 3: Implement** — `lib/models/passport_fact.dart`:

```dart
import 'package:aon2026/models/data_confidence.dart';

/// One activity-linked astronomy learning moment for a passport station.
///
/// Separate from `StampStationsData`: sign codes and educational content have
/// different owners and review cycles (design §5). Facts ship as `placeholder`
/// drafts and are promoted to `confirmed`/`derived` only after astronomy-team
/// sign-off (design §6/§7); the release publication gate (design §6) decides
/// what is shown to attendees.
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

  /// Stable reviewer reference (e.g. `MQ-AON-2026-LGS`); not rendered to
  /// attendees. Maps to a row in docs/passport-fact-sources.md.
  final String? sourceRef;
}
```

`lib/data/passport_facts_data.dart` (all ship `placeholder`; the `// target:` comment records the post-review tier from design §7):

```dart
import 'package:aon2026/models/passport_fact.dart';

/// The 9 passport learning moments — one per event venue.
///
/// DRAFTS: every fact ships `DataConfidence.placeholder` and is gated by the
/// publication policy (design §6) until the astronomy team signs off. The
/// `target` comments record the intended tier after review (design §7).
abstract final class PassportFactsData {
  static const List<PassportFact> all = [
    PassportFact(
      venueId: 'central-courtyard',
      activityLabel: 'Laser Guide Star',
      title: 'Why make an artificial star?',
      fact: 'Earth’s shifting atmosphere bends incoming starlight and '
          'blurs telescope images. Adaptive optics measures that distortion '
          'and changes optical surfaces in real time; laser guide stars '
          'provide bright reference points when the sky does not offer a '
          'suitable natural one nearby.',
      sourceRef: 'MQ-AON-2026-LGS', // target: derived
    ),
    PassportFact(
      venueId: 'astronomical-observatory',
      activityLabel: 'Telescope Park',
      title: 'A telescope is also a time machine',
      fact: 'Light takes time to travel, so a star 1,000 light-years away is '
          'seen as it was 1,000 years ago. Looking farther into space also '
          'means looking farther into the past.',
      // target: confirmed
    ),
    PassportFact(
      venueId: 'sport-and-aquatic-centre',
      activityLabel: 'Planetarium',
      title: 'A sky indoors',
      fact: 'A planetarium can simulate the night sky and guide an audience '
          'through planets, constellations, star clusters and nebulae even '
          'when weather hides the real sky outside.',
      sourceRef: 'MQ-AON-2026-PLANETARIUM', // target: derived
    ),
    PassportFact(
      venueId: '17-wallys-walk',
      activityLabel: 'Astrophotography',
      title: 'Pictures can become measurements',
      fact: 'Astronomical images are not only beautiful: measurements made '
          'from images can be used to investigate things such as lunar '
          'features, planetary motion and Earth’s rotation.',
      sourceRef: 'MQ-AON-2026-ASTROPHOTO', // target: derived
    ),
    PassportFact(
      venueId: 'mason-theatre',
      activityLabel: 'Chemistry Magic / Destination Moon',
      title: 'Stars carry chemical fingerprints',
      fact: 'Spectroscopy separates light by wavelength; characteristic '
          'patterns in a spectrum let astronomers identify atoms and '
          'molecules without physically sampling the star.',
      // target: confirmed
    ),
    PassportFact(
      venueId: 'macquarie-theatre',
      activityLabel: 'Physics Magic Show',
      title: 'Gravity can bend light',
      fact: 'A massive foreground object can deflect light from something '
          'farther away, producing gravitational-lensing magnification and '
          'distortion.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '1-central-courtyard',
      activityLabel: 'Kids’ Space',
      title: 'Orbit is continuous free fall',
      fact: 'An orbiting spacecraft moves sideways fast enough that Earth’s '
          'curved surface keeps falling away beneath it while gravity '
          'continually pulls it downward.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '11-wallys-walk',
      activityLabel: 'Laser Challenge',
      title: 'Why does a laser form such a tight beam?',
      fact: 'Laser light occupies a narrow range of wavelengths and has strong '
          'coherence, allowing it to remain highly directional compared with '
          'ordinary light sources.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '14-sir-christopher-ondaatje-avenue',
      activityLabel: 'Exhibition Hall',
      title: 'Modern astronomy is also engineering',
      fact: 'Optics, detectors, electronics and software are what turn faint '
          'incoming light into measurements scientists can actually use.',
      sourceRef: 'AAO-MQ-INSTRUMENTATION', // target: derived
    ),
  ];

  /// Reviewer source references considered valid (design §5.1). The human
  /// registry lives in docs/passport-fact-sources.md; this set is the
  /// machine-checkable half so a test needn't parse Markdown.
  static const Set<String> sourceRegistry = {
    'MQ-AON-2026-LGS',
    'MQ-AON-2026-PLANETARIUM',
    'MQ-AON-2026-ASTROPHOTO',
    'AAO-MQ-INSTRUMENTATION',
  };

  static Set<String> get venueIds => all.map((f) => f.venueId).toSet();

  static PassportFact? byVenueId(String venueId) {
    for (final f in all) {
      if (f.venueId == venueId) return f;
    }
    return null;
  }
}
```

Create `docs/passport-fact-sources.md` with a row per `sourceRef` (title · owner · claim supported · review note · date checked). Minimum viable content:

```markdown
# Passport fact sources (Phase 7)

Reviewer registry for `PassportFact.sourceRef`. Codes here MUST match
`PassportFactsData.sourceRegistry`. Astronomy-team review is authoritative for
final attendee copy; facts stay `placeholder` until promoted.

| sourceRef | Source | Owner | Supports | Review note | Checked |
|---|---|---|---|---|---|
| MQ-AON-2026-LGS | AON 2026 activities + AAO/MAVIS | Macquarie University | Laser guide star / adaptive optics wording | Confirm matches 2026 demo | 2026-08-11 |
| MQ-AON-2026-PLANETARIUM | AON 2026 activities | Macquarie University | Planetarium simulation wording | — | 2026-08-11 |
| MQ-AON-2026-ASTROPHOTO | AON 2026 astrophotography presentation | Macquarie University | Images-as-measurements wording | — | 2026-08-11 |
| AAO-MQ-INSTRUMENTATION | Australian Astronomical Optics — Macquarie | Macquarie University | Optics/detectors/software framing | — | 2026-08-11 |
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/unit/data_integrity_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/models/passport_fact.dart lib/data/passport_facts_data.dart docs/passport-fact-sources.md test/unit/data_integrity_test.dart
git commit -m "feat(passport): fact model + 9 drafts + source registry + integrity (Phase 7)"
```

---

## Task 2: Publication policy (pure)

**Files:** Create `lib/services/passport_fact_publication.dart`, `test/unit/passport_fact_publication_test.dart`.

**Interfaces:**
- `enum FactBody { body, fallback }`
- `FactPresentation({required FactBody body, required bool showDraftNote})`
- `FactPresentation resolveFactPresentation(PassportFact fact, {required bool isRelease})`
- `const factFallbackTitle`, `const factFallbackMessage` (the §6.3 copy).

- [ ] **Step 1: Write the failing test** — `test/unit/passport_fact_publication_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/services/passport_fact_publication.dart';

PassportFact _fact(DataConfidence c) => PassportFact(
      venueId: 'v', activityLabel: 'a', title: 't', fact: 'f', confidence: c);

void main() {
  test('confirmed/derived show the body, no draft note (any build)', () {
    for (final c in [DataConfidence.confirmed, DataConfidence.derived]) {
      for (final release in [true, false]) {
        final p = resolveFactPresentation(_fact(c), isRelease: release);
        expect(p.body, FactBody.body);
        expect(p.showDraftNote, isFalse);
      }
    }
  });

  test('placeholder in RELEASE shows the fallback, never the draft', () {
    final p = resolveFactPresentation(
        _fact(DataConfidence.placeholder), isRelease: true);
    expect(p.body, FactBody.fallback);
    expect(p.showDraftNote, isFalse);
  });

  test('placeholder in DEBUG shows the draft body + the review note', () {
    final p = resolveFactPresentation(
        _fact(DataConfidence.placeholder), isRelease: false);
    expect(p.body, FactBody.body);
    expect(p.showDraftNote, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (undefined).

- [ ] **Step 3: Implement** — `lib/services/passport_fact_publication.dart`:

```dart
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/passport_fact.dart';

/// Release-safe fallback copy shown when a fact is still an unreviewed draft
/// in a public build (design §6.3).
const String factFallbackTitle = 'Astronomy fact awaiting review';
const String factFallbackMessage =
    'We’re confirming the learning note for this activity with the '
    'astronomy team. Your stamp is safely collected and you can come back '
    'later.';

enum FactBody { body, fallback }

/// What the fact sheet should present, decided purely from confidence + build
/// mode (design §6). Kept out of the widget so it is unit-testable.
class FactPresentation {
  const FactPresentation({required this.body, required this.showDraftNote});
  final FactBody body;
  final bool showDraftNote;
}

FactPresentation resolveFactPresentation(
  PassportFact fact, {
  required bool isRelease,
}) {
  // confirmed/derived: publishable body, no note.
  if (fact.confidence.isReliable) {
    return const FactPresentation(body: FactBody.body, showDraftNote: false);
  }
  // placeholder: release hides the draft (safe fallback); debug shows it + note.
  return isRelease
      ? const FactPresentation(body: FactBody.fallback, showDraftNote: false)
      : const FactPresentation(body: FactBody.body, showDraftNote: true);
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/unit/passport_fact_publication_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/services/passport_fact_publication.dart test/unit/passport_fact_publication_test.dart
git commit -m "feat(passport): pure per-fact publication policy (Phase 7)"
```

---

## Task 3: Fact sheet + helper + collect stamp pop

**Files:** Create `lib/widgets/passport_fact_sheet.dart`, `test/widget/passport_fact_sheet_test.dart`.

**Interfaces:**
- `enum FactRevealReason { collected, revisit }`
- `PassportFactSheet({required PassportFact fact, required FactRevealReason reason, bool isRelease})` — a `StatelessWidget`. Uses `resolveFactPresentation`; renders title/body-or-fallback, `ConfidenceNote` when `showDraftNote`, a stamp pop when `reason == collected`, and a dismiss control; structured semantics (§10).
- `Future<void> showPassportFactSheet(BuildContext context, String venueId, {required FactRevealReason reason})` — looks up the fact; **no-ops if null**; shows the modal with `AnimationStyle.noAnimation` under reduced motion.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_fact_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';

PassportFact _fact(DataConfidence c) => PassportFact(
      venueId: 'v', activityLabel: 'Telescope Park',
      title: 'A telescope is also a time machine',
      fact: 'Light takes time to travel.', confidence: c);

// No scroll view here — the sheet must scroll itself (design §8.3), so the
// 2.0 test exercises the real internal scrolling, not the host's.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('reliable fact shows title + body, no draft note', (t) async {
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.confirmed),
        reason: FactRevealReason.revisit,
        isRelease: true)));
    expect(find.text('A telescope is also a time machine'), findsOneWidget);
    expect(find.textContaining('Light takes time'), findsOneWidget);
    expect(find.byType(ConfidenceNote), findsNothing);
  });

  testWidgets('placeholder in RELEASE shows fallback, hides the draft',
      (t) async {
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.placeholder),
        reason: FactRevealReason.collected,
        isRelease: true)));
    expect(find.textContaining('awaiting review'), findsOneWidget);
    expect(find.textContaining('Light takes time'), findsNothing);
  });

  testWidgets('placeholder in DEBUG shows the draft + a ConfidenceNote',
      (t) async {
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.placeholder),
        reason: FactRevealReason.revisit,
        isRelease: false)));
    expect(find.textContaining('Light takes time'), findsOneWidget);
    expect(find.byType(ConfidenceNote), findsOneWidget);
  });

  testWidgets('direct: no overflow at 320x568 / 2.0 (self-scrolls)', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.confirmed),
        reason: FactRevealReason.collected,
        isRelease: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  // §8.3 requires a real-modal test — and it must PROVE scrolling works, not
  // just that nothing threw (C2). Uses the long Central Courtyard draft in a
  // constrained 320×568 / 2.0 modal.
  testWidgets('real modal: content is genuinely scrollable at 320x568 / 2.0',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPassportFactSheet(context,
                  'central-courtyard', reason: FactRevealReason.revisit),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(PassportFactSheet), findsOneWidget);
    expect(t.takeException(), isNull);

    // The sheet's own scroll view must actually have somewhere to scroll.
    final scrollable = find.descendant(
        of: find.byType(PassportFactSheet), matching: find.byType(Scrollable));
    final pos = t.state<ScrollableState>(scrollable.first).position;
    expect(pos.maxScrollExtent, greaterThan(0),
        reason: 'long fact at 2.0 must overflow into a real scroll');
    await t.drag(scrollable.first, const Offset(0, -120));
    await t.pumpAndSettle();
    expect(pos.pixels, greaterThan(0)); // content actually moved
  });

  // C3: the exact combined state — placeholder + release + 320×568 + 2.0 —
  // renders the fallback without overflow. None of the other tests cover all
  // four at once.
  testWidgets('release + placeholder fallback: no overflow at 320x568 / 2.0',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.placeholder),
        reason: FactRevealReason.collected,
        isRelease: true)));
    await t.pumpAndSettle();
    expect(find.textContaining('awaiting review'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shows the venue name, not just the activity', (t) async {
    await t.pumpWidget(_host(const PassportFactSheet(
        fact: PassportFact(
            venueId: 'macquarie-theatre',
            activityLabel: 'Physics Magic Show',
            title: 'Gravity can bend light',
            fact: 'A massive object deflects light.'),
        reason: FactRevealReason.revisit,
        isRelease: false)));
    expect(find.text('Macquarie Theatre'), findsOneWidget); // from VenuesData
    expect(find.text('PHYSICS MAGIC SHOW'), findsOneWidget);
  });

  testWidgets('reduced motion: collect reveal has no scale animation', (t) async {
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: PassportFactSheet(
            fact: _fact(DataConfidence.confirmed),
            reason: FactRevealReason.collected,
            isRelease: true),
      ),
    ));
    await t.pump();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget); // static
  });

  testWidgets('motion enabled: collect reveal animates the stamp', (t) async {
    await t.pumpWidget(_host(PassportFactSheet(
        fact: _fact(DataConfidence.confirmed),
        reason: FactRevealReason.collected,
        isRelease: true)));
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('structured semantics: venue is a header, Close is a button',
      (t) async {
    final handle = t.ensureSemantics();
    addTearDown(handle.dispose);
    await t.pumpWidget(_host(const PassportFactSheet(
        fact: PassportFact(
            venueId: 'macquarie-theatre', activityLabel: 'Physics Magic Show',
            title: 'Gravity can bend light', fact: 'A massive object.'),
        reason: FactRevealReason.revisit, isRelease: false)));
    final venue = t.getSemantics(find.text('Macquarie Theatre'));
    expect(venue.getSemanticsData().flagsCollection.isHeader, isTrue);
    final close = t.getSemantics(find.text('Close'));
    expect(close.getSemanticsData().flagsCollection.isButton, isTrue);
  });
}
```

Add a missing-fact test in the **helper** (design §11.5) — same file:

```dart
  testWidgets('showPassportFactSheet no-ops for an unknown venue', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPassportFactSheet(context, 'no-such-venue',
                reason: FactRevealReason.revisit),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(PassportFactSheet), findsNothing); // no modal, no crash
    expect(t.takeException(), isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (undefined).

- [ ] **Step 3: Implement** — `lib/widgets/passport_fact_sheet.dart`:

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/passport_facts_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/services/passport_fact_publication.dart';
import 'package:aon2026/widgets/confidence_note.dart';

enum FactRevealReason { collected, revisit }

/// Looks up the fact for [venueId] and reveals it in a bottom sheet. No-ops if
/// no fact exists (design §11.5). Suppresses the sheet route animation under
/// reduced motion (design §9).
Future<void> showPassportFactSheet(
  BuildContext context,
  String venueId, {
  required FactRevealReason reason,
}) {
  final fact = PassportFactsData.byVenueId(venueId);
  if (fact == null) return Future<void>.value(); // no crash, no empty modal
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    builder: (_) => PassportFactSheet(fact: fact, reason: reason),
  );
}

/// The reveal surface. Content-tier (solid), never shader glass (design §8.2).
class PassportFactSheet extends StatelessWidget {
  const PassportFactSheet({
    required this.fact,
    required this.reason,
    this.isRelease = kReleaseMode,
    super.key,
  });

  final PassportFact fact;
  final FactRevealReason reason;
  final bool isRelease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = resolveFactPresentation(fact, isRelease: isRelease);
    final showFallback = p.body == FactBody.fallback;
    final title = showFallback ? factFallbackTitle : fact.title;
    final body = showFallback ? factFallbackMessage : fact.fact;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Scrollable content, matching the app's other sheets (whats_on:312,
    // map:423) — a long fact at text scale 2.0 must scroll, not overflow.
    return SingleChildScrollView(
      child: Padding(
      padding: EdgeInsets.fromLTRB(
        AonSpacing.space5,
        AonSpacing.space5,
        AonSpacing.space5,
        AonSpacing.space5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stamp pop — only on a fresh collect, motion-aware (design §12).
          if (reason == FactRevealReason.collected)
            _StampPop(reduceMotion: reduceMotion),
          if (reason == FactRevealReason.collected)
            const SizedBox(height: AonSpacing.space3),
          // Venue + activity context (venue name is the heading, design §8.1).
          Semantics(
            header: true,
            child: Text(
              VenuesData.byId(fact.venueId)?.name ?? fact.venueId,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AonSpacing.space1),
          Text(
            fact.activityLabel.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
          const SizedBox(height: AonSpacing.space3),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AonSpacing.space3),
          Text(body, style: theme.textTheme.bodyLarge),
          if (p.showDraftNote) ...[
            const SizedBox(height: AonSpacing.space4),
            // `showDraftNote` is only true for a placeholder fact, so
            // ConfidenceNote (which renders only for placeholder) shows here.
            ConfidenceNote(
              confidence: fact.confidence,
              message: 'Draft — awaiting review by the astronomy team.',
            ),
          ],
          const SizedBox(height: AonSpacing.space5),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _StampPop extends StatelessWidget {
  const _StampPop({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.check_circle_rounded,
        color: AonColors.amber, size: 44);
    if (reduceMotion) return icon; // no scale/translate under reduced motion
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: AonAnimations.slow, // 300ms
      curve: AonAnimations.easeOutCubic,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/widget/passport_fact_sheet_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/widgets/passport_fact_sheet.dart test/widget/passport_fact_sheet_test.dart
git commit -m "feat(passport): fact sheet + reveal helper + collect stamp pop (Phase 7)"
```

---

## Task 4: Reveal-on-collect wiring (haptic + sheet)

**Files:** Modify `lib/screens/passport_scan_screen.dart`; Create `test/widget/passport_reveal_flow_test.dart`.

**Interfaces:**
- Consumes: `showPassportFactSheet`, `FactRevealReason`, `AonHaptics.light`, `StampCollected`, `Routes.passportReward`.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_reveal_flow_test.dart` (uses the Phase 6 injected-scanner seam to emit a decoded QR; asserts sheet-for-1–8, no-sheet-for-9th, and exactly-one-haptic via a `SystemChannels.platform` mock):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

// Records HapticFeedback platform calls (method + argument) so we can assert
// EXACTLY one light-impact, ignoring any other haptic that might fire.
final List<MethodCall> _haptics = [];
void _installHapticSpy() {
  _haptics.clear();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') _haptics.add(call);
    return null;
  });
  addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

int get _lightImpacts => _haptics
    .where((c) => c.arguments == 'HapticFeedbackType.lightImpact')
    .length;

Widget _app(Widget screen, {Set<String> snapshot = const {}}) => ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => screen),
          GoRoute(
              path: Routes.passportReward,
              builder: (_, __) => const Scaffold(body: Text('REWARD'))),
        ]),
      ),
    );

// A scan screen whose scanner button emits a chosen decoded code.
Widget _scan(String decoded) => PassportScanScreen(
      scannerBuilder: (onDecoded) => ElevatedButton(
        key: const Key('emit'),
        onPressed: () => onDecoded(decoded),
        child: const Text('emit'),
      ),
    );

// Reveals the scanner and emits the decoded code, clearing any haptics from the
// scanner-selection phase FIRST so the assertion measures only the collect.
Future<void> _scanOnce(WidgetTester t) async {
  await t.tap(find.text('Scan QR code'));
  await t.pumpAndSettle();
  _haptics.clear();
  await t.tap(find.byKey(const Key('emit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a 1st collect opens the fact sheet and fires one light impact',
      (t) async {
    _installHapticSpy();
    await t.pumpWidget(_app(_scan('AON2026:AON-A-TBC')));
    await _scanOnce(t);
    // Macquarie Theatre fact title (debug build shows the draft).
    expect(find.textContaining('Gravity can bend light'), findsOneWidget);
    expect(_lightImpacts, 1);
  });

  testWidgets('the 9th collect goes to reward, not the fact sheet', (t) async {
    _installHapticSpy();
    final firstEight =
        StampStationsData.all.take(8).map((s) => s.venueId).toSet();
    final ninthCode = StampStationsData.all[8].code;
    await t.pumpWidget(_app(_scan('AON2026:$ninthCode'), snapshot: firstEight));
    await _scanOnce(t);
    expect(find.text('REWARD'), findsOneWidget);
    expect(_lightImpacts, 1); // haptic still fires once on the 9th
  });

  testWidgets('a duplicate fires no haptic and opens no sheet', (t) async {
    _installHapticSpy();
    await t.pumpWidget(
        _app(_scan('AON2026:AON-A-TBC'), snapshot: {'macquarie-theatre'}));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.textContaining('Gravity can bend light'), findsNothing);
  });

  testWidgets('an unknown code fires no haptic and opens no sheet', (t) async {
    _installHapticSpy();
    await t.pumpWidget(_app(_scan('AON2026:NOT-A-CODE')));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.byType(PassportScanScreen), findsOneWidget); // still on capture
    expect(find.text('REWARD'), findsNothing);
  });

  testWidgets('disabled collection fires no haptic and opens no sheet',
      (t) async {
    _installHapticSpy();
    await t.pumpWidget(ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(<String>{}),
        passportCollectionEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => _scan('AON2026:AON-A-TBC')),
          GoRoute(
              path: Routes.passportReward,
              builder: (_, __) => const Scaffold(body: Text('REWARD'))),
        ]),
      ),
    ));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.text('REWARD'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (no haptic/sheet wiring yet).

- [ ] **Step 3: Modify `handleInput` in `lib/screens/passport_scan_screen.dart`** — add imports and wire the reveal + haptic:

```dart
import 'dart:async';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';
```

Replace the body of `handleInput` with:

```dart
  void handleInput(StampInput input) {
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
        StampDisabled() =>
          'The passport isn\'t live yet — see staff at an information point.',
      };
    });

    // Learning layer: only a real new stamp. Never touches scanner lifecycle.
    if (outcome.result is StampCollected) {
      unawaited(AonHaptics.light(true)); // one haptic per real collect (§13)
      if (outcome.justCompleted) {
        context.push(Routes.passportReward); // 9th: reward wins, no sheet (§11.2)
      } else {
        final venueId = (outcome.result as StampCollected).venueId;
        unawaited(showPassportFactSheet(context, venueId,
            reason: FactRevealReason.collected)); // 1–8 (§11.1)
      }
    }
  }
```

(The existing `if (outcome.justCompleted) context.push(...)` at the end of the
old method is now inside this block — remove the old duplicate push.)

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/widget/passport_reveal_flow_test.dart test/widget/passport_scan_screen_test.dart test/widget/passport_scan_integration_test.dart && flutter analyze` — Expected: PASS (new + the Phase 6 scan tests still green); clean.

- [ ] **Step 5: Commit**
```bash
git add lib/screens/passport_scan_screen.dart test/widget/passport_reveal_flow_test.dart
git commit -m "feat(passport): reveal-on-collect + one haptic; 9th routes to reward (Phase 7)"
```

---

## Task 5: Grid revisit + collected-cell semantics

**Files:** Modify `lib/widgets/passport_grid.dart`, `lib/screens/passport_screen.dart`; Create `test/widget/passport_revisit_test.dart`.

**Interfaces:**
- `PassportGrid` gains `final void Function(String venueId)? onTapCollected;`. Collected cells become buttons (semantics `button: true`, hint `Opens astronomy fact`, `onTap` → `onTapCollected(venueId)`); uncollected cells stay inert with **no** button role.
- `PassportScreen` passes `onTapCollected: (id) => showPassportFactSheet(context, id, reason: FactRevealReason.revisit)`.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_revisit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_grid.dart';

Widget _host(Set<String> collected, {void Function(String)? onTap}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportGrid(
              collectedVenueIds: collected, onTapCollected: onTap),
        ),
      ),
    );

void main() {
  testWidgets('a collected cell is a button and calls back on tap', (t) async {
    final handle = t.ensureSemantics(); // repo pattern (map_category_filter_bar_test:77)
    addTearDown(handle.dispose);
    String? tapped;
    await t.pumpWidget(_host({'macquarie-theatre'}, onTap: (id) => tapped = id));
    final cell = find.bySemanticsLabel(RegExp(r', stamp collected$'));
    expect(cell, findsOneWidget);
    // Button role via the repo's 3.44 API (aon_tactile_button_test:165).
    expect(t.getSemantics(cell).getSemanticsData().flagsCollection.isButton,
        isTrue);
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(tapped, 'macquarie-theatre');
  });

  testWidgets('an uncollected cell has no button role and does nothing',
      (t) async {
    final handle = t.ensureSemantics();
    addTearDown(handle.dispose);
    String? tapped;
    await t.pumpWidget(_host(<String>{}, onTap: (id) => tapped = id));
    final cell = find.bySemanticsLabel(RegExp(r', not yet collected$')).first;
    expect(
        t.getSemantics(cell).getSemanticsData().flagsCollection.isButton,
        isFalse);
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(tapped, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (`onTapCollected` undefined).

- [ ] **Step 3: Modify `passport_grid.dart`** — add the callback and make collected cells interactive. Update `PassportGrid`:

```dart
class PassportGrid extends StatelessWidget {
  const PassportGrid({
    required this.collectedVenueIds,
    this.onTapCollected,
    super.key,
  });

  final Set<String> collectedVenueIds;
  final void Function(String venueId)? onTapCollected;
  // ... in the builder, pass onTap to each _Cell:
  //   _Cell(venueId: s.venueId, collected: ..., onTapCollected: onTapCollected)
}
```

Rework `_Cell` so a collected cell is a labelled **button** and an uncollected
cell is inert:

```dart
class _Cell extends StatelessWidget {
  const _Cell({
    required this.venueId,
    required this.collected,
    this.onTapCollected,
  });

  final String venueId;
  final bool collected;
  final void Function(String venueId)? onTapCollected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenuesData.byId(venueId);
    final name = venue?.shortName ?? venue?.name ?? venueId;

    // The Phase 6 cell visual, unchanged (decoration + icon + name).
    final visual = Container(
      padding: const EdgeInsets.all(AonSpacing.space3),
      decoration: BoxDecoration(
        color: collected
            ? AonColors.amber.withValues(alpha: 0.12)
            : AonColors.night900,
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(
          color: collected ? AonColors.amber : AonColors.night700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            collected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: collected ? AonColors.amber : AonColors.contentTertiary,
            size: AonSpacing.iconMd,
          ),
          const SizedBox(height: AonSpacing.space2),
          Text(name, style: theme.textTheme.titleSmall),
        ],
      ),
    );

    // Interactive ONLY when collected AND a callback exists — an inert cell
    // must never announce a button role (P1-4d). Reuses the Phase 3
    // AonTactileButton (keyboard Enter/Space, focus ring, reduced-motion press)
    // rather than a raw GestureDetector; haptics off (revisit fires none, §11.4).
    if (collected && onTapCollected != null) {
      return Semantics(
        container: true,
        button: true,
        label: '$name, stamp collected',
        hint: 'Opens astronomy fact',
        child: AonTactileButton(
          onTap: () => onTapCollected!(venueId),
          hapticsEnabled: false,
          borderRadius: AonSpacing.radiusMd,
          child: ExcludeSemantics(child: visual),
        ),
      );
    }
    // Collected-but-no-callback (e.g. a bare grid test) or uncollected: inert,
    // no button role.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$name, ${collected ? 'stamp collected' : 'not yet collected'}',
      child: visual,
    );
  }
}
```

Add the import: `import 'package:aon2026/widgets/aon_tactile_button.dart';`.

Note for the executor: the semantics test in this task must still see **one** labelled button node (`flagsCollection.isButton`); if `AonTactileButton` + the outer `Semantics` produce a doubled node, drop the outer `button: true`/`hint` onto the `AonTactileButton` via a `Semantics` child instead — verify against the passing test, matching `tactile_adoption_test`'s "one labelled button node" pattern.
```

(Keep the existing `Container` decoration/child from Phase 6 as `visual`.)

- [ ] **Step 4: Wire the revisit callback in `passport_screen.dart`** — replace the grid usage:

```dart
import 'package:aon2026/widgets/passport_fact_sheet.dart';
// ...
          PassportGrid(
            collectedVenueIds: state.collectedVenueIds,
            onTapCollected: (id) => showPassportFactSheet(
              context, id, reason: FactRevealReason.revisit),
          ),
```

- [ ] **Step 5: Run tests** — Run: `flutter test test/widget/passport_revisit_test.dart test/widget/passport_grid_test.dart test/widget/passport_screen_test.dart && flutter analyze` — Expected: PASS (Phase 6 grid/screen tests still green); clean.

- [ ] **Step 6: Commit**
```bash
git add lib/widgets/passport_grid.dart lib/screens/passport_screen.dart test/widget/passport_revisit_test.dart
git commit -m "feat(passport): tap a collected cell to revisit its fact; button semantics (Phase 7)"
```

---

## Task 6: Progress copy (+ disabled state)

**Files:** Modify `lib/screens/passport_screen.dart`; Create `test/widget/passport_progress_copy_test.dart`.

**Interfaces:** a pure helper `String passportProgressLine({required bool collectionEnabled, required int count, required int total})` (top-level in `passport_screen.dart` or a small util), used by `PassportScreen`.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_progress_copy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/screens/passport_screen.dart';

void main() {
  String line(bool enabled, int count) =>
      passportProgressLine(collectionEnabled: enabled, count: count, total: 9);

  test('disabled overrides in-progress states', () {
    expect(line(false, 0), 'Astronomy Passport opens on event night');
    expect(line(false, 3), 'Astronomy Passport opens on event night');
  });
  test('completion outranks the disabled gate (persisted 9/9)', () {
    expect(line(false, 9), '9 / 9 stamps'); // NOT "opens on event night"
    expect(line(true, 9), '9 / 9 stamps');
  });
  test('boundaries', () {
    expect(line(true, 0), 'Scan or enter a venue code to start');
    expect(line(true, 1), '1 / 9 stamps');
    expect(line(true, 7), '7 / 9 stamps');
    expect(line(true, 8), 'Just 1 more to go!');
    // 9 handled by the completed state; the line still reads sensibly:
    expect(line(true, 9), '9 / 9 stamps');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (undefined).

- [ ] **Step 3: Implement** — add to `passport_screen.dart` (top-level) and use it:

```dart
/// The passport progress line, disabled-state-aware (design §14).
///
/// Completion outranks the disabled gate: a persisted, already-complete passport
/// must not be relabelled "opens on event night" just because a release build
/// currently disables NEW collection. The gate blocks new collection, it does
/// not rewrite history.
String passportProgressLine({
  required bool collectionEnabled,
  required int count,
  required int total,
}) {
  if (count >= total) return '$total / $total stamps'; // completed — always
  if (!collectionEnabled) return 'Astronomy Passport opens on event night';
  if (count == 0) return 'Scan or enter a venue code to start';
  if (count == total - 1) return 'Just 1 more to go!';
  return '$count / $total stamps';
}
```

In `build`, read the gate and use the helper (the `9` case still shows the
completed state + "View your reward" as in Phase 6):

```dart
final enabled = ref.watch(passportCollectionEnabledProvider);
// ...
Text(
  passportProgressLine(
    collectionEnabled: enabled,
    count: state.count,
    total: PassportPolicy.stationCount,
  ),
  style: theme.textTheme.headlineSmall,
),
```

(Import nothing new — `passportCollectionEnabledProvider` is already in
`passport_providers.dart`.)

- [ ] **Step 4: Add a 2.0 copy regression** — extend `test/widget/passport_screen_test.dart` (or the new file) with a widget test at `320×568 / 2.0` asserting the disabled line and the `count==8` line render without overflow. Use the repo harness (`tester.view` + `platformDispatcher.textScaleFactorTestValue`) and a `passportCollectionEnabledProvider` override.

- [ ] **Step 5: Run tests** — Run: `flutter test test/widget/passport_progress_copy_test.dart test/widget/passport_screen_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 6: Commit**
```bash
git add lib/screens/passport_screen.dart test/widget/passport_progress_copy_test.dart
git commit -m "feat(passport): disabled-aware progress copy + near-complete nudge (Phase 7)"
```

---

## Task 7: Verification gate, runtime pass, docs closeout

**Files:** Modify `docs/superpowers/specs/2026-08-11-aon-passport-learning-phase7-design.md` (record closeout).

- [ ] **Step 1: Full static + test gate** — Run: `flutter analyze && flutter test` — Expected: clean; suite = Task 0 baseline + the new Phase 7 tests, all green, **no Phase 1–6 regressions**.

- [ ] **Step 2: Platform builds** — Run: `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — Expected: all succeed (no new deps, so unchanged from baseline).

- [ ] **Step 3: iOS runtime pass** (simulator; collect via manual entry — no camera needed). The **haptic is proven by the automated channel test** (Task 4), not by feel — verify the **visible** flow here. Record PASS/FAIL for each:
```text
[ ] collect a non-final stamp (manual code) → fact sheet opens for that venue,
     showing the venue name + activity + a restrained stamp pop
[ ] close sheet → capture flow continues (Scan another / manual still work)
[ ] revisit the fact by tapping the collected grid cell (opens the same sheet)
[ ] collect the 9th → reward opens, NO fact sheet
[ ] enable Reduce Motion (Settings > Accessibility) → repeat a collect:
     no sheet-route slide, no stamp scale; content appears instantly
[ ] long fact text at large text size scrolls, no clip
[ ] a placeholder fact in this (debug) build shows the draft + review note
```
(Optional: a physical iPhone can add supplementary tactile confirmation, but is
not required — the light-impact call is already asserted in Task 4.)

- [ ] **Step 4: Two-gate closeout** — record BOTH gates in the spec §16/§17:

  **CODE COMPLETE** (this branch, expected now): all tasks/tests/builds green;
  release-safe fallback verified; publication policy correct. Facts may be
  **0 confirmed / 0 derived / 9 placeholder** — the machine works, but every
  attendee currently sees the "awaiting review" fallback.

  **RELEASE READY** (a later gate, NOT satisfied by this branch): the education
  layer is only meaningful once facts are reviewed. Require **9/9 reliable**
  (`confirmed`/`derived`) — or an explicitly organiser-approved partial rollout
  exposing only the reviewed facts. Record confirmed N/9, derived N/9,
  placeholder N/9, and `sourceRegistry` documented PASS. **Do not describe Phase
  7 as "shipped to attendees" while any fact is a placeholder** — that is an
  empty fact machine (design intent §1).

- [ ] **Step 5: Final re-gate** — Run: `flutter analyze && flutter test && git diff --check && git status --short`, then a hostile read of the full `git diff main...HEAD`.

- [ ] **Step 6: Commit**
```bash
git add docs/superpowers/specs/2026-08-11-aon-passport-learning-phase7-design.md
git commit -m "docs(passport): Phase 7 CODE COMPLETE — 0/0/9 facts pending review (not RELEASE READY)"
```

---

## Self-Review

**1. Spec coverage**

| Spec § | Task |
|---|---|
| §5 content model + registry | 1 |
| §5.2 integrity (facts==stations==venues, sourceRef) | 1 |
| §6 publication policy (pure) | 2 |
| §6.3 release fallback copy | 2 (const) + 3 (render) |
| §8 fact sheet + helper + scrollable 2.0 | 3 |
| §9 reduced-motion sheet (`AnimationStyle.noAnimation`) | 3 |
| §10 structured semantics | 3 (sheet) + 5 (grid) |
| §11.1 reveal-on-collect 1–8 | 4 |
| §11.2 9th → reward, no sheet, haptic once | 4 |
| §11.3 duplicate/unknown/disabled → nothing | 4 |
| §11.4 revisit | 5 |
| §11.5 missing fact no-op | 3 (helper) |
| §12 collect stamp pop (in sheet header, motion-aware) | 3 |
| §13 one haptic per real collect | 4 |
| §14 progress copy incl. disabled | 6 |
| §15 tests | every task + 7 |
| §16 verification gate | 7 |

**2. Placeholder scan** — no "TBD/handle appropriately". The facts are intentionally `placeholder` *data* (spec-mandated), not plan gaps. The Task 3 note about the `ConfidenceNote confidence:` arg is resolved inline (pass `fact.confidence`).

**3. Type consistency** — `PassportFact`, `PassportFactsData.{byVenueId,venueIds,sourceRegistry}`, `FactBody`, `FactPresentation`, `resolveFactPresentation`, `FactRevealReason`, `PassportFactSheet`, `showPassportFactSheet`, `passportProgressLine`, `PassportGrid.onTapCollected` — names match between definition and use. Haptic spy asserts on `HapticFeedback.vibrate` (the real method behind `HapticFeedback.lightImpact`).

---

## Notes for the executor

- **Phase 6 owns the scanner.** Task 4 only *reads* the collect outcome and reveals a sheet / navigates — it never calls scanner start/stop/reset. The "Scan another" re-arm stays Phase 6's.
- **Haptic test seam:** the `SystemChannels.platform` mock counting `HapticFeedback.vibrate` is the evidence for "exactly once" — do not assert on a visual.
- **All widget tests that set scale/viewport** use `tester.view` + `platformDispatcher.textScaleFactorTestValue` (repo-proven); reduced-motion via `MaterialApp(builder:)` or `MediaQuery` inside the pumped subtree, not an outer wrapper around `MaterialApp`.
- **Never weaken an *unrelated* Phase 1–6 invariant.** If Phase 7 intentionally changes a contract, *migrate* the affected regression to assert the stronger new one — don't preserve a stale test, and don't loosen a real one. Verified: the current `passport_grid_test.dart` uses name-agnostic suffix labels (`:17,25,29`), and Phase 7 keeps the `'$name, stamp collected'` text, so it should stay green unchanged; confirm that at the Task 5 gate (if it goes red, migrate it deliberately, don't loosen).
- **Guarantees that were annotation-only are now tested** (this gauntlet round): reduced motion (no `TweenAnimationBuilder`), missing-fact no-op, structured semantics (venue header + Close button), a real forced-scroll proof, and the `release + placeholder + 2.0` combined state. A green suite must actually exercise these, not just claim them.
- **CODE COMPLETE ≠ RELEASE READY** (Task 7): the branch can be code-complete with 9 placeholder facts; it is not shippable-to-attendees until facts are reviewed.
