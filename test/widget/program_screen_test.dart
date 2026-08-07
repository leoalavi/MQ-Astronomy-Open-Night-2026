import 'package:flutter/material.dart';
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
        baseClockProvider.overrideWithValue(
          FixedClock(EventInfo.at(19, 0)),
        ),
      ],
      child: MaterialApp(
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

  testWidgets('a category chip filters the programme', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // The filter bar scrolls horizontally; the category chips sit past the
    // time-band chips and are not built until scrolled into view.
    final filterBar = find.descendant(
      of: find.byKey(const Key('program-filter-bar')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, 'Keynote lecture'),
      300,
      scrollable: filterBar,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Keynote lecture'));
    await tester.pumpAndSettle();

    expect(
      find.text('Artemis and beyond: Humankind’s future on the moon'),
      findsOneWidget,
    );
    // Only the keynote survives the filter.
    expect(find.text('Activities'), findsNothing);
  });

  testWidgets('the programme never lists the cancelled Huntsman session',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Huntsman');
    await tester.pump();

    expect(find.text('Nothing matches'), findsOneWidget);
  });
}
