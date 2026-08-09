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
    // Landed on What's On. (textContaining dodges the title's curly apostrophe.)
    expect(find.textContaining('On Now'), findsWidgets);
  });
}
