import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';

/// The app must not claim the event is tonight when it is weeks away.
///
/// ## The bug this file exists to prevent
///
/// Found on an iPhone 17 Pro on 17 August 2026 — a month before the event.
/// `EventTiming` is derived by comparing timestamps, so on any earlier date
/// *every* activity classifies as `EventTiming.upcoming`, whose label was the
/// unconditional string "Later tonight". The Program header therefore read
/// "Later tonight 36" and every card badge read "Later tonight · 4pm".
///
/// This is the state most people will see. An event app gets installed in the
/// weeks beforehand, so the pre-event screen is the *most viewed* screen the app
/// has, and it was telling everyone the programme was running that evening.
///
/// `EventPhase` already knew the truth — it returns `future`, which is why the
/// Home hero pill correctly stays hidden. The timing labels simply were not
/// consulting it.
void main() {
  Widget app(Widget home, {required DateTime now, Set<String> saved = const {}}) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): saved.toList(),
    });
    return ProviderScope(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(now))],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: home,
      ),
    );
  }

  /// A month before the event — the real date this was found on.
  final wellBefore = EventInfo.startsAt.subtract(const Duration(days: 33));

  /// The morning of the event: same calendar day, doors not yet open.
  final eventMorning = EventInfo.at(9, 0);

  group('before the event day, nothing says "tonight"', () {
    testWidgets('the Program bucket header does not claim tonight', (
      tester,
    ) async {
      await tester.pumpWidget(app(const ProgramScreen(), now: wellBefore));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Later tonight'),
        findsNothing,
        reason: 'a month out, the programme is not "later tonight"',
      );
      expect(find.textContaining('On the night'), findsWidgets);
    });

    testWidgets('no card badge claims tonight either', (tester) async {
      // The badges are the numerous case — 36 of them, each one a false claim.
      await tester.pumpWidget(app(const ProgramScreen(), now: wellBefore));
      await tester.pumpAndSettle();
      expect(find.textContaining('Later tonight ·'), findsNothing);
    });

    testWidgets('Home says nothing about tonight before the day', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const HomeScreen(),
          now: wellBefore,
          saved: {'keynote-artemis'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Later tonight'), findsNothing);
    });

    testWidgets('and never claims something is happening now', (tester) async {
      await tester.pumpWidget(app(const ProgramScreen(), now: wellBefore));
      await tester.pumpAndSettle();
      expect(find.textContaining('Happening now'), findsNothing);
    });
  });

  group('on the event day, tonight-relative wording returns', () {
    testWidgets('the morning of the event does say "Later tonight"', (
      tester,
    ) async {
      // The boundary that matters: same calendar day but before doors. Here
      // "Later tonight" is correct and must not be replaced.
      await tester.pumpWidget(app(const ProgramScreen(), now: eventMorning));
      await tester.pumpAndSettle();

      expect(find.textContaining('Later tonight'), findsWidgets);
      expect(
        find.textContaining('On the night'),
        findsNothing,
        reason: 'on the day itself, "On the night" is needlessly vague',
      );
    });

    testWidgets('mid-event still shows live statuses', (tester) async {
      await tester.pumpWidget(
        app(const ProgramScreen(), now: EventInfo.at(19, 0)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Happening now'), findsWidgets);
      expect(find.textContaining('On the night'), findsNothing);
    });
  });
}
