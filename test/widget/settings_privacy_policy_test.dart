import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/screens/privacy_screen.dart';

/// B7: the in-app Privacy Policy entry point. Stores require the privacy policy
/// to be reachable from inside the app. The row is config-driven — it appears
/// only when a real hosted URL is set (`EventConfig.privacyPolicyUrl`), so no
/// dead link ships while the production URL is still unhosted.
void main() {
  const testUrl = 'https://policy.example.test/privacy';

  test('the shipped app uses the canonical hosted policy', () {
    expect(EventConfig.astronomyOpenNight.privacyPolicyUrl,
        AppIdentity.canonicalPrivacyUrl);
    expect(AppIdentity.canonicalPrivacyUrl,
        'https://aon.syllabus-sync.app/privacy');
  });

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
          EventConfig.astronomyOpenNight.copyWith(privacyPolicyUrl: policyUrl, clearPrivacyPolicyUrl: policyUrl == null),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
  }

  Future<void> scrollTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  testWidgets('a configured URL shows the shared in-app Privacy Policy', (
    t,
  ) async {
    await t.pumpWidget(harness(policyUrl: testUrl));
    await t.pumpAndSettle();

    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    expect(row, findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(
      find.textContaining('Astronomy Open Night 2026 is developed by'),
      findsOneWidget,
    );
    await t.scrollUntilVisible(
      find.text('Android only: Google ML Kit'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Android only: Google ML Kit'), findsOneWidget);
  });

  testWidgets('no hosted URL still exposes the complete shared policy', (
    t,
  ) async {
    await t.pumpWidget(harness(policyUrl: null));
    await t.pumpAndSettle();
    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.textContaining('Leo Alavi'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Android only: Google ML Kit'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('ML Kit'), findsWidgets);
  });

  testWidgets('the row label is real Persian under fa', (t) async {
    await t.pumpWidget(harness(policyUrl: testUrl, locale: const Locale('fa')));
    await t.pumpAndSettle();
    final row = find.byKey(const Key('settings-privacy-policy'));
    await scrollTo(t, row);
    expect(find.text('سیاست حریم خصوصی'), findsOneWidget);
  });
}
