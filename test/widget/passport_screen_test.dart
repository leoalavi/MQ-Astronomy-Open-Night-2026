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
}
