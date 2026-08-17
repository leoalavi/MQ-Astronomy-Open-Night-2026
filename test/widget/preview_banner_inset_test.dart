import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/event_time_preview.dart';

/// The preview banner must not push every screen down twice.
///
/// ## The bug this file exists to prevent
///
/// Found on an iPhone 17 Pro (Dynamic Island). The banner sits above the
/// navigation shell in a Column and clears the status bar with its own SafeArea.
/// But the shell's Scaffolds still saw a non-zero `MediaQuery.padding.top`, so
/// each tab's AppBar applied the very same inset a second time. The Program
/// title dropped from 208px to 515px, leaving a ~50pt band of dead space under
/// the banner.
///
/// Double-inset bugs are easy to reintroduce, because any new widget inserted
/// above a Scaffold repeats the same mistake, and the result reads as "a bit of
/// extra padding" rather than as a fault.
void main() {
  // Held so the test can navigate without needing a context inside the router
  // subtree (GoRouter.of on the MaterialApp's own element finds nothing).
  late GoRouter router;

  /// The whole shell, so the real AppBar/SafeArea interaction is exercised.
  Widget app() {
    router = buildRouter();
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
    });
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          // A notched phone: a top inset is what makes the double-count visible.
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: child!,
        ),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );

  /// Moves to a tab that actually has an AppBar.
  ///
  /// Home is the initial tab and draws its hero straight to the top edge with no
  /// AppBar, so the doubled inset is invisible there — an earlier version of this
  /// test measured Home and passed against the unfixed code. Info has a real
  /// AppBar, which is the widget that re-applies the padding.
  Future<void> goToInfo(WidgetTester tester) async {
    router.go(Routes.info);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
  }

  /// Top of the AppBar's content — the thing that visibly moved.
  double titleTop(WidgetTester tester) =>
      tester.getRect(find.text('Useful information')).top;

  testWidgets('turning the preview on does not add a second status-bar inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goToInfo(tester);

    // Baseline: where the screen title sits with no banner.
    final before = titleTop(tester);
    expect(find.byType(EventTimePreviewBanner), findsOneWidget);

    // Switch the clock into preview mode, which reveals the banner.
    containerOf(tester).read(simulatedTimeProvider.notifier).set(
          EventInfo.at(19, 0),
        );
    await tester.pumpAndSettle();

    final bannerHeight = tester.getRect(find.byType(EventTimePreviewBanner)).height;
    expect(bannerHeight, greaterThan(0), reason: 'the banner did not appear');

    final after = titleTop(tester);
    final shift = after - before;

    // ── The arithmetic ──
    //
    // The banner's own height already includes the 59pt status-bar inset it
    // consumes via SafeArea, so bannerHeight == 59 + its visible content.
    //
    // Correct behaviour: the shell below it no longer sees that inset, so the
    // title moves down by the banner's *content* only:
    //     shift == bannerHeight - 59
    //
    // The bug: the AppBar re-applies the 59pt itself, so the title moves down by
    // the full banner height:
    //     shift == bannerHeight
    //
    // Asserting both directions, because the two values are only 59pt apart and
    // a one-sided check is easy to satisfy by accident.
    const topInset = 59.0;
    expect(
      shift,
      closeTo(bannerHeight - topInset, 2),
      reason: 'title shifted ${shift.round()}pt for a '
          '${bannerHeight.round()}pt banner; expected '
          '${(bannerHeight - topInset).round()}pt',
    );
    expect(
      shift,
      isNot(closeTo(bannerHeight, 2)),
      reason: 'the ${topInset.round()}pt status-bar inset is being applied '
          'twice — once by the banner and again by the AppBar',
    );
  });

  testWidgets('exiting the preview restores the original layout exactly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goToInfo(tester);
    final before = titleTop(tester);

    final notifier = containerOf(tester).read(simulatedTimeProvider.notifier);
    notifier.set(EventInfo.at(19, 0));
    await tester.pumpAndSettle();
    notifier.clear();
    await tester.pumpAndSettle();

    expect(titleTop(tester), closeTo(before, 0.5));
    expect(tester.takeException(), isNull);
  });
}
