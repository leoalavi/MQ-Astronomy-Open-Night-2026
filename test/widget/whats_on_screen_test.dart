import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/services/clock.dart';

/// Widget tests for the time-dependent screen.
///
/// Every test overrides [baseClockProvider] with a [FixedClock]. That is the
/// whole reason the clock is injected rather than read from `DateTime.now()` —
/// without it these assertions would only hold during a six-hour window on one
/// evening in September 2026.
///
/// Note it overrides the *base* clock, not `clockProvider`, so the in-app time
/// simulator still layers on top and can itself be tested.
void main() {
  Widget harness(DateTime now) {
    return ProviderScope(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(now))],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: const WhatsOnScreen(),
      ),
    );
  }

  testWidgets('shows a pre-event notice before the event starts', (
    tester,
  ) async {
    await tester.pumpWidget(harness(DateTime(2026, 9, 19, 12)));
    await tester.pump();

    expect(find.text('The event hasn’t started yet'), findsOneWidget);
  });

  testWidgets('shows a post-event notice after the event closes', (
    tester,
  ) async {
    await tester.pumpWidget(harness(DateTime(2026, 9, 19, 23)));
    await tester.pump();

    expect(find.text('That’s a wrap'), findsOneWidget);
  });

  testWidgets('shows live sections during the event', (tester) async {
    await tester.pumpWidget(harness(EventInfo.at(19, 0)));
    await tester.pump();

    expect(find.text('Happening now'), findsWidgets);
    expect(find.text('The event hasn’t started yet'), findsNothing);
  });

  testWidgets('surfaces the keynote as happening at 7.45pm', (tester) async {
    await tester.pumpWidget(harness(EventInfo.at(19, 45)));
    await tester.pump();

    expect(
      find.text('Artemis and beyond: Humankind’s future on the moon'),
      findsOneWidget,
    );
  });

  testWidgets('shows a starting-soon section shortly before a talk', (
    tester,
  ) async {
    // Short talks start at 8.15pm; at 8.05pm they are "starting soon".
    await tester.pumpWidget(harness(EventInfo.at(20, 5)));
    await tester.pump();

    // The "Starting soon" section sits below "Happening now", which at this
    // hour is several cards tall, so it is not built until scrolled to.
    await tester.scrollUntilVisible(
      find.text('Starting soon'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Starting soon'), findsWidgets);
  });

  testWidgets('never renders the cancelled Huntsman session', (tester) async {
    // 6pm is inside the cancelled activity's printed 4.15–9.30pm window, so
    // this would find it if it were ever re-added to the data.
    await tester.pumpWidget(harness(EventInfo.at(18, 0)));
    await tester.pump();

    expect(find.textContaining('Huntsman'), findsNothing);
  });

  testWidgets('the time simulator overrides real time', (tester) async {
    // Real "now" is a year before the event.
    await tester.pumpWidget(harness(DateTime(2025, 8, 7, 10)));
    await tester.pump();

    expect(find.text('The event hasn’t started yet'), findsOneWidget);

    // The reviewer previews event night.
    await tester.tap(find.text('Preview event night'));
    await tester.pumpAndSettle();

    expect(find.text('The event hasn’t started yet'), findsNothing);
    expect(find.textContaining('Previewing'), findsOneWidget);
    expect(find.text('Happening now'), findsWidgets);
  });
}
