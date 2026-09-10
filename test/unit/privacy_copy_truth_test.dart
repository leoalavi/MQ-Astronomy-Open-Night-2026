import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('both policies cover native, web, hosting and the privacy contact', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      for (final value in [
        'iOS',
        'ML Kit',
        'Cloudflare',
        // Data requests reach the developer account holder; event questions
        // reach the event team. Both addresses appear in both locales.
        'leo@leoalavi.dev',
        AppIdentity.eventContactEmail,
      ]) {
        expect(l.settingsPrivacyPolicyBody, contains(value));
      }
    }
    final en = await AonL10n.delegate.load(const Locale('en'));
    expect(en.settingsPrivacyPolicyBody, contains('iCloud'));
    expect(en.settingsPrivacyPolicyBody, contains('motion sensor'));
    expect(en.settingsPrivacyPolicyBody, contains('manual code entry'));
    expect(en.settingsPrivacyPolicyBody, contains('language and appearance preferences are retained'));
  });

  test('the policy carries the credit and scope the event team asked for', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    final body = en.settingsPrivacyPolicyBody;
    // The team credit names both developers. An earlier revision dropped it;
    // the event team asked for it back on 2026-09-10.
    expect(body, contains('developed by ${AppIdentity.developerCredit}'));
    expect(body, contains('Mohammad Raouf Abedini'));
    expect(body, contains(AppIdentity.forTeam));
    // Scope, in the event team's own words.
    expect(body, contains('applies specifically to the Astronomy Open Night 2026 app'));
    expect(body,
        contains('does not apply to other Syllabus Sync products or to the Macquarie University website'));
    // The scope sentence must not shrink the policy to mobile only.
    expect(body, contains('iOS, Android and web versions'));
    // Hosting is never ownership.
    expect(body, isNot(contains('is a Syllabus Sync product')));
  });

  test('English and Persian policies stay structurally parallel', () async {
    // Only the ENGLISH text is machine-checked against the website copy
    // (scripts/export-aon-pages.mjs). Persian is rendered beside it on the
    // hosted page with no such check, so a Persian edit that drops or adds a
    // paragraph would ship a policy that says different things in each
    // language. This is that missing check.
    final en =
        (await AonL10n.delegate.load(const Locale('en'))).settingsPrivacyPolicyBody;
    final fa =
        (await AonL10n.delegate.load(const Locale('fa'))).settingsPrivacyPolicyBody;
    final enParas = en.split('\n\n');
    final faParas = fa.split('\n\n');
    expect(faParas.length, enParas.length,
        reason: 'the Persian policy has a different number of paragraphs than '
            'the English one, so one language is saying more than the other');
    for (var i = 0; i < enParas.length; i++) {
      expect(enParas[i].trim(), isNotEmpty, reason: 'English paragraph $i is blank');
      expect(faParas[i].trim(), isNotEmpty, reason: 'Persian paragraph $i is blank');
    }
    // Addresses and URLs are language-independent and must appear in both.
    for (final literal in [
      'leo@leoalavi.dev',
      AppIdentity.eventContactEmail,
      AppIdentity.eventWebsiteUrl,
      'Astronomy Open Night 2026',
    ]) {
      expect(fa, contains(literal), reason: '"$literal" is missing from Persian');
      expect(en, contains(literal), reason: '"$literal" is missing from English');
    }
  });

  test('the policy body and the credit shown beneath it agree', () async {
    // The web privacy screen renders the policy body and then a credit line.
    // They came from different constants and drifted once; this pins them.
    final en =
        (await AonL10n.delegate.load(const Locale('en'))).settingsPrivacyPolicyBody;
    expect(AppIdentity.developerCredit, contains(AppIdentity.developers));
    expect(AppIdentity.developerCredit, contains('Syllabus Sync team'));
    expect(en, contains(AppIdentity.developerCredit));
  });

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
