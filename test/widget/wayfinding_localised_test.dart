import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/utils/time_format.dart';

/// The route panel used to render "About 6 min", "~400 m", the straight-line
/// caveat and its step numbers as hardcoded English, inside an otherwise
/// translated screen.
Widget _host({Locale locale = const Locale('en')}) => ProviderScope(
      overrides: [
        mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.declined),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const WayfindingScreen(initialDestinationId: 'central-courtyard'),
      ),
    );

Future<void> _open(WidgetTester t, {Locale locale = const Locale('en')}) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(_host(locale: locale));
  await t.pumpAndSettle();
  // The screen opens with a destination but no start; pick the car park so a
  // route actually resolves.
  await t.tap(find.text('West 5'));
  await t.pumpAndSettle();
}

void main() {
  final en = AonL10nEn();
  final fa = AonL10nFa();

  testWidgets('the walking stats come from the ARB, not string interpolation',
      (t) async {
    await _open(t);
    // West 5 → Central Courtyard: 6 min / 400 m.
    expect(find.text(en.wayfindingAboutMinutes(6)), findsOneWidget);
    expect(find.text(en.wayfindingApproxMetres(400)), findsOneWidget);
  });

  testWidgets('the straight-line caveat is the translated string', (t) async {
    await _open(t);
    expect(find.text(en.wayfindingStraightLineNote), findsOneWidget);
  });

  testWidgets('in Persian the stats and caveat carry no English', (t) async {
    await _open(t, locale: const Locale('fa'));
    expect(find.text(fa.wayfindingAboutMinutes(6)), findsOneWidget);
    expect(find.text(fa.wayfindingStraightLineNote), findsOneWidget);
    // The English forms must be gone, not merely joined by Persian ones.
    expect(find.text(en.wayfindingAboutMinutes(6)), findsNothing);
    expect(find.text(en.wayfindingStraightLineNote), findsNothing);
  });

  testWidgets('step numbers use the locale digits', (t) async {
    // `TimeFormat.locale` is a static that AonApp sets when the app locale
    // changes; this test pumps the screen directly, so it sets it here.
    final previous = TimeFormat.locale;
    TimeFormat.locale = 'fa';
    addTearDown(() => TimeFormat.locale = previous);

    await _open(t, locale: const Locale('fa'));
    // A Persian route list numbered 1, 2, 3 in Latin digits was the same
    // mismatch the Program screen's count pills had.
    expect(find.text('1'), findsNothing);
    expect(find.text(TimeFormat.count(1)), findsOneWidget);
  });
}
