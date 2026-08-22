import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/passport_home_card.dart';

/// The Home Passport card's stamp count.
///
/// ## The bug this file exists to prevent
///
/// The card rendered `'${count} / ${total} stamps'` — a hardcoded English word
/// and Western digits. On a Persian screen the Unicode bidi algorithm reordered
/// that mixed run so "0 / 9 stamps" showed as "stamps 9 / 0": the label was
/// untranslated AND the collected/total counts read reversed.
///
/// The fix is a localised, locale-digit message ("{count} of {total} stamps" /
/// "{count} از {total} مهر"): each is a single-direction run, so the numbers
/// keep their meaning (collected first, total second) in both languages.
void main() {
  final stations = PassportPolicy.stationVenueIds.toList();
  final total = PassportPolicy.stationCount;

  /// The card with exactly [collected] stamps collected, in [locale].
  Widget card({required int collected, required Locale locale, double scale = 1.0}) {
    return ProviderScope(
      overrides: [
        passportSnapshotProvider
            .overrideWithValue(stations.take(collected).toSet()),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        locale: locale,
        theme: AonTheme.build(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Center(child: PassportHomeCard()),
          ),
        ),
      ),
    );
  }

  String progressText(WidgetTester tester) {
    // The card has two Texts: the title and the progress line. The progress
    // one is whichever contains a digit (Western or Persian).
    final digits = RegExp(r'[0-9۰-۹]');
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((s) => digits.hasMatch(s));
  }

  group('English semantics', () {
    for (final collected in const [0, 1, 4]) {
      testWidgets('$collected collected reads "$collected of N stamps"', (
        tester,
      ) async {
        await tester.pumpWidget(card(collected: collected, locale: const Locale('en')));
        await tester.pumpAndSettle();

        final text = progressText(tester);
        expect(text, '$collected of $total stamps');
        // Collected comes BEFORE total — never reversed.
        expect(text.indexOf('$collected'), lessThan(text.indexOf('$total')));
      });
    }

    testWidgets('a complete passport reads "N of N stamps"', (tester) async {
      await tester.pumpWidget(card(collected: total, locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(progressText(tester), '$total of $total stamps');
    });

    testWidgets('the title is the localised passport name', (tester) async {
      await tester.pumpWidget(card(collected: 0, locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Astronomy Passport'), findsOneWidget);
    });
  });

  group('Persian semantics (RTL)', () {
    testWidgets('label is translated — no Latin "stamps" leaks through', (
      tester,
    ) async {
      await tester.pumpWidget(card(collected: 0, locale: const Locale('fa')));
      await tester.pumpAndSettle();

      final text = progressText(tester);
      expect(text.contains('stamps'), isFalse, reason: 'untranslated label');
      expect(text.contains('مهر'), isTrue, reason: 'expected the Persian label');
      // Persian digits, not Western.
      expect(RegExp(r'[0-9]').hasMatch(text), isFalse,
          reason: 'Western digits in a Persian count');
      expect(RegExp(r'[۰-۹]').hasMatch(text), isTrue);
    });

    testWidgets('collected/total keep their meaning (not reversed)', (
      tester,
    ) async {
      // 1 collected of N: the "۱" must sit before "مهر" in logical order, and
      // ۱ must not be swapped with the total.
      await tester.pumpWidget(card(collected: 1, locale: const Locale('fa')));
      await tester.pumpAndSettle();

      final l = await AonL10n.delegate.load(const Locale('fa'));
      // The rendered string is exactly the localised message — collected (۱)
      // first, total second — proving the counts are not swapped.
      expect(progressText(tester), l.passportStampProgress(1, total));
    });

    testWidgets('the card lays out RTL', (tester) async {
      await tester.pumpWidget(card(collected: 3, locale: const Locale('fa')));
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(find.byType(PassportHomeCard))),
          TextDirection.rtl);
    });
  });

  group('no overflow across scales, narrow phone, both locales', () {
    for (final locale in const [Locale('en'), Locale('fa')]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('${locale.languageCode} @ ${(scale * 100).round()}% · 320w', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 300);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            card(collected: total, locale: locale, scale: scale),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'overflow at ${locale.languageCode}/${scale}x');
        });
      }
    }
  });
}
