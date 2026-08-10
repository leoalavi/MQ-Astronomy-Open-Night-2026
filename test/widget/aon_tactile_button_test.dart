import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_animations.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

// Semantics tree helpers — count/find button nodes directly (getSemantics can
// resolve to a wrapper node whose own label is empty; the merged button node is
// the one to inspect).
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
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: button,
            ),
          ),
        ),
      ),
    );
  }

  AonTactileButton tb({
    required VoidCallback onTap,
    required Widget child,
    bool hapticsEnabled = true,
  }) => AonTactileButton(
    onTap: onTap,
    borderRadius: 12,
    hapticsEnabled: hapticsEnabled,
    child: child,
  );

  Finder inButton(Type t) => find.descendant(
    of: find.byType(AonTactileButton),
    matching: find.byType(t),
  );

  Widget child() => const SizedBox(
    width: 120,
    height: 60,
    child: ColoredBox(color: Colors.blue),
  );

  Iterable<DecoratedBox> borders(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(inButton(DecoratedBox))
      .where((d) => (d.decoration as BoxDecoration).border != null);

  testWidgets('onTapUp fires onTap; onTapCancel does not', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    await tester.tap(find.byType(AonTactileButton));
    expect(taps, 1);

    final g = await tester.startGesture(
      tester.getCenter(find.byType(AonTactileButton)),
    );
    await tester.pump();
    await g.moveBy(const Offset(400, 400));
    await g.cancel();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('press squishes to 0.96 and returns to 1.0 (incl. cancel)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    AnimatedScale scale() =>
        tester.widget<AnimatedScale>(inButton(AnimatedScale));
    expect(scale().scale, 1.0);

    final g = await tester.startGesture(
      tester.getCenter(find.byType(AonTactileButton)),
    );
    await tester.pump();
    expect(scale().scale, 0.96);
    expect(scale().duration, AonAnimations.fast);
    expect(scale().curve, AonAnimations.easeInOut);

    await g.cancel();
    await tester.pump();
    expect(scale().scale, 1.0);
    expect(taps, 0);
  });

  testWidgets(
    'reduced motion: outline (not opacity/scale) on press; onTap fires',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(tb(onTap: () => taps++, child: child()), reduceMotion: true),
      );

      expect(inButton(AnimatedScale), findsNothing);
      expect(inButton(Opacity), findsNothing);
      expect(borders(tester), isEmpty);

      final g = await tester.startGesture(
        tester.getCenter(find.byType(AonTactileButton)),
      );
      await tester.pump();
      expect(borders(tester), isNotEmpty);
      await g.up();
      await tester.pump();
      expect(borders(tester), isEmpty);
      expect(taps, 1);
    },
  );

  testWidgets(
    'exactly one light haptic, on tap-down only; none when disabled',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      int lightImpacts() => calls
          .where(
            (c) =>
                c.method == 'HapticFeedback.vibrate' &&
                c.arguments == 'HapticFeedbackType.lightImpact',
          )
          .length;

      await tester.pumpWidget(harness(tb(onTap: () {}, child: child())));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(AonTactileButton)),
      );
      await tester.pump();
      expect(lightImpacts(), 1);
      await g.up();
      await tester.pump();
      expect(lightImpacts(), 1);

      calls.clear();
      await tester.pumpWidget(
        harness(tb(onTap: () {}, hapticsEnabled: false, child: child())),
      );
      final g2 = await tester.startGesture(
        tester.getCenter(find.byType(AonTactileButton)),
      );
      await tester.pump();
      expect(lightImpacts(), 0);
      await g2.up();
      await tester.pump();
    },
  );

  testWidgets(
    'one merged button node: label + tap action + performing it fires onTap',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        harness(tb(onTap: () => taps++, child: const Text('Go to program'))),
      );

      final root = tester.semantics
          .find(find.byType(AonTactileButton))
          .owner!
          .rootSemanticsNode!;
      expect(buttonCount(root), 1);
      final node = firstButton(root)!;
      final data = node.getSemanticsData();
      expect(data.label, contains('Go to program'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    },
  );

  testWidgets('keyboard: Tab focuses (visible ring) + Enter/Space activate', (
    tester,
  ) async {
    final prev = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = prev);

    var taps = 0;
    await tester.pumpWidget(harness(tb(onTap: () => taps++, child: child())));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(borders(tester), isNotEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });
}
