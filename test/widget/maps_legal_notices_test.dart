import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';

class _LicenceInitializer implements MapsSdkInitializer {
  const _LicenceInitializer();

  @override
  Future<bool> ensureInitialized() async => true;

  @override
  Future<String?> openSourceLicenseInfo() async =>
      'Apache License 2.0\n\nThis product includes software developed by …';

  @override
  Future<String> resolveKey() async => '';
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: SettingsScreen(),
      ),
    );

ProviderContainer _container(MapsSdkInitializer init) {
  final c = ProviderContainer(
      overrides: [mapsSdkInitializerProvider.overrideWithValue(init)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('Credits shows the licence button and opens the text', (t) async {
    await t.pumpWidget(_host(_container(const _LicenceInitializer())));
    await t.pumpAndSettle();

    // scrollUntilVisible stops as soon as the target enters the viewport, which
    // can leave it under an edge — quick_access_test.dart:63 hit exactly this.
    await t.scrollUntilVisible(
        find.byKey(const Key('credits-maps-licences')), 300);
    await t.ensureVisible(find.byKey(const Key('credits-maps-licences')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('credits-maps-licences')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('maps-licence-text')), findsOneWidget);
    expect(find.textContaining('Apache License 2.0'), findsOneWidget);
  });

  testWidgets('no licence text means no button', (t) async {
    // Android's branch returns null — getOpenSourceSoftwareLicenseInfo has been
    // deprecated since Play services v11.0 and the OS surfaces those licences
    // itself, so there is nothing for the app to render.
    await t.pumpWidget(_host(_container(const NoopMapsSdkInitializer())));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('credits-maps-licences')), findsNothing,
        reason: 'an empty legal page is worse than no button');
  });
}
