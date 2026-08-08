# Phase 3 — Tactile System (Design)

**Date:** 2026-08-09 (Australia/Sydney)
**App:** aon2026 (Astronomy Open Night 2026)
**Reference implementation:** `../MQ_Journey` (design source of truth; read from source line-by-line).
**Naming:** "Liquid Glass-inspired" / "Glass UI layer" only — never "Liquid Glass" unqualified.
**Builds on:** Phases 1–2 — consumes `AonHaptics` (Phase 1) and the `MediaQuery.disableAnimationsOf`
reduced-motion idiom; does **not** touch the glass stack.
**Status:** Frozen for spec self-review → user review → implementation plan. Not implemented.

---

## 1. Goal

Bring MQ_Journey's **tactile press feel** — a squishy scale-down + a light haptic — to aon2026's custom
tap surfaces, backed by a small shared **motion-token layer**. On completion, the home shortcut tiles, the
programme cards, and the live strip press like MQ's cards (whole-surface squish + haptic), and the app has
an `AonAnimations` vocabulary for future motion.

**Nature of this work (honest framing):** a **faithful port of two tiny reference pieces** — a 71-line
`MqTactileButton` (squish wrapper) and a 6-token `MqAnimations` file — made genuinely better by **three
corrections MQ lacks** (§3). It is recombination + accessibility repair, not invention, and the scorecard
says so. Ambition lives in the corrections, not novelty.

### Non-goals (Phase 3) — each with its reason
- **No content-tier glass across text surfaces.** `GlassVariant.content` **always renders solid**
  (`glass_surface.dart:21`), and governance keeps Home cards / sheets / dialogs / event+list cards solid.
  Adopting it is cosmetic tokenization with ~zero visual change — deferred (revisit only if a real need
  appears).
- **No tactile squish/haptic on Material buttons** (`FilledButton`/`OutlinedButton`/`TextButton`/FAB). MQ
  never tactilizes Material buttons — they keep their ink ripple. (This was an explicit scope decision.)
- **No `variant`/`size`/`disabled`/`onLongPress` on the button.** MQ's has none; adding them is speculative.
- **No `adaptive(Duration)` helper.** MQ's exists but is **never called**, and its `Duration.zero` return
  contradicts aon2026's Phase-1 D5 rule (reduced motion **omits** transforms, never zero-duration them).
- **No map-pin adoption.** Pins are markers, not tiles/cards (out of the chosen scope).
- **No tab-bar refactor to consume `AonAnimations`.** Its inline durations (460/130/900ms) don't match the
  MQ token ladder; unifying them would change its feel — out of scope.

## 2. Source-of-truth model (unchanged from Phases 1–2)

- **From MQ_Journey:** the tactile press mechanics (`AnimatedScale` 0.96 @ `fast` easeInOut, light haptic on
  tap-down, surface-agnostic) and the motion-token vocabulary (`fast/normal/slow/sheet`, `easeInOut`/
  `easeOutCubic`).
- **aon2026 owns (do not regress):** `AonColors`/`AonTheme`/`AonSpacing`/`AonTypography`, dark-only, night
  readability, ≥56px targets, the reduced-motion = **omit-transforms** doctrine (Phase 1 D5), product
  behaviour + IA.
- **Portability principle:** `AonTactileButton` is generic (caller passes the surface + `onTap`); it imports
  `AonAnimations` + `AonHaptics` but no `AonColors`/`AonTheme`.

## 3. Reference facts + the three honest corrections

Verbatim from recon (`MQ_Journey/lib/shared/widgets/mq_tactile_button.dart`,
`.../lib/app/theme/mq_animations.dart`):

- **`MqTactileButton` (71 lines):** `GestureDetector(behavior: opaque)` → `onTapDown`(set pressed +
  `MqHaptics.light`) / `onTapUp`(clear pressed + `onTap()`) / `onTapCancel`(clear pressed) wrapping
  `AnimatedScale(scale: pressed ? 0.96 : 1.0, duration: MqAnimations.fast /*150ms*/, curve: easeInOut)`. No
  variants/sizes/disabled. `borderRadius` param is **stored but never used**. Does **not** wrap glass. 14
  call sites, all the single form.
