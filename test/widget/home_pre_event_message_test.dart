import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/utils/time_format.dart';

/// Task 10 was RETRACTED, and this is what replaced it.
///
/// The release plan claimed the "Happening now" section "renders empty with no
/// explanation" before the event, and that App Review would read that as a bug.
/// Both halves were wrong. The section is *hidden* pre-event, not empty — a
/// deliberate decision encoded in `timing_labels.dart:37`
/// (`EventPhase.future => null`) and asserted by two existing tests — and the
/// hero already names the date and hours unconditionally.
///
/// Wiring an empty-state message in broke both of those tests. These tests pin
/// the real behaviour so the "fix" is not attempted a third time.
void main() {
  testWidgets('weeks before the event, Home names the date without claiming '
      'anything is running', (t) async {
    final c = ProviderContainer(overrides: [
      currentTimeProvider.overrideWithValue(DateTime(2026, 9, 1, 12)),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: HomeScreen(),
      ),
    ));
    await t.pumpAndSettle();

    // App Review opens the app before 19 September. It must learn WHEN the
    // night is — the hero carries that, so no empty-state message is needed.
    expect(
      find.textContaining(TimeFormat.longDate(EventInfo.startsAt)),
      findsOneWidget,
      reason: 'the hero names the event date unconditionally, which is why the '
          'programme section can stay quiet',
    );

    // And it must not claim a programme is running when none is.
    expect(find.textContaining('Happening now'), findsNothing,
        reason: 'the section is deliberately hidden before the event — see '
            'timing_labels.dart:37, EventPhase.future => null');
  });
}
