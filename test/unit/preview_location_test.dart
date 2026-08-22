import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/preview_location.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/preview_location_badge.dart';

import '../support/fake_location_service.dart';

/// A real service that refuses, standing in for a device where the visitor
/// declined location — exactly the case preview mode exists to serve.
ProviderContainer _container() {
  final c = ProviderContainer(overrides: [
    locationServiceProvider
        .overrideWithValue(FakeLocationService(grant: LocationStatus.denied)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('preview is off by default', () {
    expect(_container().read(previewLocationProvider), isFalse);
  });

  test('off, the effective service is the real one', () {
    final c = _container();
    expect(c.read(effectiveLocationServiceProvider), isA<FakeLocationService>());
  });

  test('on, the effective service is the preview one', () {
    final c = _container();
    c.read(previewLocationProvider.notifier).set(true);
    expect(
        c.read(effectiveLocationServiceProvider), isA<PreviewLocationService>());
  });

  test('the preview fix sits on campus and is granted', () async {
    const svc = PreviewLocationService();
    expect(await svc.status(), LocationStatus.granted);

    final fix = await svc.watch().first;
    expect(fix.position, MapConfig.campusCentre);
    expect(fix.isLowAccuracy, isFalse,
        reason: 'a simulated fix must not also simulate poor accuracy');
  });

  test('enabling preview activates location without a prior grant', () async {
    final c = _container();
    c.read(locationControllerProvider); // instantiate the controller
    expect(c.read(locationControllerProvider).active, isFalse);

    c.read(previewLocationProvider.notifier).set(true);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(locationControllerProvider).active, isTrue,
        reason: 'preview exists for users who never granted location; gating it '
            'on state.active would make it inert for exactly them');
  });

  test('disabling preview returns to the real, ungranted service', () async {
    final c = _container();
    c.read(locationControllerProvider);
    c.read(previewLocationProvider.notifier).set(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).active, isTrue);

    c.read(previewLocationProvider.notifier).set(false);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(effectiveLocationServiceProvider), isA<FakeLocationService>());
    expect(c.read(locationControllerProvider).fix, isNull,
        reason: 'the simulated fix must not survive the toggle');
  });

  testWidgets('the badge appears only while previewing', (t) async {
    final c = _container();

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: PreviewLocationBadge()),
      ),
    ));
    expect(find.byKey(const Key('preview-location-badge')), findsNothing);

    c.read(previewLocationProvider.notifier).set(true);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview-location-badge')), findsOneWidget,
        reason: 'spec §3c: a simulated fix must never be presented as a real '
            'one, and the Settings toggle is not on screen when the visitor is '
            'looking at the map');
  });
}
