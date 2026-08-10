# Phase 5 — Gauntlet: lift text-scale to 2.0 (Design)

**Status:** frozen for review · 2026-08-10
**Pays:** the Phase 1 §6.3 / §10 flagged deferral — *"lift the global cap in
Phase 5 (Gauntlet) together with a full-app ≤2.0 responsive pass."*

## 1. Intent

The app clamps OS text scaling at `1.6` (`lib/main.dart:65`,
`maxScaleFactor: 1.6`). The clamp's own comment states the reason: *"beyond
that the programme cards overflow badly; capping is kinder than clipping."*
That was true when written. It is **no longer** true of the screens: the
Phases 1–3 hardening (EventCard's `Wrap`, scrollable `ListView` bodies,
`minHeight` instead of fixed heights) already carries every content screen to
2.0. The clamp has become a conservative crutch the screens have outgrown.

Phase 5 makes the guarantee real and bounded: **harden every surface to render
overflow-free at TextScaler 2.0, lift the clamp 1.6 → 2.0, and lock 2.0 in with
permanent regression coverage.** The ceiling stays at 2.0 by deliberate
choice — a bounded, testable promise, not unbounded platform scaling (§8).

## 2. Empirical baseline (receipts, not assumptions)

Measured by extending the existing overflow harness
(`test/widget/responsive_layout_test.dart`, which today stops at 1.6) to
TextScaler **2.0**, and by driving the modal sheets. A `RenderFlex` overflow
throws during a widget-test layout, so `tester.takeException()` is the guard.

| Surface @ 2.0 | Viewport(s) | Result |
|---|---|---|
| 6 content screens (standalone) — Home, Program, What's On, Info, Wayfinding, EventDetail | 320 / 360 / 414 wide **and** 320×568 (short) | **no overflow** |
| Integrated shell + all 5 tabs incl. **Map** (via `buildRouter()`, navigating each tab) | 320 / 360 / 414 | **no overflow** |
| What's On `_TimeSimulatorSheet` | 320×640 / 360×780 | **overflow 1098 / 912 px** |
| Map `_ParkingSheet` (opened via marker tap) | **320×568** | **overflow** (did not manifest at 320×640) |

The probes were throwaway; their surviving form is the Phase-5 regression
suite (§5). The measured *screen* result is why this phase is *verify-and-lift*,
not *fix-all-the-overflows*: **the six content screens are currently clean at
all tested widths and heights, including the 320×568 short viewport**, and their
`ListView`-scrollable bodies substantially reduce vertical-overflow risk. That
is a measurement at specific dimensions, not a proof for every possible height —
and it does not immunise against horizontal overflow, fixed-header overflow, or
overlay collisions, which the regression matrix (§5) guards against explicitly.
The **sheets** are the exception that did reproduce.

**Self-gauntlet correction — viewport height matters.** My first screen probes
used generous heights (640 / 780 / 896); at those heights `_ParkingSheet`'s tap
missed and it read as clean. Re-probing at a realistic short phone (**320×568**,
≈ iPhone SE) surfaced the `_ParkingSheet` overflow. The existing suite
(`responsive_layout_test`, `shell_responsive_test`) also uses tall heights only
— so **the regression tests below MUST include a short viewport**, or
sheet/short-screen overflows slip through (§5).

**Corroboration (independent of the probes above):** `shell_responsive_test.dart`
already pumps the integrated `buildRouter()` shell at scale **2.0** on 320/414,
and `hero_glass_test.dart` already exercises the hero at **2.0** — both green
today. The shell and hero are therefore already 2.0-clean; this phase does not
re-litigate them, it extends coverage to the *un-covered* surfaces.

## 3. The one real defect class — non-scrollable modal sheets

A modal bottom sheet whose body is a fixed `Column(mainAxisSize: min)` cannot
absorb large text: at 2.0 the content exceeds the sheet and overflows. Two
sheets have this shape; one does not:

| Sheet | Structure | Status |
|---|---|---|
| `_TimeSimulatorSheet` (`whats_on_screen.dart:295`) | `SafeArea > Padding > Column(min)`, opened `isScrollControlled: true` | **defective — proven (1098px @ 320×640)** |
| `_ParkingSheet` (`map_screen.dart`) | default modal (`isScrollControlled: false`) → `SafeArea > Padding > Column(min)` | **defective — confirmed at 320×568** |
| `_VenueSheet` (`map_screen.dart`) | `DraggableScrollableSheet > ListView` | **already safe — no change** |

