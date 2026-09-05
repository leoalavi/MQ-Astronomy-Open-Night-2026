import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/url_opener.dart';

/// B7: the in-app Privacy Policy entry point. Stores require the privacy policy
/// to be reachable from inside the app. The row is config-driven — it appears
/// only when a real hosted URL is set (`EventConfig.privacyPolicyUrl`), so no
/// dead link ships while the production URL is still unhosted.
void main() {
  const testUrl = 'https://policy.example.test/privacy';

  Widget harness({
    required String? policyUrl,
    List<Uri>? opened,
    bool openOk = true,
    Locale? locale,
  }) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      overrides: [
        eventConfigProvider.overrideWithValue(
          EventConfig.astronomyOpenNight.copyWith(privacyPolicyUrl: policyUrl),
        ),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened?.add(uri);
          return openOk;
        }),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
  }

  Future<void> scrollTo(WidgetTester t, Finder f) => t.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('a configured URL shows a Privacy Policy row that opens it',
      (t) async {
    final opened = <Uri>[];
    await t.pumpWidget(harness(policyUrl: testUrl, opened: opened));
    await t.pumpAndSettle();

    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    expect(row, findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await t.tap(row);
    await t.pumpAndSettle();
    expect(opened, [Uri.parse(testUrl)]);
  });

  testWidgets('no hosted URL still exposes a complete offline privacy policy', (t) async {
    final opened = <Uri>[];
    await t.pumpWidget(harness(policyUrl: null, opened: opened));
    await t.pumpAndSettle();
    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Leo Alavi'), findsOneWidget);
    expect(find.textContaining('ML Kit'), findsWidgets);
    expect(opened, isEmpty);
  });

  testWidgets('a failed open is reported honestly, never a crash', (t) async {
    await t.pumpWidget(harness(policyUrl: testUrl, openOk: false));
    await t.pumpAndSettle();
    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    await t.tap(row);
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.settingsPrivacyPolicyUnavailable), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the row label is real Persian under fa', (t) async {
    await t.pumpWidget(
      harness(policyUrl: testUrl, locale: const Locale('fa')),
    );
    await t.pumpAndSettle();
    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    expect(find.text('سیاست حریم خصوصی'), findsOneWidget);
  });
}
