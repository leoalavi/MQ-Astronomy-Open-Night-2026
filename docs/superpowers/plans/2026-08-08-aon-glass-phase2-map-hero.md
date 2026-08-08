# Phase 2 — Map + Hero Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Deliver the Phase 2 glass payoff — a floating glass **map control island** (zoom + recenter) over
the live tiles, faithful **glass filter chips** (unselected glass / selected solid amber), and a **hero glass
date pill** over the galaxy photo — by consuming the Phase 1 `GlassSurface` primitive, with an explicit,
reasoned non-adoption set (app bars / FAB / sheets / pins / attribution stay solid).

**Architecture:** Pure consumption of the shipped Phase 1 glass stack (`GlassSurface`, `AonGlass`,
`GlassShaderCache`, `resolveGlassRenderMode`) — **zero** new rendering/policy code. Two new widgets
(`MapControlIsland`, `MapCategoryFilterBar`) are extracted so they are unit-testable **without** mounting the
widget-test-hostile live `FlutterMap`; a pure `clampZoom` helper proves the camera math; the live camera
wiring and the real refraction shader are verified on-device (documented coverage bounds).

**Tech Stack:** Flutter 3.44.7 / Dart 3.12, flutter_map 8.3.1, flutter_riverpod, go_router, `dart:ui`
`ImageFilter.shader` (Impeller-only). Design spec:
`docs/superpowers/specs/2026-08-08-aon-glass-phase2-map-hero-design.md` (frozen).

## Global Constraints

Copied verbatim from the spec; every task's requirements implicitly include this section.

- **Naming:** "Liquid Glass-inspired" / "Glass UI layer" only — never "Liquid Glass" unqualified.
- **No new rendering/policy code:** every new *glass* surface uses `GlassSurface(variant: control)`. Selected
  chips are deliberately **solid** (not glass). No changes to `glass_surface.dart`, `aon_glass.dart`,
  `glass_shader.dart`, `nav_metrics.dart`, `liquid_tab_bar.dart`, `pubspec.yaml`, `main.dart`.
- **Governance rule 1 (reworded):** no **nested/overlapping** glass. A grouped control = one glass parent
  with plain children; **independent** sibling controls may each be glass (the chips are independent siblings,
  exactly as MQ does them). Never a glass child inside a glass parent.
- **Governance rules 2–4 (non-adoptions):** bottom sheets stay solid `night900`; the Directions FAB stays
  solid amber; content-page AppBars stay opaque `night950`; marker pins + OSM attribution stay solid. Do
  **not** touch them.
- **Zoom-at-bounds = enabled, safe no-op** via `clampZoom` (frozen). The island stays **stateless** (injected
  callbacks, no `MapController`/camera-event dependency). Reactive disabled-state is deferred, out of scope.
- **Zoom bounds come from `MapConfig.minZoom`/`maxZoom`** (currently 14/19) — never the literals in code/tests.
- **Night ergonomics:** dark-only; ≥13px readable text; **≥56px tap targets** (`AonSpacing.minTapTarget`) on
  the island buttons **and** the chips; larger/softer radii.
- **`control` is a rendering tier, not an interactivity role** — the non-interactive hero pill legitimately
  uses `control` and carries no button semantics.
- **Accessibility:** custom chips must carry **one coherent** `Semantics(button, selected, label)` node (no
  duplicate label read); reduced-motion → frost, high-contrast → solid are inherited from the ladder.
