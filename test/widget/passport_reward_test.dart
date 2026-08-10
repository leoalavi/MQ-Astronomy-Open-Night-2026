import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:aon2026/screens/passport_reward_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> snapshot, {bool reduceMotion = false}) =>
    ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const PassportRewardScreen(),
      ),
    );

Future<void> _teardown(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

void main() {
  final all = StampStationsData.stationVenueIds;

  testWidgets('complete -> shows the redeem instruction', (t) async {
    await t.pumpWidget(_host(all));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Show this to staff'), findsOneWidget);
    await _teardown(t);
  });

  testWidgets('INCOMPLETE -> refuses to show redemption', (t) async {
    await t.pumpWidget(_host(<String>{'macquarie-theatre'})); // 1/9
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Show this to staff'), findsNothing);
    expect(find.textContaining('not complete'), findsOneWidget);
    await _teardown(t);
  });

  testWidgets('reduced motion omits the confetti widget', (t) async {
    await t.pumpWidget(_host(all, reduceMotion: true));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(ConfettiWidget), findsNothing);
    await _teardown(t);
  });

  testWidgets('complete: no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host(all));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await _teardown(t);
  });
}
