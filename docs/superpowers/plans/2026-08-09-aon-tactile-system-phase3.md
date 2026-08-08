# Phase 3 — Tactile System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bring MQ_Journey's tactile press feel (squish + light haptic) to aon2026's custom tap surfaces via
a new `AonTactileButton`, backed by an `AonAnimations` motion-token vocabulary, adopted on QuickLinkTile,
EventCard, and LiveStrip — with reduced-motion feedback preserved and button semantics intact.

**Architecture:** A surface-agnostic squish wrapper (`GestureDetector` + `AnimatedScale`, MQ-verbatim) with
three aon2026 corrections: reduced-motion **omits** the squish but shows an **instant (non-animated)
`Opacity` pressed state**; the button carries `MergeSemantics`+`Semantics(button)`; and no vestigial
params. It replaces the tiles' `InkWell` (squish supersedes ripple). Consumes Phase-1 `AonHaptics` and the
`MediaQuery.disableAnimationsOf` idiom; does not touch the glass stack.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12, flutter_riverpod. Frozen design spec:
`docs/superpowers/specs/2026-08-09-aon-tactile-system-phase3-design.md`.

## Global Constraints

Copied verbatim from the spec; every task's requirements implicitly include this section.

- **Press scale = `0.96`** (MQ-verbatim, FROZEN — not an on-device tweak). Duration `AonAnimations.fast`
  (150ms), curve `AonAnimations.easeInOut`.
- **Reduced motion drops the motion, never the feedback:** under `MediaQuery.disableAnimationsOf`, omit the
  `AnimatedScale` (scale stays `1.0`) and instead apply an **instant** `Opacity(opacity: pressed ? 0.6 :
  1.0)` — a plain `Opacity`, NOT `AnimatedOpacity`. Never `Duration.zero`.
- **Button API is exactly** `{required Widget child, required VoidCallback onTap, bool hapticsEnabled =
  true, double borderRadius = 12}`. **No** `semanticLabel`, `variant`, `size`, `disabled`, `onLongPress`,
  `autofocus`, `focusNode`. `borderRadius` shapes the keyboard focus ring (its only job).
- **Semantics + keyboard:** the button wraps `MergeSemantics > Semantics(button: true, onTap: onTap) >
  FocusableActionDetector > GestureDetector > DecoratedBox(foreground focus ring) > feedback` → one coherent
  button node (child text is the label; no forced label → no double-read); Tab-focusable; `ActivateIntent`
  (Enter/Space) → `onTap`; a theme-`primary` focus ring on keyboard focus.
- **Haptic:** light impact on tap-down only, via `AonHaptics.light(hapticsEnabled)`. No haptic on up/cancel.
- **Adoption replaces the `InkWell`** on QuickLinkTile / EventCard / LiveStrip (squish replaces ripple); the
  surface (`Material`/`Card` + content) is preserved, the `onTap` moves to the button.
- **Do NOT touch:** the glass stack, `AonHaptics`, theme button styles, the tab bar, Material buttons,
  bottom sheets, map pins, or content-tier glass (all deferred/non-goals).
- **Night ergonomics:** the tiles are already ≥56/104px; do not shrink them.

---

## File Structure

**Create**
- `lib/app/theme/aon_animations.dart` — `AonAnimations` (duration ladder + 2 curves).
- `lib/widgets/aon_tactile_button.dart` — `AonTactileButton`.
- `test/widget/aon_tactile_button_test.dart`
- `test/widget/tactile_adoption_test.dart` — QuickLinkTile / EventCard / LiveStrip adoption.

**Modify**
- `lib/widgets/quick_link_tile.dart` — replace `InkWell` with `AonTactileButton`.
- `lib/widgets/event_card.dart` — same.
- `lib/screens/home_screen.dart` — `_LiveStrip`: same.

---

## Task 1: AonAnimations + AonTactileButton

**Files:**
- Create: `lib/app/theme/aon_animations.dart`, `lib/widgets/aon_tactile_button.dart`
- Test: `test/widget/aon_tactile_button_test.dart`

**Interfaces:**
- Produces: `AonAnimations` (`fast/normal/slow/sheet` Durations, `easeInOut/easeOutCubic` Curves);
  `AonTactileButton({required Widget child, required VoidCallback onTap, bool hapticsEnabled = true})`.
