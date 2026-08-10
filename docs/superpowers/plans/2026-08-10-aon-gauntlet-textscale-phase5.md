# Phase 5 — Gauntlet: lift text-scale to 2.0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lift the app-wide text-scale clamp from 1.6 → 2.0, hardening every surface (screens, shell, all three modal sheets) to render overflow-free at TextScaler 2.0, with permanent regression coverage including the app-root clamp policy itself.

**Architecture:** Three non-scrollable modal sheets overflow at 2.0 on a short viewport; each is fixed by wrapping its body in a `SingleChildScrollView` (one sheet is already safe and only gets a regression test). The inline text-scale clamp in `main.dart` is extracted into a pure, testable policy (`resolveAppTextScaler` + `kMaxTextScale = 2.0`) so the production ceiling can be asserted. The content screens and integrated shell already survive 2.0 (measured) and gain permanent short-viewport + 2.0 regression coverage.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12; flutter_riverpod, go_router, flutter_map, flutter_test.

**Design spec:** `docs/superpowers/specs/2026-08-10-aon-gauntlet-textscale-phase5-design.md` (frozen; incorporates the self-gauntlet + Raouf's 12-finding review). Every claim of overflow/no-overflow below was verified with throwaway probes during planning.

## Global Constraints

- **Text-scale ceiling is `2.0`** (`kMaxTextScale`). Bounded deliberately; do not remove the cap.
- **Do NOT run `dart format`.** The repo is not formatted to Dart 3.12 tall-style; a blanket reformat drifts unrelated files. Match the surrounding style by hand. `flutter analyze` must stay **clean** (zero issues) at every commit.
- **Dark-only app.** No light-theme work.
- **Every sheet test asserts the sheet actually opened *before* judging layout** (a unique-to-that-sheet widget), so a missed interaction can never false-pass as "no overflow".
- **Viewport height is load-bearing:** the sheet/short-screen regressions use **320×568** (≈ iPhone SE); tall viewports hide these overflows.
- **Branch:** all work on `feature/gauntlet-textscale-phase5` off `main`. Never commit to `main`.
- **Commits:** `type(scope): summary`, ending with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **TextScaler comparison idiom:** compare scalers by `scaler.scale(100)` (a number), never by `TextScaler` identity.

---

## Task 0: Preflight — branch + green baseline

**Files:** none (setup only).

- [ ] **Step 1: Create the feature branch**

```bash
git checkout main
git checkout -b feature/gauntlet-textscale-phase5
```

- [ ] **Step 2: Establish a green baseline**

```bash
flutter analyze
flutter test
```

Expected: analyze clean; all tests pass (~195). If anything is red here, STOP — the baseline must be green before changes.

---

## Task 1: What's On time-simulator sheet — scroll fix + 2.0 test

**Files:**
- Create: `test/widget/text_scale_sheets_test.dart`
- Modify: `lib/screens/whats_on_screen.dart` (`_TimeSimulatorSheet.build`, ~line 313)

**Interfaces:**
- Consumes: `WhatsOnScreen`, `baseClockProvider`, `FixedClock`, `EventInfo.at`.
- Produces: `text_scale_sheets_test.dart` (Tasks 2 adds to this same file).

- [ ] **Step 1: Write the failing test**

Create `test/widget/text_scale_sheets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/services/clock.dart';

void main() {
  testWidgets(
      "What's On time-simulator sheet: opens, no overflow, scrollable @ 320x640 / 2.0",
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        theme: AonTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const WhatsOnScreen(),
      ),
    ));

    // Open the sheet via the AppBar science icon (deterministic trigger).
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pump(const Duration(milliseconds: 400));

    // Mandatory: prove the sheet opened BEFORE judging layout.
    expect(find.text('Back to real time'), findsOneWidget);
    // No overflow, and the body is genuinely scrollable.
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test — verify it FAILS for the right reasons**

```bash
flutter test test/widget/text_scale_sheets_test.dart
```

Expected: FAIL — a `RenderFlex overflowed by ~1098 pixels` exception (and `SingleChildScrollView` not found). The `find.text('Back to real time')` assertion should PASS (the sheet opens; it just overflows).

- [ ] **Step 3: Apply the fix — wrap the sheet body in a `SingleChildScrollView`**

In `lib/screens/whats_on_screen.dart`, inside `_TimeSimulatorSheet.build`, change the outer return. Old:

```dart
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
```

New (wrap `Padding` in `SingleChildScrollView`):

```dart
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AonSpacing.space5,
            0,
            AonSpacing.space5,
            AonSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
```

Then re-indent the Column's children by 2 spaces and add the matching close: the block currently ending

```dart
          ],
        ),
      ),
    );
