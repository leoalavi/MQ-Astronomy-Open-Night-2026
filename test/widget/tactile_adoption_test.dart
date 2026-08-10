import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/save_button.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/widgets/quick_link_tile.dart';

int buttonCount(SemanticsNode n) {
  var c = n.getSemanticsData().flagsCollection.isButton ? 1 : 0;
  n.visitChildren((ch) {
    c += buttonCount(ch);
    return true;
  });
  return c;
}

/// Every button node's accessible label, in tree order.
List<String> buttonLabels(SemanticsNode n) {
  final out = <String>[];
  void walk(SemanticsNode node) {
    final d = node.getSemanticsData();
    if (d.flagsCollection.isButton) out.add(d.label);
    node.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(n);
  return out;
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
  void expectOneButtonLabelled(WidgetTester tester, String needle) {
    final root = tester.semantics
        .find(find.byType(AonTactileButton))
        .owner!
        .rootSemanticsNode!;
    expect(buttonCount(root), 1);
    final data = firstButton(root)!.getSemanticsData();
    expect(data.label, contains(needle));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  }

  testWidgets(
    'QuickLinkTile: tactile button, no InkWell, one labelled button node',
    (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
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
        ),
      );

      expect(
        find.descendant(
          of: find.byType(QuickLinkTile),
          matching: find.byType(AonTactileButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(QuickLinkTile),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      await tester.tap(find.byType(QuickLinkTile));
      expect(taps, 1);
      expectOneButtonLabelled(tester, 'Map');
      handle.dispose();
    },
  );

  // ══════════════════════════════════════════════════════
  // GOVERNANCE: EventCard's two-action contract
  //
  // The original rule was "an EventCard exposes exactly ONE button node".
  // That was correct when the card had one action. TASK 5 of the Astronomy
  // brief requires a save action on programme cards, so the card now has two
  // genuinely distinct actions — open, and save.
  //
  // The rule is NOT weakened to "one or more buttons". Nesting the save
  // control inside AonTactileButton would have satisfied a loose rule while
  // silently breaking accessibility: AonTactileButton wraps its subtree in
  // MergeSemantics, which would swallow the save button into the card's node
  // and leave screen-reader users unable to reach it at all.
  //
  // The replacement rule is stricter, and encodes what makes two actions safe:
  //   1. exactly two button nodes — no accidental third target
  //   2. each independently labelled, and the labels differ
  //   3. the save action names the activity, not just "star"
  //   4. neither is swallowed by the other's MergeSemantics
  //   5. both clear the 56pt touch-target floor
  //   6. no InkWell anywhere (the design system's tactile rule still holds)
  // ══════════════════════════════════════════════════════
  testWidgets('EventCard governance: exactly two distinct, labelled actions',
      (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    final event = EventsData.all.first;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: Scaffold(body: EventCard(event: event, onTap: () => taps++)),
      ),
    ));
    await tester.pumpAndSettle();

    // (6) design-system rule: tactile, never InkWell.
    expect(
        find.descendant(
            of: find.byType(EventCard),
            matching: find.byType(AonTactileButton)),
        findsNWidgets(2));
    expect(
        find.descendant(
            of: find.byType(EventCard), matching: find.byType(InkWell)),
        findsNothing);

    // (1) exactly two button nodes.
    final root =
        tester.semantics.find(find.byType(EventCard)).owner!.rootSemanticsNode!;
    expect(buttonCount(root), 2,
        reason: 'a third tappable node means something nested by accident');

    // (2)+(3) both labelled, labels differ, save names the activity.
    final labels = buttonLabels(root);
    expect(labels, hasLength(2));
    expect(labels.toSet(), hasLength(2), reason: 'duplicate semantic labels');
    expect(labels.every((s) => s.trim().isNotEmpty), isTrue);
    expect(labels.any((s) => s.contains(event.title)), isTrue,
        reason: 'the card action must name the activity');
    expect(labels.any((s) => s.startsWith('Save ') && s.contains(event.title)),
        isTrue, reason: 'the save action must name what it saves');

    // (4) the save action survives independently of the card's MergeSemantics.
    expect(
        find.bySemanticsLabel(RegExp('^Save ${RegExp.escape(event.title)}')),
        findsOneWidget);

    // (5) both actions clear the touch-target floor.
    expect(tester.getSize(find.byType(EventCard)).height,
        greaterThanOrEqualTo(AonSpacing.minTapTarget));
    expect(tester.getSize(find.byType(SaveButton)).height,
        greaterThanOrEqualTo(AonSpacing.minTapTarget));

    // The card action still fires when the body is tapped.
    await tester.tap(find.text(event.title));
    await tester.pumpAndSettle();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('EventCard: tapping save does NOT also open the activity',
      (tester) async {
    // The classic nested-tappable bug: two overlapping targets where the
    // inner one bubbles to the outer.
    var opens = 0;
    final event = EventsData.all.first;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: Scaffold(body: EventCard(event: event, onTap: () => opens++)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SaveButton));
    await tester.pumpAndSettle();
    expect(opens, 0, reason: 'tapping save must not also open the activity');
  });

  testWidgets(
    'Home map CTA: tactile button, no InkWell, navigates to the map',
    (tester) async {
      // Replaces the old _LiveStrip check. The live strip was superseded by the
      // "Happening now" rail; the map CTA is now Home's primary tactile surface
      // and the organisers' most-requested affordance.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseClockProvider.overrideWithValue(
              FixedClock(EventInfo.at(19, 0)),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            routerConfig: buildRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The CTA sits below the hero and the activity rails, so it is not built
      // until scrolled into view.
      final cta = find.text('Open the campus map');
      await tester.scrollUntilVisible(
        cta,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cta, findsOneWidget);
      final ctaButton = find.ancestor(
        of: cta,
        matching: find.byType(AonTactileButton),
      );
      expect(ctaButton, findsOneWidget);
      expect(
        find.descendant(of: ctaButton, matching: find.byType(InkWell)),
        findsNothing,
      );

      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);
    },
  );
}
