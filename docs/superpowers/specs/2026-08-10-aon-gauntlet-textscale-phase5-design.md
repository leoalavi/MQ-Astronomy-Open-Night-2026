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

| Surface @ 2.0 | Widths 320 / 360 / 414 | Result |
|---|---|---|
| 6 content screens (standalone) — Home, Program, What's On, Info, Wayfinding, EventDetail | all | **no overflow** |
| Integrated shell + all 5 tabs incl. **Map** (via `buildRouter()`) | all | **no overflow** |
| What's On `_TimeSimulatorSheet` | 320 / 360 | **overflow 1098 / 912 px** |

The probes were throwaway; their surviving form is the Phase-5 regression
suite (§5). The measured screen result is why this phase is *verify-and-lift*,
not *fix-all-the-overflows*.

## 3. The one real defect class — non-scrollable modal sheets

A modal bottom sheet whose body is a fixed `Column(mainAxisSize: min)` cannot
absorb large text: at 2.0 the content exceeds the sheet and overflows. Two
sheets have this shape; one does not:

| Sheet | Structure | Status |
|---|---|---|
| `_TimeSimulatorSheet` (`whats_on_screen.dart:295`) | `SafeArea > Padding > Column(min)`, opened `isScrollControlled: true` | **defective — proven** |
| `_ParkingSheet` (`map_screen.dart`) | `SafeArea > Padding > Column(min)` | **defective — same shape, confirm via TDD** |
| `_VenueSheet` (`map_screen.dart`) | `DraggableScrollableSheet > ListView` | **already safe — no change** |

**Fix (both defective sheets):** wrap the content `Column` in a
`SingleChildScrollView`, so the body scrolls internally within whatever height
the sheet is granted instead of overflowing. Minimal, canonical, no layout
redesign. The `Column(mainAxisSize: min)` is preserved inside the scroll view
so small-text sheets keep sizing to content.

## 4. The clamp lift

`lib/main.dart:65` — `maxScaleFactor: 1.6` → `maxScaleFactor: 2.0`. The
adjacent comment is rewritten to state the new guarantee: every surface is
verified overflow-free to 2.0; the cap is held at 2.0 deliberately, so the OS
cannot request a scale the app has not been hardened and regression-tested
against. `minScaleFactor: 1.0` is unchanged.

## 5. Testing plan — make 2.0 permanent

The suite gains three things, all TDD (write failing → fix → green):

1. **Extend `responsive_layout_test.dart`.** Matrix becomes widths
   `{320, 360, 414}` × scales `{1.0, 1.6, 2.0}` (adds the 360w column and the
   2.0 row; 1.6 retained as an intermediate). Same `takeException()` guard.
2. **Sheet-at-2.0 tests (new).** Open `_TimeSimulatorSheet` and `_ParkingSheet`
   at 2.0 on 320 / 360 and assert no exception — the exact probes that caught
   the bug, made permanent. A brief note asserts `_VenueSheet` is already
   scrollable (regression guard against someone "simplifying" it back to a
   Column).
3. **Integrated-shell + Map @ 2.0 test (new).** Pump `buildRouter()` at 2.0,
   navigate all five tabs, assert no exception at each. Closes the fact that
   **`MapScreen` currently has zero test coverage.**

## 6. Verification / acceptance gate

Phase 5 is complete only when ALL hold:

- `flutter analyze` clean.
- `flutter test` green, including the extended matrix and the three new tests.
- The clamp reads `maxScaleFactor: 2.0` with the guarantee documented.
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
| Regression durability | 5 → target 9 | The 2.0 matrix + sheet + Map tests; Map going from 0 → covered is most of the lift |
| Honesty of guarantee | — target 10 | Bounded 2.0 claim, receipts in §2, NOT-AVAILABLE items named in §7 |
| Change surface / risk | — target 9 | Two `SingleChildScrollView` wraps + one constant + tests; no screen redesign |

## 10. Files

- Modify: `lib/main.dart:65` (clamp) + comment.
- Modify: `lib/screens/whats_on_screen.dart` (`_TimeSimulatorSheet` scroll wrap).
- Modify: `lib/screens/map_screen.dart` (`_ParkingSheet` scroll wrap).
- Modify: `test/widget/responsive_layout_test.dart` (matrix → +360w, +2.0).
- Create: `test/widget/text_scale_gauntlet_test.dart` (sheets @ 2.0 + shell/Map @ 2.0).