```

becomes (one extra `)` for the `SingleChildScrollView`):

```dart
            ],
          ),
        ),
      ),
    );
```

(Re-indentation is cosmetic — Dart ignores it — but keep it tidy since `dart format` is not run. If re-indenting the whole child list is noisy, the minimal valid form is to add only the `SingleChildScrollView(child:` wrapper and the single extra `)`, leaving inner indentation as-is; both compile and pass.)

- [ ] **Step 4: Run the test — verify it PASSES**

```bash
flutter test test/widget/text_scale_sheets_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/whats_on_screen.dart test/widget/text_scale_sheets_test.dart
git commit -m "fix(ui): scroll the What's On time-simulator sheet at large text (Phase 5)

Non-scrollable Column overflowed ~1098px at 320x640 / TextScaler 2.0.
Wrap body in SingleChildScrollView; add a 2.0 regression test that asserts
the sheet opens, does not overflow, and is scrollable.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Map sheets — expose for testing, fix Parking, test Parking + Venue

`_ParkingSheet` and `_VenueSheet` open via map-marker taps whose on-screen position depends on the map camera (viewport-sensitive, non-deterministic). Per spec §5.2, expose both sheet widgets with `@visibleForTesting` and drive them through a real `showModalBottomSheet` in the test — deterministic *and* faithful (real modal height constraint, production-matching `isScrollControlled`, so the Parking overflow still reproduces). Verified during planning: Parking overflows at 320×568 (west-6 by 315px), Venue does not; the `SingleChildScrollView` wrap resolves Parking.

**Files:**
- Modify: `lib/screens/map_screen.dart` (rename `_ParkingSheet`→`ParkingSheet`, `_VenueSheet`→`VenueSheet`, add `@visibleForTesting`; fix `ParkingSheet`)
- Modify: `test/widget/text_scale_sheets_test.dart` (add Parking + Venue tests + a shared modal harness)

**Interfaces:**
- Produces: `ParkingSheet({Key? key, required String parkingId})`, `VenueSheet({Key? key, required String venueId})` — public, `@visibleForTesting`. **Public widgets must declare a `key` param** (`use_key_in_widget_constructors` lint fails the analyze gate otherwise — private widgets are exempt, public ones are not), so add `super.key`.

- [ ] **Step 1: Write the failing tests (will not compile yet)**

Add to `test/widget/text_scale_sheets_test.dart` — new imports at top:

```dart
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/widgets/confidence_note.dart';
```

Add a shared harness helper and the two tests inside `main()`:

```dart
  // Opens `sheet` via a real modal bottom sheet at the given viewport / 2.0,
  // matching production's isScrollControlled flag so real modal height
  // constraints (and thus overflow) reproduce.
  Future<void> openModalSheet(
    WidgetTester tester,
    Widget sheet, {
    required bool scrollControlled,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AonTheme.build(),
        home: Builder(
          builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: scrollControlled,
                    builder: (_) => sheet,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Parking sheet: opens, no overflow, scrollable @ 320x568 / 2.0',
      (tester) async {
    // Production opens the parking sheet with isScrollControlled: false.
    await openModalSheet(tester, const ParkingSheet(parkingId: 'west-6'),
        scrollControlled: false, size: const Size(320, 568));

    // Mandatory: ConfidenceNote is unique to the parking sheet — proves it opened.
    expect(find.byType(ConfidenceNote), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('Venue sheet: already safe, opens, no overflow @ 320x568 / 2.0',
      (tester) async {
    // Production opens the venue sheet with isScrollControlled: true.
    await openModalSheet(tester, const VenueSheet(venueId: 'macquarie-theatre'),
        scrollControlled: true, size: const Size(320, 568));

    // DraggableScrollableSheet is unique to the venue sheet — proves it opened.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
```

