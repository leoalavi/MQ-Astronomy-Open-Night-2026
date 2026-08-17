import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/services/clock.dart';

/// Renders every primary screen across phone widths (320/360/414) at the
/// default text size and at the app's maximum clamped text scale (2.0x), plus a
/// dedicated short-viewport (320×568) case at 2.0. A [RenderFlex] overflow
/// throws during layout in a test, so `takeException()` returning non-null fails
/// the case — this is the guard that the layouts stay unbroken for large-text
/// and small-screen users. Height is load-bearing: fixed-height content overflows
/// on a short phone, which tall viewports hide.
void main() {
  Widget harness(Widget screen, double scale) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
  }

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Program': const ProgramScreen(),
    'Info': const InfoScreen(),
    'Wayfinding': const WayfindingScreen(),
    'EventDetail': EventDetailScreen(eventId: EventsData.all.first.id),
  };

  for (final size in [
    const Size(320, 640),
    const Size(360, 780),
    const Size(414, 896),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      screens.forEach((name, screen) {
        testWidgets('$name @ ${size.width.toInt()}x scale$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(harness(screen, scale));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  // Height is load-bearing: a realistic short phone (~iPhone SE) at 2.0 is where
  // fixed-height content overflows. Screens are ListView-scrollable and stay
  // clean here — this locks that in so a future fixed-height regression is caught.
  screens.forEach((name, screen) {
    testWidgets('$name @ 320x568 (short) scale2.0', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness(screen, 2.0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
