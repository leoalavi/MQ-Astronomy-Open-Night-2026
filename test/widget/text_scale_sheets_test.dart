import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/screens/whats_on_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/confidence_note.dart';

void main() {
  testWidgets(
    "What's On time-simulator sheet: opens, no overflow, scrollable @ 320x640 / 2.0",
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseClockProvider.overrideWithValue(
              FixedClock(EventInfo.at(19, 0)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const WhatsOnScreen(),
          ),
        ),
      );

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
    },
  );

  // Opens `sheet` via a real modal bottom sheet at the given viewport / 2.0.
  // CRITICAL: the 2.0 override goes in MaterialApp.builder (ABOVE the Navigator),
  // so the pushed modal route inherits it. Verified: a descendant INSIDE the
  // sheet then reads scale(100)==200; if the MediaQuery is placed in `home:`
  // (below the Navigator) the modal renders at 1.0 and the test silently proves
  // nothing. Matches production's isScrollControlled flag so the real modal
  // height constraint (and thus the overflow) reproduces.
  Future<void> openModalSheet(
    WidgetTester tester,
    Widget sheet, {
    required bool scrollControlled,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: scrollControlled,
                    builder: (_) => sheet,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Effective text scale at a descendant — guards against the modal silently
  // rendering at 1.0 (see the harness note above).
  double scaleAt(WidgetTester tester, Finder descendant) =>
      MediaQuery.textScalerOf(tester.element(descendant)).scale(100);

  testWidgets('Parking sheet: opens at 2.0, no overflow, scrollable @ 320x568', (
    tester,
  ) async {
    // Production opens the parking sheet with isScrollControlled: false.
    await openModalSheet(
      tester,
      const ParkingSheet(parkingId: 'west-6'),
      scrollControlled: false,
      size: const Size(320, 568),
    );

    // Mandatory: ConfidenceNote is unique to the parking sheet — proves it opened.
    expect(find.byType(ConfidenceNote), findsOneWidget);
    // Prove the sheet is genuinely at 2.0 (not 1.0) BEFORE judging overflow.
    expect(scaleAt(tester, find.byType(ConfidenceNote)), 200);
    expect(tester.takeException(), isNull);
    // Scoped: THIS sheet scrolls (ancestor of its own content), not "exactly one
    // SingleChildScrollView in the whole app tree".
    expect(
      find.ancestor(
        of: find.byType(ConfidenceNote),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Venue sheet: already safe, opens at 2.0, no overflow @ 320x568', (
    tester,
  ) async {
    // Production opens the venue sheet with isScrollControlled: true.
    await openModalSheet(
      tester,
      const VenueSheet(venueId: 'macquarie-theatre'),
      scrollControlled: true,
      size: const Size(320, 568),
    );

    // DraggableScrollableSheet is unique to the venue sheet — proves it opened.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(scaleAt(tester, find.byType(DraggableScrollableSheet)), 200);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
}
