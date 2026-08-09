# Phase 3 — Tactile System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bring MQ_Journey's tactile press feel (squish + light haptic) to aon2026's custom tap surfaces via
a new `AonTactileButton`, backed by an `AonAnimations` motion-token vocabulary, adopted on QuickLinkTile,
EventCard, and LiveStrip — with reduced-motion feedback preserved and button semantics intact.

**Architecture:** A surface-agnostic squish wrapper (`GestureDetector` + `AnimatedScale`, MQ-verbatim) with
four aon2026 corrections: reduced-motion **omits** the squish but shows an **instant (non-animated)
`Opacity` pressed state**; the button carries `MergeSemantics`+`Semantics(button)`; and no vestigial
params. It replaces the tiles' `InkWell` (squish supersedes ripple). Consumes Phase-1 `AonHaptics` and the
`MediaQuery.disableAnimationsOf` idiom; does not touch the glass stack.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12, flutter_riverpod. Frozen design spec:
`docs/superpowers/specs/2026-08-09-aon-tactile-system-phase3-design.md`.

## Global Constraints

Copied verbatim from the spec; every task's requirements implicitly include this section.

- **Press scale = `0.96`** (MQ-verbatim, FROZEN — not an on-device tweak). Duration `AonAnimations.fast`
  (150ms), curve `AonAnimations.easeInOut`.
- **Reduced motion drops the motion, never the feedback — and is contrast-safe:** under
  `MediaQuery.disableAnimationsOf`, omit the `AnimatedScale` (pass the child through unscaled) and show the
  pressed state as an **instant outline** on the foreground `DecoratedBox` — **not** a whole-child
  `Opacity` fade (which would sap text/icon contrast for the exact user who set the preference). No tween,
  no `AnimatedOpacity`, no `Duration.zero`.
