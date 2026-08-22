import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('the English privacy copy does not deny what the app now does', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    final body = en.settingsPrivacyBody.toLowerCase();

    expect(body, isNot(contains('tracks no location')),
        reason: 'the app sends location to Google for directions');
    expect(body, isNot(contains('only thing it fetches')),
        reason: 'the app also fetches Google map imagery and routes');
    expect(body, contains('google'),
        reason: 'third-party sharing needs disclosure and explicit permission '
            'under 5.1.2(i) — 5.1.1(i) governs the privacy POLICY, which is a '
            'different obligation');
  });

  test('both locales define the privacy body and mention Google', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(l.settingsPrivacyBody.trim(), isNotEmpty);
      expect(l.settingsPrivacyBody.toLowerCase(),
          anyOf(contains('google'), contains('گوگل')),
          reason: '${locale.languageCode} must disclose the Google surface too');
    }
  });

  test('neither locale still promises nothing leaves the phone', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(l.settingsPrivacyCardTitle.toLowerCase(),
          isNot(contains('nothing leaves')),
          reason: 'something does leave: location, when you ask for directions');
    }
  });
}
