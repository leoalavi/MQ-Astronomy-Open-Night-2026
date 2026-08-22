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

  test('the campus attribution names Macquarie University', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    expect(en.mapAttributionCampus, contains('Macquarie University'));
    expect(en.mapAttributionCampus, isNot(contains('©')),
        reason: "MQ's ownership of the cartographic master is unconfirmed "
            'under spec §8.6 — we do not assert copyright on their behalf');
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
