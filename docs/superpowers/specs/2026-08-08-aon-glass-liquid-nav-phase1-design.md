# Phase 1 — Glass Foundation + Signature Liquid Navigation (Design)

**Date:** 2026-08-08 (Australia/Sydney)
**App:** aon2026 (Astronomy Open Night 2026)
**Reference implementation:** `../MQ_Journey` (same owner; the sibling app aon2026 was
adapted from). Treated as the authoritative reference — behaviour is read from its
source line-by-line, not reconstructed from memory.
**Naming:** "Liquid Glass-inspired" / "Glass UI layer" only. This is Flutter, not
Apple's API — never call it "Liquid Glass" unqualified in code, comments, or copy.
**Status:** Frozen for spec self-review → user review → implementation plan. Not implemented.

---

## 1. Goal

Deliver **one production vertical slice** that proves the whole Liquid Glass + signature
navigation architecture through aon2026's **real bottom navigation** — no demo/showcase
screen. On completion, aon2026's tab bar is a floating glass island with the metaball
lens, gel-press, per-tab flourishes, haptics, and the full **shader → frost → solid**
fallback ladder, re-skinned to aon2026's amber/night identity, with every existing route,
branch, and behaviour preserved.

**Nature of this work (honest framing — G7):** this is a **high-fidelity port** of
MQ_Journey's design language, not an invention. It is recombination whose value is
*distribution* (aon2026 inherits a proven system), plus honest aon2026 adaptations (the
≥13px night label, reduced-motion determinism, dynamically-sourced clearance) and **one new
species** — the astronomy-native `orbit` FX (§5.9). Ambition here lives in fidelity and the
adaptations, not novelty.

**Glass-payoff bound (honest — G3):** in Phase 1 the glass lives only on the tab bar, which
floats over mostly near-black night content. So the *interaction* DNA (metaball, gel, FX,
haptics) is fully visible, but the *refraction* is strongest over the **Map** branch (real
tiles behind it) and deliberately subtle over dark text screens. The broad glass-lensing
payoff arrives in **Phase 2** (map controls, hero overlays). Phase 1 proves the architecture
and the signature nav — it is not the moment the whole app turns to glass.

### Non-goals (Phase 1)
- No glass on content/text surfaces yet (map controls, hero overlays, sheets = Phase 2;
  component system = Phase 3).
- No standalone `AonTactileButton` (Phase 3 — nothing in Phase 1 consumes it).
- No new navigation, routes, screens, or product behaviour.
- No app-wide text-scale policy change (see §6.3 — a scoped decision, deferred to Phase 5).

## 2. Source-of-truth model (unchanged from approved brainstorm)

- **From MQ_Journey:** Liquid Glass architecture, shader + rendering behaviour, fallback
  ladder, glass governance, `LiquidTabBar`, metaball mechanics, per-tab FX, tactile
  interaction, haptics, motion principles.
- **aon2026 owns (do not regress):** `AonTheme`, `AonColors`, `AonSpacing`,
  `AonTypography`, dark-only design, night readability, 56px interaction targets,
  larger/softer radii, hero photography, dark map tiles, product behaviour + IA.
