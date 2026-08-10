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
not *fix-all-the-overflows*: content screens are `ListView`-scrollable, so they
absorb vertical growth at any height. The **sheets** are the exception.

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
sheet, wrap the name `Text` in `Expanded` (one line, harmless for short names).
Labeled defensive: it hardens a latent structural fragility the gauntlet found,
not a currently-reproducing overflow.

## 4. The clamp lift

`lib/main.dart:65` — `maxScaleFactor: 1.6` → `maxScaleFactor: 2.0`. The
adjacent comment is rewritten to state the new guarantee: every surface is
verified overflow-free to 2.0; the cap is held at 2.0 deliberately, so the OS
cannot request a scale the app has not been hardened and regression-tested
against. `minScaleFactor: 1.0` is unchanged.

## 5. Testing plan — make 2.0 permanent

The suite gains three things, all TDD (write failing → fix → green). **Viewport
choice is load-bearing** (§2): the sheet tests use a short viewport so the
overflow actually reproduces.

1. **Extend `responsive_layout_test.dart` — add the 2.0 row.** Matrix becomes
   the existing widths `{320, 414}` × scales `{1.0, 1.6, 2.0}` (just the 2.0
   row; **no 360w column** — 320w is strictly the more constraining width for
   horizontal overflow, so 360 would be test-bloat without a distinct failure
   mode). Same `takeException()` guard. This locks the 6 content screens.
2. **Sheet-at-2.0 tests (new file `text_scale_sheets_test.dart`).**
   - `_TimeSimulatorSheet`: open via the What's On AppBar science icon at 2.0,
     **320×640**, assert no exception (the exact probe that caught the bug).
   - `_ParkingSheet`: open by tapping a parking marker on `MapScreen` at 2.0,
     **320×568** (the height where it reproduces — a tall viewport hides it).
     *Feasibility confirmed:* `MapScreen` pumps in a widget test and a parking
     marker is tappable at this size. *Robustness caveat:* marker hit-testing
     is viewport-sensitive (it missed at 320×640); the test pins 320×568 and
     uses `warnIfMissed: false`. If this proves flaky in practice, the fallback
     is to extract the sheet body to a public widget testable directly — noted,
     not pre-emptively done.
   - `_VenueSheet`: assert it contains a `Scrollable` (regression guard against
     someone "simplifying" it back to a non-scrollable `Column`).
3. **Extend `shell_responsive_test.dart` — navigate tabs at 2.0 (not a new
   file).** `shell_responsive_test` **already** pumps `buildRouter()` at 2.0 for
   the *initial* (Home) route; because `StatefulShellRoute.indexedStack` builds
   branches lazily, **Map/Program/Now/Info are never built there.** Add one case
   that, at 2.0, taps through each tab and asserts no exception after each —
   closing the fact that **`MapScreen` currently has zero coverage.** This is
   the genuine delta; it does not re-prove Home-at-2.0.

## 6. Verification / acceptance gate

Phase 5 is complete only when ALL hold:

- `flutter analyze` clean.
- `flutter test` green, including the extended matrix and the new tests.
- The clamp reads `maxScaleFactor: 2.0` with the guarantee documented.
  *Lift is safe (verified):* no test asserts `maxScaleFactor`/`1.6` or depends
  on clamped scaling, and `shell_responsive_test` + `hero_glass_test` already
  exercise 2.0 directly — so raising the cap cannot silently break the suite.
- **On-device iOS pass at 2.0** (iOS simulator, `Settings > Larger Text` or an
  injected 2.0 scale): every screen + both fixed sheets legible and unclipped.
  This is best-effort verification, honestly reported — ellipsis truncation
  does **not** throw, so automated tests cannot see it; a human eye can.

## 7. Honest bounds & deferrals

- **Android runtime & performance traces: `NOT AVAILABLE`** — no Android
  emulator and no profiler trace in this environment, exactly as flagged in
  Phases 2–3. No perf-profiling strand is claimed.
- **Ellipsis truncation is not overflow.** A `Text` with `overflow: ellipsis`
  that runs out of room at 2.0 truncates silently without throwing. The
  automated suite cannot catch it; the on-device pass (§6) is the mitigation.
  Any truncation that loses *critical* information found on-device is fixed in
  this phase; cosmetic truncation is acceptable degradation.
- **Unbounded scaling is deliberately NOT done.** The OS can request scales
  above 2.0 (iOS accessibility sizes, Android font scale × display size). The
  app hardens to and caps at 2.0. Lifting past 2.0 is out of scope and, for a
  one-handed walking companion, degrades usefulness past the point of value.
- **No new a11y features.** Semantics, contrast, and ≥56px targets were built
  per-phase. This gauntlet *verifies* a11y survives at 2.0; it does not extend
  it.

## 8. Scope

**In:** the two sheet fixes (§3); the clamp lift (§4); the three test additions
(§5); the on-device 2.0 pass (§6).

**Out:** perf profiling; Android runtime; new screens/widgets; unbounded
scaling; any a11y feature work; any visual/design change to a screen that is
already overflow-free at 2.0.

## 9. Scorecard (0–10, re-scored at closeout)

| Axis | Score | What raises it (named artifact) |
|---|---|---|
| Accessibility reach | 6 → target 9 | Clamp at 2.0 with every surface verified; the +3 is the on-device truncation pass catching what tests can't |
| Regression durability | 5 → target 9 | The 2.0 matrix + short-viewport sheet tests + tab-nav Map coverage; Map going from 0 → covered is most of the lift |
| Honesty of guarantee | 7 → target 10 | Bounded 2.0 claim, receipts in §2 (incl. the self-gauntlet height correction), NOT-AVAILABLE items named in §7 |
| Change surface / risk | 8 → target 9 | Two `SingleChildScrollView` wraps + one `Expanded` + one constant + tests; no screen redesign |

## 10. Files

- Modify: `lib/main.dart:65` (clamp `1.6 → 2.0`) + comment.
- Modify: `lib/screens/whats_on_screen.dart` (`_TimeSimulatorSheet` scroll wrap).
- Modify: `lib/screens/map_screen.dart` (`_ParkingSheet` scroll wrap **and**
  `Expanded` on the name `Text` — §3 secondary finding).
- Modify: `test/widget/responsive_layout_test.dart` (add the `2.0` scale row).
- Modify: `test/widget/shell_responsive_test.dart` (add tab-navigation-at-2.0,
  covering Map).
- Create: `test/widget/text_scale_sheets_test.dart` (`_TimeSimulatorSheet` @
  320×640, `_ParkingSheet` @ 320×568, `_VenueSheet` scrollable-guard).
