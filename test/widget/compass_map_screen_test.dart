import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/compass_mode_view.dart';
import '../support/fake_location_service.dart';

ProviderContainer _container(FakeLocationService svc) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

void main() {
  testWidgets('MapScreen → compass mode renders CompassModeView and hides the wayfinding FAB (§0-N)',
      (t) async {
    final c = _container(FakeLocationService());
    await t.runAsync(() async {
      await t.pumpWidget(_app(c));
      await t.pump();
    });
    // Campus-map mode: the wayfinding FAB is present.
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.tap(find.bySemanticsLabel(l.mapModeCompass));
    await t.pump(); // setState → switch mode
    await t.pump(const Duration(milliseconds: 400)); // let the Scaffold FAB exit-animation finish

    expect(find.byType(CompassModeView), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing); // §0-N
  });
}