- [ ] **Step 2: Run — verify compile failure (symbols are still private)**

```bash
flutter test test/widget/text_scale_sheets_test.dart
```

Expected: compile error — `ParkingSheet` / `VenueSheet` not defined.

- [ ] **Step 3: Expose the two sheet widgets**

In `lib/screens/map_screen.dart`:
1. Ensure the foundation import is present (it comes via `package:flutter/material.dart`, already imported — `@visibleForTesting` is available).
2. Rename the classes and constructors, annotate, and **add `super.key`** (public
   widgets require a `key` param — verified: without it, `flutter analyze`
   reports 2 `use_key_in_widget_constructors` infos and the gate fails; with it,
   "No issues found"):

```dart
@visibleForTesting
class VenueSheet extends ConsumerWidget {
  const VenueSheet({super.key, required this.venueId});
```

```dart
@visibleForTesting
class ParkingSheet extends ConsumerWidget {
  const ParkingSheet({super.key, required this.parkingId});
```

3. Update the two call sites inside `map_screen.dart`:

```dart
      builder: (_) => VenueSheet(venueId: venueId),
```

```dart
      builder: (_) => ParkingSheet(parkingId: parkingId),
```

- [ ] **Step 4: Run — Parking FAILS (overflow), Venue PASSES**

```bash
flutter test test/widget/text_scale_sheets_test.dart
```

Expected: the What's On test (Task 1) passes; **Venue passes**; **Parking FAILS** with `RenderFlex overflowed by ~315 pixels`. (Confirms the harness reproduces the real overflow.)

- [ ] **Step 5: Fix `ParkingSheet` — scroll wrap + `Expanded` on the name**

In `lib/screens/map_screen.dart`, `ParkingSheet.build`:

(a) Wrap the body in `SingleChildScrollView`. Old:

```dart
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
```

New:

```dart
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AonSpacing.space5,
            0,
            AonSpacing.space5,
            AonSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
```

…and add the one extra closing `)` at the end of the build (the `],\n        ),\n      ),\n    );` block gains a `),` for the `SingleChildScrollView`, mirroring Task 1 Step 3).

(b) Give the name `Text` a bounded width so a long name wraps instead of overflowing the header Row (defensive — current names are short). Old:

```dart
            Row(
              children: [
                const Icon(
                  Icons.local_parking_rounded,
                  color: AonColors.mapParking,
                ),
                const SizedBox(width: AonSpacing.space3),
                Text(parking.name, style: theme.textTheme.headlineSmall),
              ],
            ),
```

New (wrap the name in `Expanded`; it constrains width and lets the name wrap — it does not force a single line, which is the desired large-text behaviour):

```dart
            Row(
              children: [
                const Icon(
                  Icons.local_parking_rounded,
                  color: AonColors.mapParking,
                ),
                const SizedBox(width: AonSpacing.space3),
                Expanded(
                  child:
                      Text(parking.name, style: theme.textTheme.headlineSmall),
                ),
              ],
            ),
```

- [ ] **Step 6: Run — all sheet tests PASS**

```bash
flutter test test/widget/text_scale_sheets_test.dart
```

