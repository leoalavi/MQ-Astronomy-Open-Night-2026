import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/utils/time_format.dart';

/// Event Detail, examined in Persian.
///
/// ## The bugs this file exists to prevent
///
/// Found on an iPhone 17 Pro on the Event Detail page in Persian:
///
/// * The **Save** button still read "Save"/"Saved" in English — the only
///   hardcoded control label left after the Settings language picker shipped.
///   `SaveButton.labelled` interpolated the literals instead of `l.actionSave` /
///   `l.actionSaved`.
///
/// * The English **description** and **placeholder-time note** rendered with
///   their trailing full stop on the wrong end (".award", ".full event"), and
///   the **venue name** — "17 Wally's Walk" — rendered as "Wally's Walk 17".
///   All three are English data in an RTL paragraph and needed `Bidi.isolate`.
void main() {
  /// An event with a description, a numbered venue, and a placeholder time.
  final event = EventsData.all.firstWhere(
    (e) =>
        e.description.isNotEmpty && e.sessions.isNotEmpty,
  );

  Widget app(String id, {required Locale locale}) {
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
        home: EventDetailScreen(eventId: id),
      ),
    );
  }

  Iterable<String> visibleStrings(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>();

  group('the Save control is localised', () {
    testWidgets('Persian shows a translated save label, not "Save"', (
      tester,
    ) async {
      await tester.pumpWidget(app(event.id, locale: const Locale('fa')));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      // The localised label is present.
      final fa = lookupAonL10n(const Locale('fa'));
      expect(find.text(fa.actionSave), findsWidgets);
    });

    testWidgets('English still shows "Save"', (tester) async {
      await tester.pumpWidget(app(event.id, locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsWidgets);
    });
  });

  group('English data keeps its shape in RTL', () {
    testWidgets('no English sentence has a leading orphaned full stop', (
      tester,
    ) async {
      await tester.pumpWidget(app(event.id, locale: const Locale('fa')));
      await tester.pumpAndSettle();

      // A sentence rendered with the isolate keeps its stop at the end of the
      // string; the failure mode left a bare unisolated Latin sentence.
      const fsi = '\u2068';
      final unisolatedEnglish = visibleStrings(tester).where((s) {
        final looksEnglish =
            RegExp('^[\\x00-\\x7F\u2068\u2069\\s\u2014\u2019\u201c\u201d]+\$')
                .hasMatch(s);
        final isSentence = s.trimRight().endsWith('.') && s.contains(' ');
        return looksEnglish && isSentence && !s.contains(fsi);
      }).toList();
      expect(unisolatedEnglish, isEmpty,
          reason: 'unisolated English sentences in RTL: $unisolatedEnglish');
    });

    testWidgets('a numbered venue name is not rendered number-last', (
      tester,
    ) async {
      await tester.pumpWidget(app(event.id, locale: const Locale('fa')));
      await tester.pumpAndSettle();

      // The raw reversed form the venue "17 Wally's Walk" took on device.
      final reversed = visibleStrings(tester).where(
        (s) => RegExp('Walk\\s+\\d+\u2069?\$').hasMatch(s),
      );
      expect(reversed, isEmpty, reason: 'venue name rendered number-last');
    });
  });
}
