import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:aon2026/screens/passport_screen.dart';

void main() {
  final en = AonL10nEn();

  String line(bool enabled, int count) =>
      passportProgressLine(en, collectionEnabled: enabled, count: count,
          total: 9);

  test('disabled overrides in-progress states', () {
    expect(line(false, 0), 'Astronomy Passport opens on event night');
    expect(line(false, 3), 'Astronomy Passport opens on event night');
  });
  test('completion outranks the disabled gate (persisted 9/9)', () {
    expect(line(false, 9), '9 / 9 stamps'); // NOT "opens on event night"
    expect(line(true, 9), '9 / 9 stamps');
  });
  test('boundaries', () {
    expect(line(true, 0), 'Scan or enter a venue code to start');
    expect(line(true, 1), '1 / 9 stamps');
    expect(line(true, 7), '7 / 9 stamps');
    expect(line(true, 8), 'Just 1 more to go!');
    expect(line(true, 9), '9 / 9 stamps');
  });

  // The screen used to hardcode every one of these in English, so a Persian
  // visitor read the whole passport in a language they may not have. The rule
  // is EN+FA for every string; this proves the progress line honours it.
  test('the line is localised, not hardcoded English', () {
    final fa = AonL10nFa();
    String faLine(bool enabled, int count) => passportProgressLine(
          fa, collectionEnabled: enabled, count: count, total: 9);

    for (final probe in <String Function()>[
      () => faLine(false, 0),
      () => faLine(true, 0),
      () => faLine(true, 8),
      () => faLine(true, 9),
    ]) {
      final value = probe();
      expect(value, isNotEmpty);
      expect(
        value,
        isNot(matches(RegExp(r'[A-Za-z]{4,}'))),
        reason: 'Persian copy must not fall back to an English sentence',
      );
    }
  });

  test('every AonL10n locale resolves the passport keys', () {
    for (final l in <AonL10n>[AonL10nEn(), AonL10nFa()]) {
      expect(l.passportOpensOnEventNight, isNotEmpty);
      expect(l.passportStartHint, isNotEmpty);
      expect(l.passportOneMoreToGo, isNotEmpty);
      expect(l.passportProgress(3, 9), isNotEmpty);
      expect(l.passportScanTitle, isNotEmpty);
      expect(l.passportScanCollected, isNotEmpty);
      expect(l.passportScanDisabled, isNotEmpty);
      expect(l.settingsPassportPreviewTitle, isNotEmpty);
      expect(l.settingsPassportPreviewBody, isNotEmpty);
      expect(l.passportPreviewBadge, isNotEmpty);
    }
  });
}
