import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/glass_surface.dart';

void main() {
  Widget harness({
    bool highContrast = false,
    bool reduceMotion = false,
    double scale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        theme: AonTheme.build(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(scale),
            ),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  // The hero date row renders "<long date>  ·  <range>"; anchor on the separator.
  Finder dateText() => find.textContaining('·').first;

  testWidgets('hero date is wrapped in a GlassSurface', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(
      find.ancestor(of: dateText(), matching: find.byType(GlassSurface)),
      findsOneWidget,
    );
  });

  testWidgets('high-contrast renders the solid rung (no BackdropFilter in the pill)',
      (tester) async {
    await tester.pumpWidget(harness(highContrast: true));
    await tester.pump();
    final pill = find.ancestor(of: dateText(), matching: find.byType(GlassSurface));
    expect(
      find.descendant(of: pill, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

  testWidgets('reduced-motion renders the frost rung (BackdropFilter present)',
      (tester) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pump();
    final pill = find.ancestor(of: dateText(), matching: find.byType(GlassSurface));
    expect(
      find.descendant(of: pill, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
  });

  testWidgets('no overflow at 320px across text scales', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      await tester.pumpWidget(harness(scale: scale));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });
}
