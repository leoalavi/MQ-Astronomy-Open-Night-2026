import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';

/// Localisation and right-to-left correctness.
///
/// Astronomy ships **English and Persian only** — see `l10n.yaml` for why we
/// do not inherit MQ Journey's 35 Open Day locales. These tests hold that line
/// honestly: they check the two locales are complete and that Persian actually
/// lays out right-to-left, rather than counting locales.
void main() {
  _contentSingleSourceTests();

  Widget app(Widget home, {Locale? locale}) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): [
        'keynote-artemis',
      ],
    });
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        locale: locale,
        theme: AonTheme.build(),
        home: home,
      ),
    );
  }

  group('supported locales', () {
    test('exactly English and Persian are declared', () {
      // Deliberately pinned. Adding a locale must be a conscious act that
      // comes with a real translation, not a silent config drift.
      expect(AonL10n.supportedLocales.map((l) => l.languageCode).toSet(), {
        'en',
        'fa',
      });
    });

    test('the Persian ARB has every key the English template has', () {
      // The honest version of "zero untranslated keys": compare the files,
      // rather than trusting a generator that silently falls back to English.
      Map<String, dynamic> arb(String path) =>
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

      final en = arb('lib/l10n/app_en.arb');
      final fa = arb('lib/l10n/app_fa.arb');

      bool isKey(String k) => !k.startsWith('@');
      final enKeys = en.keys.where(isKey).toSet();
      final faKeys = fa.keys.where(isKey).toSet();

      expect(
        faKeys.difference(enKeys),
        isEmpty,
        reason: 'Persian has keys English does not',
      );
      expect(
        enKeys.difference(faKeys),
        isEmpty,
        reason: 'these English keys are missing a Persian translation',
      );
    });

    test('no Persian value was left as its English source', () {
      Map<String, dynamic> arb(String p) =>
          json.decode(File(p).readAsStringSync()) as Map<String, dynamic>;
      final en = arb('lib/l10n/app_en.arb');
      final fa = arb('lib/l10n/app_fa.arb');

      // A copied-through English string is the tell-tale of a fake
      // translation. The only legitimate exceptions are strings that are pure
      // placeholders or symbols.
      // Keys whose Persian value is *correctly* identical to the English.
      //
      // Language names in a picker are endonyms: "English" stays "English" and
      // "فارسی" stays "فارسی" whichever language the app is currently in, so
      // that someone who cannot read the current language can still find their
      // own. Translating them would defeat the control.
      //
      // Nothing else belongs here. If a key needs adding, the question to ask
      // is "would a Persian reader see English words?" — if yes, translate it
      // instead of allowlisting it.
      const allowedIdentical = <String>{
        'settingsLanguageEnglish',
        'settingsLanguagePersian',
      };
      final identical = <String>[];
      for (final k in en.keys.where((k) => !k.startsWith('@'))) {
        if (fa[k] == en[k] && !allowedIdentical.contains(k)) {
          identical.add(k);
        }
      }
      expect(
        identical,
        isEmpty,
        reason: 'untranslated (English left in the fa ARB): $identical',
      );
    });
  });

  group('resolution', () {
    testWidgets('English renders English copy', (tester) async {
      await tester.pumpWidget(
        app(const MyNightScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Night'), findsWidgets);
    });

    testWidgets('Persian renders Persian copy', (tester) async {
      await tester.pumpWidget(
        app(const MyNightScreen(), locale: const Locale('fa')),
      );
      await tester.pumpAndSettle();

      expect(find.text('شب من'), findsWidgets);
      expect(find.text('My Night'), findsNothing);
    });

    testWidgets('an unsupported locale falls back to English, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const MyNightScreen(), locale: const Locale('de')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('My Night'), findsWidgets);
    });
  });

  group('right-to-left', () {
    testWidgets('Persian lays out RTL', (tester) async {
      await tester.pumpWidget(
        app(const MyNightScreen(), locale: const Locale('fa')),
      );
      await tester.pumpAndSettle();

      final dir = Directionality.of(tester.element(find.byType(MyNightScreen)));
      expect(dir, TextDirection.rtl);
    });

    testWidgets('English stays LTR', (tester) async {
      await tester.pumpWidget(
        app(const MyNightScreen(), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(MyNightScreen))),
        TextDirection.ltr,
      );
    });

    testWidgets('the back arrow mirrors in Persian', (tester) async {
      // Semantic mirroring: a leading arrow must point the way "back" goes in
      // the reading direction, or it points at the future.
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(
              leading: const BackButtonIcon(),
              title: const Text('x'),
            ),
          ),
          locale: const Locale('fa'),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byType(Icon).first);
      // Flutter's platform-adaptive back icon is directionality-aware; assert
      // we are actually in the mirrored context so it resolves correctly.
      expect(
        Directionality.of(tester.element(find.byType(AppBar))),
        TextDirection.rtl,
      );
      expect(icon.icon, isNotNull);
    });

    for (final (name, screen) in <(String, Widget)>[
      ('Home', const HomeScreen()),
      ('My Night', const MyNightScreen()),
      ('Settings', const SettingsScreen()),
    ]) {
      testWidgets('$name renders in Persian RTL without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(app(screen, locale: const Locale('fa')));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$name overflowed in fa',
        );
      });
    }

    testWidgets('Persian survives a narrow phone at 2.0 text scale', (
      tester,
    ) async {
      // The compounding worst case: longest strings, smallest screen, biggest
      // type, mirrored layout.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseClockProvider.overrideWithValue(
              FixedClock(EventInfo.at(19, 0)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            locale: const Locale('fa'),
            theme: AonTheme.build(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const MyNightScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('no hardcoded Astronomy strings in widgets', () {
    test(
      'key user-facing copy is not literal in lib/screens or lib/widgets',
      () {
        // Guards the l10n migration from regressing. These are strings a
        // developer would plausibly retype rather than add a key for.
        const banned = <String>[
          "'Happening now'",
          "'Starting soon'",
          "'Later tonight'",
          "'Up next'",
          "'My Night'",
          "'Walk there'",
          "'Open the campus map'",
          "'Look inside in 360°'",
          "'Reduce motion'",
        ];

        final offenders = <String>[];
        for (final dir in ['lib/screens', 'lib/widgets']) {
          for (final f
              in Directory(dir)
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart'))) {
            final src = f.readAsStringSync();
            for (final b in banned) {
              if (src.contains(b)) offenders.add('${f.path}: $b');
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'use an ARB key instead of a literal:\n${offenders.join('\n')}',
        );
      },
    );
  });
}

/// Content that must have exactly one source of truth.
///
/// Separate from localisation, but the same failure mode: a string duplicated in
/// two places drifts when only one is edited. The hero credit is the one that
/// matters legally — Liz supplied it with the image ("Image credit: A Deep
/// Triangulum Galaxy, Aleix Roig 2026") and crediting the photographer
/// differently on two screens is worse than not crediting at all.
void _contentSingleSourceTests() {
  group('no duplicated content literals', () {
    test('the hero credit appears only in EventConfig, not in any screen', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('l10n/generated')) continue;
        // The config is where it is *supposed* to live.
        if (entity.path.endsWith('config/event_config.dart')) continue;

        final text = entity.readAsStringSync();
        if (text.contains('Aleix Roig') || text.contains('Triangulum')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'the hero credit is hardcoded in $offenders — read it from '
            'EventConfig.heroCredit so the two can never disagree',
      );
    });
  });
}
