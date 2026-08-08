# Glass Foundation + Signature Liquid Navigation — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give aon2026 a floating Liquid-Glass tab-bar island with the metaball lens, gel-press, per-tab FX (incl. a new astronomy-native `orbit`), haptics, and a shader→frost→solid fallback ladder — re-skinned to aon2026's amber/night identity, every existing route preserved.

**Architecture:** Port MQ_Journey's proven glass + `LiquidTabBar` onto aon2026's existing theme. Generic primitives take caller-injected colour (`LiquidTabBar`) or read the `AonGlass` token layer (`GlassSurface`); never import `AonColors`/`AonTheme` into a primitive. The shader is Impeller-only and degrades to frost/solid; its load is non-fatal at startup.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12, `flutter_riverpod`, `go_router`, `flutter_map`, GLSL fragment shader via `dart:ui` `FragmentProgram` + `ImageFilter.shader`.

**Reference implementation (authoritative — read/copy, never retype from memory):**
`/Users/raoof.r12/Desktop/Raouf/MQ_Journey` (`$REF` below).
**Design spec (source of truth for scope/decisions):**
`docs/superpowers/specs/2026-08-08-aon-glass-liquid-nav-phase1-design.md`.

## Global Constraints

- SDK floor already set: `pubspec.yaml` `flutter: '>=3.44.0'`. Do not change dependencies.
- **Naming:** "Liquid Glass-inspired" / "Glass UI layer" only — never "Liquid Glass" unqualified in code/comments/copy.
- **Portability:** `LiquidTabBar` + shader infra take purely caller-injected colour/config (no token import). `GlassSurface → AonGlass` allowed. **No** portable primitive imports `AonColors`/`AonTheme`.
- **aon2026 identity preserved:** dark-only, `AonColors`/`AonSpacing`/`AonTypography`/`AonTheme` unchanged; night-readability floor **≥13px** (no text below 13px); 56px interaction targets; hero + dark map tiles + product behaviour untouched.
- **Shader startup is non-fatal:** `GlassShaderCache.ensureLoaded()` must never throw; shader-init failure MUST NOT prevent app startup. Binding initialised first.
- **Reduced motion:** `MediaQuery.disableAnimationsOf(context)` = motion only (omit decorative transforms, do not animate with `Duration.zero`). `highContrast` is separate → forces solid.
- **Verification honesty:** results are `PASS` / `FAIL` / `NOT AVAILABLE`; a build ≠ shader-render proof (Impeller runtime-dependent); automated tests never exercise the shader (frost in the test harness) — shader path is runtime-only evidence.
- **Lint:** `analysis_options.yaml` enforces `prefer_single_quotes`, `prefer_const_constructors`, `always_declare_return_types`, `unawaited_futures`, etc. Keep `flutter analyze` clean.
- Do **not** blanket-run `dart format` — the repo has pre-existing Dart-3.12 formatter drift across all files; match surrounding style by hand (see the repo's memory note).

---

## File Structure

**Create**
- `shaders/glass_refraction.frag` — GLSL refraction shader (copied verbatim from `$REF`).
- `lib/app/theme/aon_glass.dart` — `AonGlass` tokens (owns aon2026 tint/opacity/shader params).
- `lib/utils/haptics.dart` — `AonHaptics` (impact/selection wrappers).
- `lib/widgets/glass_shader.dart` — `GlassShaderCache` (loads/caches the FragmentProgram).
- `lib/widgets/glass_surface.dart` — `GlassSurface` + `resolveGlassRenderMode` (3-tier + fallback ladder).
- `lib/widgets/nav_metrics.dart` — `AonNavMetrics` (single source: bar height + floating-nav clearance).
- `lib/widgets/liquid_tab_bar.dart` — `LiquidTabBar` + `TabFx` (+ new `orbit`/`_OrbitFx`, `selectedColor`, reduced-motion, ≥13px label).
- Tests: `test/widget/glass_surface_test.dart`, `test/widget/aon_haptics_test.dart`, `test/widget/liquid_tab_bar_test.dart`, `test/widget/nav_metrics_test.dart`, `test/widget/app_shell_test.dart`, `test/widget/shell_clearance_test.dart`, `test/widget/shell_responsive_test.dart`.

**Modify**
- `pubspec.yaml` — register the shader.
- `lib/main.dart` — async `main()` + non-fatal shader preload.
- `lib/widgets/app_shell.dart` — glass island + `LiquidTabBar`, driven by `AonNavMetrics`.
- `lib/screens/{home,program,whats_on,map,info}_screen.dart` — consume `AonNavMetrics.clearance(context)`.
  (The existing `test/widget/responsive_layout_test.dart` is left untouched; shell coverage is a new file.)

**Reference token values (from `lib/app/theme/aon_colors.dart`, already in the repo):**
`night950 0xFF05070F` · `night900 0xFF0B0F1D` · `night800 0xFF141A2E` · `night700 0xFF232B45` · `amber 0xFFFFB945` · `contentPrimary 0xFFF2F4FA` · `contentSecondary 0xFFB9C0D4`.

---

## Task 1: Branch + shader asset + pubspec registration

**Files:**
- Create: `shaders/glass_refraction.frag`
- Modify: `pubspec.yaml` (the `flutter:` block)

**Interfaces:**
- Produces: the asset `shaders/glass_refraction.frag` registered under `flutter: shaders:`, loadable via `FragmentProgram.fromAsset('shaders/glass_refraction.frag')`.

- [ ] **Step 1: Create a feature branch** (we start on `main`).

```bash
cd /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026
git checkout -b feature/glass-liquid-nav-phase1
```

- [ ] **Step 2: Copy the shader verbatim from the reference** (never retype GLSL).

```bash
mkdir -p shaders
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/shaders/glass_refraction.frag shaders/glass_refraction.frag
```

- [ ] **Step 3: Register the shader in `pubspec.yaml`.** Find the `flutter:` block:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

Replace it with (add the `shaders:` list — order per Flutter docs: `shaders:` before `assets:` is fine):

```yaml
flutter:
  uses-material-design: true
  shaders:
    - shaders/glass_refraction.frag
  assets:
    - assets/images/
```

- [ ] **Step 4: Verify the project still resolves and analyzes.**

Run: `flutter pub get && flutter analyze`
Expected: `Got dependencies!` and `No issues found!`

- [ ] **Step 5: Commit.**

```bash
git add pubspec.yaml shaders/glass_refraction.frag
git commit -m "feat(glass): register liquid-glass refraction shader asset"
```

---

## Task 2: `AonGlass` tokens

**Files:**
- Create: `lib/app/theme/aon_glass.dart`
- Test: `test/widget/glass_surface_test.dart` (token cases added here; widget cases in Task 4)

**Interfaces:**
- Produces: `abstract final class AonGlass` with `static const double blurMd, rimWidth, refractiveIndex, aberration, blurCoeff, fresnel, refractIntensity, radiusBar, radiusFloating, opacityContent, opacityHighContrast;` and `static double opacityRegular(bool isDark), borderAlpha(bool isDark), shadowAlpha(bool isDark);` and `static Color tint(bool isDark)`.

- [ ] **Step 1: Write the failing test.** Create `test/widget/glass_surface_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_glass.dart';

void main() {
  group('AonGlass tokens', () {
    test('dark tint is the aon2026 night surface, content stays legible', () {
      expect(AonGlass.tint(true), AonColors.night800);
      expect(AonGlass.opacityContent, greaterThanOrEqualTo(0.94));
      expect(AonGlass.opacityHighContrast, greaterThanOrEqualTo(0.94));
    });

    test('regular (shader body) opacity is translucent enough to refract', () {
      expect(AonGlass.opacityRegular(true), lessThan(0.6));
      expect(AonGlass.opacityRegular(true), greaterThan(0.3));
    });

    test('shader tokens carried from the reference', () {
      expect(AonGlass.refractiveIndex, 1.6);
      expect(AonGlass.rimWidth, 42);
      expect(AonGlass.fresnel, 0.8);
      expect(AonGlass.refractIntensity, 0.85);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:aon2026/app/theme/aon_glass.dart'`.

- [ ] **Step 3: Create `lib/app/theme/aon_glass.dart`** (adapted from `$REF/lib/app/theme/mq_glass.dart`; tint → night surface, dark-tuned):

```dart
import 'package:flutter/widgets.dart';

import 'package:aon2026/app/theme/aon_colors.dart';

/// Design tokens for the Liquid Glass-inspired ("Glass UI layer") material.
///
/// Adapted from MQ Journey's `mq_glass.dart` (REUSE WITH MODIFICATION). The
/// numeric shader/frost tokens are carried over; the **tint is aon2026's night
/// surface** and values are dark-tuned (this app is dark-only). Owns the
/// aon2026 glass identity so the generic `GlassSurface` primitive stays free of
/// `AonColors`/`AonTheme` coupling.
abstract final class AonGlass {
  // Blur (sigma) for the non-shader frost fallback.
  static const double blurMd = 18;

  // Body opacity per rung. Thin enough that refraction shows through on the
  // shader path; near-opaque on the content tier so text never depends on the
  // backdrop.
  static double opacityRegular(bool isDark) => isDark ? 0.45 : 0.52;
  static const double opacityContent = 0.94;
  static const double opacityHighContrast = 0.96;

  // Border / shadow alpha.
  static double borderAlpha(bool isDark) => isDark ? 0.28 : 0.35;
  static double shadowAlpha(bool isDark) => isDark ? 0.35 : 0.14;

  // Default radii (geometry may still be overridden per surface).
  static const double radiusBar = 18;
  static const double radiusFloating = 22;

  // Shader params (logical/UV; converted to physical px in the shader path).
  static const double refractiveIndex = 1.6;
  static const double rimWidth = 42;
  static const double aberration = 0.05;
  static const double blurCoeff = 0.03;

  // Liquid-glass rim effects (0..1 strengths).
  static const double fresnel = 0.8;

  /// Strength of the physically-based (Snell) refraction march.
  static const double refractIntensity = 0.85;

  /// Base tint colour. aon2026 is dark-only; the light branch is retained for
  /// API symmetry with the reference but resolves to a night surface.
  static Color tint(bool isDark) =>
      isDark ? AonColors.night800 : AonColors.night900;
}
```

- [ ] **Step 4: Run the test to see it pass.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit.**

```bash
git add lib/app/theme/aon_glass.dart test/widget/glass_surface_test.dart
git commit -m "feat(glass): add AonGlass design tokens (night-tuned)"
```

---

## Task 3: `GlassShaderCache`

**Files:**
- Create: `lib/widgets/glass_shader.dart`
- Test: `test/widget/glass_surface_test.dart` (append)

**Interfaces:**
- Produces: `abstract final class GlassShaderCache` with `static Future<void> ensureLoaded()`, `static bool get ready`, `static ui.FragmentShader newShader()`.

- [ ] **Step 1: Write the failing test** (append to `test/widget/glass_surface_test.dart`, inside `main()`):

```dart
  group('GlassShaderCache', () {
    test('ensureLoaded never throws and is not ready without Impeller', () async {
      // The test harness has no Impeller, so the shader never loads; the load
      // must complete non-fatally and report not-ready (→ frost fallback).
      await GlassShaderCache.ensureLoaded();
      expect(GlassShaderCache.ready, isFalse);
    });
  });
```

Add the import at the top of the file:

```dart
import 'package:aon2026/widgets/glass_shader.dart';
```

- [ ] **Step 2: Run it to see it fail.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: FAIL — URI for `glass_shader.dart` doesn't exist.

- [ ] **Step 3: Copy the reference verbatim** (it imports only `dart:ui` + `foundation` — no rename needed):

```bash
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/lib/shared/widgets/glass_shader.dart lib/widgets/glass_shader.dart
```

Confirm the asset path inside is `'shaders/glass_refraction.frag'` (it is — matches Task 1). Do not edit the file.

- [ ] **Step 4: Run the test to see it pass.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit.**

```bash
git add lib/widgets/glass_shader.dart test/widget/glass_surface_test.dart
git commit -m "feat(glass): add GlassShaderCache (Impeller-gated, non-fatal load)"
```

---

## Task 4: `GlassSurface` + `resolveGlassRenderMode`

**Files:**
- Create: `lib/widgets/glass_surface.dart`
- Test: `test/widget/glass_surface_test.dart` (append policy + tier tests)

**Interfaces:**
- Consumes: `AonGlass` (Task 2), `GlassShaderCache` (Task 3).
- Produces: `enum GlassVariant { bar, control, content }`, `enum GlassRenderMode { shader, frost, solid }`, `GlassRenderMode resolveGlassRenderMode({required GlassVariant variant, required bool highContrast, required bool disableAnimations, required bool shaderSupported, bool allowShader = true})`, and `class GlassSurface extends StatelessWidget` with `({required Widget child, GlassVariant variant = GlassVariant.control, BorderRadius? borderRadius, EdgeInsetsGeometry? padding, Color? color, Color? borderColor, double? borderWidth, BoxConstraints? constraints, List<BoxShadow>? boxShadow, bool allowShader = true})`.

- [ ] **Step 1: Write the failing tests** (append to `test/widget/glass_surface_test.dart`). These mirror `$REF/test/shared/widgets/glass_surface_test.dart`, adapted to dark:

```dart
  Widget host({
    required Widget child,
    bool highContrast = false,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(
          highContrast: highContrast,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('resolveGlassRenderMode', () {
    test('content is always solid', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.content, highContrast: false, disableAnimations: false, shaderSupported: true),
        GlassRenderMode.solid);
    });
    test('high contrast forces solid', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.control, highContrast: true, disableAnimations: false, shaderSupported: true),
        GlassRenderMode.solid);
    });
    test('reduce motion drops to frost', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.control, highContrast: false, disableAnimations: true, shaderSupported: true),
        GlassRenderMode.frost);
    });
    test('no shader support drops to frost', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.bar, highContrast: false, disableAnimations: false, shaderSupported: false),
        GlassRenderMode.frost);
    });
    test('supported + no a11y flags -> shader', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.control, highContrast: false, disableAnimations: false, shaderSupported: true),
        GlassRenderMode.shader);
    });
    test('allowShader:false forces frost even when supported', () {
      expect(
        resolveGlassRenderMode(variant: GlassVariant.control, highContrast: false, disableAnimations: false, shaderSupported: true, allowShader: false),
        GlassRenderMode.frost);
    });
  });

  group('GlassSurface tiers (Impeller off in tests → frost, never shader)', () {
    testWidgets('content tier is solid — no BackdropFilter', (tester) async {
      await tester.pumpWidget(host(child: const GlassSurface(variant: GlassVariant.content, child: SizedBox(width: 100, height: 40))));
      expect(find.byType(BackdropFilter), findsNothing);
    });
    testWidgets('control tier renders a frost BackdropFilter', (tester) async {
      await tester.pumpWidget(host(child: const GlassSurface(variant: GlassVariant.control, child: SizedBox(width: 100, height: 40))));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
    testWidgets('high contrast forces solid (no BackdropFilter)', (tester) async {
      await tester.pumpWidget(host(highContrast: true, child: const GlassSurface(variant: GlassVariant.control, child: SizedBox(width: 100, height: 40))));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
```

Add imports at the top:

```dart
import 'package:aon2026/widgets/glass_surface.dart';
```

- [ ] **Step 2: Run to see it fail.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: FAIL — URI for `glass_surface.dart` doesn't exist.

- [ ] **Step 3: Create `lib/widgets/glass_surface.dart` by copying the reference, then adapting.** Copy first:

```bash
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/lib/shared/widgets/glass_surface.dart lib/widgets/glass_surface.dart
```

Then apply these exact edits:

**Edit 3a — imports.** Replace:

```dart
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_glass.dart';
import 'package:mq_journey/shared/widgets/glass_shader.dart';
```

with (no `AonColors` import — the primitive must not couple to it; border colour comes from the `AonGlass` token layer):

```dart
import 'package:aon2026/app/theme/aon_glass.dart';
import 'package:aon2026/widgets/glass_shader.dart';
```

**Edit 3b — token references.** Replace every `MqGlass.` with `AonGlass.` (occurrences: `MqGlass.radiusBar`, `MqGlass.radiusFloating`, `MqGlass.borderAlpha`, `MqGlass.shadowAlpha`, `MqGlass.opacityHighContrast`, `MqGlass.opacityContent`, `MqGlass.tint`, `MqGlass.opacityRegular`, `MqGlass.blurMd`, `MqGlass.rimWidth`, `MqGlass.refractiveIndex`, `MqGlass.aberration`, `MqGlass.blurCoeff`, `MqGlass.fresnel`, `MqGlass.refractIntensity`).

**Edit 3c — border colour** (dark-only app → dark branch is what runs; light branch sourced from `AonGlass`, not `AonColors`). In `_resolveBorderColor`, replace:

```dart
    return (isDark ? Colors.white : MqColors.charcoal800).withValues(
```

with:

```dart
    return (isDark ? Colors.white : AonGlass.tint(false)).withValues(
```

- [ ] **Step 4: Run the tests to see them pass.**

Run: `flutter test test/widget/glass_surface_test.dart`
Expected: PASS (policy group + tier group + Tasks 2–3 groups). Then `flutter analyze` → `No issues found!`

- [ ] **Step 5: Commit.**

```bash
git add lib/widgets/glass_surface.dart test/widget/glass_surface_test.dart
git commit -m "feat(glass): add GlassSurface 3-tier material + fallback policy"
```

---

## Task 5: `AonHaptics`

**Files:**
- Create: `lib/utils/haptics.dart`
- Create: `test/widget/aon_haptics_test.dart` (the smoke test in Step 2 below)

**Interfaces:**
- Produces: `abstract final class AonHaptics` with `static Future<void> light(bool isEnabled)`, `medium`, `heavy`, `selection(bool isEnabled)`.

- [ ] **Step 1: Copy the reference and rename.**

```bash
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/lib/core/utils/haptics.dart lib/utils/haptics.dart
```

Edit: replace `class MqHaptics` with `class AonHaptics`, and update the doc comment first line to `/// Astronomy Open Night haptic feedback wrapper.`

- [ ] **Step 2: Write a smoke test.** Create `test/widget/aon_haptics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/utils/haptics.dart';

void main() {
  test('disabled haptics is a no-op and never throws', () async {
    await AonHaptics.selection(false);
    await AonHaptics.light(false);
  });
}
```

- [ ] **Step 3: Run it.**

Run: `flutter test test/widget/aon_haptics_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add lib/utils/haptics.dart test/widget/aon_haptics_test.dart
git commit -m "feat: add AonHaptics wrapper"
```

---

## Task 6: `LiquidTabBar` — port + adaptations (`selectedColor`, `orbit`, reduced motion, ≥13px label)

**Files:**
- Create: `lib/widgets/liquid_tab_bar.dart`
- Test: `test/widget/liquid_tab_bar_test.dart`

**Interfaces:**
- Consumes: `AonHaptics` (Task 5) — used by the shell, not the widget; the widget stays colour-only.
- Produces: `enum TabFx { bounce, homecoming, orbit, rotateOpen, scanline, spin }`, `class LiquidNavItem { const LiquidNavItem({required IconData icon, required IconData activeIcon, required String label, required TabFx fx}); }`, `class LiquidTabBar extends StatefulWidget` with `({required int currentIndex, required ValueChanged<int> onSelected, required List<LiquidNavItem> items, required Color color, Color? accent, Color? selectedColor, double height = 66})`.

- [ ] **Step 1: Write the failing tests.** Create `test/widget/liquid_tab_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/liquid_tab_bar.dart';

const _items = [
  LiquidNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', fx: TabFx.homecoming),
  LiquidNavItem(icon: Icons.info_outline, activeIcon: Icons.info, label: 'Info', fx: TabFx.orbit),
  LiquidNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map', fx: TabFx.rotateOpen),
];

Finder _orbit() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_OrbitPainter');

Widget _host({
  int index = 0,
  ValueChanged<int>? onSelected,
  bool disableAnimations = false,
  double textScale = 1.0,
  TextDirection dir = TextDirection.ltr,
}) {
  var i = index;
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: dir,
        child: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => LiquidTabBar(
              currentIndex: i,
              onSelected: (x) { onSelected?.call(x); setState(() => i = x); },
              color: Colors.white,
              selectedColor: const Color(0xFFFFB945),
              accent: const Color(0xFFFFB945),
              items: _items,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap selects that tab', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(onSelected: picked.add));
    await tester.tap(find.byIcon(Icons.map_outlined), warnIfMissed: false);
    await tester.pump();
    expect(picked, [2]);
  });

  testWidgets('orbit fx plays on select and leaves no overlay when idle', (tester) async {
    await tester.pumpWidget(_host());
    expect(_orbit(), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_orbit(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_orbit(), findsNothing);
  });

  testWidgets('the selected label uses at least 13px (night floor)', (tester) async {
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('Home'));
    expect(label.style!.fontSize, greaterThanOrEqualTo(13));
  });

  testWidgets('reduced motion: selection is instant — no orbit, active icon immediately', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
    await tester.pump(); // ONE frame, no settle — proves no in-flight animation
    expect(_orbit(), findsNothing); // no decorative FX
    expect(find.byIcon(Icons.info), findsOneWidget); // Info active icon shown at once
  });

  testWidgets('each tab exposes button + label semantics; unselected is not selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    // Map is unselected (index 0 = Home selected), so only the tab's Semantics
    // carries 'Map' — no visible label Text to collide with.
    final map = tester.getSemantics(find.bySemanticsLabel('Map'));
    expect(map.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(map.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(map.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('horizontal drag: crosses tabs, clamps in range, ends on the drag-end tab', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(onSelected: picked.add));
    final bar = tester.getRect(find.byType(LiquidTabBar));
    // Drag from the left edge fully across to the right edge.
    await tester.dragFrom(bar.centerLeft + const Offset(4, 0), Offset(bar.width, 0));
    await tester.pumpAndSettle();
    expect(picked, isNotEmpty);
    expect(picked.every((x) => x >= 0 && x < _items.length), isTrue); // clamp
    expect(picked.last, _items.length - 1); // dragging to the right edge lands on the last tab
  });

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL: tapping the physically-left tab selects the last item', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(dir: TextDirection.rtl, onSelected: picked.add));
    // Under RTL item 2 (Map) renders at the physical left.
    await tester.tap(find.byIcon(Icons.map_outlined), warnIfMissed: false);
    await tester.pump();
    expect(picked, [2]);
  });
}
```

- [ ] **Step 2: Run to see it fail.**

Run: `flutter test test/widget/liquid_tab_bar_test.dart`
Expected: FAIL — URI for `liquid_tab_bar.dart` doesn't exist.

- [ ] **Step 3: Copy the reference verbatim.**

```bash
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/lib/app/router/liquid_tab_bar.dart lib/widgets/liquid_tab_bar.dart
```

- [ ] **Step 4: Apply adaptation A — `selectedColor` + `orbit` enum + widget field.**

In `enum TabFx`, replace:

```dart
enum TabFx { bounce, homecoming, rotateOpen, scanline, spin }
```

with:

```dart
enum TabFx { bounce, homecoming, orbit, rotateOpen, scanline, spin }
```

In the `LiquidTabBar` constructor, replace:

```dart
    required this.color,
    this.accent,
    this.height = 66,
  });
```

with:

```dart
    required this.color,
    this.accent,
    this.selectedColor,
    this.height = 66,
  });
```

And after `final Color? accent;` add:

```dart
  /// Colour for the selected tab's icon, label and lens. Defaults to [color].
  /// The shell injects aon2026 amber here for its selected-state identity.
  final Color? selectedColor;
```

- [ ] **Step 5: Apply adaptation B — reduced-motion in the state.**

In `_LiquidTabBarState`, add this getter after the `_pressed` field:

```dart
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);
```

Replace `_animateTo`:

```dart
  void _animateTo(double target) {
    _fracFrom = _displayFrac;
    _fracTo = target;
    _slide.forward(from: 0);
  }
```

with:

```dart
  void _animateTo(double target) {
    if (_reduceMotion) {
      // No decorative interpolation — the lens jumps to the selection.
      _fracFrom = _fracTo = target;
      _slide.value = 1;
      return;
    }
    _fracFrom = _displayFrac;
    _fracTo = target;
    _slide.forward(from: 0);
  }
```

- [ ] **Step 6: Apply adaptation C — selected colour + ≥13px label + gel gating in `_buildTab`.**

Replace the gel-press `AnimatedScale` opening:

```dart
        child: AnimatedScale(
          scale: pressed ? 0.85 : 1.0, // gel-press
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
```

with (under reduced motion the scale stays `1.0` and therefore never changes, so `AnimatedScale` never animates — no `Duration.zero` needed; the decorative transform is simply omitted, not zero-animated):

```dart
        child: AnimatedScale(
          scale: (pressed && !_reduceMotion) ? 0.85 : 1.0, // gel-press
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
```

Replace the `_TabIcon(...)` construction:

```dart
              _TabIcon(
                item: item,
                selected: selected,
                color: widget.color,
                accent: widget.accent ?? widget.color,
              ),
```

with (selected icon takes the amber selectedColor; pass reduce-motion down):

```dart
              _TabIcon(
                item: item,
                selected: selected,
                color: selected ? (widget.selectedColor ?? widget.color) : widget.color,
                accent: widget.accent ?? widget.color,
                reduceMotion: _reduceMotion,
              ),
```

Replace the label `Text` style block:

```dart
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
```

with (≥13px night floor + selected amber):

```dart
                          style: TextStyle(
                            color: widget.selectedColor ?? widget.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
```

- [ ] **Step 7: Apply adaptation D — lens tint uses selectedColor.**

Replace the lens `DecoratedBox` decoration:

```dart
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(indH / 2),
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.26),
                          ),
                        ),
```

with:

```dart
                        decoration: BoxDecoration(
                          color: (widget.selectedColor ?? widget.color).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(indH / 2),
                          border: Border.all(
                            color: (widget.selectedColor ?? widget.color).withValues(alpha: 0.26),
                          ),
                        ),
```

- [ ] **Step 8: Apply adaptation E — `_TabIcon` reduce-motion field + orbit dispatch.**

In `_TabIcon`, replace the constructor + fields:

```dart
  const _TabIcon({
    required this.item,
    required this.selected,
    required this.color,
    required this.accent,
  });

  final LiquidNavItem item;
  final bool selected;
  final Color color;
  final Color accent;
```

with:

```dart
  const _TabIcon({
    required this.item,
    required this.selected,
    required this.color,
    required this.accent,
    required this.reduceMotion,
  });

  final LiquidNavItem item;
  final bool selected;
  final Color color;
  final Color accent;
  final bool reduceMotion;
```

In `_TabIconState`, extend the duration ternary so `orbit` reads as a full loop:

```dart
    duration:
        widget.item.fx == TabFx.scanline || widget.item.fx == TabFx.homecoming
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 620),
```

→

```dart
    duration:
        widget.item.fx == TabFx.scanline ||
            widget.item.fx == TabFx.homecoming ||
            widget.item.fx == TabFx.orbit
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 620),
```

Replace `didUpdateWidget` in `_TabIconState`:

```dart
  @override
  void didUpdateWidget(covariant _TabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _c.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _c.value = 0;
    }
  }
```

with (reduced motion → jump to the rest/end state, no flourish):

```dart
  @override
  void didUpdateWidget(covariant _TabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      if (widget.reduceMotion) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else if (!widget.selected && oldWidget.selected) {
      _c.value = 0;
    }
  }
```

In `_TabIconState.build`, after the existing `if (widget.item.fx == TabFx.homecoming) {...}` block, add the orbit dispatch:

```dart
    if (widget.item.fx == TabFx.orbit) {
      return _OrbitFx(controller: _c, accent: widget.accent, child: icon);
    }
```

- [ ] **Step 9: Apply adaptation F — add the new `_OrbitFx` widget + painter.** Append at the end of the file (after `_ViewfinderPainter`):

```dart
/// aon2026's signature flourish: a single star traces one elliptical orbit
/// around the icon on selection, then fades — the app's astronomy motif.
/// Idle (t == 0 or 1) renders the bare icon; no overlay lingers.
class _OrbitFx extends StatelessWidget {
  const _OrbitFx({
    required this.controller,
    required this.accent,
    required this.child,
  });

  final AnimationController controller;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, icon) {
        final t = controller.value;
        final active = t > 0 && t < 1;
        return SizedBox(
          width: 34,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              icon!,
              if (active)
                CustomPaint(
                  size: const Size(34, 30),
                  painter: _OrbitPainter(progress: t, color: accent),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One star on an elliptical path, fading in then out over a single loop.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rx = size.width * 0.42;
    final ry = size.height * 0.42;
    final angle = 2 * math.pi * Curves.easeInOut.transform(progress) - math.pi / 2;
    final fade = math.sin(math.pi * progress); // 0 -> 1 -> 0
    final pos = Offset(c.dx + rx * math.cos(angle), c.dy + ry * math.sin(angle));

    // Faint orbit ring.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      Paint()
        ..color = color.withValues(alpha: 0.16 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Soft glow then the star.
    canvas.drawCircle(pos, 4.0, Paint()..color = color.withValues(alpha: 0.32 * fade));
    canvas.drawCircle(pos, 2.2, Paint()..color = color.withValues(alpha: fade));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.progress != progress || old.color != color;
}
```

- [ ] **Step 10: Run the tests to see them pass.**

Run: `flutter test test/widget/liquid_tab_bar_test.dart`
Expected: PASS (7 tests). Then `flutter analyze` → `No issues found!`

- [ ] **Step 11: Commit.**

```bash
git add lib/widgets/liquid_tab_bar.dart test/widget/liquid_tab_bar_test.dart
git commit -m "feat(nav): port LiquidTabBar with amber identity, orbit FX, reduced-motion, 13px label"
```

---

## Task 7: `AonNavMetrics`

**Files:**
- Create: `lib/widgets/nav_metrics.dart`
- Test: `test/widget/nav_metrics_test.dart`

**Interfaces:**
- Produces: `abstract final class AonNavMetrics` with `static const double barHeight`, `static double resolvedBarHeight(BuildContext context)`, `static double clearance(BuildContext context)`.

- [ ] **Step 1: Write the failing test.** Create `test/widget/nav_metrics_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/nav_metrics.dart';

void main() {
  testWidgets('clearance = bar height + padding + gap + safe-area bottom', (tester) async {
    late double clearance;
    late double barH;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Builder(builder: (context) {
          barH = AonNavMetrics.resolvedBarHeight(context);
          clearance = AonNavMetrics.clearance(context);
          return const SizedBox();
        }),
      ),
    ));
    // >= (not ==): if measure-first later makes the height scale-aware, this
    // test must not force it back to the constant.
    expect(barH, greaterThanOrEqualTo(AonNavMetrics.barHeight));
    // Clearance is computed from the RESOLVED height, so it survives adaptation:
    // barH + 12 outer + 12 gap + 34 safe-area.
    expect(clearance, closeTo(barH + 12 + 12 + 34, 0.01));
  });
}
```

- [ ] **Step 2: Run to see it fail.**

Run: `flutter test test/widget/nav_metrics_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create `lib/widgets/nav_metrics.dart`.**

```dart
import 'package:flutter/widgets.dart';

/// Single source of truth for the floating glass tab-bar's geometry.
///
/// The island height and the body clearance behind it are derived from ONE
/// resolved height so they can never drift into separate magic numbers
/// (spec §5.8). aon2026 measures first: the bar height is constant unless a
/// real overflow is found at a large text scale, in which case only this
/// function changes and all four consumers follow.
abstract final class AonNavMetrics {
  /// The `LiquidTabBar` default height. Baseline **expected** to hold through
  /// 2.0 text scale (non-scaling icon 25 + scaled 13px label ≈ 53 < 66);
  /// **verified in Task 11**, not assumed here.
  static const double barHeight = 66;

  /// Gap between the island and the screen edges (matches the shell padding).
  static const double _outerBottomPadding = 12;

  /// Breathing room between the last content item and the island.
  static const double _contentGap = 12;

  /// The resolved bar height for the current context. Constant today;
  /// the single place to make it text-scale-aware if measurement demands it.
  static double resolvedBarHeight(BuildContext context) => barHeight;

  /// Bottom clearance a scrollable body must reserve so its last item, and any
  /// floating control, clears the glass island AND the home indicator.
  static double clearance(BuildContext context) =>
      resolvedBarHeight(context) +
      _outerBottomPadding +
      _contentGap +
      MediaQuery.paddingOf(context).bottom;
}
```

- [ ] **Step 4: Run to see it pass.**

Run: `flutter test test/widget/nav_metrics_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/widgets/nav_metrics.dart test/widget/nav_metrics_test.dart
git commit -m "feat(nav): add AonNavMetrics single-source bar height + clearance"
```

---

## Task 8: `AppShell` — glass island + `LiquidTabBar`

**Files:**
- Modify: `lib/widgets/app_shell.dart` (full replace)
- Test: `test/widget/app_shell_test.dart`

**Interfaces:**
- Consumes: `GlassSurface`, `GlassVariant` (Task 4); `LiquidTabBar`, `LiquidNavItem`, `TabFx` (Task 6); `AonHaptics` (Task 5); `AonNavMetrics` (Task 7); `AonColors`.
- Produces: `class AppShell extends StatelessWidget` with `const AppShell({required StatefulNavigationShell navigationShell, super.key})` — unchanged public API.

- [ ] **Step 1: Write the failing test.** Create `test/widget/app_shell_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

late GoRouter _router;

Widget _app() {
  _router = buildRouter();
  return ProviderScope(
    child: MaterialApp.router(
      theme: AonTheme.build(),
      routerConfig: _router,
    ),
  );
}

void main() {
  testWidgets('shell shows the 5 tabs via LiquidTabBar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    // NOTE: a tab renders its label Text ONLY when selected (unselected tabs
    // collapse the label to SizedBox.shrink), so assert the always-present
    // icons, not find.text on every label. Initial state = Home selected.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget); // Home active
    expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget); // Program
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget); // Now
    expect(find.byIcon(Icons.map_outlined), findsOneWidget); // Map
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget); // Info
    expect(find.text('Home'), findsWidgets); // the one selected label is shown
  });

  testWidgets('tapping a tab actually navigates its branch + updates selection', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Assert a widget UNIQUE to the Program page — NOT the tab's own 'Program'
    // label (which would false-pass even if routing were broken). The Program
    // screen shows a count like 'N items in the program'.
    expect(find.textContaining('items in the program'), findsOneWidget);
    // Selected-state moved: Program active icon in, Home no longer active.
    expect(find.byIcon(Icons.list_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
  });

  testWidgets('reselecting the active tab stays on its root without error', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Tap the now-active Program tab again (reselect → goBranch initialLocation).
    await tester.tap(find.byIcon(Icons.list_alt_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('items in the program'), findsOneWidget);
  });

  testWidgets('back navigation: a pushed full-screen route pops back to the shell', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Wayfinding is pushed above the shell (hides the tab bar). push() returns
    // a Future that completes on pop; unawaited to satisfy `unawaited_futures`.
    unawaited(_router.push('/wayfinding'));
    await tester.pumpAndSettle();
    expect(find.text('Walking directions'), findsWidgets);
    expect(find.byType(LiquidTabBar), findsNothing);
    // Pop → the shell (and its tab bar) return.
    _router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to see it fail.**

Run: `flutter test test/widget/app_shell_test.dart`
Expected: FAIL — `find.byType(LiquidTabBar)` finds nothing (shell still uses `NavigationBar`).

- [ ] **Step 3: Replace `lib/widgets/app_shell.dart` entirely** with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:go_router/go_router.dart';

/// The tab shell wrapping the five top-level screens.
///
/// The bottom navigation is a floating Liquid Glass-inspired island (the
/// signature nav), not a flat Material bar — see
/// docs/superpowers/specs/2026-08-08-aon-glass-liquid-nav-phase1-design.md.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<LiquidNavItem> _items = [
    LiquidNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      fx: TabFx.homecoming,
    ),
    LiquidNavItem(
      icon: Icons.list_alt_outlined,
      activeIcon: Icons.list_alt_rounded,
      label: 'Program',
      fx: TabFx.bounce,
    ),
    LiquidNavItem(
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule_rounded,
      label: 'Now',
      fx: TabFx.spin,
    ),
    LiquidNavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Map',
      fx: TabFx.rotateOpen,
    ),
    LiquidNavItem(
      icon: Icons.info_outline_rounded,
      activeIcon: Icons.info_rounded,
      label: 'Info',
      fx: TabFx.orbit,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body runs behind the floating island so the glass has live content
      // to refract.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassSurface(
            variant: GlassVariant.control,
            borderRadius: BorderRadius.circular(
              AonNavMetrics.resolvedBarHeight(context) / 2,
            ),
            child: LiquidTabBar(
              height: AonNavMetrics.resolvedBarHeight(context),
              currentIndex: navigationShell.currentIndex,
              color: AonColors.contentSecondary,
              selectedColor: AonColors.amber,
              accent: AonColors.amber,
              items: _items,
              onSelected: (index) {
                // Fire-and-forget haptic; `unawaited` makes the intent explicit
                // and is future-proof if this callback ever becomes async.
                unawaited(AonHaptics.selection(true));
                // Tapping the active tab returns it to its root — the
                // platform-standard behaviour on both iOS and Android.
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to see it pass.**

Run: `flutter test test/widget/app_shell_test.dart`
Expected: PASS (4 tests: render, navigate+selected-state, reselect, back-nav). Then `flutter analyze` → `No issues found!`

- [ ] **Step 5: Commit.**

```bash
git add lib/widgets/app_shell.dart test/widget/app_shell_test.dart
git commit -m "feat(nav): mount LiquidTabBar in a floating glass island shell"
```

---

## Task 9: `main.dart` — async startup + non-fatal shader preload

**Files:**
- Modify: `lib/main.dart:9-28` (the `main()` function)

**Interfaces:**
- Consumes: `GlassShaderCache` (Task 3).

- [ ] **Step 1: Replace the `main()` function.** Current:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait. The app is used one-handed while walking; a rotation
  // mid-stride is never intentional here.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: AonApp()));
}
```

Replace with (async; binding stays first; shader preload is non-fatal — `ensureLoaded` never throws):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait. The app is used one-handed while walking; a rotation
  // mid-stride is never intentional here.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Preload the glass refraction shader (Impeller only). Non-fatal by
  // construction: on unsupported targets or a load failure the surfaces fall
  // back to frost/solid — this must never block app startup.
  await GlassShaderCache.ensureLoaded();

  runApp(const ProviderScope(child: AonApp()));
}
```

Add the import (with the other `package:aon2026` imports):

```dart
import 'package:aon2026/widgets/glass_shader.dart';
```

- [ ] **Step 2: Verify the whole suite + analyze.**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests pass (the existing 135 + the new tab-bar/shell/glass/metrics tests).

- [ ] **Step 3: Commit.**

```bash
git add lib/main.dart
git commit -m "feat: preload glass shader at startup (non-fatal, binding-first)"
```

---

## Task 10: Floating-nav clearance on the 5 shell screens

**Files:**
- Create: `test/widget/shell_clearance_test.dart`
- Modify: `lib/screens/home_screen.dart`, `program_screen.dart`, `whats_on_screen.dart`, `info_screen.dart`, `map_screen.dart`

**Interfaces:**
- Consumes: `AonNavMetrics.clearance(context)` (Task 7).

Each shell screen's scroll body currently reserves a fixed `AonSpacing.space10` (40) bottom padding, which is far less than the floating island's height (~112 incl. safe area) — so the last item is occluded. Replace the bottom value with the derived clearance.

- [ ] **Step 1: Write the failing occlusion test.** Create `test/widget/shell_clearance_test.dart`. It scrolls Home to its end and asserts the last item's bottom clears the tab-bar island's top. With the current `space10` padding this **fails** (last item hides under the island).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

void main() {
  testWidgets('Home last item clears the floating island after scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(theme: AonTheme.build(), routerConfig: buildRouter()),
    ));
    await tester.pumpAndSettle();

    // Fling the Home scroll view to its very bottom.
    await tester.fling(find.byType(Scrollable).first, const Offset(0, -4000), 5000);
    await tester.pumpAndSettle();

    // 'Image credit' is the last card on Home.
    final credit = find.text('Image credit');
    expect(credit, findsOneWidget);
    final creditBottom = tester.getRect(credit).bottom;
    final barTop = tester.getRect(find.byType(LiquidTabBar)).top;
    expect(creditBottom, lessThanOrEqualTo(barTop),
        reason: 'last item must sit above the floating glass island');
  });
}
```

- [ ] **Step 2: Run it to watch it fail.**

Run: `flutter test test/widget/shell_clearance_test.dart`
Expected: FAIL — `creditBottom` is greater than `barTop` (the last card is under the island) because the screens still use `AonSpacing.space10`.

- [ ] **Step 3: `program_screen.dart` / `whats_on_screen.dart` / `info_screen.dart`** — each has a `ListView(padding: const EdgeInsets.fromLTRB(AonSpacing.space4, 0, AonSpacing.space4, AonSpacing.space10), ...)`. In each of the three files, change that one padding to a non-const built from the clearance. Replace:

```dart
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonSpacing.space10,
        ),