**Primary fix (both defective sheets):** wrap the content `Column` in a
`SingleChildScrollView`, so the body scrolls internally within whatever height
the sheet is granted instead of overflowing. Minimal, canonical, no layout
redesign. The `Column(mainAxisSize: min)` is preserved inside the scroll view
so small-text sheets keep sizing to content.

**Fix proven, not assumed.** The `SingleChildScrollView` wrap was prototyped on
`_TimeSimulatorSheet` and re-probed at 2.0 (320×640 / 360×780): the overflow is
gone and the sheet is genuinely scrollable (a `Scrollable` is present — it is a
mechanism fix, not a coincidence of shorter content). Prototype reverted; the
real change lands via TDD (§5).

**Secondary finding — `_ParkingSheet` name Row (defensive).** Its header is
`Row(children: [Icon, SizedBox, Text(parking.name, headlineSmall)])` with **no
`Expanded`/`Flexible`** around the name. Current data names are short ("West 5",
"South 2"), so this does **not** overflow horizontally at 2.0 today — but a
vertical `SingleChildScrollView` would not catch it if it did. While fixing this
sheet, wrap the name `Text` in `Expanded` so it **wraps within the remaining row
width** (`Expanded` constrains the available horizontal space; it does not by
itself force a single line — and for large-text accessibility, wrapping is the
preferred behaviour here, so no `maxLines`/`ellipsis` is imposed). Labeled
defensive: it hardens a latent structural fragility the gauntlet found, not a
currently-reproducing overflow.

## 4. The clamp lift — made testable

Today the policy is inlined in `AonApp.build`'s `builder:`
(`lib/main.dart:63`): `MediaQuery.textScalerOf(context).clamp(minScaleFactor:
1.0, maxScaleFactor: 1.6)`. A synthetic-`TextScaler(2.0)` component test cannot
see this constant at all — so the clamp is the one thing Phase 5 changes that
nothing tests. That is the steering wheel going untested.

**Extract the policy so it can be asserted directly.** Introduce a named
constant and a pure function (in `main.dart`, or a small `lib/app/text_scale.dart`):

```dart
const double kMaxTextScale = 2.0; // Phase 5 accessibility ceiling
TextScaler resolveAppTextScaler(TextScaler os) =>
    os.clamp(minScaleFactor: 1.0, maxScaleFactor: kMaxTextScale);
```

The builder calls `resolveAppTextScaler(MediaQuery.textScalerOf(context))`
instead of the inline clamp. The constant is the single source of truth for the
ceiling; the comment states the guarantee (verified overflow-free to 2.0; capped
at 2.0 deliberately). `minScaleFactor: 1.0` is part of the policy and is tested
as such (§5.4). If anyone later reverts `kMaxTextScale` to 1.6, the ceiling test
fails — the regression the old inline clamp could never have.

## 5. Testing plan — make 2.0 permanent

The suite gains the following, all TDD (write failing → fix → green).
**Viewport choice is load-bearing** (§2): tests that must catch vertical
overflow use a short viewport so it actually reproduces.

1. **Extend `responsive_layout_test.dart` — widths, the 2.0 scale, and a short
   height.** Matrix becomes widths `{320, 360, 414}` × scales `{1.0, 1.6, 2.0}`,
   **plus a dedicated `320×568` (short) case at 2.0 for all six content
   screens.** Two corrections from review: (a) **360w is kept** — the app has
   width-responsive `LayoutBuilder` branches (e.g. `home_screen.dart:59`, grid
   columns `= (maxWidth/260).ceil().clamp(1,4)`; the hero and `LiquidTabBar`),
   so width is *not* monotonic and 320 does not provably subsume 360. (Those
   branches all yield 2 columns across 320–414, so none *crosses* in-band, but
   the branch exists — keeping 360 costs little and removes the assumption.)
   (b) The **320×568 short case is retained permanently** for the screens, not
   only the sheets — the phase's own lesson (height is load-bearing) must not be
   preserved for two sheets while a future fixed-height screen regression sneaks
   back in under tall-only tests. Guard: `tester.takeException()`.
