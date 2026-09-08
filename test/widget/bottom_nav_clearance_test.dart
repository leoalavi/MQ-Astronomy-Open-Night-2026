import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/widgets/nav_metrics.dart';

/// The floating tab bar must never sit on top of content.
///
/// ## The bug this file exists to prevent
///
/// The shell sets `extendBody: true`, so every tab's body runs UNDERNEATH the
/// floating glass island. Screens are expected to reserve
/// `AonNavMetrics.clearance` at the bottom of their scroll view to compensate.
/// Settings and My Night instead hardcoded `AonSpacing.space16` — 64pt against a
/// real clearance of 66 (bar) + 12 + 12 + the home indicator ≈ 124pt on an
/// iPhone. The last row of Credits, the "Google Maps licences" button, was
/// therefore permanently half-hidden behind the island and awkward to tap. Seen
/// on device.
void main() {
  Widget settings({double bottomInset = 34}) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        // copyWith, NOT a bare MediaQueryData: constructing one from scratch
        // zeroes `size`, which leaves the ListView with no viewport to lay out
        // or scroll.
        builder: (context, child) => MediaQuery(
          // A home-indicator phone: the inset the clearance must absorb.
          data: MediaQuery.of(context)
              .copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    );
  }

  group('Settings reserves the shell clearance', () {
    testWidgets('the list bottom padding covers the island AND the home '
        'indicator', (tester) async {
      await tester.pumpWidget(settings());
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byType(ListView).first);
      final pad = (list.padding as EdgeInsets?)!;
      final ctx = tester.element(find.byType(SettingsScreen));
      final needed = AonNavMetrics.clearance(ctx);

      expect(
        pad.bottom,
        greaterThanOrEqualTo(needed),
        reason: 'the last Credits row would sit behind the floating tab bar',
      );
      // And that clearance genuinely accounts for the bar, not just some
      // number that happens to be large.
      expect(needed, greaterThan(AonNavMetrics.barHeight));
    });

    testWidgets('the clearance grows with the safe-area inset', (tester) async {
      await tester.pumpWidget(settings(bottomInset: 0));
      await tester.pumpAndSettle();
      final flat = ((tester.widget<ListView>(find.byType(ListView).first))
              .padding as EdgeInsets?)!
          .bottom;

      await tester.pumpWidget(settings(bottomInset: 34));
      await tester.pumpAndSettle();
      final notched = ((tester.widget<ListView>(find.byType(ListView).first))
              .padding as EdgeInsets?)!
          .bottom;

      expect(notched, greaterThan(flat),
          reason: 'a home-indicator phone needs more room, not the same');
      expect(notched - flat, closeTo(34, 0.01));
    });

    testWidgets('the last Credits row scrolls fully clear of the island',
        (tester) async {
      // The end-to-end version of the same claim, in real pixels.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(settings());
      await tester.pumpAndSettle();

      // The developer attribution is the last always-present Credits row. (The
      // "Google Maps licences" button below it only renders once the native SDK
      // reports licence text, which a test host has no way to supply.)
      // NB: scroll with the PLAIN finder — a chained `.first` throws "No
      // element" instead of reporting "not yet built" while the scroll is still
      // looking for it.
      final last = find.textContaining('Leo Alavi');
      await tester.scrollUntilVisible(last, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // Scrolled to the very end, the final row must come to rest ABOVE the
      // island rather than under it.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SettingsScreen));
      final islandTop = 844 - AonNavMetrics.clearance(ctx);
      final box = tester.getRect(last.first);
      expect(
        box.bottom,
        lessThanOrEqualTo(islandTop + AonNavMetrics.barHeight),
        reason: 'the last Credits row is tucked under the floating tab bar',
      );
    });
  });

  group('no shell screen hardcodes its bottom inset', () {
    test('every tab screen uses AonNavMetrics.clearance', () {
      // The screens rendered INSIDE the tab shell, i.e. the ones the floating
      // island overlaps. Event detail is pushed above the shell and has none.
      const shellScreens = [
        'lib/screens/home_screen.dart',
        'lib/screens/program_screen.dart',
        'lib/screens/my_night_screen.dart',
        'lib/screens/map_screen.dart',
        'lib/screens/info_screen.dart',
        'lib/screens/settings_screen.dart',
      ];
      final missing = <String>[];
      for (final path in shellScreens) {
        final src = File(path).readAsStringSync();
        if (!src.contains('AonNavMetrics.clearance')) missing.add(path);
      }
      expect(missing, isEmpty,
          reason: 'these scroll under the floating tab bar with no clearance:\n'
              '${missing.join('\n')}');
    });

    // ── The gap that let the bug above ship a second time ──
    //
    // The screen-level guard passed the whole time. A modal bottom sheet was
    // pushed on the BRANCH navigator, which lives INSIDE the shell's Scaffold —
    // so the floating island painted straight over the sheet, and, worse, was
    // still hit-testable through the modal barrier. On the 6.9" simulator a tap
    // aimed at "Show on map" switched tabs and dismissed the sheet instead.
    // Reported by Pouya 2026-09-08 for West 6 and 1 Central Courtyard.
    //
    // Bottom padding cannot fix that: it only governs where the LAST item
    // comes to rest, not which widget is on top. The fix is
    // `useRootNavigator: true`, which puts the sheet and its scrim above the
    // whole shell. Four of the choosers already did this; the rest did not.
    test('every sheet shown inside the shell opens on the root navigator', () {
      const shellSheets = [
        'lib/widgets/venue_info_sheet.dart',
        'lib/widgets/parking_choices_sheet.dart',
        'lib/widgets/toilet_choices_sheet.dart',
        'lib/widgets/information_points_sheet.dart',
        'lib/widgets/passport_fact_sheet.dart',
        'lib/widgets/event_time_preview.dart',
        'lib/screens/program_screen.dart',
        // VenueSheet, ParkingSheet, search, favourites and the building sheet
        // are all opened from the map screen's own file.
        'lib/screens/map_screen.dart',
      ];
      final trapped = <String>[];
      for (final path in shellSheets) {
        final src = File(path).readAsStringSync();
        // Every showModalBottomSheet in the file must opt in, not just one.
        final opens = 'showModalBottomSheet'.allMatches(src).length;
        final rooted = 'useRootNavigator: true'.allMatches(src).length;
        if (opens > rooted) trapped.add('$path ($opens sheets, $rooted rooted)');
      }
      expect(trapped, isEmpty,
          reason: 'these sheets open UNDER the floating tab bar, which stays '
              'tappable through the modal barrier:\n${trapped.join('\n')}');
    });
  });
}
