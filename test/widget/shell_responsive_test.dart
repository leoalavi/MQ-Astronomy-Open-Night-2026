import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/nav_metrics.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(414, 896)]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('shell no-overflow @ ${size.width.toInt()} x scale$scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp.router(
            theme: AonTheme.build(),
            routerConfig: buildRouter(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidTabBar), findsOneWidget);
      });
    }
  }

  // The existing loop above only exercises the INITIAL (Home) route at 2.0.
  // StatefulShellRoute.indexedStack builds branches lazily, so Map/Program/Now/
  // Info are never built there. Navigate each tab at 2.0 on a tall AND a short
  // viewport, proving each destination actually opens — this is the only
  // coverage MapScreen has.
  //
  // (inactive icon to TAP, tab label proving the destination became selected)
  const destinations = <(IconData, String)>[
    (Icons.list_alt_outlined, 'Program'),
    (Icons.schedule_outlined, 'Now'),
    (Icons.map_outlined, 'Map'),
    (Icons.info_outline_rounded, 'Info'),
    (Icons.home_outlined, 'Home'), // Home deselects to the OUTLINED icon
  ];

  for (final size in [const Size(320, 640), const Size(320, 568)]) {
    testWidgets(
        'shell navigates EVERY tab, each opens, no overflow @ ${size.height.toInt()}h scale2.0',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
        ],
        child: MaterialApp.router(
          theme: AonTheme.build(),
          routerConfig: buildRouter(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      for (final (tapIcon, label) in destinations) {
        // The tab is present and not yet selected.
        expect(find.byIcon(tapIcon), findsOneWidget);
        // warnIfMissed:false is safe ONLY because the label assertion below
        // makes a real miss (no navigation) a hard failure.
        await tester.tap(find.byIcon(tapIcon), warnIfMissed: false);
        await tester.pumpAndSettle();
        // Destination actually became active: its tab label now renders (labels
        // show only for the selected tab; unselected tabs render no label).
        expect(find.text(label), findsWidgets,
            reason: 'tapping $tapIcon did not navigate to $label');
        // ...and it did so without overflow.
        expect(tester.takeException(), isNull);
      }
    });
  }

  // Nav-clearance invariant at 2.0: Phase 1 reserves body clearance assuming the
  // floating island is AonNavMetrics.barHeight tall. Prove the bar does NOT grow
  // at 2.0 (its labels are height-clamped), so that reservation stays correct
  // and content is never occluded by the island. (Verified: 66.0 at 1.0 AND 2.0.)
  testWidgets('LiquidTabBar height == reserved clearance at 320x568 / 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: AonTheme.build(),
        routerConfig: buildRouter(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(LiquidTabBar)).height,
      AonNavMetrics.barHeight,
    );
  });
}