- **`MqAnimations` (6 tokens):** `fast 150 / normal 200 / slow 300 / sheet 350`; `defaultCurve easeInOut`,
  `sheetCurve easeOutCubic`; plus `adaptive(Duration, ref)` → `Duration.zero` when a settings provider's
  `reducedMotion` is true. **`adaptive` has zero call sites; only `fast` and `normal` are used anywhere.**

**The three corrections (this is where the port earns its keep):**
1. **Reduced motion (MQ has a bug here).** MqTactileButton's `AnimatedScale` runs **unconditionally** — its
   only reduced-motion path (`adaptive`) is never wired, so MQ's button ignores reduced motion.
   `AonTactileButton` reads `MediaQuery.disableAnimationsOf(context)` and **omits** the squish (scale stays
   `1.0`), matching the codebase idiom (`liquid_tab_bar.dart:243`, `scale: (pressed && !_reduceMotion) ?
   … : 1.0`). Not `Duration.zero` — omission (Phase 1 D5).
2. **Button semantics (MQ has none).** MqTactileButton is a bare `GestureDetector` with no semantic role —
   fine when its child is a labelled button, but it **replaces `InkWell`** on aon2026's tiles, which today
   get their button role from that `InkWell`. `AonTactileButton` wraps `Semantics(button: true, onTap:
   onTap, label: semanticLabel)` so replacing `InkWell` does not regress accessibility.
3. **Cut the vestigial `borderRadius`.** MQ stores it unused; aon2026 drops it (Phase-2 gauntlet lesson —
   no dead params). The button is surface-agnostic; radius comes from the child.

## 4. Concrete files

**Create**
- `lib/app/theme/aon_animations.dart` — `AonAnimations` (duration ladder `fast/normal/slow/sheet` + curves
  `easeInOut`/`easeOutCubic`). Phase-3 consumers: `fast` + `easeInOut` (§7 flags the rest as the ported
  vocabulary, not speculative machinery).
- `lib/widgets/aon_tactile_button.dart` — `AonTactileButton` (squish + light haptic + reduced-motion
  omission + button semantics).
- `test/widget/aon_tactile_button_test.dart`

**Modify**
- `lib/widgets/quick_link_tile.dart` — replace `Material > InkWell(onTap)` with `AonTactileButton(onTap:,
  child: Material > Container)`; preserve the night900 surface, border, clip, and content.
- `lib/widgets/event_card.dart` — same swap around the `Card` body.
- `lib/screens/home_screen.dart` — `_LiveStrip`: same swap.

No changes to the glass stack, `AonHaptics`, theme button styles, or the tab bar.

## 5. Architecture

### 5.1 `AonAnimations` (motion tokens)
```dart
abstract final class AonAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 350);
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
}
```
Faithful port of MQ's vocabulary (values verbatim). **No `adaptive` helper** (§3, §1 non-goals). Phase 3
consumes `fast` + `easeInOut` via the tactile button; the remaining tokens are the established motion scale
for later phases (honestly flagged in §7 — a 6-const vocabulary is standard design-system practice, not the
kind of unused *widget* the Phase-2 gauntlet cut).

### 5.2 `AonTactileButton`
Surface-agnostic squish wrapper. Public API:
```dart
AonTactileButton({
  Key? key,
  required Widget child,        // the caller's visual surface (Material/Container/etc.)
  required VoidCallback onTap,   // fired on tap-up
  bool hapticsEnabled = true,    // light haptic on tap-down
  String? semanticLabel,         // optional; the button role is always applied
})
```
Mechanics (verbatim from MQ except the corrections):
- `Semantics(button: true, onTap: onTap, label: semanticLabel, child: GestureDetector(...))` — wraps the
  gesture layer so the whole surface reads as one button node.