Expected: PASS (What's On, Parking, Venue).

- [ ] **Step 7: Verify analyze is clean (watch for `@visibleForTesting` misuse warnings)**

```bash
flutter analyze
```

Expected: clean. (`@visibleForTesting` symbols are used only inside `map_screen.dart` and the test — no warning.)

- [ ] **Step 8: Commit**

```bash
git add lib/screens/map_screen.dart test/widget/text_scale_sheets_test.dart
git commit -m "fix(ui): scroll the map parking sheet at large text; test both map sheets (Phase 5)

_ParkingSheet overflowed ~315px at 320x568 / 2.0 (non-scrollable Column in a
default modal). Wrap in SingleChildScrollView and give the name Text an
Expanded (defensive: wrap long names). _VenueSheet already scrolls
(DraggableScrollableSheet) — add a regression test proving it stays clean.
Both sheets exposed @visibleForTesting so tests drive a real modal
deterministically instead of tapping camera-dependent map markers.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Text-scale policy — extract, lift to 2.0, test the ceiling

**Files:**
- Create: `lib/app/text_scale.dart`
- Create: `test/widget/text_scale_policy_test.dart`
- Modify: `lib/main.dart` (builder + import + comment)

**Interfaces:**
- Produces: `const double kMaxTextScale`; `TextScaler resolveAppTextScaler(TextScaler os)`.

Two tests: a pure-function test of the policy, **and an app-root integration
test that proves `main.dart` actually wires it** — the latter is the one that
catches a revert of the production clamp (verified during planning: with the
current inline 1.6 clamp it reads 160, and after wiring it reads 200).

- [ ] **Step 1: Write both failing tests**

Create `test/widget/text_scale_policy_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/text_scale.dart';
import 'package:aon2026/main.dart';

void main() {
  // Compare scalers by the number they produce, not by TextScaler identity.
  double resolved(double os) =>
      resolveAppTextScaler(TextScaler.linear(os)).scale(100);

  test('policy function: floor 1.0, ceiling 2.0', () {
    expect(kMaxTextScale, 2.0);
    expect(resolved(0.5), 100); // below floor -> 1.0
    expect(resolved(1.0), 100);
    expect(resolved(1.6), 160); // passes through (exactly 160.0 — verified)
    expect(resolved(2.0), 200); // ceiling reached, not clipped
    expect(resolved(3.0), 200); // ceiling ENFORCED (would be 300 uncapped / 160 if reverted to 1.6)
  });

  // The steering-wheel test: proves the PRODUCTION app caps the effective scale
  // at 2.0, not just that the pure function is correct. Catches a revert of the
  // main.dart wiring (which the function test alone cannot see).
  testWidgets('app root caps effective text scale at 2.0', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.0; // OS asks for 3.0
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: AonApp()));
    await tester.pump(const Duration(milliseconds: 400));

    // Effective scale at a descendant of the app root is capped to 2.0.
    final ctx = tester.element(find.byType(Text).first);
    expect(MediaQuery.textScalerOf(ctx).scale(100), 200);
  });
}
```

- [ ] **Step 2: Run — verify it FAILS to compile**

```bash
flutter test test/widget/text_scale_policy_test.dart
```

Expected: compile error — `resolveAppTextScaler` / `kMaxTextScale` not defined.

- [ ] **Step 3: Create the policy**

Create `lib/app/text_scale.dart`:

```dart
import 'package:flutter/widgets.dart';

/// The app-wide text-scale ceiling (Phase 5 — Gauntlet).
///
/// Every surface is verified overflow-free at this scale (see
/// `docs/superpowers/specs/2026-08-10-aon-gauntlet-textscale-phase5-design.md`).
/// The cap is held here deliberately, so the OS cannot request a scale the app
/// has not been hardened and regression-tested against. Raising it past 2.0 is
/// future accessibility work, not a value judgement about large text.
const double kMaxTextScale = 2.0;

/// Resolves an OS-requested [TextScaler] into the app's supported range
/// `[1.0, kMaxTextScale]`. This is the single source of truth for the policy;
/// `AonApp`'s `MaterialApp.builder` calls it.
TextScaler resolveAppTextScaler(TextScaler os) => os.clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: kMaxTextScale,
    );
