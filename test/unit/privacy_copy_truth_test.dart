import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test(
    'the web policy screen text carries the third-party disclosures',
    () async {
      // PrivacyScreen renders the webPrivacy* strings, not settingsPrivacyPolicyBody,
      // so these need their own check.
      for (final locale in AonL10n.supportedLocales) {
        final l = await AonL10n.delegate.load(locale);
      expect(l.webPrivacyMlKitBody, contains('ML Kit'));
        expect(l.webPrivacyMapsBody, contains('policies.google.com/privacy'));
        expect(l.webPrivacyScope.trim(), isNotEmpty);
      }
    },
  );

  test('English and Persian policies stay structurally parallel', () async {
    // PrivacyScreen now renders structured webPrivacy* sections. Pin the
    // section count and require content in both locales so a translation
    // cannot silently omit one.
    final en = await AonL10n.delegate.load(const Locale('en'));
    final fa = await AonL10n.delegate.load(const Locale('fa'));
    List<String> sections(AonL10n l) => [
      l.webPrivacyScope,
      l.webPrivacyStorageBody,
      l.webPrivacyLocationBody,
      l.webPrivacyCameraBody,
      l.webPrivacyMlKitBody,
      l.webPrivacyMapsBody,
      l.webPrivacyAnalyticsBody,
      l.webPrivacyRetentionBody,
      l.webPrivacyContactBody(
        'leo@leoalavi.dev',
        'astronomyopennight@mq.edu.au',
        'https://event.mq.edu.au/astronomy-open-night/',
        'https://aon.syllabus-sync.app/privacy',
      ),
    ];
    final enSections = sections(en);
    final faSections = sections(fa);
    expect(faSections.length, enSections.length);
    for (var i = 0; i < enSections.length; i++) {
      expect(
        enSections[i].trim(),
        isNotEmpty,
        reason: 'English section $i is blank',
      );
      expect(
        faSections[i].trim(),
        isNotEmpty,
        reason: 'Persian section $i is blank',
      );
    }
    // The contact address is language-independent and must survive translation.
    expect(faSections.join('\n'), contains('leo@leoalavi.dev'));
    expect(enSections.join('\n'), contains('leo@leoalavi.dev'));
  });

  test(
    'the English privacy copy does not deny what the app now does',
    () async {
      final en = await AonL10n.delegate.load(const Locale('en'));
      final body = en.settingsPrivacyBody.toLowerCase();

      expect(
        body,
        isNot(contains('tracks no location')),
        reason: 'the app sends location to Google for directions',
      );
      expect(
        body,
        isNot(contains('only thing it fetches')),
        reason: 'the app also fetches Google map imagery and routes',
      );
      expect(
        body,
        contains('google'),
        reason:
            'third-party sharing needs disclosure and explicit permission '
            'under 5.1.2(i) — 5.1.1(i) governs the privacy POLICY, which is a '
            'different obligation',
      );
    },
  );

  test('Android SDK diagnostics and backup limits are disclosed', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    expect(en.settingsPrivacyBody, contains('ML Kit'));
    expect(en.settingsPrivacyBody, contains('installation identifiers'));
    expect(en.settingsPrivacyBody, contains('system backups'));
    expect(en.settingsPrivacyBody, isNot(contains('collects no analytics')));
    final fa = await AonL10n.delegate.load(const Locale('fa'));
    expect(fa.settingsPrivacyBody, contains('ML Kit'));
    expect(fa.settingsPrivacyBody, contains('شناسه'));
  });

  test('both locales define the privacy body and mention Google', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(l.settingsPrivacyBody.trim(), isNotEmpty);
      expect(
        l.settingsPrivacyBody.toLowerCase(),
        anyOf(contains('google'), contains('گوگل')),
        reason: '${locale.languageCode} must disclose the Google surface too',
      );
    }
  });

  test('neither locale still promises nothing leaves the phone', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(
        l.settingsPrivacyCardTitle.toLowerCase(),
        isNot(contains('nothing leaves')),
        reason: 'something does leave: location, when you ask for directions',
      );
    }
  });
}