- **Portability principle (one model, no contradiction):** `LiquidTabBar` and the shader
  infrastructure take **purely caller-injected** colours/config — no token-layer import at
  all. `GlassSurface` supplies generic rendering mechanics and reads its **defaults** from
  the `AonGlass` token layer (analogous to the reference's `GlassSurface → MqGlass`),
  accepting per-call overrides. **Allowed:** `GlassSurface → AonGlass`. **Prohibited:** any
  portable primitive importing `AonColors`/`AonTheme` directly. Colour flows:
  shell → Aon tokens/config → generic primitive.

## 3. Dependency map (port / adapt / leave behind)

| MQ_Journey source | Classification | aon2026 action |
|---|---|---|
| `shaders/glass_refraction.frag` | directly portable (verbatim; no app coupling) | copy unchanged |
| `lib/shared/widgets/glass_shader.dart` (`GlassShaderCache`) | directly portable (only `dart:ui`) | copy unchanged; **preserve its try/catch + `isShaderFilterSupported` guard** (§5.2) |
| `lib/shared/widgets/glass_surface.dart` (`GlassSurface`, `resolveGlassRenderMode`, `_GlassShaderBackdrop`) | theme-coupled (`MqColors`/`MqGlass`) | port; colour/tint sourced from `AonGlass` tokens; **`resolveGlassRenderMode` policy kept verbatim** |
| `lib/app/theme/mq_glass.dart` (`MqGlass`) | theme-coupled (tint→`MqColors`) | adapt → `AonGlass`; tint→night surface; numeric shader tokens kept; dark-tuned |
| `lib/shared/widgets/glass_pane.dart` (`GlassPane`) | portable (thin control-tier wrapper) | port in **Phase 2** (no Phase-1 consumer) |
| `lib/app/router/liquid_tab_bar.dart` (`LiquidTabBar`, `TabFx`, `LiquidNavItem`, fx painters) | directly portable (only `dart:math`+material; colour-parameterised) | port; **add** `selectedColor` (caller-injected) + reduced-motion + large-text adaptation; metaball/FX kept |
| `lib/core/utils/haptics.dart` (`MqHaptics`) | portable (rename only) | → `AonHaptics` |
| `lib/app/theme/mq_animations.dart` (`MqAnimations`) | **settings-coupled** (`adaptive` reads a settings provider) | adapt → `AonAnimations` in **Phase 3** (no Phase-1 consumer); when ported, `adaptive` reads `MediaQuery.disableAnimationsOf` (no settings screen exists) |
| `lib/app/bootstrap/bootstrap.dart` | MQ-specific (tz/env/Firebase/Supabase) | **not ported**; fold only the non-fatal `await GlassShaderCache.ensureLoaded()` step into aon2026 `main()` |
| `lib/app/router/app_shell.dart` (glass island wiring) | routing-coupled (immersive flag, active-branch provider) | adapt; keep aon2026's 5-branch `goBranch` (reselect-resets-to-root); **drop** immersive + active-branch coupling |
| `lib/app/router/active_shell_branch_index_provider.dart` | MQ-specific (only `ScanPage` reads it) | **not ported** |
| `lib/shared/widgets/mq_tactile_button.dart` | theme+haptics-coupled | **deferred to Phase 3** |
| `mq_theme` / `mq_typography` / `mq_spacing` / `mq_colors` | aon2026 already owns equivalents | **not ported** |
| `test/shared/widgets/glass_surface_test.dart` | portable (adapt to dark/aon) | mirror |
| `test/app/router/liquid_tab_bar_test.dart` | portable (adapt; drop RTL — aon2026 is LTR-only) | mirror |
| `test/app/router/app_shell_test.dart` | adapt to aon2026 shell | mirror |

## 4. Concrete files

**Create**
- `shaders/glass_refraction.frag`
- `lib/app/theme/aon_glass.dart` — `AonGlass` tokens (owns aon2026 tint/border/opacity/shader params)
- `lib/utils/haptics.dart` — `AonHaptics`
- `lib/widgets/glass_shader.dart` — `GlassShaderCache`
- `lib/widgets/glass_surface.dart` — `GlassSurface`, `GlassVariant`, `GlassRenderMode`, `resolveGlassRenderMode`
- `lib/widgets/liquid_tab_bar.dart` — `LiquidTabBar`, `LiquidNavItem`, `TabFx`
- `lib/widgets/nav_metrics.dart` — `AonNavMetrics` (resolves the text-scaled bar height + floating-nav clearance from context; single source for both)
- `test/widget/glass_surface_test.dart`
- `test/widget/liquid_tab_bar_test.dart`
- `test/widget/app_shell_test.dart`

**Modify**
- `pubspec.yaml` — add `shaders:` under `flutter:` (§5.1)
- `lib/main.dart` — `main()` → `async`; **preserve the existing `WidgetsFlutterBinding.ensureInitialized()`** as the first line; `await GlassShaderCache.ensureLoaded()` after the existing `SystemChrome` setup and before `runApp` (non-fatal, §5.2)
- `lib/widgets/app_shell.dart` — `extendBody: true`; replace Material `NavigationBar` with the glass island + `LiquidTabBar`; preserve `goBranch`; drive island height/radius from `AonNavMetrics` (§5.8)
- `lib/screens/home_screen.dart`, `program_screen.dart`, `whats_on_screen.dart`, `map_screen.dart`, `info_screen.dart` — consume `AonNavMetrics.clearance(context)` for bottom clearance (§5.8, D4)

## 5. Architecture

### 5.1 Shader + registration
Copy `glass_refraction.frag` verbatim to `shaders/glass_refraction.frag` and register it
under Flutter's `shaders:` pubspec field (compiled to platform-specific formats by the
build). aon2026 has no `shaders:` section today; add:

