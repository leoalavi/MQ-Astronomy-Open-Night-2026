import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/services/clock.dart';

void main() {
  testWidgets(
      "What's On time-simulator sheet: opens, no overflow, scrollable @ 320x640 / 2.0",
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        theme: AonTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const WhatsOnScreen(),
      ),
    ));

    // Open the sheet via the AppBar science icon (deterministic trigger).
    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pump(const Duration(milliseconds: 400));

    // Mandatory: prove the sheet opened BEFORE judging layout.
    expect(find.text('Back to real time'), findsOneWidget);
    // No overflow, and THIS sheet's body is genuinely scrollable (scoped to the
    // sheet — not "exactly one SingleChildScrollView in the whole tree", which
    // would be brittle if a screen later gains its own).
    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(
        of: find.text('Back to real time'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });
}
