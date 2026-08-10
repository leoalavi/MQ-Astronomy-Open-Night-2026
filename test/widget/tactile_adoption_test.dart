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
    final root =
        tester.semantics.find(find.byType(AonTactileButton)).owner!.rootSemanticsNode!;
    expect(buttonCount(root), 1);
    final data = firstButton(root)!.getSemanticsData();
    expect(data.label, contains(needle));
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
        findsNothing);

    await tester.tap(find.byType(QuickLinkTile));
    expect(taps, 1);
    expectOneButtonLabelled(tester, 'Map');
    handle.dispose();
  });

  testWidgets(
      'EventCard: tactile buttons, no InkWell, TWO distinct button nodes '
      '(open + save)', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    final event = EventsData.all.first;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AonTheme.build(),
        home: Scaffold(body: EventCard(event: event, onTap: () => taps++)),
      ),
    ));

    // The card body AND the save button are both tactile buttons.
    expect(find.descendant(of: find.byType(EventCard), matching: find.byType(AonTactileButton)),
        findsNWidgets(2));
    expect(find.descendant(of: find.byType(EventCard), matching: find.byType(InkWell)), findsNothing);

    // Tapping the card body still opens it. Tap the title rather than the
    // card bounds, so the hit never lands on the save button's corner.
    await tester.tap(find.text(event.title));
    expect(taps, 1);

    // GOVERNANCE CHANGE (Astronomy): a card now exposes exactly TWO button
    // nodes, not one. The brief requires a save action on programme cards, and
    // AonTactileButton's MergeSemantics would swallow a *nested* control — so
    // the save button is mounted as a sibling and is separately reachable.
    // Both nodes must be individually labelled.
    final root = tester.semantics
        .find(find.byType(EventCard))
        .owner!
        .rootSemanticsNode!;
    expect(buttonCount(root), 2);

    // The save action carries its own accessible name (not just a star glyph).
    expect(
      find.bySemanticsLabel(RegExp('Save ${RegExp.escape(event.title)}')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Home map CTA: tactile button, no InkWell, navigates to the map',
      (tester) async {
    // Replaces the old _LiveStrip check. The live strip was superseded by the
    // "Happening now" rail; the map CTA is now Home's primary tactile surface
    // and the organisers' most-requested affordance.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(theme: AonTheme.build(), routerConfig: buildRouter()),
    ));
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
    final ctaButton = find.ancestor(of: cta, matching: find.byType(AonTactileButton));
    expect(ctaButton, findsOneWidget);
    expect(find.descendant(of: ctaButton, matching: find.byType(InkWell)), findsNothing);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
