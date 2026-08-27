import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/save_button.dart';

/// "My Night" screen behaviour.
///
/// Saved state is device-local (`shared_preferences`), so each test seeds the
/// in-memory mock store rather than stubbing the notifier — that exercises the
/// real persistence path.
void main() {
  /// Seeds saved ids for the Astronomy event before the app reads them.
  void seedSaved(List<String> ids) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): ids,
    });
  }

  Widget harness({DateTime? now, Widget? home}) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(
          FixedClock(now ?? EventInfo.at(19, 0)),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: home ?? const MyNightScreen(),
      ),
    );
  }

  testWidgets('empty state invites the visitor to the programme', (
    tester,
  ) async {
    seedSaved([]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Your night is empty'), findsOneWidget);
    // A dead end is the failure mode; assert the way out.
    expect(find.text('Browse the program'), findsOneWidget);
  });

  testWidgets('uses night vocabulary from the event config', (tester) async {
    seedSaved([]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('My Night'), findsWidgets);
    expect(find.textContaining('Your Day'), findsNothing);
  });

  testWidgets('shows a saved activity with its venue and time', (tester) async {
    seedSaved(['keynote-artemis']);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.text('Artemis and beyond: Humankind’s future on the moon'),
      findsOneWidget,
    );
    expect(find.textContaining('Macquarie Theatre'), findsOneWidget);
    expect(find.text('7.30pm – 8.15pm'), findsOneWidget);
  });

  testWidgets('orders the timeline chronologically', (tester) async {
    // Saved out of order on purpose.
    seedSaved(['keynote-artemis', 't3-pope']);
    await tester.pumpWidget(harness(now: EventInfo.at(16, 0)));
    await tester.pumpAndSettle();

    final pope = tester.getTopLeft(find.textContaining('Galactic guesswork'));
    final keynote = tester.getTopLeft(
      find.textContaining('Artemis and beyond'),
    );
    // The 4.30pm talk must sit above the 7.30pm keynote.
    expect(pope.dy, lessThan(keynote.dy));
  });

  testWidgets('offers a walking-directions action per entry', (tester) async {
    seedSaved(['keynote-artemis']);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Walk there'), findsOneWidget);
  });

  testWidgets('removing an entry empties the timeline and offers undo', (
    tester,
  ) async {
    seedSaved(['keynote-artemis']);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove from plan'));
    await tester.pumpAndSettle();

    expect(find.text('Your night is empty'), findsOneWidget);
    // Remove sits next to "Walk there" on a card tapped in the dark — undo
    // is not optional.
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('tapping Undo puts the entry back', (tester) async {
    // Offering an Undo that does nothing is worse than offering none. The
    // suite asserted the action was *present* but never pressed it, so the
    // restore path itself was unverified.
    seedSaved(['keynote-artemis']);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    final title = find.textContaining('Artemis and beyond');
    expect(title, findsOneWidget);

    await tester.tap(find.byTooltip('Remove from plan'));
    await tester.pumpAndSettle();
    expect(title, findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(title, findsOneWidget,
        reason: 'Undo must restore the removed activity');
    expect(find.text('Your night is empty'), findsNothing);
  });

  testWidgets('a multi-session activity is labelled N of M', (tester) async {
    seedSaved(['physics-magic-show']);
    await tester.pumpWidget(harness(now: EventInfo.at(16, 0)));
    await tester.pumpAndSettle();

    expect(find.text('Session 1 of 3'), findsOneWidget);
    expect(find.text('Session 3 of 3'), findsOneWidget);
  });

  testWidgets('surfaces a clash between two saved activities', (tester) async {
    // The keynote and the engineering talk both run 7.30–8.15pm.
    seedSaved(['keynote-artemis', 'featured-engineering-astronomy']);
    await tester.pumpWidget(harness(now: EventInfo.at(17, 0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('run at the same time'), findsOneWidget);
    expect(find.textContaining('Overlaps'), findsWidgets);
  });

  testWidgets('does not warn about two sessions of the same activity', (
    tester,
  ) async {
    seedSaved(['physics-magic-show']);
    await tester.pumpWidget(harness(now: EventInfo.at(16, 0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('run at the same time'), findsNothing);
  });

  testWidgets('finished entries collapse into their own section', (
    tester,
  ) async {
    seedSaved(['physics-magic-show']);
    await tester.pumpWidget(harness(now: EventInfo.at(19, 0)));
    await tester.pumpAndSettle();

    // "Finished" appears twice by design — the section header and the badge
    // on the entry inside it.
    expect(find.text('Finished'), findsWidgets);
    // The two later sessions are still listed above it.
    expect(find.text('Session 3 of 3'), findsOneWidget);
  });

  group('SaveButton', () {
    testWidgets('toggles saved state and persists it', (tester) async {
      seedSaved([]);
      await tester.pumpWidget(
        harness(
          home: const Scaffold(
            body: SaveButton(eventId: 'keynote-artemis', eventTitle: 'Keynote'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

      await tester.tap(find.byType(SaveButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(
          SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id),
        ),
        ['keynote-artemis'],
      );
    });

    testWidgets('carries an accessible name, not just a star glyph', (
      tester,
    ) async {
      seedSaved([]);
      await tester.pumpWidget(
        harness(
          home: const Scaffold(
            body: SaveButton(eventId: 'keynote-artemis', eventTitle: 'Keynote'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Save Keynote to My Night'), findsOneWidget);
    });
  });

  group('saved storage', () {
    testWidgets('is scoped per event so a future event starts empty', (
      tester,
    ) async {
      // Last year's saved ids must not leak into this event's plan.
      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor('open-day-2026'): ['something-else'],
      });

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Your night is empty'), findsOneWidget);
    });
  });

  group('routing', () {
    testWidgets('the My Night tab opens the timeline', (tester) async {
      seedSaved(['keynote-artemis']);
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

      // Starts on Home, not on the plan.
      expect(find.byType(MyNightScreen), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MyNightScreen), findsOneWidget);
      expect(
        find.text('Artemis and beyond: Humankind’s future on the moon'),
        findsOneWidget,
      );
    });
  });
}
