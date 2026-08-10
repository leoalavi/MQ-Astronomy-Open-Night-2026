import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/activity_rail_card.dart';

/// The Astronomy Home screen.
///
/// Home has to answer, in order: what is this event, what is on now, what is
/// next, where do I go, and what have I saved. Each test pins one of those.
void main() {
  void seedSaved(List<String> ids) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): ids,
    });
  }

  Widget harness(DateTime now) {
    return ProviderScope(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(now))],
      child: MaterialApp(theme: AonTheme.build(), home: const HomeScreen()),
    );
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );

  group('hero', () {
    testWidgets('names the event, the date and the time', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.text('Astronomy Open Night'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      // The hero's date pill carries both, in one string. Several all-evening
      // activities also read "4pm – 10pm", so match the combined label.
      expect(
        find.textContaining('Saturday 19 September 2026  ·  4pm – 10pm'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Happening now" during the event', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.text('Happening now'), findsWidgets);
    });

    testWidgets('shows "Starts soon" in the two hours before doors',
        (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(15, 0)));
      await tester.pumpAndSettle();

      expect(find.text('Starts soon'), findsOneWidget);
    });

    testWidgets('shows "Ending soon" in the last 45 minutes', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(21, 30)));
      await tester.pumpAndSettle();

      expect(find.text('Ending soon'), findsOneWidget);
    });

    testWidgets('stays quiet weeks before the event', (tester) async {
      // A badge reading "the event is in 6 weeks" on every launch is noise.
      seedSaved([]);
      await tester.pumpWidget(harness(DateTime(2026, 8, 1, 12)));
      await tester.pumpAndSettle();

      expect(find.text('Starts soon'), findsNothing);
      expect(find.text('Happening now'), findsNothing);
    });
  });

  group('activity rails', () {
    testWidgets('lists what is running right now', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.byType(ActivityRailCard), findsWidgets);
      // The keynote runs 7.30–8.15pm, so at 7pm it is upcoming, not running.
      expect(find.text('Up next'), findsWidgets);
    });

    testWidgets('an activity can be saved straight from the rail',
        (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      final firstStar = find
          .descendant(
            of: find.byType(ActivityRailCard).first,
            matching: find.byIcon(Icons.star_outline_rounded),
          )
          .first;
      await tester.tap(firstStar);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(
          SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id),
        ),
        hasLength(1),
      );
    });
  });

  group('My Night preview', () {
    testWidgets('is absent when nothing is saved', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next in My Night'), findsNothing);
    });

    testWidgets('surfaces the next saved activity', (tester) async {
      seedSaved(['keynote-artemis']);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.text('Next in My Night'), findsOneWidget);
      expect(
        find.text('Artemis and beyond: Humankind’s future on the moon'),
        findsOneWidget,
      );
    });

    testWidgets('counts the rest of the plan', (tester) async {
      seedSaved(['keynote-artemis', 't3-pope', 't4-fava']);
      await tester.pumpWidget(harness(EventInfo.at(16, 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 activities saved'), findsOneWidget);
    });
  });

  group('map and quick access', () {
    testWidgets('the map CTA is present and explicit', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Open the campus map'));
      expect(find.text('Open the campus map'), findsOneWidget);
      expect(
        find.textContaining('walking directions from the car parks'),
        findsOneWidget,
      );
    });

    testWidgets('quick access uses the official venue vocabulary',
        (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Telescopes'));
      // Every one of these is backed by the printed programme or map legend.
      expect(find.text('Telescopes'), findsOneWidget);
      expect(find.text('Planetariums'), findsOneWidget);
      // "First aid" is both the shortcut label and the venue's own name, so
      // it legitimately appears twice on the tile.
      expect(find.text('First aid'), findsWidgets);
      expect(find.text('Parking'), findsOneWidget);
    });

    testWidgets('quick access grounds each shortcut in its real venue name',
        (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Telescopes'));
      // "Telescopes" is our label; "Observatory" is what the map calls it.
      expect(find.text('Observatory'), findsWidgets);
    });
  });

  group('attribution', () {
    testWidgets('credits the hero image on the Home screen', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(
        tester,
        find.text('A Deep Triangulum Galaxy — Aleix Roig, 2026'),
      );
      expect(
        find.text('A Deep Triangulum Galaxy — Aleix Roig, 2026'),
        findsOneWidget,
      );
    });
  });

  group('excluded content', () {
    testWidgets('never surfaces the cancelled Huntsman session',
        (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(18, 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Huntsman'), findsNothing);
    });
  });
}