- `GestureDetector(behavior: HitTestBehavior.opaque)`:
  - `onTapDown` → `setState(pressed = true)`; `AonHaptics.light(hapticsEnabled)`.
  - `onTapUp` → `setState(pressed = false)`; `onTap()`.
  - `onTapCancel` → `setState(pressed = false)` (no haptic, no `onTap`).
  - every handler guards `if (!mounted) return;`.
- `AnimatedScale(scale: (pressed && !reduceMotion) ? 0.96 : 1.0, duration: AonAnimations.fast, curve:
  AonAnimations.easeInOut, child: child)`, where `reduceMotion = MediaQuery.disableAnimationsOf(context)`.
  Under reduced motion the scale never leaves `1.0` — the squish is **omitted**, not zero-duration'd.
- No `AnimationController` (plain implicit `AnimatedScale`, matching MQ). No drop shadow (MQ removed it). No
  disabled state (`onTap` is non-nullable, always fires) — matching MQ.

**Semantics coherence (Phase-2 O3 lesson — avoid double-read):** `semanticLabel` is **optional** and used
only for icon-only children. The tiles already carry their own text, so they pass **no** `semanticLabel`
(the child text is the label, exactly as the `InkWell` they replace) and wrap the child in `MergeSemantics`
so the role + all the tile's text collapse into **one** button node. Passing a `semanticLabel` *and*
keeping the child text would read the label twice — do not do both.

### 5.3 Adoption pattern (the three tiles)
Each tile today is `Material(color, radius, clip) > InkWell(onTap) > <content>`. The port becomes:
```dart
AonTactileButton(
  onTap: onTap,
  child: Material(
    color: ...,
    borderRadius: ...,
    clipBehavior: Clip.antiAlias,
    child: <the existing Container/Padding + content, minus the InkWell>,
  ),
)
```
- The **whole card squishes** (the `AnimatedScale` scales the `Material` surface), matching MQ's
  whole-card press.
- The **ink ripple is replaced by the squish** — MQ's deliberate press aesthetic. This is a conscious
  trade (lose ripple, gain squish + haptic), not an oversight. Nesting `AonTactileButton`'s
  `GestureDetector` *inside* the retained `InkWell` is rejected: two tap recognizers in one arena is exactly
  the conflict MQ avoids by giving its tiles no `InkWell`.
- **Per-tile specifics** (none pass `semanticLabel`; each wraps its content in `MergeSemantics` so the
  tile's own text is the button's label — §5.2):
  - `QuickLinkTile` — `Material(night900, radiusMd, clip)`; `onTap` → `AonTactileButton`. VoiceOver reads
    "<label>, <description>, button" from the existing title + description text.
  - `EventCard` — `Card`-themed surface; `onTap` → `AonTactileButton`. Label from the existing title/meta.
  - `_LiveStrip` — `Material(live@0.12, radiusMd, clip)`; `onTap` → `AonTactileButton`. Label from the
    existing "N activities happening right now" text.

## 6. Accessibility
- **Reduced motion:** the squish is omitted under `MediaQuery.disableAnimationsOf` (§5.2). Haptic + `onTap`
  still fire — only the decorative scale is dropped.
- **Semantics:** every adopted tile keeps a single `button`-role node with its label + tap action (§5.2).
- **Targets:** the tiles are already ≥56/104px; the port does not shrink them.
- **Haptics preference:** `hapticsEnabled` defaults `true` (no settings screen, as with the Phase-1 tab
  bar); retained so a preference can gate it later.

## 7. Testing plan

- **`aon_tactile_button_test.dart`:**
  - renders its child; `onTapUp` fires `onTap`; `onTapCancel` does **not** fire `onTap`.
  - **press scale:** after `onTapDown` (no settle) the `AnimatedScale.scale` target is `0.96`; after
    `onTapUp` it returns to `1.0`.
  - the `AnimatedScale` uses `duration == AonAnimations.fast` and `curve == AonAnimations.easeInOut` (proves
    the token is consumed).
  - **reduced motion:** with `MediaQuery(disableAnimations: true)`, after `onTapDown` the scale stays
    `1.0` (squish omitted) **and** `onTap` still fires on up.
  - **haptic:** capture `SystemChannels.platform` method calls via a mock handler; `onTapDown` with
    `hapticsEnabled: true` emits `HapticFeedback.vibrate`/`lightImpact`; with `hapticsEnabled: false` it
    does not.
  - **semantics:** one node with `button: true`, the given `semanticLabel`, and a tap action.