```yaml
flutter:
  uses-material-design: true
  shaders:
    - shaders/glass_refraction.frag
  assets:
    - assets/images/
```

Preserve the shader uniform **declaration order** exactly. For `ImageFilter.shader`, the
engine owns the first `vec2` size uniform and the first `sampler2D` input; **Dart code must
not overwrite those engine-provided slots.** Application-controlled float uniforms begin
**after** the reserved size slots (the reference's `_GlassShaderBackdrop` correctly starts
its `setFloat` calls at index `2` — `uRadius` — and never touches indices `0/1` or the
sampler), matching the current Flutter `ImageFilter.shader` contract. That contract is
Impeller-only, which is exactly why the runtime-support guard in §5.2 is required.

**Reconciliation rule:** the reference is authoritative for *product behaviour*; the
installed Flutter runtime API is authoritative for the *engine contract*. If MQ_Journey's
code ever appears to write the engine-owned size indices (`0/1`) or the sampler slot, **stop
and reconcile against the installed Flutter version before porting** — do not copy it
verbatim.

### 5.2 GlassShaderCache + startup invariant
Port `GlassShaderCache` **verbatim**. Its proven safety properties are load-bearing and
must be preserved:
- `_load()` early-returns when `ui.ImageFilter.isShaderFilterSupported` is false.
- `FragmentProgram.fromAsset` is wrapped in `try/catch`; on failure `_program = null` and
  the error is logged, **not rethrown**.
- `ready` = `_program != null && isShaderFilterSupported`.
- `ensureLoaded()` awaits a single shared future and **never throws**.