- **Coverage bounds (state, don't hide):** (a) the real refraction shader never runs under `flutter test`;
  (b) the live camera movement is not asserted by a mounted-map test — both verified on-device.

---

## File Structure

**Create**
- `lib/widgets/map_control_island.dart` — `clampZoom` (pure top-level) + `MapControlIsland` (one
  `GlassSurface(control)` with three plain `IconButton`s; injected `onZoomIn`/`onZoomOut`/`onRecenter`).
- `lib/widgets/map_category_filter_bar.dart` — public `MapCategoryFilterBar` + private `_MapCategoryChip`
  (glass unselected / solid-amber selected; ≥56 target; single-node semantics).
- `test/widget/map_control_island_test.dart`
- `test/widget/map_category_filter_bar_test.dart`
- `test/widget/hero_glass_test.dart`

**Modify**
- `lib/screens/map_screen.dart` — drop the app-bar Recentre action; mount `MapControlIsland` (`Positioned`,
  right/upper) wired to `_controller` via `clampZoom`; replace the private `_CategoryFilterBar` with
  `MapCategoryFilterBar`; delete the old private class. `_MapAttribution`/`_MarkerPin`/FAB untouched.
- `lib/screens/home_screen.dart` — wrap the `_Hero` date/time row in a `GlassSurface(control)` pill.

---

## Task 1: `clampZoom` helper + `MapControlIsland` widget

**Files:**
- Create: `lib/widgets/map_control_island.dart`
- Test: `test/widget/map_control_island_test.dart`

**Interfaces:**
- Produces: `double clampZoom(double current, double delta, {required double min, required double max})`;
  `class MapControlIsland extends StatelessWidget` with named required `VoidCallback onZoomIn, onZoomOut,
  onRecenter`.
- Consumes: `GlassSurface`, `GlassVariant` (`lib/widgets/glass_surface.dart`); `AonColors`, `AonSpacing`.

- [ ] **Step 1: Write the failing test**

`test/widget/map_control_island_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/map_control_island.dart';

void main() {
  group('clampZoom', () {
    test('in-range steps change the value', () {
      expect(clampZoom(16, 1, min: 14, max: 19), 17);
      expect(clampZoom(16, -1, min: 14, max: 19), 15);
    });
    test('clamps at the upper bound (no-op past max)', () {
      expect(clampZoom(19, 1, min: 14, max: 19), 19);
      expect(clampZoom(18.5, 1, min: 14, max: 19), 19);
    });
    test('clamps at the lower bound (no-op past min)', () {
      expect(clampZoom(14, -1, min: 14, max: 19), 14);
    });
  });

  Widget harness({
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onRecenter,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: MapControlIsland(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onRecenter: onRecenter,
          ),
        ),
      ),
    );
  }

  testWidgets('renders ONE glass surface with three buttons', (tester) async {
    await tester.pumpWidget(harness(
      onZoomIn: () {}, onZoomOut: () {}, onRecenter: () {},
    ));
    expect(find.byType(GlassSurface), findsOneWidget); // one control layer, not three
    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
  });

  testWidgets('each button fires its injected callback', (tester) async {
    var zin = 0, zout = 0, rec = 0;
    await tester.pumpWidget(harness(
      onZoomIn: () => zin++, onZoomOut: () => zout++, onRecenter: () => rec++,
    ));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    expect([zin, zout, rec], [1, 1, 1]);
  });

  testWidgets('tap targets are >= 56 at 1.0 and 2.0 text scale', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(child: MapControlIsland(
              onZoomIn: () {}, onZoomOut: () {}, onRecenter: () {},
            )),
          ),
        ),
      ));
      final size = tester.getSize(find.widgetWithIcon(IconButton, Icons.add_rounded));
      expect(size.height, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
      expect(size.width, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/map_control_island_test.dart`
Expected: FAIL — `map_control_island.dart` / `MapControlIsland` / `clampZoom` do not exist yet.

- [ ] **Step 3: Write the minimal implementation**

`lib/widgets/map_control_island.dart`:
```dart
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// Clamps a zoom step to `[min, max]`. Pure and unit-tested. A step past a bound
/// is a safe no-op (returns the bound) — this is what lets the zoom buttons stay
/// enabled without live-camera state (Phase 2 spec §5.2).
double clampZoom(double current, double delta,
    {required double min, required double max}) {
  final next = current + delta;
  if (next < min) return min;
  if (next > max) return max;
  return next;
}

/// A floating glass island of map controls: zoom in / zoom out / recentre.
///
/// One [GlassSurface] with three plain [IconButton]s — a single glass control
/// layer, never glass-on-glass. It takes injected callbacks and carries **no**
/// `MapController` dependency, so it is unit-testable without a live `FlutterMap`.
/// The screen wires the callbacks to the controller (via [clampZoom]).
class MapControlIsland extends StatelessWidget {
  const MapControlIsland({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.add_rounded, 'Zoom in', onZoomIn),
          _divider(),
          _button(Icons.remove_rounded, 'Zoom out', onZoomOut),
          _divider(),
          _button(Icons.my_location_rounded, 'Recentre', onRecenter),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: AonColors.contentPrimary,
      iconSize: AonSpacing.iconDefault,
      constraints: const BoxConstraints(
        minWidth: AonSpacing.minTapTarget,
        minHeight: AonSpacing.minTapTarget,
      ),
    );
  }

  Widget _divider() => Container(
        width: AonSpacing.minTapTarget - 24,
        height: 1,
        color: Colors.white.withValues(alpha: 0.12),
      );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/map_control_island_test.dart`
Expected: PASS (all 6 tests). If the target-size test fails, confirm the `constraints` on the `IconButton`.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/map_control_island.dart test/widget/map_control_island_test.dart
git commit -m "feat(map): MapControlIsland glass control + clampZoom helper (Phase 2)"
```

---

## Task 2: `MapCategoryFilterBar` (glass filter chips)

**Files:**
- Create: `lib/widgets/map_category_filter_bar.dart`
- Test: `test/widget/map_category_filter_bar_test.dart`

**Interfaces:**
- Produces: `class MapCategoryFilterBar extends StatelessWidget` with `{required Set<VenueCategory> selected,
  required ValueChanged<VenueCategory> onToggle}`.
- Consumes: `VenueCategory` (`lib/models/venue.dart`); `VenueStyle` (`lib/utils/venue_style.dart`);
  `GlassSurface`/`GlassVariant`; `AonColors`, `AonSpacing`.

- [ ] **Step 1: Write the failing test**

`test/widget/map_category_filter_bar_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/map_category_filter_bar.dart';

void main() {
  Widget harness({
    required Set<VenueCategory> selected,
    ValueChanged<VenueCategory>? onToggle,
    double scale = 1.0,
  }) {
    return MaterialApp(
      theme: AonTheme.build(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(
            alignment: Alignment.topCenter,
            child: MapCategoryFilterBar(
              selected: selected,
              onToggle: onToggle ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  // A stable label present in the bar (parking is never `other`).
  const parking = 'Parking';
  const toilets = 'Toilets';

  testWidgets('unselected chip is glass', (tester) async {
    await tester.pumpWidget(harness(selected: const {}));
    final glass = find.ancestor(
      of: find.text(parking),
      matching: find.byType(GlassSurface),
    );
    expect(glass, findsOneWidget);
  });

  testWidgets('selected chip is solid amber (no glass)', (tester) async {
    await tester.pumpWidget(harness(selected: {VenueCategory.parking}));
    final glass = find.ancestor(
      of: find.text(parking),
      matching: find.byType(GlassSurface),
    );
    expect(glass, findsNothing); // solid, not glass
    final label = tester.widget<Text>(find.text(parking));
    expect(label.style?.color, AonColors.onAccent); // brand-on-amber
  });

  testWidgets('tapping a chip fires onToggle with its category', (tester) async {
    VenueCategory? toggled;
    await tester.pumpWidget(harness(selected: const {}, onToggle: (c) => toggled = c));
    await tester.tap(find.text(parking));
    expect(toggled, VenueCategory.parking);
  });

  testWidgets('chip hit target >= 56 at 1.0 and 2.0', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(harness(selected: const {}, scale: scale));
      final ink = find.ancestor(of: find.text(parking), matching: find.byType(InkWell));
      expect(tester.getSize(ink).height, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
    }
  });

  testWidgets('one coherent semantics node per chip; selected flag tracks state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(selected: {VenueCategory.parking}));

    // Single node carries the label (no duplicate read from the inner Text).
    expect(find.bySemanticsLabel(parking), findsOneWidget);

    final selectedSem = tester.getSemantics(find.bySemanticsLabel(parking));
    final unselectedSem = tester.getSemantics(find.bySemanticsLabel(toilets));
    expect(selectedSem.flagsCollection.isButton, isTrue);
    // Avoid Tristate literals / deprecated APIs: selected differs from unselected.
    expect(selectedSem.flagsCollection.isSelected,
        isNot(unselectedSem.flagsCollection.isSelected));
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/map_category_filter_bar_test.dart`
Expected: FAIL — the file/class does not exist.

- [ ] **Step 3: Write the minimal implementation**

`lib/widgets/map_category_filter_bar.dart`:
```dart
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// Horizontal category filter row for the map.
///
/// Extracted from the map screen's private `_CategoryFilterBar` so it can be
/// widget-tested **without** mounting the live `FlutterMap` (spec P1-#1). It is
/// map-specific presentation, not a glass primitive: the state (`selected`) lives
/// in `MapScreen`; this widget only renders + reports toggles.
///
/// Faithful to the reference `_CategoryChip`: glass carries only the *inactive*
/// state; the selected chip is solid brand amber.
class MapCategoryFilterBar extends StatelessWidget {
  const MapCategoryFilterBar({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<VenueCategory> selected;
  final ValueChanged<VenueCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    final categories = VenueCategory.values
        .where((c) => c != VenueCategory.other)
        .toList(growable: false);
    return SizedBox(
      height: 60, // holds the >=56 chip target with breathing room
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AonSpacing.space4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AonSpacing.space2),
        itemBuilder: (context, i) {
          final category = categories[i];
          return _MapCategoryChip(
            category: category,
            isSelected: selected.contains(category),
            onTap: () => onToggle(category),
          );
        },
      ),
    );
  }
}

class _MapCategoryChip extends StatelessWidget {
  const _MapCategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final VenueCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = VenueStyle.colorFor(category);
    final fg = isSelected ? AonColors.onAccent : AonColors.contentPrimary;
    final radius = BorderRadius.circular(AonSpacing.radiusFull);

    final tappable = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AonSpacing.minTapTarget),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AonSpacing.space3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    VenueStyle.iconFor(category),
                    size: AonSpacing.iconSm,
                    color: isSelected ? AonColors.onAccent : categoryColor,
                  ),
                  const SizedBox(width: AonSpacing.space2),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Widget visual = isSelected
        ? DecoratedBox(
            decoration: BoxDecoration(color: AonColors.amber, borderRadius: radius),
            child: tappable,
          )
        : GlassSurface(
            variant: GlassVariant.control,
            borderRadius: radius,
            borderColor: categoryColor.withValues(alpha: 0.5),
            child: tappable,
          );

    // One coherent semantics node; the inner visual is excluded so the label is
    // read exactly once (spec P2-#7).
    return Semantics(
      button: true,
      selected: isSelected,
      label: category.label,
      onTap: onTap,
      child: ExcludeSemantics(child: visual),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/map_category_filter_bar_test.dart`
Expected: PASS (all 5 tests). Note: under `flutter test` Impeller is off, so the unselected chip's
`GlassSurface` renders the **frost** rung — `find.byType(GlassSurface)` still matches (that is the assertion).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/map_category_filter_bar.dart test/widget/map_category_filter_bar_test.dart
git commit -m "feat(map): glass MapCategoryFilterBar (glass unselected / solid-amber selected)"
```

---

## Task 3: Hero glass date pill

**Files:**
- Modify: `lib/screens/home_screen.dart` (the `_Hero` widget, date/time `Row` at ~lines 223-245)
- Test: `test/widget/hero_glass_test.dart`

**Interfaces:**
- Consumes: `GlassSurface`/`GlassVariant`; existing `AonColors`, `AonSpacing`, `EventInfo`, `TimeFormat`,
  `theme.textTheme` already imported by `home_screen.dart`.

- [ ] **Step 1: Write the failing test**

`test/widget/hero_glass_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/glass_surface.dart';

void main() {
  Widget harness({bool highContrast = false, bool reduceMotion = false, double scale = 1.0}) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        theme: AonTheme.build(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(scale),
            ),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  // The hero date row renders "<long date>  ·  <range>"; anchor on the separator.
  Finder dateText() => find.textContaining('·').first;

  testWidgets('hero date is wrapped in a GlassSurface', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(
      find.ancestor(of: dateText(), matching: find.byType(GlassSurface)),
      findsOneWidget,
    );
  });

  testWidgets('high-contrast renders the solid rung (no BackdropFilter in the pill)',
      (tester) async {
    await tester.pumpWidget(harness(highContrast: true));
    await tester.pump();
    final pill = find.ancestor(of: dateText(), matching: find.byType(GlassSurface));
    expect(
      find.descendant(of: pill, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

  testWidgets('reduced-motion renders the frost rung (BackdropFilter present)',
      (tester) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pump();
    final pill = find.ancestor(of: dateText(), matching: find.byType(GlassSurface));
    expect(
      find.descendant(of: pill, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
  });

  testWidgets('no overflow at 320px across text scales', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      await tester.pumpWidget(harness(scale: scale));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/hero_glass_test.dart`
Expected: FAIL — the date row is not yet wrapped in a `GlassSurface` (first test finds none).

- [ ] **Step 3: Write the minimal implementation**

In `lib/screens/home_screen.dart`, add the import:
```dart
import 'package:aon2026/widgets/glass_surface.dart';
```
Replace the date/time `Row(...)` (the last child of the hero `Column`, ~lines 223-245) with:
```dart
LayoutBuilder(
  builder: (context, constraints) => GlassSurface(
    variant: GlassVariant.control,
    borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
    child: ConstrainedBox(
      // maxWidth = the available hero text-column width; the pill never exceeds
      // the hero's horizontal content bounds (spec §5.4). No padding on the
      // GlassSurface itself — it is inside the bound so the pill can't overflow.
      constraints: BoxConstraints(maxWidth: constraints.maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space3,
          vertical: AonSpacing.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_rounded,
              size: AonSpacing.iconSm,
              color: AonColors.contentSecondary,
            ),
            const SizedBox(width: AonSpacing.space2),
            Flexible(
              child: Text(
                '${TimeFormat.longDate(EventInfo.startsAt)}  ·  '
                '${TimeFormat.range(EventInfo.startsAt, EventInfo.endsAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AonColors.contentSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/hero_glass_test.dart`
Expected: PASS (4 tests). If the high-contrast test fails, confirm `GlassSurface`'s solid rung skips
`BackdropFilter` (it does — see `glass_surface.dart` `_solid`).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart test/widget/hero_glass_test.dart
git commit -m "feat(home): hero glass date pill over the galaxy photo (Phase 2)"
```

---

## Task 4: Integrate into `map_screen.dart`

**Files:**
- Modify: `lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: `MapControlIsland` + `clampZoom` (Task 1); `MapCategoryFilterBar` (Task 2); existing
  `MapController _controller`, `MapConfig`, `Routes`.

> **No new widget test here (documented bound R2/R3):** the live `FlutterMap`/`DarkTileLayer` fetch network
> tiles with no `errorBuilder`, so `MapScreen` is not cleanly widget-testable. This task's verification is
> `flutter analyze` clean + the full existing suite staying green + the on-device gate in Task 5. The camera
> *math* is already proven by `clampZoom` (Task 1); the *wiring* is verified on-device.

- [ ] **Step 1: Remove the app-bar Recentre action**

In the `AppBar`, delete the `actions: [...]` Recentre `IconButton` so the Map AppBar is title-only:
```dart
appBar: AppBar(
  title: const Text('Map'),
),
```

- [ ] **Step 2: Swap the filter bar for the extracted component**

Add the import:
```dart
import 'package:aon2026/widgets/map_category_filter_bar.dart';
import 'package:aon2026/widgets/map_control_island.dart';
```
Replace the `_CategoryFilterBar(...)` in the `Column` with:
```dart
MapCategoryFilterBar(
  selected: _visible,
  onToggle: (category) => setState(() {
    _visible.contains(category)
        ? _visible.remove(category)
        : _visible.add(category);
  }),
),
```
Delete the now-unused private `_CategoryFilterBar` class.

- [ ] **Step 3: Mount the control island in the map Stack**

Add, as a child of the map `Stack` (sibling of the `FlutterMap` and the attribution `Positioned`),
placed on the right edge / upper map area (rule per spec §5.2):
```dart
Positioned(
  top: AonSpacing.space4,
  right: AonSpacing.space4,
  child: MapControlIsland(
    onZoomIn: () => _controller.move(
      _controller.camera.center,
      clampZoom(_controller.camera.zoom, 1,
          min: MapConfig.minZoom, max: MapConfig.maxZoom),
    ),
    onZoomOut: () => _controller.move(
      _controller.camera.center,
      clampZoom(_controller.camera.zoom, -1,
          min: MapConfig.minZoom, max: MapConfig.maxZoom),
    ),
    onRecenter: () => _controller.move(
      MapConfig.campusCentre,
      MapConfig.initialZoom,
    ),
  ),
),
```

- [ ] **Step 4: Verify analyze + full regression suite**

Run: `flutter analyze`
Expected: No issues (confirm no unused imports remain — e.g. if `_CategoryFilterBar`'s removal orphaned an
import). Then run the whole suite:
Run: `flutter test`
Expected: the pre-Phase-2 baseline plus the new tests all green; **no regression**.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/map_screen.dart
git commit -m "feat(map): mount glass control island + glass filter bar; drop app-bar recenter"
```

---

## Task 5: Verification & parity gate

**Files:** none (evidence-gathering; may update the spec's §8 evidence lines with results).

Record **each** item as `PASS` / `FAIL` / `NOT AVAILABLE` (never inherited from a prior phase).

- [ ] **Step 1: Static + tests baseline**

Run: `flutter analyze` → clean (or document pre-existing exceptions).
Run: `flutter test` → capture the before/after totals (baseline captured before Task 1; all pre-existing
tests green, new tests green). Report the numbers rather than a hard-coded count.

- [ ] **Step 2: Builds**

Run: `flutter build ios --debug --no-codesign` and `flutter build apk --debug`.
Expected: both build. Record PASS/FAIL.

- [ ] **Step 3: iOS runtime + shader/refraction evidence (two-part, spec P2-#11)**

Boot an iOS simulator, install, launch. Verify:
- map controls actually recenter/zoom and **clamp** at `MapConfig.min/maxZoom` (live-camera wiring);
- `GlassShaderCache.ready == true` at runtime (support + cache), **and** pan the map under the stationary
  island so tiles distort through the glass (motion proves the refraction path, not a flat frost);
- hero: compare the shader render against a forced-frost render of the pill (a still of frost ≈ refraction,
  so the comparison is the evidence);
- **hero legibility** (spec P2-#10): the date text is readable over the **brightest** (galaxy core) and
  **darkest** parts of the photo in shader / frost / solid; if the default `control` translucency fails over
  the core, apply the darker `color:` tint fallback (§5.4) and re-verify.

Capture screenshots. Record each as PASS/FAIL/NOT AVAILABLE.
(If `xcode-select` points at CommandLineTools, the MCP attach needs
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`; otherwise fall back to
`xcrun simctl` install/launch/`io screenshot` and say so explicitly.)

- [ ] **Step 4: Frost fallback + reduced-motion/high-contrast**

Verify frost where the shader is unavailable; reduced-motion → frost, high-contrast → solid, all legible.
Record PASS/FAIL.

- [ ] **Step 5: Android runtime**

If an emulator is available, verify map controls + hero. Else record `NOT AVAILABLE`.

- [ ] **Step 6: On-device layout clearances (spec P2-#8)**

Confirm the control island clears **all four** neighbours by ≥ `AonSpacing.space4`: category-filter row,
Directions FAB, attribution, and the system/safe-area edges. Confirm no overlap at the platform text-scale
max (integrated app is capped at 1.6). Record PASS/FAIL.

- [ ] **Step 7: Performance sanity pass (spec §9, measured in aon2026)**

Prefer profile mode on a real device: frame jank while scrolling/panning behind the glass over live tiles,
rapid zoom taps, shader warm-up on first map paint. If profiling can't be run here, record `NOT AVAILABLE`.

- [ ] **Step 8: Parity + hostile audit**

Visual parity comparison vs MQ_Journey (map controls + glass-over-imagery). Then a second hostile audit for
glass-on-glass, legibility, or governance breaches introduced by the port. Record findings + fixes.

- [ ] **Step 9: Finish the branch**

**REQUIRED SUB-SKILL:** use superpowers:finishing-a-development-branch — verify tests, present options,
execute the chosen one.

---

## Self-Review

**Spec coverage:** island (§5.2, T1+T4), filter chips (§5.3, T2+T4), hero pill (§5.4, T3), non-adoptions
(§6 — T4 leaves FAB/attribution/pins/app bar untouched), extraction/testability (P1-#1, T2), zoom-bounds
frozen (P1-#3, T1/T4 constants + clampZoom), governance rule 1 (independent glass siblings — T2 chips),
56px targets (T1+T2), single-node semantics (T2), legibility split (structure in T3, runtime in T5),
two-part shader evidence (T5), baseline-not-171 (T5), coverage bounds (T4 note + T5). All mapped.

**Placeholder scan:** no TBD/TODO; every code step is complete and runnable. The hero `maxWidth` is a
derived rule (`constraints.maxWidth`), not a magic number.

**Type consistency:** `clampZoom(double, double, {min, max}) → double` used identically in T1 test, T1 impl,
and T4 wiring. `MapControlIsland({onZoomIn, onZoomOut, onRecenter})` and `MapCategoryFilterBar({selected,
onToggle})` signatures match across create/consume. `flutter_map` API (`_controller.camera.center/.zoom`,
`move`) confirmed against 8.3.1. Semantics assertions use `flagsCollection.isButton` (bool) and compare
`.isSelected` values (avoids the Tristate landmine + deprecated `hasFlag`).