- **Adoption tests** (either in the button test file or per-tile): mounting `QuickLinkTile` / `EventCard` /
  `_LiveStrip` (via its screen), tapping fires the tile's `onTap`, and the tile exposes one `button`
  semantics node with its label. (`_LiveStrip` is private → exercise it by pumping `HomeScreen` and tapping,
  or assert the pattern via `QuickLinkTile`/`EventCard` which are public.)
- **Regression:** `responsive_layout_test` (mounts Home + Program, which contain all three tiles) stays
  green; the full suite stays green against the captured pre-Phase-3 baseline.

**Coverage note:** the haptic is verified by the platform-channel capture (test), not by the runtime —
haptics can't be seen in a screenshot. The squish **is** runtime-observable (a mid-press scale-down).

## 8. Acceptance gate (Phase 3 is complete only when ALL hold)

**Functional/UX:** the three tile types press with a whole-card squish and a light haptic; tapping still
navigates exactly as before; Material buttons unchanged (ripple intact); no tile shrinks below its target.

**A11y:** reduced-motion omits the squish (haptic + onTap intact); each adopted tile reads as one `button`
node with its label; high-contrast/large-text unaffected (no glass involved).

**Verification & evidence** — record each as `PASS` / `FAIL` / `NOT AVAILABLE`:
- `flutter analyze` clean; tests pass (report before/after totals vs the captured baseline).
- Android **build**; iOS **build**; iOS **runtime** (tiles squish on press; nav still works).
- **Squish** — visually confirmed on-device (a tile scaled-down mid-press).
- **Haptic** — verified by the test's platform-channel capture (NOT visually verifiable; say so).
- Android **runtime** / performance — record `NOT AVAILABLE` if the environment can't run them.

Then: **visual/behaviour parity vs MQ_Journey** (whole-card squish + light-haptic-on-down) and a **hostile
audit** for gesture conflicts, lost semantics, or reduced-motion regressions introduced by the port.

## 9. Honest scorecard (re-scored at freeze)

| Axis | Now | What moves it up (named artifact) |
|---|---|---|
| Reference fidelity | 9 | squish mechanics (0.96 @ `fast` easeInOut, light-haptic-on-down, surface-agnostic) + token values ported verbatim |
| Internal consistency | 9 | reduced-motion uses the exact codebase idiom; no `adaptive`/`Duration.zero` contradiction; content-glass no-op named not smuggled |
| Honesty / falsifiability | 9 | the "MQ ignores reduced motion" bug is named; the haptic coverage bound is stated; unused motion tokens flagged |
| aon2026 ergonomic fit | 8 | reduced-motion omission + button semantics are real a11y repairs over MQ; targets preserved |
| Ambition / invention | 4 | it is a **port** of two tiny pieces; the three corrections are repair, not a new species — a native press flourish (e.g. a night-tuned haptic pattern) would raise it |
| Implementation-readiness | 9 | files, API, mechanics, adoption pattern, and tests all named; no dead params/helpers; gesture-conflict path reasoned |

**Honest verdict:** a faithful, small port whose value is (a) spreading MQ's tactile DNA to ~6 tile
surfaces and (b) three accessibility/quality corrections MQ never made. It is not an invention and does not
pretend to be; the one place ambition could rise (an aon2026-native press flourish) is named and held out.

## 10. Open decisions for the final parity review
- Press scale: `0.96` (MQ-verbatim) vs a slightly deeper `0.94` for a more pronounced night-glove press —
  tuned on-device.
- Whether the live strip's chevron should also nudge on press (a small native flourish) — flagged, not in
  this phase.
- Whether to later gate `hapticsEnabled` on a real preference once a settings surface exists.
