import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/config/app_identity.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';

/// The canonical public Privacy Policy at https://aon.syllabus-sync.app/privacy
/// is a static, JS-free page (`web/privacy.html`) GENERATED from the in-app
/// privacy strings (the `webPrivacy*` keys), so a store reviewer or a
/// JavaScript-disabled client can read exactly the same policy the app shows —
/// there is no second, independently-maintained policy.
///
/// This test fails if `web/privacy.html` drifts from that source. When it fails,
/// regenerate:  `python3 tool/privacy/gen_privacy_html.py`
void main() {
  final en = AonL10nEn();
  final html = File('web/privacy.html').readAsStringSync();
  // Plain-text rendering of the page (tags stripped, whitespace collapsed).
  // Strip tags to EMPTY (not a space) so a linkified URL like
  // "(<a>https://…</a>)" collapses back to "(https://…)" exactly as authored;
  // the generator keeps each section's body on its own line, so bodies stay
  // separated by the surrounding whitespace.
  final text = html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  test('privacy.html is a static, readable, JS-free page with correct metadata', () {
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<html lang="en">'));
    expect(html, contains('<title>${en.webPrivacyPageTitle}</title>'));
    expect(html, contains('<h1>${en.webPrivacyPageTitle}</h1>'));
    expect(html, contains('rel="canonical" href="${AppIdentity.canonicalPrivacyUrl}"'));
    // No app runtime, no unresolved template tokens.
    expect(html, isNot(contains('flutter')));
    expect(html, isNot(contains('{developer}')));
    expect(html, isNot(contains('{forTeam}')));
    expect(html, isNot(contains('{date}')));
  });

  test('every in-app privacy section is present verbatim in privacy.html', () {
    final expected = <String>[
      norm(en.webPrivacyLastUpdated(AppIdentity.privacyLastUpdated)),
      norm(en.webPrivacyIntro(AppIdentity.developers, AppIdentity.forTeam)),
      norm(en.webPrivacyScope),
      en.webPrivacyStorageHeading, en.webPrivacyStorageBody,
      en.webPrivacyLocationHeading, en.webPrivacyLocationBody,
      en.webPrivacyCameraHeading, en.webPrivacyCameraBody,
      en.webPrivacyMapsHeading, en.webPrivacyMapsBody,
      en.webPrivacyAnalyticsHeading, en.webPrivacyAnalyticsBody,
      en.webPrivacyRetentionHeading, en.webPrivacyRetentionBody,
      en.webPrivacyContactHeading, en.webPrivacyContactBody,
      norm(en.webPrivacyCredit(AppIdentity.developers, AppIdentity.forTeam)),
      AppIdentity.copyrightLine,
    ];
    for (final chunk in expected) {
      expect(text, contains(norm(chunk)),
          reason: 'web/privacy.html is stale — regenerate with '
              'tool/privacy/gen_privacy_html.py. Missing: "${norm(chunk)}"');
    }
  });

  test('contacts keep their roles and the copyright is the event team', () {
    // Privacy/developer contact is a real mailto link; event support is present.
    expect(html, contains('mailto:leo@leoalavi.dev'));
    expect(html, contains('astronomyopennight@mq.edu.au'));
    // Never present Syllabus Sync as owner, never a university copyright.
    expect(html, isNot(contains('Syllabus Sync')));
    expect(html.toLowerCase(), isNot(contains('macquarie university')));
    expect(html, isNot(matches(RegExp(r'©\s*20\d\d\s*Macquarie'))));
    expect(html, contains('© ${AppIdentity.copyrightYear} ${AppIdentity.copyrightHolder}'));
  });
}
