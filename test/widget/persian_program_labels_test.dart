import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/timing_labels.dart';

/// Three defects found by looking at the Persian Program screen on a simulator.
///
/// 1. **Reversed time ranges.** `TimeBand.label` was a hardcoded "4–6pm". A
///    numeral–dash–numeral run followed by a Latin "pm" is the classic shape the
///    bidi algorithm reorders inside an RTL line, so the three chips rendered as
///    "6pm–4", "8pm–6", "10pm–8" — every one reversed, and a visitor filtering
///    by time was reading a range that did not exist.
///
/// 2. **Untranslated section names.** `EventCategory.label` was hardcoded
///    English, so a fully Persian screen still said "Activities" above every
///    card and as the Event Detail app-bar title.
///
/// 3. **Mixed digit systems.** Persian uses Extended Arabic-Indic digits, and
///    the count pills interpolated a raw int. "36 برنامه" sat directly above
///    times reading "۴ب.ظ.".
void main() {
  Widget app({required Locale locale}) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
    });
    TimeFormat.locale = locale.languageCode;
    addTearDown(() => TimeFormat.locale = 'en');
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        locale: locale,
        theme: AonTheme.build(),
        home: const ProgramScreen(),
      ),
    );
  }

  Iterable<String> visibleStrings(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>();

  group('time-band chips', () {
    testWidgets('no chip carries a reversible mixed-direction range in Persian',
        (tester) async {
      await tester.pumpWidget(app(locale: const Locale('fa')));
      await tester.pumpAndSettle();

      // The exact reversed strings observed on device.
      for (final wrong in ['6pm–4', '8pm–6', '10pm–8']) {
        expect(find.text(wrong), findsNothing, reason: 'reversed range: $wrong');
      }
      // And the English source strings must not be on screen at all.
      for (final english in ['4–6pm', '6–8pm', '8–10pm']) {
        expect(find.text(english), findsNothing);
      }
    });

    testWidgets('the English chips are still correct in English', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('4–6pm'), findsOneWidget);
      expect(find.text('6–8pm'), findsOneWidget);
      expect(find.text('8–10pm'), findsOneWidget);
    });

    test('every band has a Persian label with no Latin letters', () {
      // A Latin run is what allowed the reordering, so the Persian label must
      // not reintroduce one.
      final fa = lookupAonL10n(const Locale('fa'));
      for (final band in TimeBand.values) {
        final label = band.labelOf(fa);
        expect(
          RegExp(r'[A-Za-z]').hasMatch(label),
          isFalse,
          reason: '$band still contains Latin text: "$label"',
        );
      }
    });
  });

  group('programme section names', () {
    test('every category has a genuinely Persian label', () {
      final fa = lookupAonL10n(const Locale('fa'));
      final en = lookupAonL10n(const Locale('en'));
      for (final category in EventCategory.values) {
        expect(
          category.labelOf(fa),
          isNot(category.labelOf(en)),
          reason: '$category is untranslated',
        );
        expect(RegExp(r'[A-Za-z]').hasMatch(category.labelOf(fa)), isFalse);
      }
    });

    testWidgets('the Persian screen never shows an English section name', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: const Locale('fa')));
      await tester.pumpAndSettle();
      for (final category in EventCategory.values) {
        expect(
          find.text(category.label),
          findsNothing,
          reason: '"${category.label}" leaked onto the Persian screen',
        );
      }
    });
  });

  group('digits follow the locale', () {
    testWidgets('Persian counts use Persian digits', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('fa')));
      await tester.pumpAndSettle();

      // Any string that is a count should not carry Western digits while the
      // rest of the screen is in Persian numerals.
      final westernDigitCounts = visibleStrings(tester)
          .where((s) => s.contains('برنامه') && RegExp(r'[0-9]').hasMatch(s))
          .toList();
      expect(
        westernDigitCounts,
        isEmpty,
        reason: 'Western digits in a Persian count: $westernDigitCounts',
      );
    });

    test('TimeFormat.count localises', () {
      TimeFormat.locale = 'fa';
      addTearDown(() => TimeFormat.locale = 'en');
      final persian = TimeFormat.count(36);
      expect(RegExp(r'[0-9]').hasMatch(persian), isFalse,
          reason: 'expected Persian digits, got "$persian"');

      TimeFormat.locale = 'en';
      expect(TimeFormat.count(36), '36');
    });
  });
}