- Consumes: `AonHaptics` (`lib/utils/haptics.dart`).

- [ ] **Step 1: Write the failing test**

`test/widget/aon_tactile_button_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

void main() {
  Widget harness(Widget button, {bool reduceMotion = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => MediaQuery(
              // copyWith preserves the ambient size/dpr; only toggle the flag.
              data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
              child: button,
            ),
          ),
        ),
      ),
    );
  }

  // Scope press-feedback finders to the button subtree so a stray framework
  // Opacity/AnimatedScale can never satisfy or break the assertion.
  Finder inButton(Type t) =>
      find.descendant(of: find.byType(AonTactileButton), matching: find.byType(t));

  // A plain child so the only AnimatedScale/Opacity in the subtree is the button's.
  Widget child() => const SizedBox(width: 120, height: 60, child: ColoredBox(color: Colors.blue));

  testWidgets('onTapUp fires onTap; onTapCancel does not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(AonTactileButton(onTap: () => taps++, child: child())));

    await tester.tap(find.byType(AonTactileButton));
    expect(taps, 1);

    // Cancelled gesture: down then move away → cancel, no tap.
    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    await g.moveBy(const Offset(400, 400));
    await g.cancel();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('press squishes to 0.96 and returns to 1.0 (incl. cancel)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(AonTactileButton(onTap: () => taps++, child: child())));

    AnimatedScale scale() => tester.widget<AnimatedScale>(inButton(AnimatedScale));
    expect(scale().scale, 1.0);

    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(scale().scale, 0.96); // pressed
    expect(scale().duration, AonAnimations.fast);
    expect(scale().curve, AonAnimations.easeInOut);

    await g.cancel();
    await tester.pump();
    expect(scale().scale, 1.0); // no stuck-squished card
    expect(taps, 0);
  });

  testWidgets('reduced motion: no squish, instant Opacity pressed state, onTap still fires',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(AonTactileButton(onTap: () => taps++, child: child()), reduceMotion: true),
    );

    // No animated squish under reduced motion.
    expect(inButton(AnimatedScale), findsNothing);
    // A plain (non-animated) Opacity provides the pressed state.
    expect(inButton(AnimatedOpacity), findsNothing);
    Opacity op() => tester.widget<Opacity>(inButton(Opacity));
    expect(op().opacity, 1.0);

    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(op().opacity, 0.6); // instant pressed feedback
    await g.up();
    await tester.pump();
    expect(op().opacity, 1.0);
    expect(taps, 1);
  });

  testWidgets('light haptic on tap-down (exact call); none when disabled', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    // hapticsEnabled: true (default)
    await tester.pumpWidget(harness(AonTactileButton(onTap: () {}, child: child())));
    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(
      calls.any((c) =>
          c.method == 'HapticFeedback.vibrate' && c.arguments == 'HapticFeedbackType.lightImpact'),
      isTrue,
    );
    await g.up();
    await tester.pump();

    // hapticsEnabled: false → no haptic call
    calls.clear();
    await tester.pumpWidget(
      harness(AonTactileButton(onTap: () {}, hapticsEnabled: false, child: child())),
    );
    final g2 = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
    await g2.up();
    await tester.pump();
  });

  testWidgets('is a single button semantics node with a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(
      AonTactileButton(onTap: () {}, child: const Text('Go to program')),
    ));
    expect(find.bySemanticsLabel('Go to program'), findsOneWidget);
    final sem = tester.getSemantics(find.bySemanticsLabel('Go to program'));
    expect(sem.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('keyboard: Tab focuses (visible ring) + Enter/Space activate', (tester) async {
    // Focus highlights only show in keyboard-navigation mode; force it for the test.
    final prev = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = prev);

    var taps = 0;
    await tester.pumpWidget(harness(AonTactileButton(onTap: () => taps++, child: child())));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // Focus ring visible: the button's foreground DecoratedBox now has a border.
    final ringed = tester
        .widgetList<DecoratedBox>(inButton(DecoratedBox))
        .where((d) => (d.decoration as BoxDecoration).border != null);
    expect(ringed, isNotEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/aon_tactile_button_test.dart`
