import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/services/clock.dart';

void main() {
  // An event that is genuinely running, so the status badge and the running
  // session's inline badge both render. These sit in tight rows, so this also
  // guards against a regression in the badge's bounded-width layout.
  final liveEvent = EventsData.all.firstWhere((e) => e.sessions.isNotEmpty);
  final liveSession = liveEvent.sessions.first;
  final duringSession = liveSession.start.add(const Duration(minutes: 5));

  Widget harness(String eventId) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(duringSession)),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: EventDetailScreen(eventId: eventId),
      ),
    );
  }

  testWidgets('shows a running event with its live status badge', (
    tester,
  ) async {
    await tester.pumpWidget(harness(liveEvent.id));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(liveEvent.title), findsOneWidget);
    // Both the header status badge and the running session badge say this.
    expect(find.textContaining('Happening now'), findsWidgets);
  });

  testWidgets('a removed event id lands on a recoverable not-found screen', (
    tester,
  ) async {
    await tester.pumpWidget(harness('this-id-does-not-exist'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('We can’t find that activity'), findsOneWidget);
    expect(find.text('Browse the program'), findsOneWidget);
  });
}
