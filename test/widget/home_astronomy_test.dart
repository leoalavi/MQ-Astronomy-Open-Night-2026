import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
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
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/timing_badge.dart';

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
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: const HomeScreen(),
      ),
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

    testWidgets('shows "Starts soon" in the two hours before doors', (
      tester,
    ) async {
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
      // "Up next" sits below the Happening-now rail and the passport card, so
      // it is not built until scrolled to.
      await scrollTo(tester, find.text('Up next'));
      expect(find.text('Up next'), findsWidgets);
    });

    testWidgets('an activity can be saved straight from the rail', (
      tester,
    ) async {
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

    testWidgets('never counts down to an UNPUBLISHED finish (audit HP-A)', (
      tester,
    ) async {
      // kids-space is startOnly: a published 4.15pm start and a 10pm STAND-IN
      // end. At 7pm it is "happening now". The card must show the timing label
      // but NOT a fabricated "ends in 3 hr" countdown to a finish the programme
      // never published — the honesty gate event_card / activity_rail_card /
      // my_night_screen already apply.
      seedSaved(['kids-space']);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      expect(find.text('Next in My Night'), findsOneWidget);
      final card = find.ancestor(
        of: find.text('Next in My Night'),
        matching: find.byType(AonTactileButton),
      );
      final badge = tester.widget<TimingBadge>(
        find.descendant(of: card, matching: find.byType(TimingBadge)),
      );
      expect(
        badge.trailingText,
        isNull,
        reason: 'a startOnly session has no published finish to count down to',
      );
    });
  });

  group('map and quick access', () {
    testWidgets('the map CTA is present and explicit', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Open the campus map'));
      expect(find.text('Open the campus map'), findsOneWidget);
      expect(find.textContaining('walking directions'), findsOneWidget);
      expect(find.textContaining('first aid'), findsNothing);
    });

    testWidgets('quick access uses the official venue vocabulary', (
      tester,
    ) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Telescopes'));
      // Every one of these is backed by the printed programme or map legend.
      expect(find.text('Telescopes'), findsOneWidget);
      expect(find.text('Planetariums'), findsOneWidget);
      // The official map gives no named/routable First Aid destination, so it
      // must not be presented as a confirmed interactive shortcut.
      expect(find.text('First aid'), findsNothing);
      expect(find.textContaining('first aid'), findsNothing);
      expect(find.text('Parking'), findsOneWidget);
    });

    testWidgets('quick access grounds each shortcut in its real venue name', (
      tester,
    ) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Telescopes'));
      // "Telescopes" is our label; "Observatory" is what the map calls it.
      expect(find.text('Observatory'), findsWidgets);
    });
  });

  group('attribution', () {
    testWidgets('credits the hero image exactly once, under the hero', (
      tester,
    ) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      // The credit is a caption directly under the hero image now, so it is
      // prefixed ("Image credit: …") rather than a bare string — and it must
      // appear exactly once on Home (no bottom-of-page duplicate).
      final credit = find.textContaining('Aleix Roig, 2026');
      await scrollTo(tester, credit);
      expect(credit, findsOneWidget);
    });

    testWidgets('the Home footer credits the two developers', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(19, 0)));
      await tester.pumpAndSettle();

      // Names are proper nouns and must appear verbatim, spelling intact.
      final footer = find.textContaining('Leo Alavi');
      await scrollTo(tester, footer);
      expect(footer, findsOneWidget);
      expect(find.textContaining('Mohammad Raouf Abedini'), findsOneWidget);
    });
  });

  group('excluded content', () {
    testWidgets('never surfaces the cancelled Huntsman session', (
      tester,
    ) async {
      seedSaved([]);
      await tester.pumpWidget(harness(EventInfo.at(18, 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Huntsman'), findsNothing);
    });
  });
}