2. **Sheet-at-2.0 tests (new file `text_scale_sheets_test.dart`).** Each sheet
   test **proves the sheet actually opened before judging layout**, so a missed
   interaction can never false-pass as "no overflow":
   - `_TimeSimulatorSheet` @ **320×640**, 2.0: open via the What's On AppBar
     science icon; assert a sheet-unique artefact is present (e.g. the "Preview
     event night" title / the "Back to real time" button) → assert no exception
     → assert a `Scrollable` is present.
   - `_ParkingSheet` @ **320×568**, 2.0: tap a parking marker on `MapScreen`;
     **assert `ConfidenceNote` (a `_ParkingSheet`-unique widget) is visible**
     → then assert no exception → assert a `Scrollable` is present. The
     sheet-opened assertion is mandatory and precedes the layout check, so a
     missed marker tap fails the test rather than silently passing. *Feasibility
     confirmed:* `MapScreen` pumps and a parking marker is tappable at 320×568.
     *Robustness:* if marker hit-testing proves flaky, the fallback is to
     extract the sheet body to a public widget and test it directly — preferred
     over maintaining a probabilistic test. `warnIfMissed:false` is used only
     because the mandatory sheet-opened assertion already makes a real miss fail.
   - `_VenueSheet` @ **320×568**, 2.0: open via a venue marker tap; assert the
     sheet opened → **assert no exception (a real layout test, not merely a
     structural check)** → assert its `Scrollable` is present. "Contains a
     `Scrollable`" alone does not prove the subtree is overflow-free, so the
     global "every surface at 2.0" promise requires the actual layout assertion.
3. **Extend `shell_responsive_test.dart` — navigate tabs at 2.0 (not a new
   file).** `shell_responsive_test` **already** pumps `buildRouter()` at 2.0 for
   the *initial* (Home) route; because `StatefulShellRoute.indexedStack` builds
   branches lazily, **Map/Program/Now/Info are never built there.** Add one case
   that, at 2.0 on **both a tall (320×640) and a short (320×568)** viewport, taps
   through each tab and asserts no exception after each — closing the fact that
   **`MapScreen` currently has zero coverage.** This is the genuine delta; it
   does not re-prove Home-at-2.0.
4. **App-root clamp policy test (new, in `text_scale_sheets_test.dart` or a
   focused `text_scale_policy_test.dart`).** Assert the *production* policy via
   `resolveAppTextScaler` (§4), independent of any injected component scaler:
   - requested `1.0` → `1.0` (floor holds)
   - requested `1.6` → `1.6` (mid passes through)
   - requested `2.0` → `2.0` (ceiling reached, not clipped)
   - requested `3.0` → `2.0` (**documented 2.0 ceiling enforced**)
   - requested `0.5` → `1.0` (floor enforced)

   Compared via `scaler.scale(100)` to avoid `TextScaler` identity pitfalls.
   This is the regression that fails if the ceiling is ever reverted to 1.6 —
   the test §6 previously (wrongly) celebrated not having.

## 6. Verification / acceptance gate

Phase 5 is complete only when ALL hold:

- `flutter analyze` clean.
- `flutter test` green, including the extended matrix and the new tests —
  **including the app-root clamp policy test (§5.4)** that asserts the production
  ceiling is 2.0. (Before this phase no test asserted the clamp; after it, one
  must — so a later revert to 1.6 breaks the suite.)
- The policy reads `kMaxTextScale = 2.0` with the guarantee documented (§4).
- **Platform build gate** — recorded as `PASS / FAIL / NOT AVAILABLE`:
  - `flutter build ios --simulator` (or `--no-codesign`) — expected PASS.
  - `flutter build apk --debug` — expected PASS if the Android toolchain is
    present, else `NOT AVAILABLE`. (Build availability ≠ emulator availability;
    Android *runtime* stays `NOT AVAILABLE` per §7, but a build may still run.)
- **On-device iOS pass at 2.0** (iOS simulator): every screen + both fixed
  sheets legible and unclipped. The scale must be an **effective** 2.0, not just
  an assumed one: during the run, record the resolved
  `MediaQuery.textScalerOf(context)` at a descendant of the app root (a
  temporary debug probe, removed before final commit) so the evidence is
  *platform request → production app resolves effective 2.0 → screen verified*,
  not "the accessibility slider is approximately 2.0." Best-effort and honestly
  reported — ellipsis truncation does **not** throw, so automated tests cannot
  see it; a human eye can.

## 7. Honest bounds & deferrals

- **Android runtime & performance traces: `NOT AVAILABLE`** — no Android
  emulator and no profiler trace in this environment, exactly as flagged in
  Phases 2–3. No perf-profiling strand is claimed.
- **Ellipsis truncation is not overflow.** A `Text` with `overflow: ellipsis`
  that runs out of room at 2.0 truncates silently without throwing. The
  automated suite cannot catch it; the on-device pass (§6) is the mitigation.
  Any truncation that loses *critical* information found on-device is fixed in
  this phase; cosmetic truncation is acceptable degradation.
- **Scaling above 2.0 is an acknowledged accessibility limitation of this
  release.** The OS can request scales above 2.0 (iOS accessibility sizes,
  Android font scale × display size). This release bounds at 2.0 because the app
  has not yet been hardened or regression-tested above that bound — *not* because
  larger text lacks value (a user who sets >2.0 has stated exactly what creates
  value for them). Raising the ceiling past 2.0 is deferred to **future
  accessibility work**, not dismissed.
- **No new semantics, contrast, focus, target-size, or assistive-input
  features.** (Lifting supported scaling 1.6 → 2.0 *is itself* an accessibility
  improvement — this bullet scopes out the *other* a11y dimensions, which were
  built per-phase; the gauntlet verifies they survive at 2.0, it does not extend
  them.)

## 8. Scope

**In:** the two sheet fixes + the `_ParkingSheet` name-Row `Expanded` (§3); the
clamp lift, extracted to a testable policy (§4); the test additions (§5.1–5.4:
screen matrix + short viewport, three sheet layout tests, tab-nav coverage, and
the clamp policy test); the platform build gate + effective-scale on-device pass
(§6).

**Out:** perf profiling; Android *runtime*; new screens/widgets; scaling above
2.0 (deferred to future a11y work, §7); other a11y dimensions (semantics,
contrast, focus, target size); any visual/design change to a surface already
overflow-free at 2.0.

## 9. Scorecard (0–10, re-scored at closeout)

| Axis | Score | What raises it (named artifact) |
|---|---|---|
| Accessibility reach | 6 → target 8 | Clamp at 2.0 with every surface verified + on-device truncation pass. Capped at target **8, not 9**: >2.0 is a known, user-facing limitation deferred to future a11y work (§7) — a 9 would imply near-complete support the spec deliberately does not claim |
| Regression durability | 5 → target 9 | The 2.0 matrix + permanent 320×568 short-viewport screen case + three sheet layout tests + tab-nav Map coverage + the app-root clamp policy test; Map 0 → covered and the clamp becoming testable are most of the lift |
| Honesty of guarantee | 7 → target 10 | Bounded 2.0 claim, receipts in §2 (incl. the self-gauntlet height correction), effective-scale on-device evidence (§6), NOT-AVAILABLE/limitation items named in §7 |
| Change surface / risk | 8 → target 9 | Two `SingleChildScrollView` wraps + one `Expanded` + a policy extraction (constant + pure fn) + tests; no screen redesign |

## 10. Files

- Modify: `lib/main.dart` — replace the inline clamp with `resolveAppTextScaler`
  + `kMaxTextScale = 2.0` (§4) and update the comment. (Helper may live in a new
  `lib/app/text_scale.dart` if cleaner for import from tests.)
- Modify: `lib/screens/whats_on_screen.dart` (`_TimeSimulatorSheet` scroll wrap).
- Modify: `lib/screens/map_screen.dart` (`_ParkingSheet` scroll wrap **and**
  `Expanded` on the name `Text` — §3 secondary finding).
- Modify: `test/widget/responsive_layout_test.dart` (widths `{320,360,414}` ×
  scales `{1.0,1.6,2.0}` **and** a permanent `320×568` @ 2.0 case for all six
  screens).
- Modify: `test/widget/shell_responsive_test.dart` (tab-navigation @ 2.0 on tall
  **and** 320×568, covering Map).
- Create: `test/widget/text_scale_sheets_test.dart` — sheet layout tests with a
  mandatory sheet-opened assertion: `_TimeSimulatorSheet` @ 320×640,
  `_ParkingSheet` @ 320×568, `_VenueSheet` @ 320×568 (all: opened → no exception
  → `Scrollable` present); plus the **app-root clamp policy test** (§5.4)
  asserting the 2.0 ceiling and 1.0 floor via `resolveAppTextScaler`. (Split the
  policy test into `text_scale_policy_test.dart` if the file grows unwieldy.)
