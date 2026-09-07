import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('no shipped string claims OpenStreetMap attribution', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      final claims = <String>[
        l.settingsMapDataAttribution,
        l.creditsMapDataBody,
        l.mapAttributionCampus,
      ];
      for (final c in claims) {
        expect(
          c.toLowerCase(),
          isNot(contains('openstreetmap')),
          reason: 'the app renders no OSM tiles after the Google swap; '
              'locale ${locale.languageCode} still attributes OSM',
        );
      }
    }
  });

  // Superseded 2026-09-07. The attribution used to be REQUIRED to name the
  // university as the map's source. The project supervisor has since
  // instructed that the app must not use the university's name for anything,
  // because the app is an independent student project with no university
  // approval. The credit now names the SOURCE DOCUMENT instead. The '(c)' ban
  // below still stands: we assert ownership on nobody's behalf.
  test('the campus attribution credits a source, not a university', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    expect(en.mapAttributionCampus, contains('Astronomy Open Night'));
    expect(en.mapAttributionCampus.toLowerCase(),
        isNot(contains('macquarie')),
        reason: 'no app surface may name the university');
    expect(en.mapAttributionCampus, isNot(contains('\u00a9')),
        reason: 'the campus map credit asserts copyright for nobody');
  });

  // The © ban has to hold across EVERY shipped string, not just the one on the
  // basemap overlay. It did not: a Credits line arrived reading "Event
  // materials, campus map and branding © {host}" — asserting, in the same
  // build, exactly the ownership `mapAttributionCampus` refuses to assert.
  // The campus map is still credited, as a SOURCE, in creditsMapDataBody.
  test('no shipped string claims © over the campus map', () async {
    const mapPhrases = ['campus map', 'نقشهٔ پردیس'];

    for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_fa.arb']) {
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

      decoded.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        if (!value.contains('©')) return;

        for (final phrase in mapPhrases) {
          expect(
            value.toLowerCase().contains(phrase.toLowerCase()),
            isFalse,
            reason: '$path: "$key" asserts © over the campus map. MQ\'s '
                'ownership of the cartographic master is unconfirmed under '
                'spec §8.6 — credit it as a source, as creditsMapDataBody '
                'does, until the written sign-off lands.',
          );
        }
      });
    }
  });

  test('NO shipped ARB string mentions OpenStreetMap', () async {
    // The getters above are the ones we know about. This scans everything
    // shipped, so a string added later cannot quietly reintroduce the claim.
    for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_fa.arb']) {
      final text = await File(path).readAsString();
      expect(text.toLowerCase(), isNot(contains('openstreetmap')),
          reason: '$path still attributes OSM after the tiles were removed');
      expect(text, isNot(contains('tile.openstreetmap.org')));
    }
  });
}