```

- [ ] **Step 4: Run — policy function PASSES, app-root STILL FAILS**

```bash
flutter test test/widget/text_scale_policy_test.dart
```

Expected: the `policy function` test PASSES; the `app root caps…` test **FAILS**
with `Expected: <200> Actual: <160.0>` — because `main.dart` still uses the
inline 1.6 clamp. This is the meaningful red proving the wiring is not yet done.

- [ ] **Step 5: Wire `main.dart` to use the policy**

In `lib/main.dart`, add the import:

```dart
import 'package:aon2026/app/text_scale.dart';
```

Replace the inline clamp in the `builder` (currently `lib/main.dart:59-71`). Old:

```dart
      builder: (context, child) {
        // Clamp the OS text scale. Users on a large accessibility setting are
        // still respected up to 1.6x, but beyond that the programme cards
        // overflow badly; capping is kinder than clipping.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
```

New:

```dart
      builder: (context, child) {
        // Clamp the OS text scale to the app's verified range (see
        // lib/app/text_scale.dart). Every surface is hardened to 2.0; the cap
        // is held there deliberately so the app never exposes an unverified
        // scale. Lifting past 2.0 is future accessibility work.
        final scale = resolveAppTextScaler(MediaQuery.textScalerOf(context));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
```

- [ ] **Step 6: Run — both policy tests now GREEN, then analyze + full suite**

```bash
flutter test test/widget/text_scale_policy_test.dart
flutter analyze
flutter test
```

Expected: both policy tests PASS (the app-root test now reads 200); analyze
clean (`textScaleFactorTestValue`/`clearTextScaleFactorTestValue` are **not**
deprecated — verified during planning); full suite green.

- [ ] **Step 7: Commit**

```bash
git add lib/app/text_scale.dart lib/main.dart test/widget/text_scale_policy_test.dart
git commit -m "feat(a11y): lift text-scale ceiling 1.6 -> 2.0 via a tested policy (Phase 5)

Extract the inline clamp into resolveAppTextScaler + kMaxTextScale=2.0 so both
the policy function AND the production app-root wiring are asserted (a pumped
AonApp caps an OS-requested 3.0 to an effective 2.0). Reverting the cap OR the
main.dart wiring now breaks the suite — the regression the inline clamp lacked.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Regression matrix lock-in — screens + shell at 2.0 and short viewport

These surfaces already survive 2.0 (measured during planning); this task makes that permanent, and bakes in the phase's key lesson — **viewport height is load-bearing**. Expected green on first run (lock-in, not a fix).

**Files:**
- Modify: `test/widget/responsive_layout_test.dart`
- Modify: `test/widget/shell_responsive_test.dart`

- [ ] **Step 1: Extend `responsive_layout_test.dart` — widths, 2.0, and a short-height block**

Replace the size/scale loops (currently widths `[320×640, 414×896]` × scales `[1.0, 1.6]`) so the matrix is widths `{320, 360, 414}` × scales `{1.0, 1.6, 2.0}`, and add a dedicated short-viewport block. Change:

```dart
  for (final size in [const Size(320, 640), const Size(414, 896)]) {
    for (final scale in [1.0, 1.6]) {
      screens.forEach((name, screen) {
        testWidgets('$name @ ${size.width.toInt()}x scale$scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(harness(screen, scale));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
```

to:

```dart
  for (final size in [
    const Size(320, 640),
    const Size(360, 780),
    const Size(414, 896),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      screens.forEach((name, screen) {
        testWidgets('$name @ ${size.width.toInt()}x scale$scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(harness(screen, scale));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  // Height is load-bearing: a realistic short phone (~iPhone SE) at 2.0 is where
  // fixed-height content overflows. Screens are ListView-scrollable and stay
  // clean here — this locks that in so a future fixed-height regression is caught.
  screens.forEach((name, screen) {
    testWidgets('$name @ 320x568 (short) scale2.0', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(screen, 2.0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
```

Also update the file's top doc-comment (currently says "maximum clamped text scale (1.6x)") to read `2.0`.

- [ ] **Step 2: Run — verify green**

```bash
flutter test test/widget/responsive_layout_test.dart
```

Expected: all PASS (screens already survive 2.0 at every width and the 320×568 short case).

- [ ] **Step 3: Extend `shell_responsive_test.dart` — navigate every tab at 2.0 (tall + short)**

Append inside `main()` (after the existing loop), a nav test per short/tall size. Add imports at the top of the file if missing:

```dart
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
```

Add:

```dart
  // The existing loop above only exercises the INITIAL (Home) route at 2.0.
  // StatefulShellRoute.indexedStack builds branches lazily, so Map/Program/Now/
  // Info are never built there. Navigate each tab at 2.0 on a tall AND a short
  // viewport — this is the only coverage MapScreen has.
  for (final size in [const Size(320, 640), const Size(320, 568)]) {
    testWidgets('shell navigates every tab, no overflow @ ${size.height.toInt()}h scale2.0',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
        ],
        child: MaterialApp.router(
          theme: AonTheme.build(),
          routerConfig: buildRouter(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      for (final icon in const [
        Icons.list_alt_outlined, // Program
        Icons.schedule_outlined, // Now
        Icons.map_outlined, // Map
        Icons.info_outline_rounded, // Info
        Icons.home_rounded, // back to Home
      ]) {
        final finder = find.byIcon(icon);
        if (finder.evaluate().isEmpty) continue;
        await tester.tap(finder, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });
  }
```

- [ ] **Step 4: Run — verify green**

```bash
flutter test test/widget/shell_responsive_test.dart
```

Expected: all PASS (shell nav, incl. Map, is clean at 2.0 on both heights).

- [ ] **Step 5: Full suite + analyze**

```bash
flutter analyze
flutter test
```

Expected: analyze clean; all green.

- [ ] **Step 6: Commit**

```bash
git add test/widget/responsive_layout_test.dart test/widget/shell_responsive_test.dart
git commit -m "test(a11y): permanent 2.0 + short-viewport regression for screens and shell (Phase 5)

responsive_layout: widths {320,360,414} x scales {1.0,1.6,2.0} + a dedicated
320x568 short case for all six screens. shell_responsive: navigate every tab
(incl. Map, previously zero coverage) at 2.0 on tall AND 320x568. Locks in the
phase's lesson that viewport height is load-bearing.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Verification gate (Phase 5 complete only when ALL hold)

- [ ] **Static + tests**

```bash
flutter analyze
flutter test
```

Expected: analyze clean; all green, including `text_scale_policy_test.dart` (asserts the 2.0 ceiling), the three sheet tests, and the extended matrices.

- [ ] **Platform build gate** — record each as `PASS / FAIL / NOT AVAILABLE`:

```bash
flutter build ios --simulator --no-codesign
flutter build apk --debug
```

iOS simulator build expected PASS. Android build: PASS if the Android toolchain is present, else record `NOT AVAILABLE` (build availability ≠ emulator availability; Android *runtime* remains `NOT AVAILABLE`).

- [ ] **On-device iOS pass at 2.0 (best-effort, honestly reported)**

Boot an iOS simulator, run the app, and set an effective 2.0 text scale. Prove the scale is *effective* (not assumed): temporarily add a debug probe at a descendant of the app root that logs `MediaQuery.textScalerOf(context).scale(100)` and confirm it reports `200` when the OS requests ≥2.0 — evidence of *platform request → production clamp → effective 2.0*. Visually confirm every screen + the What's On and Parking sheets are legible and unclipped (ellipsis truncation does not throw, so only a human eye catches it). Remove the debug probe before the final commit. Record findings (including any critical truncation fixed) as a short runtime-results note appended to the design spec.

- [ ] **Finish the branch** — REQUIRED SUB-SKILL: use superpowers:finishing-a-development-branch (verify green suite → present merge options → execute → clean up).

## File summary

| File | Change | Task |
|---|---|---|
| `lib/app/text_scale.dart` | **create** — `kMaxTextScale`, `resolveAppTextScaler` | 3 |
| `lib/main.dart` | use the policy; comment | 3 |
| `lib/screens/whats_on_screen.dart` | `_TimeSimulatorSheet` scroll wrap | 1 |
| `lib/screens/map_screen.dart` | expose `ParkingSheet`/`VenueSheet` `@visibleForTesting`; Parking scroll wrap + name `Expanded` | 2 |
| `test/widget/text_scale_sheets_test.dart` | **create** — 3 sheet tests + modal harness | 1, 2 |
| `test/widget/text_scale_policy_test.dart` | **create** — policy-function test **+ app-root wiring test** (pumps `AonApp`, proves effective cap = 2.0) | 3 |
| `test/widget/responsive_layout_test.dart` | matrix +360w +2.0 + 320×568 screens | 4 |
| `test/widget/shell_responsive_test.dart` | tab-nav @ 2.0 (tall + short) | 4 |