aon2026 `main()` becomes async. It **must** call `WidgetsFlutterBinding.ensureInitialized()`
as its first line (aon2026 already does — **preserve it**), then keep its existing
`SystemChrome` orientation/overlay setup, then `await GlassShaderCache.ensureLoaded()`
before `runApp`. The binding must be initialised before this async/platform-dependent
preload. Because `ensureLoaded()` cannot throw, the preload is a **non-fatal** step:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();   // preserve — required before the async preload
  // ... existing SystemChrome orientation/overlay setup ...
  await GlassShaderCache.ensureLoaded();        // non-fatal; degrades to frost/solid on failure
  runApp(const ProviderScope(child: AonApp()));
}
```

**Invariant (must hold):**
```
shader available                      → shader glass
unavailable/unsupported/load-failure  → frost fallback
accessibility/policy demands stronger → frost or solid
shader-init failure                   → MUST NOT prevent application startup
```
Decorative material rendering must never gate application launch. (This scopes the guarantee
to *shader* failure — the app can still fail to launch for unrelated reasons.) (Unlike MQ's
`bootstrap.dart`, aon2026's `main()` has no env/service validation to fail on; we port only
the shader-load step, keeping aon2026's existing `SystemChrome` setup.)

### 5.3 AonGlass tokens (`lib/app/theme/aon_glass.dart`)
Owns aon2026's glass identity so the primitives stay generic. Dark-tuned (aon2026 is
dark-only); the light branches from `MqGlass` are dropped or collapsed to the dark value.
- Numeric shader/frost tokens carried from `MqGlass`: `blurMd 18`, `rimWidth 42`,
  `refractiveIndex 1.6`, `aberration 0.05`, `blurCoeff 0.03`, `fresnel 0.8`,
  `refractIntensity 0.85`, `radiusBar 18`, `radiusFloating 22`.
- `tint` → `AonColors.night800` (aon2026 night surface), not charcoal.
- `opacityRegular` ~0.45 (shader/frost body), `opacityContent`/`opacityHighContrast`
  ≥ 0.94 (text legibility never depends on the backdrop).
- Border colour → white @ `borderAlpha` (0.28 dark), forced opaque under high contrast.
- These values are a **starting point**; final tuning happens on-device during the Phase 1
  visual/parity pass and is recorded back into this file.

### 5.4 GlassSurface + render-mode policy
Port `GlassSurface` (three variants `bar`/`control`/`content`) and the pure
`resolveGlassRenderMode(variant, highContrast, disableAnimations, shaderSupported,
allowShader)` **verbatim as the primary reference**. Colour/tint come from `AonGlass`
tokens (not a direct `AonColors` import) plus optional caller overrides (`color`,
`borderColor`, `borderWidth`). Brightness/high-contrast/disable-animations are read from
`MediaQuery` internally, exactly as the reference does.

Render-mode semantics (unchanged from the reference policy):
- `content` **or** `highContrast` → **solid** (near-opaque, no BackdropFilter).
- else `disableAnimations` **or** `!shaderSupported` **or** `!allowShader` → **frost**
  (static `ImageFilter.blur`).
- else → **shader** (`ImageFilter.shader` refraction).

`highContrast` is a **separate** input from `disableAnimations`; they are never conflated.

### 5.5 Deferred primitives (no Phase-1 consumer — earn rent later)
- **`GlassPane`** (thin `GlassSurface(control)` wrapper) → **Phase 2**, where the map
  controls first consume it.
- **`AonAnimations`** (shared motion tokens) → **Phase 3** (component system). Phase 1 needs
  no shared motion-token layer: `LiquidTabBar` keeps the reference's literal durations, and
  both it and `GlassSurface` read `MediaQuery.disableAnimationsOf` directly.

`AonHaptics` is **not** deferred — the tab bar consumes it in Phase 1 (§5.7). A vertical
slice stays clean when every new abstraction has a Phase-1 caller.

### 5.6 LiquidTabBar (generic; caller-injected identity)
Port `liquid_tab_bar.dart` — it already imports only `dart:math` + material and is fully
colour-parameterised (`color`, `accent`). Preserve **all** signature mechanics verbatim:
metaball lens position/lerp in index-space, `_slide` controller, tap + horizontal-drag
selection, gel-press `AnimatedScale`, the `_TabIcon` FX dispatch, and every FX painter
(`_ScanlineFx`, `_HomecomingFx`, `_SunrisePainter`, `_ViewfinderPainter`) with their
"leave no overlays behind" idle behaviour. Keep the RTL-safe hit-testing code (harmless
under LTR).

**Adaptations (kept generic — no `AonColors` import inside this file):**
- **D2 — `selectedColor`:** add an optional `Color? selectedColor`. The selected
  icon/label/lens tint use `selectedColor ?? color`; unselected use `color`. The shell
  injects `AonColors.amber` (selected) + `AonColors.contentSecondary` (base) +
  `accent: AonColors.amber` (FX). The widget stays reusable.
- **D5 — reduced motion:** read `MediaQuery.disableAnimationsOf(context)`. When true the bar
  **does not animate** — it does not run zero-duration animations, it simply **omits the
  decorative transforms**. Deterministic behaviour (defined once; referenced by §6.1):
  - no metaball interpolation (the lens jumps to the selected index)
  - no per-tab FX
  - no bounce
  - no gel scale deformation
  - selected index / lens position updates immediately
  - selected icon / label state updates immediately

  This closes a gap in the reference (whose tab-bar animations were unconditional). The
  internal animation durations otherwise remain the reference's literals (no `AonAnimations`
  layer in Phase 1).
- **Label legibility (G2 — corrects a night-ergonomics breach):** the reference hard-codes a
  `fontSize: 10` selected label, but aon2026's type scale has a documented **hard floor —
  *nothing below 13px*** (`aon_typography.dart`, night readability). Porting 10px verbatim
  would plant sub-floor text on the primary nav. **Raise the tab label to ≥13px** (aon2026
  identity wins), exposed as a caller-tunable `labelStyle`/size with a 13px default so the
  primitive stays generic.
- **Large text — measure-first (G1, not speculative machinery):** do **not** pre-build
  adaptive-height logic. Receipts from the reference geometry: the icon is a **non-scaling**
  `size: 25`; the label scales, so at 2.0× the selected content ≈ `25 + (13×2) + gap ≈ 53`,
  inside the reference's fixed **66** box. **Verify** the fixed height holds at 1.6 and 2.0 by
  test; **only if** a real overflow is measured, add adaptation (constrained-but-readable
  label / adjusted spacing / selectively drop decorative FX before the destination becomes
  unreadable) — never suppress the user's scale. The metaball and selected-state identity are
  never sacrificed.
- **G6 — one new species (`TabFx.orbit`):** add a new astronomy-native flourish + painter
  (`_OrbitFx`) — see §5.9 — of the same modest complexity as `spin`/`rotateOpen`, with the
  same "leave no overlay when idle" contract as the reference FX.

### 5.7 AonHaptics
Port `MqHaptics` verbatim (rename). Phase 1 uses `AonHaptics.selection()` on tab tap.
`isEnabled` defaults true (no settings screen); the parameter is retained so a preference
can gate it later. (`AonAnimations` is deferred — §5.5.)

### 5.8 AppShell integration (D4)
Adapt `lib/widgets/app_shell.dart`:
- `Scaffold(extendBody: true, body: navigationShell, bottomNavigationBar: SafeArea(top:
  false, child: Padding(fromLTRB(16,0,16,12), child: GlassSurface(variant: control,
  borderRadius: pill, child: LiquidTabBar(...)))))`. The island radius is a pill —
  `barHeight / 2` (G5: the reference's `36` on its `66`-tall bar is effectively the same, since
  the shader clamps `min(radius, minSide/2) = 33` — not a contradiction). If the bar height
  ever changes (§5.6 measure-first), the radius tracks it so it stays a pill.
- Preserve the exact `goBranch(index, initialLocation: index == currentIndex)` reselect
  logic (tapping the active tab returns it to root — aon2026's current behaviour).
- Drop MQ's `immersiveActive`/`allowShader` gating and the active-branch provider write.
- Inject the 5 `LiquidNavItem`s reusing aon2026's existing nav icons + labels + the D1 FX.

**Floating-bar clearance (single-sourced — NOT five magic numbers):** because
`extendBody: true` lets content scroll *behind* the island (so the glass has something to
refract), the clearance is derived from the bar's *resolved* height, never hand-typed per
screen. A **single** `AonNavMetrics` helper resolves the height from context and exposes the
clearance:

```
resolvedBarHeight(context) = the LiquidTabBar's own layout math over the scaled
                             icon + label metrics (one function, shared)