Expected: FAIL — `aon_animations.dart` / `aon_tactile_button.dart` do not exist.

- [ ] **Step 3: Write the minimal implementation**

`lib/app/theme/aon_animations.dart`:
```dart
import 'package:flutter/material.dart';

/// Astronomy Open Night motion tokens.
///
/// A small, canonical duration + curve vocabulary ported from MQ_Journey's
/// `MqAnimations` (values verbatim), preventing magic-number animation values.
/// Phase 3 consumes [fast] + [easeInOut] (the tactile button); the rest are the
/// established scale for later phases. No `adaptive` helper: reduced motion is
/// handled by consumers omitting transforms (Phase-1 D5), not `Duration.zero`.
abstract final class AonAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration sheet = Duration(milliseconds: 350);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
}
```

`lib/widgets/aon_tactile_button.dart`:
```dart
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/utils/haptics.dart';

/// A surface-agnostic tactile wrapper: a squishy press-in scale + a light haptic
/// on tap-down. Ported from MQ_Journey's `MqTactileButton`, with three aon2026
/// corrections: reduced motion keeps *feedback* (an instant, non-animated opacity
/// press) while dropping the *motion*; a coherent button-semantics node; and no
/// vestigial params.
///
/// The caller supplies the visual surface via [child]; this widget adds only the
/// press feedback, gesture, and semantics — no surface, no shadow.
class AonTactileButton extends StatefulWidget {
  const AonTactileButton({
    super.key,
    required this.child,
    required this.onTap,
    this.hapticsEnabled = true,
    this.borderRadius = 12,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Fires a light haptic on tap-down when true. Present for reference-signature
  /// parity with `MqTactileButton`; feeds [AonHaptics.light].
  final bool hapticsEnabled;

  /// Shapes the keyboard focus ring to match the child's corners. (MQ's
  /// `MqTactileButton` carried this param but never used it; here it earns its keep.)
  final double borderRadius;

  @override
  State<AonTactileButton> createState() => _AonTactileButtonState();
}

class _AonTactileButtonState extends State<AonTactileButton> {
  bool _pressed = false;
  bool _focused = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
      widget.onTap();
      return null;
    }),
  };

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails _) {
    _setPressed(true);
    AonHaptics.light(widget.hapticsEnabled);
  }

  void _handleTapUp(TapUpDetails _) {
    _setPressed(false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Reduced motion drops the motion, not the feedback: an instant (non-animated)
    // opacity press replaces the squish so a pressed state is always visible.
    final Widget feedback = reduceMotion
        ? Opacity(opacity: _pressed ? 0.6 : 1.0, child: widget.child)
        : AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: AonAnimations.fast,
            curve: AonAnimations.easeInOut,
            child: widget.child,
          );

    // Keyboard focus ring (only shown in keyboard-navigation mode). Wraps the
    // un-scaled bounds so the press squish doesn't move it.
    final Widget ringed = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _focused
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : const BoxDecoration(),
      child: feedback,
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          actions: _actions,
          onShowFocusHighlight: (value) {
            if (mounted) setState(() => _focused = value);
          },
          mouseCursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: () => _setPressed(false),
            child: ringed,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/aon_tactile_button_test.dart`
Expected: PASS (all 5 tests). If the haptic test flakes, confirm the mock handler is set before the gesture
and a `pump()` follows `startGesture`.

- [ ] **Step 5: Commit**

```bash
git add lib/app/theme/aon_animations.dart lib/widgets/aon_tactile_button.dart test/widget/aon_tactile_button_test.dart
git commit -m "feat(ui): AonTactileButton + AonAnimations — squish + haptic, reduced-motion-safe (Phase 3)"
```

---

## Task 2: Adopt on QuickLinkTile, EventCard, LiveStrip

**Files:**
- Test: `test/widget/tactile_adoption_test.dart`
- Modify: `lib/widgets/quick_link_tile.dart`, `lib/widgets/event_card.dart`, `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: `AonTactileButton` (Task 1).

- [ ] **Step 1: Write the failing test**

`test/widget/tactile_adoption_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/quick_link_tile.dart';

