import 'package:flutter/material.dart';
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
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/services/clock.dart';

/// Renders every primary screen on the smallest supported phone (320pt) and a
/// standard phone (414pt), at the default text size and at the app's maximum
/// clamped text scale (1.6x). A [RenderFlex] overflow throws during layout in
/// a test, so `takeException()` returning non-null fails the case — this is the
/// guard that the layouts stay unbroken for large-text and small-screen users.
void main() {
  Widget harness(Widget screen, double scale) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        theme: AonTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: screen,
      ),
    );
  }

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Program': const ProgramScreen(),
    'WhatsOn': const WhatsOnScreen(),
    'Info': const InfoScreen(),
    'Wayfinding': const WayfindingScreen(),
    'EventDetail': EventDetailScreen(eventId: EventsData.all.first.id),
  };

  for (final size in [const Size(320, 640), const Size(414, 896)]) {
    for (final scale in [1.0, 1.6]) {
      screens.forEach((name, screen) {
        testWidgets('$name @ ${size.width.toInt()}x scale$scale',
            (tester) async {
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
}
