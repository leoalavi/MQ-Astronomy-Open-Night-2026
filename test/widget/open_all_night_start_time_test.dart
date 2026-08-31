import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/widgets/activity_rail_card.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// Regression: an "open all night" activity with NO published start
/// (`TimingConfidence.openAllNight` — Liz gave "no set opening times") must
/// never have a fabricated clock start time surfaced in its "up next" badge.
///
/// Before the event every activity classifies as `upcoming`. The badge for an
/// upcoming activity appends `TimeFormat.time(session.start)`. For a normal
/// activity that start is real and published. For `openAllNight` the `start`
/// is a 4pm STAND-IN (the event-window bound) that the organisers explicitly
/// declined to publish — so surfacing "· 4pm" is exactly the invented-time the
/// TimingConfidence system exists to prevent, and it contradicts the card's own
/// "Open all night" line (one clear truth per card).
///
/// The symmetric guard already exists on the finish side (`hasPublishedEnd`
/// gates the "ends in N" countdown, audit HP-A); this asserts the start side.
void main() {
  // The two Liz-confirmed full-event activities.
  final solar = EventsData.byId('solar-system-walk')!; // openAllNight
  // A normal published-start activity, used as the scope guard: the fix must
  // NOT suppress a legitimately published start.
  final kids = EventsData.byId('kids-space')!; // startOnly, real 4.15pm start

  // Weeks before the event: everything is `upcoming`, phase is future.
  final preEvent = DateTime(2026, 8, 1, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget cardHarness(Widget child) {
    return ProviderScope(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(preEvent))],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  TimingBadge badgeIn(WidgetTester tester, Finder card) => tester.widget<TimingBadge>(
        find.descendant(of: card, matching: find.byType(TimingBadge)),
      );

  group('ActivityRailCard (Home rail)', () {
    testWidgets('openAllNight shows no fabricated start time, only "Open all night"',
        (tester) async {
      final timed = TimedEvent(
        event: solar,
        timing: EventTiming.upcoming,
        session: solar.sessions.first,
      );
      await tester.pumpWidget(
        cardHarness(ActivityRailCard(timed: timed, now: preEvent)),
      );
      await tester.pumpAndSettle();

      final badge = badgeIn(tester, find.byType(ActivityRailCard));
      expect(badge.trailingText, isNull,
          reason: 'openAllNight has no published start to present');
      expect(find.text('Open all night'), findsOneWidget);
    });

    testWidgets('a startOnly activity keeps its real published start', (tester) async {
      final timed = TimedEvent(
        event: kids,
        timing: EventTiming.upcoming,
        session: kids.sessions.first,
      );
      await tester.pumpWidget(
        cardHarness(ActivityRailCard(timed: timed, now: preEvent)),
      );
      await tester.pumpAndSettle();

      final badge = badgeIn(tester, find.byType(ActivityRailCard));
      expect(badge.trailingText, '4.15pm',
          reason: 'a published 4.15pm start must still be shown');
    });
  });

  group('EventCard (Program list)', () {
    testWidgets('openAllNight shows no fabricated start time, only "Open all night"',
        (tester) async {
      await tester.pumpWidget(
        cardHarness(EventCard(
          event: solar,
          timing: EventTiming.upcoming,
          now: preEvent,
          onTap: () {},
        )),
      );
      await tester.pumpAndSettle();

      final badge = badgeIn(tester, find.byType(EventCard));
      expect(badge.trailingText, isNull,
          reason: 'openAllNight has no published start to present');
      expect(find.text('Open all night'), findsOneWidget);
    });

    testWidgets('a startOnly activity keeps its real published start', (tester) async {
      await tester.pumpWidget(
        cardHarness(EventCard(
          event: kids,
          timing: EventTiming.upcoming,
          now: preEvent,
          onTap: () {},
        )),
      );
      await tester.pumpAndSettle();

      final badge = badgeIn(tester, find.byType(EventCard));
      expect(badge.trailingText, '4.15pm');
    });
  });

  group('Home _NextUpCard (saved openAllNight)', () {
    testWidgets('a saved openAllNight activity never counts to a fabricated start',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): [
          'solar-system-walk',
        ],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [baseClockProvider.overrideWithValue(FixedClock(preEvent))],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.ancestor(
        of: find.text('Next in My Night'),
        matching: find.byType(AonTactileButton),
      );
      expect(card, findsOneWidget);
      final badge = tester.widget<TimingBadge>(
        find.descendant(of: card, matching: find.byType(TimingBadge)),
      );
      expect(badge.trailingText, isNull,
          reason: 'openAllNight (no set opening times) must not show a 4pm start');
    });
  });
}