void main() {
  testWidgets('QuickLinkTile is a tactile button; tap fires onTap; one button node', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AonTheme.build(),
      home: Scaffold(
        body: QuickLinkTile(
          icon: Icons.map_rounded,
          label: 'Map',
          description: 'Venues, toilets, first aid',
          accent: Colors.amber,
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.descendant(of: find.byType(QuickLinkTile), matching: find.byType(AonTactileButton)),
        findsOneWidget);
    expect(find.descendant(of: find.byType(QuickLinkTile), matching: find.byType(InkWell)),
        findsNothing); // ripple replaced by squish

    await tester.tap(find.byType(QuickLinkTile));
    expect(taps, 1);

    final sem = tester.getSemantics(find.bySemanticsLabel(RegExp('Map')));
    expect(sem.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('EventCard is a tactile button; tap fires onTap; button node with title', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    final event = EventsData.all.first;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AonTheme.build(),
        home: Scaffold(body: EventCard(event: event, onTap: () => taps++)),
      ),
    ));

    expect(find.descendant(of: find.byType(EventCard), matching: find.byType(AonTactileButton)),
        findsOneWidget);
    expect(find.descendant(of: find.byType(EventCard), matching: find.byType(InkWell)), findsNothing);

    await tester.tap(find.byType(EventCard));
    expect(taps, 1);

    final sem = tester.getSemantics(
        find.bySemanticsLabel(RegExp(RegExp.escape(event.title))));
    expect(sem.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('_LiveStrip adopts the tactile button (structural, via HomeScreen)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(theme: AonTheme.build(), home: const HomeScreen()),
    ));
    await tester.pump();

    // The live strip's text sits inside an AonTactileButton (ripple replaced).
    final strip = find.textContaining('happening right now');
    expect(strip, findsOneWidget);
    expect(
      find.ancestor(of: strip, matching: find.byType(AonTactileButton)),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/tactile_adoption_test.dart`
Expected: FAIL — the tiles still use `InkWell`; no `AonTactileButton` present.

- [ ] **Step 3: Implement — QuickLinkTile**

In `lib/widgets/quick_link_tile.dart`, add `import 'package:aon2026/widgets/aon_tactile_button.dart';` and
replace the `Material > InkWell` with `AonTactileButton > Material`:
```dart
return AonTactileButton(
  onTap: onTap,
  borderRadius: AonSpacing.radiusMd, // focus ring matches the tile's corners
  child: Material(
    color: AonColors.night900,
    borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
    clipBehavior: Clip.antiAlias,
    child: Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(AonSpacing.space4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: AonColors.night700),
      ),
      child: Column(
        // ... unchanged content ...
      ),
    ),
  ),
);
```

- [ ] **Step 4: Implement — EventCard**

In `lib/widgets/event_card.dart`, add the import and replace `Card > InkWell` with `AonTactileButton >
Card`:
```dart
return AonTactileButton(
  onTap: onTap,
  borderRadius: AonSpacing.radiusMd, // matches the themed Card's corner radius
  child: Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AonSpacing.space4),
      child: Column(
        // ... unchanged content ...
      ),
    ),
  ),
);
```

- [ ] **Step 5: Implement — _LiveStrip**

In `lib/screens/home_screen.dart` (`_LiveStrip.build`), add the import and replace `Material > InkWell`
with `AonTactileButton > Material`:
```dart
return AonTactileButton(
  onTap: () => context.go(Routes.whatsOn),
  borderRadius: AonSpacing.radiusMd,
  child: Material(
    color: AonColors.live.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
    clipBehavior: Clip.antiAlias,
    child: Container(
      padding: const EdgeInsets.all(AonSpacing.space4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: AonColors.live.withValues(alpha: 0.4)),
      ),
      child: Row(
        // ... unchanged content ...
      ),
    ),
  ),
);
```

- [ ] **Step 6: Run the adoption test + full regression**

Run: `flutter test test/widget/tactile_adoption_test.dart`
Expected: PASS (3 tests).
Run: `flutter analyze` → clean (no orphaned imports).
Run: `flutter test` → the pre-Phase-3 baseline plus the new tests, all green; `responsive_layout_test`
(mounts Home + Program with all three tiles) unaffected.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/quick_link_tile.dart lib/widgets/event_card.dart lib/screens/home_screen.dart test/widget/tactile_adoption_test.dart
git commit -m "feat(ui): adopt AonTactileButton on QuickLinkTile, EventCard, LiveStrip"
```