- **Button API is exactly** `{required Widget child, required VoidCallback onTap, bool hapticsEnabled =
  true, required double borderRadius}`. **No** `semanticLabel`, `variant`, `size`, `disabled`,
  `onLongPress`, `autofocus`, `focusNode`. `borderRadius` is **required** (a surface-agnostic wrapper must be
  told its child's shape) and shapes both the focus ring and the reduced-motion press outline.
- **Semantics + keyboard:** the button wraps `MergeSemantics > Semantics(button: true, onTap: onTap) >
  FocusableActionDetector > GestureDetector(excludeFromSemantics: true) > DecoratedBox(foreground outline) >
  squish` → **exactly one** button node (child text is the label; no forced label → no double-read; the
  gesture layer is `excludeFromSemantics` so it adds no second node); Tab-focusable; `ActivateIntent`
  (Enter/Space) → `onTap`; a theme-`primary` outline on keyboard focus and on reduced-motion press.
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

## Task 0: Preflight (baseline + branch)

**Files:** none (environment capture).

- [ ] **Step 1: Capture git + toolchain state**

Run and record:
```bash
git status --short
git branch --show-current
git rev-parse --short HEAD
flutter analyze
flutter test
```
Record: current branch + commit SHA, the pre-Phase-3 `flutter analyze` result, and the `flutter test`
total/result (this is the **baseline** Task 3 reports against). Note any pre-existing failures.

- [ ] **Step 2: Ensure a Phase-3 feature branch**

If `git branch --show-current` is `main` (or not a Phase-3 branch), create one before any edit:
```bash
git checkout -b feature/tactile-system-phase3
```
Do not implement on `main`. (Prevents discovering at Task 3 that the work was committed to `main`.)

---

## Task 1: AonAnimations + AonTactileButton

**Files:**
- Create: `lib/app/theme/aon_animations.dart`, `lib/widgets/aon_tactile_button.dart`
- Test: `test/widget/aon_tactile_button_test.dart`

**Interfaces:**
- Produces: `AonAnimations` (`fast/normal/slow/sheet` Durations, `easeInOut/easeOutCubic` Curves);
  `AonTactileButton({required Widget child, required VoidCallback onTap, bool hapticsEnabled = true,
  required double borderRadius})` — API identical to Global Constraints (review-6).
- Consumes: `AonHaptics` (`lib/utils/haptics.dart`).

- [ ] **Step 1: Write the failing test**

`test/widget/aon_tactile_button_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

// Semantics tree helpers — count/find button nodes directly (getSemantics can
// resolve to a wrapper node whose own label is empty; the merged button node is
// the one to inspect). Verified against the real structure.
int buttonCount(SemanticsNode n) {
  var c = n.getSemanticsData().flagsCollection.isButton ? 1 : 0;
  n.visitChildren((ch) {
    c += buttonCount(ch);
    return true;
  });
  return c;
}

SemanticsNode? firstButton(SemanticsNode n) {
  if (n.getSemanticsData().flagsCollection.isButton) return n;
  SemanticsNode? found;
  n.visitChildren((ch) {
    found ??= firstButton(ch);
    return true;
  });
  return found;
}

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

  // Factory so every call passes the required borderRadius without repetition.
  AonTactileButton tb({
    required VoidCallback onTap,
    required Widget child,
    bool hapticsEnabled = true,
  }) =>
      AonTactileButton(
        onTap: onTap,
        borderRadius: 12,
        hapticsEnabled: hapticsEnabled,
        child: child,
      );

  Finder inButton(Type t) =>
      find.descendant(of: find.byType(AonTactileButton), matching: find.byType(t));

  // A plain child so the only AnimatedScale/DecoratedBox in the subtree is the button's.
  Widget child() => const SizedBox(width: 120, height: 60, child: ColoredBox(color: Colors.blue));

  // The button's foreground outline DecoratedBoxes that currently carry a border.
  Iterable<DecoratedBox> borders(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(inButton(DecoratedBox))
      .where((d) => (d.decoration as BoxDecoration).border != null);

  testWidgets('onTapUp fires onTap; onTapCancel does not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    await tester.tap(find.byType(AonTactileButton));
    expect(taps, 1);

    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    await g.moveBy(const Offset(400, 400));
    await g.cancel();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('press squishes to 0.96 and returns to 1.0 (incl. cancel)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    AnimatedScale scale() => tester.widget<AnimatedScale>(inButton(AnimatedScale));
    expect(scale().scale, 1.0);

    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(scale().scale, 0.96);
    expect(scale().duration, AonAnimations.fast);
    expect(scale().curve, AonAnimations.easeInOut);

    await g.cancel();
    await tester.pump();
    expect(scale().scale, 1.0); // no stuck-squished card
    expect(taps, 0);
  });

  testWidgets('reduced motion: outline (not opacity/scale) on press; onTap fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(tb(onTap: () => taps++, child: child()), reduceMotion: true),
    );

    // No animated squish and NO opacity fade under reduced motion.
    expect(inButton(AnimatedScale), findsNothing);
    expect(inButton(Opacity), findsNothing);
    expect(borders(tester), isEmpty); // not pressed yet

    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(borders(tester), isNotEmpty); // instant pressed OUTLINE
    await g.up();
    await tester.pump();
    expect(borders(tester), isEmpty);
    expect(taps, 1);
  });

  testWidgets('exactly one light haptic, on tap-down only; none when disabled', (tester) async {
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

    int lightImpacts() => calls
        .where((c) =>
            c.method == 'HapticFeedback.vibrate' && c.arguments == 'HapticFeedbackType.lightImpact')
        .length;

    await tester.pumpWidget(harness(tb(onTap: () {}, child: child())));
    final g = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(lightImpacts(), 1); // exactly one, on down
    await g.up();
    await tester.pump();
    expect(lightImpacts(), 1); // still one — none on up
    // (cancel path) new press then cancel adds no extra beyond its own down.

    // hapticsEnabled: false → zero
    calls.clear();
    await tester.pumpWidget(harness(tb(onTap: () {}, hapticsEnabled: false, child: child())));
    final g2 = await tester.startGesture(tester.getCenter(find.byType(AonTactileButton)));
    await tester.pump();
    expect(lightImpacts(), 0);
    await g2.up();
    await tester.pump();
  });

  testWidgets('one merged button node: label + tap action + performing it fires onTap',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: const Text('Go to program'))));

    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    final root = owner.rootSemanticsNode!;
    expect(buttonCount(root), 1); // exactly one button node (excludeFromSemantics gesture)
    final node = firstButton(root)!;
    final data = node.getSemanticsData();
    expect(data.label, contains('Go to program'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1); // semantic activation invokes onTap
    handle.dispose();
  });

  testWidgets('keyboard: Tab focuses (visible ring) + Enter/Space activate', (tester) async {
    final prev = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = prev);

    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(borders(tester), isNotEmpty); // focus ring visible

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
/// on tap-down. Ported from MQ_Journey's `MqTactileButton`, with four aon2026
/// corrections: reduced motion keeps *feedback* (an instant, non-animated pressed
/// *outline*, not an opacity fade) while dropping the *motion*; one coherent
/// button-semantics node (the gesture layer is excluded from semantics); full
/// keyboard operability + a focus ring; and `borderRadius` repurposed from a
/// vestigial param to shape the outline/ring.
///
/// The caller supplies the visual surface via [child]; this widget adds only the
/// press feedback, gesture, keyboard, and semantics — no surface, no shadow.
class AonTactileButton extends StatefulWidget {
  const AonTactileButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.hapticsEnabled = true,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Fires a light haptic on tap-down when true. Present for reference-signature
  /// parity with `MqTactileButton`; feeds [AonHaptics.light].
  final bool hapticsEnabled;

  /// Shapes both the keyboard focus ring and the reduced-motion pressed outline
  /// to match the child's corners. Required: a surface-agnostic wrapper must be
  /// told its child's shape. (MQ's `MqTactileButton` carried this param but never
  /// used it; here it earns its keep.)
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

    // Motion path squishes; reduced-motion path passes the child through unscaled
    // (its pressed state comes from the outline below — never an opacity fade).
    final Widget squished = reduceMotion
        ? widget.child
        : AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: AonAnimations.fast,
            curve: AonAnimations.easeInOut,
            child: widget.child,
          );

    // One foreground outline serves both instant states, contrast-safe (adds a
    // border, dims nothing): keyboard focus ring, and reduced-motion pressed state.
    // Wraps the un-scaled bounds so the normal-mode squish doesn't move it.
    final bool showOutline = _focused || (reduceMotion && _pressed);
    final Widget ringed = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: showOutline
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : const BoxDecoration(),
      child: squished,
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
          // excludeFromSemantics: the outer Semantics is the sole a11y action, so
          // the gesture layer must not emit a second (duplicate) semantic node.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
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
Expected: all Task-1 tests pass. If the haptic test flakes, confirm the mock handler is set before the gesture
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
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/quick_link_tile.dart';

int buttonCount(SemanticsNode n) {
  var c = n.getSemanticsData().flagsCollection.isButton ? 1 : 0;
  n.visitChildren((ch) {
    c += buttonCount(ch);
    return true;
  });
  return c;
}

SemanticsNode? firstButton(SemanticsNode n) {
  if (n.getSemanticsData().flagsCollection.isButton) return n;
  SemanticsNode? found;
  n.visitChildren((ch) {
    found ??= firstButton(ch);
    return true;
  });
  return found;
}

void main() {
  // Assert the merged button node of a solo-mounted tile: exactly one, labelled, tappable.
  void expectOneButtonLabelled(WidgetTester tester, String contains) {
    final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    expect(buttonCount(root), 1);
    final data = firstButton(root)!.getSemanticsData();
    expect(data.label, contains(contains));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  }

  testWidgets('QuickLinkTile: tactile button, no InkWell, one labelled button node', (tester) async {
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
    expectOneButtonLabelled(tester, 'Map');
    handle.dispose();
  });

  testWidgets('EventCard (complex surface): tactile button, no InkWell, one titled button node',
      (tester) async {
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
    expectOneButtonLabelled(tester, event.title);
    handle.dispose();
  });

  testWidgets('_LiveStrip: tactile button, no InkWell, tapping navigates to What\'s On', (tester) async {
    // Real router so context.go works — behaviour, not just structure (review-3).
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(theme: AonTheme.build(), routerConfig: buildRouter()),
    ));
    await tester.pumpAndSettle();

    final strip = find.textContaining('happening right now');
    expect(strip, findsOneWidget);
    final stripButton = find.ancestor(of: strip, matching: find.byType(AonTactileButton));
    expect(stripButton, findsOneWidget);
    expect(find.descendant(of: stripButton, matching: find.byType(InkWell)), findsNothing);

    await tester.tap(strip);
    await tester.pumpAndSettle();
    // Landed on What's On. (Use textContaining to dodge the title's curly apostrophe
    // in "What’s On Now".)
    expect(find.textContaining('On Now'), findsWidgets);
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
Expected: all Task-2 tests pass.
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

`flutter analyze` clean; `flutter test` — report before/after totals vs the **Task 0** baseline.

- [ ] **Step 2: Builds**

`flutter build ios --debug --no-codesign` and `flutter build apk --debug` — record PASS/FAIL.

- [ ] **Step 3: iOS runtime**

Boot the simulator (`xcrun simctl boot <udid>`), attach the MCP panel, `flutter build ios --simulator
--debug`, launch. Verify on-device:
- a home QuickLinkTile / an EventCard **squishes** on press (a mid-press scale-down);
- navigation still works from all three tile types;
- **reduced-motion**: enable Reduce Motion (Settings ▸ Accessibility, or an `disableAnimations` MediaQuery
  harness) and confirm the squish is gone but an **instant pressed outline** shows, with **no text/icon
  dimming**;
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

- [ ] **Step 7: Re-gate after any audit fix (review-11 — no victory lap)**

If Step 6 (or the on-device pass) changed **any** code, the earlier green results are stale. Do not skip:
```bash
flutter analyze
flutter test
```
Then re-run any affected platform/runtime check from Steps 2–3, and review `git diff` before finishing. If
nothing changed, note "no post-audit changes" and proceed.

- [ ] **Step 8: Finish the branch**

**REQUIRED SUB-SKILL:** superpowers:finishing-a-development-branch — verify tests, present options, execute
the choice.

---

## Self-Review

**Spec coverage:** Task 0 preflight/baseline+branch (review-5); AonAnimations (§5.1 → T1); AonTactileButton
with the frozen structure + reduced-motion **outline** (review-2) + `excludeFromSemantics` (review-9) + exact
haptic (review-8) + one-node/label/tap-action semantics (review-4) + required `borderRadius` (review-6/10) +
keyboard (§5.2 → T1 tests); adoption replacing InkWell with real merged-semantics + LiveStrip **navigation**
tests (§5.3 → T2, review-3/7); non-adoptions (T2 leaves Material buttons/sheets/pins/glass untouched);
never-disabled fact (§3); re-gate after audit (review-11); G5 frozen 0.96 / G6 no chevron / G7
touch-vs-assistive / G10 high-contrast — all mapped.

**Placeholder scan:** no TBD/TODO; every code step is complete. The `// ... unchanged content ...` markers
in T2 refer to code already present in the files being modified (not new code to invent).

**Type consistency:** `AonTactileButton({child, onTap, hapticsEnabled, required borderRadius})` used
identically across Global Constraints, T1 Interfaces, T1 impl, T1 tests, and T2 adoption (all three tiles
pass `borderRadius: AonSpacing.radiusMd`). `AonAnimations.fast`/`easeInOut` consumed in the button and
asserted in the test. Semantics assertions use a tree-walk (`buttonCount`/`firstButton`) — not
`getSemantics`, which resolves to a wrapper with an empty label.

**Prototype/scratch-harness validation (feasibility only — NOT Phase-3 evidence):** during the gauntlet the
load-bearing idioms were exercised in throwaway harnesses to prove they are *possible* — `onTapDown` after
`startGesture`+`pump` (scale `0.96`); `tapCancel`→`1.0`; exactly-one `lightImpact` capture (robust to
`SystemChrome` noise); a single merged button node whose label carries the child text, with a working
`SemanticsAction.tap` under `excludeFromSemantics`; `ActivateIntent` on **both** Enter and Space; the
reduced-motion **outline** (border on press, no `AnimatedScale`/`Opacity`); `alwaysTraditional` surfaces the
ring; Tab focuses without `autofocus`; `_LiveStrip` renders at 19:00; the ring container is
`DecoratedBox(position: DecorationPosition.foreground)`. **All of these must be re-run against the
repository code after implementation** — same standard as build/shader evidence; this establishes API
feasibility, not Phase-3 pass.