```

with:

```dart
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonNavMetrics.clearance(context),
        ),
```

Add the import to each of the three files:

```dart
import 'package:aon2026/widgets/nav_metrics.dart';
```

- [ ] **Step 4: `home_screen.dart`** — the `SliverPadding` bottom is `AonSpacing.space10`. Replace:

```dart
            padding: const EdgeInsets.fromLTRB(
              AonSpacing.space4,
              AonSpacing.space5,
              AonSpacing.space4,
              AonSpacing.space10,
            ),
```

with:

```dart
            padding: EdgeInsets.fromLTRB(
              AonSpacing.space4,
              AonSpacing.space5,
              AonSpacing.space4,
              AonNavMetrics.clearance(context),
            ),
```

Add the import:

```dart
import 'package:aon2026/widgets/nav_metrics.dart';
```

- [ ] **Step 5: `map_screen.dart`** — the map isn't scrollable, so raise the two floating elements above the island.

  **Why the FAB needs manual lifting (non-obvious):** each screen is its **own** `Scaffold` nested inside the `AppShell` Scaffold. The glass island is the *outer* Scaffold's `bottomNavigationBar`; the inner `MapScreen` Scaffold has no `bottomNavigationBar`, so it does **not** auto-lift its FAB above the island — the FAB would sit under the glass. Hence the explicit bottom padding below.

  **Runtime-verified heuristic (honest):** the exact subtractions below (`- space3`, `- space4`) are first-cut offsets. Confirm the FAB and attribution actually clear the island on device in Task 11 Step 5 and adjust the constants if they sit too high/low — do not treat these numbers as proven.

  For the FAB, replace:

```dart
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.wayfinding),
        backgroundColor: AonColors.amber,
        foregroundColor: AonColors.onAccent,
        icon: const Icon(Icons.directions_walk_rounded),
        label: const Text('Directions'),
      ),