clearance(context)         = resolvedBarHeight(context)
                           + outerBottomPadding   (the island's 12)
                           + safeAreaBottom
                           + contentGap
```

**One calculation, four consumers.** The same `resolvedBarHeight` drives (1) the
`GlassSurface` island height, (2) the pill radius (`height / 2`), (3) the `LiquidTabBar`
internal layout, and (4) each screen's body/content clearance — no parallel magic numbers.

**G1 note:** if the fixed `66` height holds through 2.0 (the expected case, per §5.6's
receipts), `resolvedBarHeight` is effectively constant and the only *dynamic* term is
`safeAreaBottom` (from `MediaQuery`). The single-source helper still earns its place — it
prevents per-screen drift and absorbs a height change for free *if* the measure-first check
ever finds one — but this spec does **not** assume the bar must grow with text scale.

Concrete touch-points to verify **at every tested text scale** (tracked in the acceptance
gate):
- Program / What's On / Info / Home scroll views: last item clears the island.
- Map: `© OpenStreetMap` attribution (`Positioned`) and the "Directions" FAB clear the
  island; venue/parking bottom sheets remain fully reachable.
- Safe areas: iPhone home indicator + Android gesture-navigation area respected via
  `SafeArea(top: false)`; keyboard insets where relevant.

### 5.9 Per-tab FX mapping (D1 + G6)
`Home → homecoming` · `Program → bounce` · `Now → spin` · `Map → rotateOpen` ·
`Info → orbit` (**new**). `scanline` is QR-specific and unused.

**G6 — the one new species (aon2026-native FX).** The reference offers only four non-QR
flourishes for five tabs, so a naive mapping repeats `bounce` (Program + Info) and adds
nothing aon2026-native. Instead add **`TabFx.orbit`** + a new `_OrbitFx` painter: on
selection, a small point orbits the icon once (a star tracing an ellipse) and leaves **no
overlay when idle**, honouring the reference's FX contract and of the same modest complexity
as `spin`/`rotateOpen`. This resolves the shortage *and* is the single genuinely new kind
this port contributes — an astronomy motif that reads unmistakably as aon2026. FX assignment
is revisitable in the final parity review.

## 6. Accessibility

### 6.1 Motion (`disableAnimations`)
`MediaQuery.disableAnimationsOf(context)` is treated **only** as a reduced-motion signal.
The deterministic behaviour is defined once in §5.6 (no metaball interpolation, no per-tab
FX, no bounce, no gel deformation; selected index/lens and icon/label update immediately).
The bar **omits** the decorative transforms rather than animating them with `Duration.zero`.
Correct selected-state feedback is always preserved.

### 6.2 Glass under reduced motion — documented aon2026 policy
The render policy also drops `control`/`bar` glass to **frost** (static) under
`disableAnimations`. This is a **deliberate aon2026 product/accessibility policy** (the
live-refraction shader animates as the backdrop scrolls, which reads as motion), inherited
from the MQ_Journey reference — **not** something Flutter's reduced-motion setting
inherently requires. `highContrast` is a separate input that forces **solid**. We do not
invent any "reduce transparency" signal (Flutter exposes none).

### 6.3 Text scaling — no global 1.6 cap to protect navigation
The navigation must not be the reason to clamp the user's text scale. Requirements —
distinguishing what the **component** can guarantee from what the **production app** currently
exposes:
- Build `LiquidTabBar` to adapt to large text (§5.6) using current `TextScaler` APIs, not
  deprecated `textScaleFactor` assumptions.
- **Component-level:** stress-test `LiquidTabBar`/shell with synthetic `TextScaler` up to
  **2.0 / platform practical maximum** (~1.0, 1.3, 1.6, 2.0) — no overflow, no loss of
  semantics; the selected destination stays understandable at every scale.
- **Production-app level:** the running app still caps scaling at 1.6 (root clamp, below),
  so the *integrated* shell is verified through **1.6**. The app cannot expose 2.0 until the
  clamp is lifted — the 2.0 guarantee is a **component** guarantee, not a production claim.

**Scoped decision — the existing global clamp (`lib/main.dart:57`, `maxScaleFactor: 1.6`):**
Phase 1 makes the navigation robust to platform-max **independently** of this clamp, so the
clamp is no longer the nav's crutch. Lifting the app-wide cap is **not** done in Phase 1
because content screens were only overflow-hardened to 1.6 in the recent audit; raising it
app-wide would expose out-of-scope content-screen overflows. **Recommendation:** lift the
global cap in **Phase 5 (Gauntlet)** together with a full-app ≤2.0 responsive pass. This is
an explicit, flagged deferral — see §10. (If the owner wants the cap lifted in Phase 1, that
pulls the whole-app large-text audit forward.)

### 6.4 Semantics
Preserve `LiquidTabBar`'s per-tab `Semantics(button, selected, label, onTap)` so
VoiceOver/TalkBack announce each destination and its selected state.

## 7. Testing plan (mirrors the reference + aon2026's existing test style)

- **`glass_surface_test.dart`** — port the pure `resolveGlassRenderMode` cases (content→solid,
  highContrast→solid, disableAnimations→frost, !shaderSupported→frost, supported→shader,
  allowShader:false→frost) + tier widget behaviour (content = solid / no BackdropFilter;
  control = frost in tests, since Impeller is off in the test harness; highContrast→solid;
  reduce-motion→frost). Adapt colour assertions to aon2026 dark tint.
- **`liquid_tab_bar_test.dart`** — tap selection fires `onSelected`; **horizontal-drag
  selection** crosses tab boundaries correctly, **clamps safely at the left/right edges**,
  and only resolves valid destination indices; FX plays on select and **leaves no overlays**
  (idle painters absent) — **including the new `_OrbitFx`** (G6: painter present mid-orbit,
  absent at idle); gel-press; per-tab semantics (button/selected/label); the ≥13px label
  (G2); reduced-motion path (omits FX/transforms, lens jumps — no zero-duration animation);
  large-text layout at 1.6 and 2.0 (no overflow). **Keep the reference's RTL regression
  test** — the ported component carries RTL-safe hit-testing and drag maths, and deleting a
  cheap, already-proven guard buys nothing even though aon2026 ships LTR.
- **`app_shell_test.dart`** — 5 tabs render; tapping navigates the branch; selected state
  correct; reselect returns to branch root; back navigation intact.
- **Responsive** — add shell cases to `responsive_layout_test.dart` (or a sibling) at
  320/414 pt × {1.0, 1.3, 1.6, 2.0}: no overflow, island + last content item both visible.
- Existing 135 tests must stay green (per-screen widget tests don't mount the shell; the
  `main.dart` async change and shell change are covered by the new tests).

**Coverage bound (G4 — stated loudly, not buried):** Impeller is **off** in the
`flutter test` harness, so `control`/`bar` surfaces render **frost** in every test (MQ's own
suite asserts exactly this). The automated tests therefore prove the **policy + fallback
ladder + frost + solid** paths and **never execute the real refraction shader**. The shader
render path has **zero automated coverage by design** and is verified *only* by the runtime
on-device check in §8 — treat a green test run as evidence of the fallback ladder, not of the
shader.

## 8. Acceptance gate (Phase 1 is complete only when ALL hold)

Functional/UX: app starts normally; existing routes still work; selected-tab state correct;
back navigation correct; branch reselect returns to root; tab FX do not retrigger
incorrectly; LiquidTabBar fully integrated in the real `AppShell`; metaball + gel-press +
per-tab FX + amber selected identity present; haptic on selection.

Rendering/fallback: shader loads where supported; frost fallback works where unsupported/on
load failure; solid under high-contrast/content; **startup always succeeds** (§5.2 invariant).

A11y/responsive: reduced-motion path works (§6.1); high-contrast forces solid; accessibility
semantics usable; **large-text (component-level):** `LiquidTabBar`/shell pass synthetic
`TextScaler` stress through 2.0 with no overflow/semantic loss; **large-text (production-app
level):** the integrated shell verified through the currently permitted 1.6 (the root 1.6
cap remains documented a11y debt until Phase 5, §6.3); no clipping on small/large phones;
safe areas correct (home indicator, gesture nav); keyboard/insets where relevant.

Verification & evidence — after implementation, record **each** item as `PASS` / `FAIL` /
`NOT AVAILABLE` (never inherit a pre-implementation result). A green **build does not prove
the shader rendered** — `ImageFilter.shader` is Impeller-runtime-dependent, so the shader
path needs an actual on-device/runtime check, distinct from a compile. Track separately:
- `flutter analyze` — passes, or pre-existing exceptions documented.
- Relevant tests pass.
- Android **build**.
- Android **runtime** (app launches; nav works).
- iOS **build**.
- iOS **runtime** (app launches; nav works).
- **Shader render path** — verified on an Impeller runtime (not merely compiled).
- **Frost fallback** — verified where the shader is unavailable.
- **Performance sanity pass measured in aon2026** (§9).

Then: final **visual parity comparison against MQ_Journey**, and a **second hostile parity
audit** for gaps introduced by the port.

## 9. Performance validation (measured in aon2026 — not inherited)

MQ_Journey is evidence the **architecture is viable**, never evidence that performance is
acceptable in aon2026 (different screens, backdrop composition, map rendering, hero imagery,
widget hierarchy, device workload). After integration, perform a real performance sanity
pass, preferring **profile-mode** on actual devices. Inspect where tooling permits:
- frame jank / dropped frames
- raster & GPU workload
- scrolling behind the glass island
- rapid tab switching
- repeated FX triggering
- shader warm-up / first-use behaviour

(Map-over-glass interaction is **Phase 2** scope — it is not part of this checklist.)

If meaningful profiling cannot be performed in this environment, record it
**`NOT AVAILABLE`**, not `PASS`.

## 10. Phase 1 implementation boundary

**In scope:** the 6 new Dart source files (`aon_glass`, `haptics`, `glass_shader`,
`glass_surface`, `liquid_tab_bar`, `nav_metrics`) + the shader, `pubspec` shader
registration, async `main()` shader load (binding-first), the `AppShell` glass-island
integration with `LiquidTabBar` (≥13px night label, new `TabFx.orbit`/`_OrbitFx`,
height/radius/clearance driven by `AonNavMetrics`), the single-sourced floating-nav clearance
across the 5 shell screens, the 3 new tests, and the verification/parity gate.

**Net-new beyond a verbatim port (small, but real work — not "just copy"):** the `_OrbitFx`
painter (G6), the ≥13px label adaptation (G2), the reduced-motion gating of the tab bar's
controllers (D5), and `AonNavMetrics` (G1/D4). These are the honest adaptation surface; the
plan must budget for them rather than treating Phase 1 as a pure copy.

**Explicitly out of scope / deferred:**
- `GlassPane` primitive (no Phase-1 consumer) → **Phase 2**.
- `AonAnimations` motion tokens (no Phase-1 consumer) → **Phase 3**.
- Standalone `AonTactileButton` → **Phase 3** (component system).
- Glass on map controls, hero overlays, venue/parking sheets, app bars → **Phase 2**.
- `content`-tier glass adoption across text surfaces → **Phase 2/3**.
- Lifting the app-wide `maxScaleFactor: 1.6` clamp + whole-app ≤2.0 responsive pass →
  **Phase 5 (Gauntlet)** (§6.3).
- Not ported: MQ `bootstrap.dart`, `active_shell_branch_index_provider`, MQ theme/token
  files, `mq_tactile_button`.

## 11. Open decisions for the final parity review
- Per-tab FX semantics (D1 + G6) — confirm the `orbit`/`homecoming`/`spin`/`rotateOpen`/
  `bounce` mapping on-device, or reassign.
- `AonGlass` opacity/tint final values — tuned on-device for legibility over night surfaces.
- Whether reduced-motion should keep frost glass or go fully solid (currently frost, §6.2).
- Final tab-label size (≥13px floor is fixed; exact value tuned on-device, §5.6/G2).

## 12. Honest scorecard (this spec, re-scored at freeze)

Named axes, 0–10, each with the buildable artifact that raises it. Re-scored at Phase-1
close; scores may drop then — explaining why is a feature.

| Axis | Now | What moves it up (named artifact) |
|---|---|---|
| Reference fidelity | 8 | line-by-line port confirmed; G5 pill note added |
| Internal consistency | 9 | G1 removed the adaptive-height/clearance contradiction |
| Honesty / falsifiability | 9 | G3 payoff-bound + G4 shader-coverage bound + G7 framing now explicit |
| aon2026 ergonomic fit | 8 | G2 (10px→≥13px) fixes the night-readability breach |
| Ambition / invention | 5 | it is a **port** by design; `TabFx.orbit` (G6) is the one new species — a second astronomy motif (glass tuned to the hero palette) would raise it |
| Implementation-readiness | 9 | no speculative machinery left; the net-new surface (§10) is named and budgeted |

**Honest verdict:** this is a high-fidelity port with four real adaptations and one new
species — not an invention, and it does not pretend to be. The bones are sound and the loose
screws found in the self-gauntlet (G1–G7) are torqued. The one place ambition could rise
without breaking parity is a second aon2026-native touch (astronomy-tuned glass/FX), held as
a flagged option, not smuggled into Phase 1.
