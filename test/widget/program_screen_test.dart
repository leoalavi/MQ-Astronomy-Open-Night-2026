import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/clock.dart';

void main() {
  Widget harness() {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: const ProgramScreen(),
      ),
    );
  }

  testWidgets('renders the programme sections', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Program'), findsOneWidget);
    expect(find.text('Activities'), findsWidgets);
  });

  testWidgets('shows a count of programme items', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.textContaining('items in the program'), findsOneWidget);
  });

  testWidgets('both filter labels show in full, no overflow (narrow + 1.6x)', (
    tester,
  ) async {
    // The real-device tight case from the bug report: a ~320pt phone, two
    // half-width controls, and large text. Labels must not truncate or overflow.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Filter by time'), findsOneWidget);
    expect(find.text('Filter by activity'), findsOneWidget);
    // A truncating Row would raise a RenderFlex overflow here.
    expect(tester.takeException(), isNull);
  });

  // Opens a filter dropdown (by button key) and picks the option ListTile whose
  // title is [label], scrolling it into view first (the sheet can overflow the
  // small test viewport, e.g. the last "On the night" row).
  Future<void> pick(WidgetTester tester, Key button, String label) async {
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    final opt = find.widgetWithText(ListTile, label);
    await tester.ensureVisible(opt);
    await tester.pumpAndSettle();
    await tester.tap(opt);
    await tester.pumpAndSettle();
  }

  Future<void> pickTime(WidgetTester tester, String label) =>
      pick(tester, const Key('program-time-filter'), label);

  Future<void> pickActivity(WidgetTester tester, String label) =>
      pick(tester, const Key('program-activity-filter'), label);

  // The time filter is START-HOUR only: a 6pm pick excludes Open-all-night
  // items (no honest start hour); "On the night" isolates exactly those. The
  // "X of 36" count tracks the rendered list.
  testWidgets('time filter = start hour; On the night isolates open-all-night', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Capture the cosmos'), findsOneWidget); // full list

    // 6pm hour: 9 events start in the 6pm hour; the Open-all-night items are not
    // among them.
    await pickTime(tester, '6pm');
    expect(find.text('Capture the cosmos'), findsNothing);
    expect(find.text('Solar system walk'), findsNothing);
    expect(find.text('9 of 36 shown'), findsOneWidget);

    // Immediate refresh → On the night: only the two open-all-night items.
    await pickTime(tester, 'On the night');
    expect(find.text('Capture the cosmos'), findsOneWidget);
    expect(find.text('Solar system walk'), findsOneWidget);
    expect(find.text('2 of 36 shown'), findsOneWidget);
  });

  testWidgets('time + activity combine (AND), and clear independently', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Activity = Short talks (12), then Time = 6pm → 4 short talks start at 6pm.
    await pickActivity(tester, 'Short talks');
    expect(find.text('12 of 36 shown'), findsOneWidget);
    await pickTime(tester, '6pm');
    expect(find.text('4 of 36 shown'), findsOneWidget); // AND

    // Clear TIME only → activity (Short talks) preserved → back to 12.
    await pickTime(tester, 'All times');
    expect(find.text('12 of 36 shown'), findsOneWidget);

    // Re-apply 6pm, then clear ACTIVITY only → time preserved → all 9 at 6pm.
    await pickTime(tester, '6pm');
    await pickActivity(tester, 'All activities');
    expect(find.text('9 of 36 shown'), findsOneWidget);

    // Clear All (app bar) resets everything.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('items in the program'), findsOneWidget);
    expect(find.text('Filter by time'), findsOneWidget);
    expect(find.text('Filter by activity'), findsOneWidget);
  });

  testWidgets('search narrows the list and offers a way back', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zzzz-nothing-matches');
    await tester.pump();

    expect(find.text('Nothing matches'), findsOneWidget);
    // An empty state with no escape hatch is a dead end — assert the way out.
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    expect(find.text('Nothing matches'), findsNothing);
  });

  testWidgets('the activity filter narrows the programme to one category', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await pickActivity(tester, 'Keynote lecture');

    expect(
      find.text('Artemis and beyond: Humankind’s future on the moon'),
      findsOneWidget,
    );
    // Only the keynote survives the filter.
    expect(find.text('1 of 36 shown'), findsOneWidget);
  });

  testWidgets('the programme never lists the cancelled Huntsman session', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Huntsman');
    await tester.pump();

    expect(find.text('Nothing matches'), findsOneWidget);
  });
}