---

## Task 3: Verification & finish

**Files:** none (evidence; may update spec §8 with results).

Record each item `PASS` / `FAIL` / `NOT AVAILABLE` (never inherited).

- [ ] **Step 1: Static + tests baseline**

`flutter analyze` clean; `flutter test` — report before/after totals vs the pre-Phase-3 baseline (capture
the baseline before Task 1).

- [ ] **Step 2: Builds**

`flutter build ios --debug --no-codesign` and `flutter build apk --debug` — record PASS/FAIL.

- [ ] **Step 3: iOS runtime**

Boot the simulator (`xcrun simctl boot <udid>`), attach the MCP panel, `flutter build ios --simulator
--debug`, launch. Verify on-device:
- a home QuickLinkTile / an EventCard **squishes** on press (a mid-press scale-down);
- navigation still works from all three tile types;
- **reduced-motion**: enable Reduce Motion (Settings ▸ Accessibility, or an `disableAnimations` MediaQuery
  harness) and confirm the squish is gone but an **instant opacity press** shows;
- **high-contrast visual regression (G10)**: the tiles still render usably; no lost state layer;
- **keyboard (bonus)**: if an external keyboard is attachable, Tab shows a focus ring and Enter/Space
  activates a tile; otherwise the Task-1 keyboard test is the evidence (record `NOT AVAILABLE` on-device).
Capture screenshots. Record each PASS/FAIL.

- [ ] **Step 4: Haptic (test-verified, not visual)**

The exact-`lightImpact` platform-channel assertion in Task 1 is the haptic evidence — note it is NOT
visually verifiable.

- [ ] **Step 5: Android runtime / performance**

If an emulator/profile trace is unavailable, record `NOT AVAILABLE`.

- [ ] **Step 6: Parity + hostile audit**

Behaviour parity vs MQ_Journey (whole-card squish + light-haptic-on-down). Hostile audit for: gesture
conflicts (double-onTap), lost/duplicated semantics, reduced-motion feedback regressions, stuck-pressed
states.

- [ ] **Step 7: Finish the branch**

**REQUIRED SUB-SKILL:** superpowers:finishing-a-development-branch — verify tests, present options, execute
the choice.

---

## Self-Review

**Spec coverage:** AonAnimations (§5.1 → T1), AonTactileButton with the frozen structure + reduced-motion
Opacity + exact haptic + button semantics (§5.2 → T1 tests), adoption replacing InkWell on the three tiles
(§5.3 → T2), non-adoptions (T2 leaves Material buttons/sheets/pins/glass untouched), never-disabled fact
(§3 → the tiles' required non-null onTaps), G5 frozen 0.96 / G6 no chevron / G7 touch-vs-assistive / G8
exact haptic / G9 cancel→1.0 / G10 high-contrast — all mapped.

**Placeholder scan:** no TBD/TODO; every code step is complete. The `// ... unchanged content ...` markers
in T2 refer to code already present in the files being modified (not new code to invent).

**Type consistency:** `AonTactileButton({child, onTap, hapticsEnabled, borderRadius})` used identically
across T1 impl, T1 tests, and T2 adoption (all three tiles pass `borderRadius: AonSpacing.radiusMd`).
`AonAnimations.fast`/`easeInOut` consumed in the button and asserted in the test.

**Empirical validation (done during the gauntlet, before freezing):** every load-bearing idiom was run and
confirmed — `onTapDown` fires after `startGesture`+`pump` (scale reads `0.96`); `tapCancel`→`1.0`; the exact
`HapticFeedback.vibrate`/`lightImpact` platform call is captured (and robust to `SystemChrome` setup noise);
`MergeSemantics`+`Semantics(button)` yields one button node whose label carries the child text;
`ActivateIntent` fires on **both** Enter and Space; `FocusHighlightStrategy.alwaysTraditional` surfaces the
ring; Tab focuses without any `autofocus` API; `_LiveStrip` renders at the 19:00 fixed clock. The focus-ring
container is `DecoratedBox(position: DecorationPosition.foreground)` (not `Container.foregroundDecoration`).
