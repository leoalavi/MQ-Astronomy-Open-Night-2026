import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';

/// Cross-surface privacy consistency. The canonical policy is the web policy
/// (`webPrivacy*`, rendered in-app on every platform and as the static
/// `web/privacy.html` — see `privacy_html_sync_test`).
void main() {
  final en = AonL10nEn();
  final fa = AonL10nFa();

  test('privacy contact is leo@leoalavi.dev on every privacy surface', () {
    for (final s in [
      en.webPrivacyContactBody(
        'leo@leoalavi.dev',
        'support@example.test',
        'https://event.example.test',
        'https://policy.example.test',
      ),
      fa.webPrivacyContactBody(
        'leo@leoalavi.dev',
        'support@example.test',
        'https://event.example.test',
        'https://policy.example.test',
      ),
    ]) {
      expect(s, contains('leo@leoalavi.dev'));
      // Never the stale developer gmail, never the event mailbox as the
      // *privacy* contact line.
      expect(s, isNot(contains('leo.alavi.dev@gmail.com')));
    }
  });

  test('event support address stays out of the privacy-contact role', () {
    final contact = en.webPrivacyContactBody(
      'leo@leoalavi.dev',
      'astronomyopennight@mq.edu.au',
      'https://event.mq.edu.au/astronomy-open-night/',
      'https://aon.syllabus-sync.app/privacy',
    );
    expect(
      contact,
      contains('Privacy and developer questions: leo@leoalavi.dev'),
    );
    expect(
      contact,
      contains('Event and support questions: astronomyopennight@mq.edu.au'),
    );
  });

  test('material facts appear in the shared canonical policy', () {
    final web = [
      en.webPrivacyStorageBody,
      en.webPrivacyCameraBody,
      en.webPrivacyMlKitBody,
      en.webPrivacyMapsBody,
      en.webPrivacyRetentionBody,
      en.webPrivacyAnalyticsBody,
    ].join('\n');
    expect(web, contains('Delete my data'));
    expect(web, contains('ML Kit'));
    expect(web, contains('Google Maps'));
    expect(web, contains('sell your personal data'));
  });

  test('canonical copy makes no mobile-store release-status claim', () {
    final policy = [
      en.webPrivacyIntro('X', 'Y'),
      en.webPrivacyScope,
      en.webPrivacyStorageBody,
      en.webPrivacyLocationBody,
      en.webPrivacyCameraBody,
      en.webPrivacyMlKitBody,
      en.webPrivacyMapsBody,
      en.webPrivacyAnalyticsBody,
      en.webPrivacyRetentionBody,
      en.webPrivacyContactBody('a', 'b', 'c', 'd'),
    ].join('\n').toLowerCase();
    for (final claim in [
      'pre-release',
      'prerelease',
      'not yet published',
      'not publicly released',
      'published on google play',
      'published on the app store',
    ]) {
      expect(policy, isNot(contains(claim)));
    }
  });

  test(
    'no surface implies university/Syllabus-Sync ownership or © Macquarie',
    () {
      final all = [
        en.webPrivacyIntro('X', 'Y'),
        fa.webPrivacyIntro('X', 'Y'),
        en.webPrivacyContactBody(
          'a@b.test',
          'c@d.test',
          'https://example.test',
          'https://example.test/privacy',
        ),
        en.webPrivacyScope,
      ].join('\n');
      expect(all, isNot(contains('Syllabus Sync')));
      expect(all.toLowerCase(), isNot(contains('macquarie university')));
      expect(all, isNot(matches(RegExp(r'©\s*20\d\d\s*Macquarie'))));
    },
  );
}
