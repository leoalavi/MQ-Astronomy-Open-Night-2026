import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> snapshot) => ProviderScope(
  overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
  child: const MaterialApp(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    home: PassportScreen(),
  ),
);

void main() {
  testWidgets('shows progress out of 9', (t) async {
    await t.pumpWidget(_host({'macquarie-theatre'}));
    expect(find.textContaining('1 / 9'), findsOneWidget);
  });

  testWidgets('complete shows the reward affordance', (t) async {
    await t.pumpWidget(_host(StampStationsData.stationVenueIds));
    expect(find.textContaining('9 / 9'), findsOneWidget);
    expect(find.text('View your reward'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host({'macquarie-theatre'}));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  void bigViewport(WidgetTester t) {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('disabled copy renders at 320x568 / 2.0', (t) async {
    bigViewport(t);
    await t.pumpWidget(ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(<String>{}),
        passportCollectionEnabledProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: PassportScreen(),
      ),
    ));
    await t.pumpAndSettle();
    expect(
        find.text('Astronomy Passport opens on event night'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('near-complete nudge at 320x568 / 2.0', (t) async {
    bigViewport(t);
    final eight = StampStationsData.all.take(8).map((s) => s.venueId).toSet();
    await t.pumpWidget(_host(eight));
    await t.pumpAndSettle();
    expect(find.text('Just 1 more to go!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // The reset control is compiled out of release builds, but `flutter test`
  // runs in debug, so the confirm/cancel paths are reachable — and worth
  // holding: a stamp trail that silently wipes on a mis-tap would be a bad
  // night for someone eight stamps in.
  group('reset (debug-only control)', () {
    Finder resetButton() => find.byTooltip('Reset passport (debug)');

    testWidgets('cancelling leaves every stamp in place', (t) async {
      await t.pumpWidget(_host({'macquarie-theatre', 'mason-theatre'}));
      await t.pumpAndSettle();
      expect(find.textContaining('2 / 9'), findsOneWidget);

      await t.tap(resetButton());
      await t.pumpAndSettle();
      expect(find.text('Reset passport?'), findsOneWidget);
      expect(
        find.text('This clears all collected stamps on this device.'),
        findsOneWidget,
      );

      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Reset passport?'), findsNothing);
      expect(find.textContaining('2 / 9'), findsOneWidget);
    });

    testWidgets('confirming clears the passport', (t) async {
      await t.pumpWidget(_host({'macquarie-theatre', 'mason-theatre'}));
      await t.pumpAndSettle();

      await t.tap(resetButton());
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Reset'));
      await t.pumpAndSettle();

      expect(find.text('Reset passport?'), findsNothing);
      // Back to the zero state, which is the "start" copy, not "0 / 9".
      expect(find.text('Scan or enter a venue code to start'), findsOneWidget);
    });
  });
}
