import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';

ProviderContainer _container({MapsConsent consent = MapsConsent.unknown}) {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer(overrides: [
    mapsConsentSnapshotProvider.overrideWithValue(consent),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _app(ProviderContainer c, {Locale locale = const Locale('en')}) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const SettingsScreen(),
      ),
    );

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f); // fully into the viewport so it is hit-testable at 2.0 scale
  await t.pumpAndSettle();
}

void main() {
  testWidgets('EN: Google Maps privacy notice is present; no revoke when consent unknown', (t) async {
    await t.pumpWidget(_app(_container()));
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    await _scrollTo(t, find.textContaining('sent to Google'));
    expect(find.text(l.settingsGoogleMapsNotice), findsOneWidget);
    expect(find.text(l.settingsRevokeGoogleConsent), findsNothing); // nothing to revoke yet
  });

  testWidgets('FA: notice renders in Persian', (t) async {
    await t.pumpWidget(_app(_container(), locale: const Locale('fa')));
    await t.pumpAndSettle();
    final fa = await AonL10n.delegate.load(const Locale('fa'));
    await _scrollTo(t, find.text(fa.settingsGoogleMapsNotice));
    expect(find.text(fa.settingsGoogleMapsNotice), findsOneWidget);
  });

  testWidgets('revoke visible only when accepted; tapping it → consent unknown (next nav re-asks)', (t) async {
    final c = _container(consent: MapsConsent.accepted);
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(c.read(mapsConsentProvider), MapsConsent.accepted);
    final l = await AonL10n.delegate.load(const Locale('en'));
    await _scrollTo(t, find.text(l.settingsRevokeGoogleConsent));
    await t.tap(find.text(l.settingsRevokeGoogleConsent));
    await t.pumpAndSettle();
    expect(c.read(mapsConsentProvider), MapsConsent.unknown);
  });

  testWidgets('320×568 @ textScale 2.0: revoke row reachable + tappable', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = _container(consent: MapsConsent.accepted);
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: _app(c),
    ));
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    await _scrollTo(t, find.text(l.settingsRevokeGoogleConsent));
    await t.tap(find.text(l.settingsRevokeGoogleConsent));
    await t.pumpAndSettle();
    expect(c.read(mapsConsentProvider), MapsConsent.unknown); // proved reachable + tappable
    expect(t.takeException(), isNull);
  });
}