```

with (lift it clear of the island; `- 12` removes the FAB's own default margin so the gap isn't doubled):

```dart
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: AonNavMetrics.clearance(context) - AonSpacing.space3,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.wayfinding),
          backgroundColor: AonColors.amber,
          foregroundColor: AonColors.onAccent,
          icon: const Icon(Icons.directions_walk_rounded),
          label: const Text('Directions'),
        ),
      ),
```

For the attribution, replace:

```dart
                const Positioned(
                  left: AonSpacing.space2,
                  bottom: AonSpacing.space2,
                  child: _MapAttribution(),
                ),
```

with:

```dart
                Positioned(
                  left: AonSpacing.space2,
                  bottom: AonNavMetrics.clearance(context) - AonSpacing.space4,
                  child: const _MapAttribution(),
                ),
```

Add the import:

```dart
import 'package:aon2026/widgets/nav_metrics.dart';
```

- [ ] **Step 6: Run the clearance test (now passing) + analyze + full suite.**

Run: `flutter test test/widget/shell_clearance_test.dart && flutter analyze && flutter test`
Expected: the occlusion test now PASSES (last item clears the island); `No issues found!`; all tests pass.

- [ ] **Step 7: Commit.**

```bash
git add test/widget/shell_clearance_test.dart lib/screens/home_screen.dart lib/screens/program_screen.dart lib/screens/whats_on_screen.dart lib/screens/info_screen.dart lib/screens/map_screen.dart
git commit -m "feat(nav): clear the floating glass island on all shell screens"
```

---

## Task 11: Responsive shell test + final verification gate

**Files:**
- Create: `test/widget/shell_responsive_test.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Create the shell responsive matrix.** Create `test/widget/shell_responsive_test.dart` (a new file, separate from the existing per-screen `responsive_layout_test.dart`, which is untouched). This is the broad no-overflow smoke across sizes/scales; the *occlusion* assertion lives in Task 10's `shell_clearance_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(414, 896)]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('shell no-overflow @ ${size.width.toInt()} x scale$scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp.router(
            theme: AonTheme.build(),
            routerConfig: buildRouter(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidTabBar), findsOneWidget);
      });
    }
  }
}
```

- [ ] **Step 2: Run the shell responsive test.**

Run: `flutter test test/widget/shell_responsive_test.dart`
Expected: PASS (8 cases). If any overflow appears at 2.0, that is the measure-first signal (spec §5.6/G1) to add tab-bar height adaptation — fix the component, re-run.

- [ ] **Step 3: Full gate — analyze + entire suite.**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; all tests green.

- [ ] **Step 4: Build verification (record honestly).**

```bash
flutter build apk --debug
flutter build ios --simulator --debug
```
Record each as `PASS` / `FAIL` / `NOT AVAILABLE`. A green build is **not** shader-render evidence.

- [ ] **Step 5: Runtime + shader/frost + performance evidence.** Launch on a booted device/emulator (or the web-server + browser as a fallback for layout only). Record, each as `PASS`/`FAIL`/`NOT AVAILABLE`:
  - Android runtime (app launches, nav works), iOS runtime.
  - **Shader render path** on an Impeller runtime (visually confirm refraction on the tab bar over the Map branch), and **frost fallback** where unsupported.
  - **Performance sanity** in profile mode where possible (frame jank, scrolling behind the island, rapid tab switching, repeated FX, shader warm-up). If profiling isn't possible here, record `NOT AVAILABLE` — never `PASS`.

- [ ] **Step 6: Parity + hostile re-audit → fix → RE-RUN THE GATE → commit.** Do **not** commit straight after the runtime/parity pass — visual fixes can invalidate the green evidence from Steps 3–4. Run this loop:
  1. Visually compare the nav against MQ_Journey; run a second hostile parity read for gaps introduced by the port (map FAB/attribution offsets from Task 10 Step 5, colours, metaball feel, FX).
  2. Apply any fixes the audit produces.
  3. **Re-run the complete gate on the final code:** `flutter analyze && flutter test`, and re-run the Android/iOS builds (Step 4) if any source changed.
  4. Inspect the whole diff: `git status && git --no-pager diff --stat` and read the substantive hunks.
  5. Only when the gate is green on the *final* code, commit:

```bash
git add -A
git commit -m "test(nav): shell responsive coverage 320/414 x 1.0-2.0; phase-1 gate"
```

  Record the final evidence table (analyze / tests / Android build / Android runtime / iOS build / iOS runtime / shader render / frost fallback / performance) as `PASS` / `FAIL` / `NOT AVAILABLE` — never inherit a pre-fix result.

---

## Self-Review (run against the spec)

**Spec coverage — every §5 item maps to a task:**
- §5.1 shader + pubspec → Task 1. §5.2 `GlassShaderCache` + non-fatal `main()` → Tasks 3, 9. §5.3 `AonGlass` → Task 2. §5.4 `GlassSurface`/policy → Task 4. §5.5 deferrals (`GlassPane`/`AonAnimations`) → correctly **absent**. §5.6 `LiquidTabBar` (selectedColor/orbit/reduced-motion/≥13px/measure-first) → Task 6. §5.7 `AonHaptics` → Task 5. §5.8 shell + `AonNavMetrics` clearance → Tasks 7, 8, 10. §5.9 FX mapping incl. `orbit` → Task 8 (`_items`) + Task 6 (`_OrbitFx`). §6.1–6.4 a11y (reduced-motion, high-contrast, text-scale, semantics) → Tasks 4, 6, 11. §7 tests → Tasks 2–8, 11 + G4 coverage bound (Impeller-off frost) baked into Task 4. §8 gate → Task 11. §9 perf → Task 11 Step 5. §10 boundary honoured (no `GlassPane`/`AonAnimations`/`AonTactileButton`).
- **Not ported** (verified absent from all tasks): MQ `bootstrap.dart`, `active_shell_branch_index_provider`, `mq_tactile_button`, MQ theme/token files.

**Placeholder scan:** no `TBD`/`TODO`/"handle edge cases"/"similar to Task N"; every code step carries real code or an exact copy+edit.

**Type consistency:** `GlassShaderCache.{ensureLoaded,ready,newShader}`, `resolveGlassRenderMode(variant,highContrast,disableAnimations,shaderSupported,allowShader)`, `GlassVariant.{bar,control,content}`, `AonGlass.{tint,opacityRegular,opacityContent,opacityHighContrast,...}`, `LiquidTabBar({currentIndex,onSelected,items,color,accent,selectedColor,height})`, `LiquidNavItem({icon,activeIcon,label,fx})`, `TabFx.{bounce,homecoming,orbit,rotateOpen,scanline,spin}`, `AonHaptics.selection(bool)`, `AonNavMetrics.{barHeight,resolvedBarHeight,clearance}`, `AppShell({navigationShell})` — used identically across Tasks 4/6/7/8/9.

**Known measure-first item (spec §5.6/G1):** Task 11 Step 2 is the trigger — only add tab-bar height adaptation *if* a real 2.0 overflow is measured; do not pre-build it.
