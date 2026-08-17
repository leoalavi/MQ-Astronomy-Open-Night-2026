import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/utils/bidi.dart';

/// English data sentences must keep their punctuation in a Persian layout.
///
/// ## The bug this file exists to prevent
///
/// Found on an iPhone 17 Pro with the app in Persian. Venue and car-park notes
/// are English free text held in `venues_data.dart` — they are data, not UI copy,
/// so they are never translated. Rendered raw inside an RTL paragraph they came
/// out as:
///
///     ask at any information point .in the Central Courtyard
///     Building-level location. Follow signage .inside
///
/// A full stop is a bidi-*neutral* character, so with no isolate around it the
/// Unicode algorithm resolves it against the paragraph — RTL — and places it at
/// the left end of the line. The sentence reads as though it were corrupted.
///
/// `Bidi.isolate` wraps the run in FSI/PDI so it resolves as its own LTR island
/// while the surrounding page stays RTL. That keeps the stop attached to the
/// sentence *and* keeps the block right-aligned with the rest of the Persian.
///
/// Only free-text sentences are isolated. Titles and venue names are single runs
/// with no punctuation at either boundary, so they never drifted, and isolating
/// them would bury invisible control characters in every `find.text` in the
/// suite for no benefit.
void main() {
  Widget app({required Locale locale}) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
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
        home: const InfoScreen(),
      ),
    );
  }

  /// Every rendered string on screen.
  Iterable<String> visibleStrings(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>();

  group('free-text notes are bidi-isolated', () {
    test('the fixtures really do contain sentences ending in a full stop', () {
      // If the data ever stopped ending in punctuation this suite would pass
      // vacuously, so assert the precondition rather than assume it.
      final sentences = [
        ...VenuesData.all.map((v) => v.notes),
        ...ParkingData.all.map((p) => p.notes),
      ].whereType<String>().where((n) => n.trimRight().endsWith('.'));

      expect(
        sentences,
        isNotEmpty,
        reason: 'no note ends in a full stop, so the drift cannot be exercised',
      );
    });

    testWidgets('in Persian, every note that ends in a stop is isolated', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: const Locale('fa')));
      await tester.pumpAndSettle();

      // Escapes, not literals: an invisible control character in source is the
      // very hazard the analyzer's text_direction_code_point_in_literal warns
      // about, and it would make this file unreviewable in a diff.
      const fsi = '\u2068';
      const pdi = '\u2069';

      final unisolatedSentences = visibleStrings(tester).where((s) {
        final isSentence = s.trimRight().endsWith('.') && s.contains(' ');
        // Persian copy from the ARB is fine as-is; only English data needs the
        // isolate. A rough but reliable test for Latin script:
        final isEnglish =
            RegExp('^[\\x00-\\x7F\u2068\u2069\\s\u2014\u2019\u201c\u201d]+\$')
                .hasMatch(s);
        return isSentence && isEnglish && !s.contains(fsi);
      }).toList();

      expect(
        unisolatedSentences,
        isEmpty,
        reason: 'these English sentences will render with the full stop on the '
            'wrong end in an RTL layout: $unisolatedSentences',
      );

      // And confirm the isolate is genuinely present on at least one of them,
      // so a change that dropped isolation everywhere could not pass.
      expect(
        visibleStrings(tester).where((s) => s.contains(fsi) && s.contains(pdi)),
        isNotEmpty,
      );
    });

    testWidgets('isolation is applied in English too, harmlessly', (
      tester,
    ) async {
      // Bidi.isolate is direction-agnostic by design: in an LTR locale FSI/PDI
      // are no-ops, so call sites never have to branch on the current language.
      await tester.pumpWidget(app(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        visibleStrings(tester).where((s) => s.contains('\u2068')),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('venue labels that begin with a street number', () {
    // ## The second half of the same bug class
    //
    // Observed on device with the app in Persian: the Home rail showed
    // "Wally's Walk 17" for the venue "17 Wally's Walk". Digits are European
    // Numbers in the bidi algorithm and take the paragraph's embedding level, so
    // in an RTL line a leading street number is carried to the far end of the
    // run. Campus addresses are almost all of this shape — "1 Central
    // Courtyard", "14 Sir Christopher Ondaatje Avenue" — so the reversal hit
    // most cards, and it is the exact failure bidi.dart's own doc comment
    // predicts.
    test('the fixtures really do contain leading-number labels', () {
      final numbered = VenuesData.all
          .map((v) => v.chipLabel)
          .where((label) => RegExp(r'^\d').hasMatch(label));
      expect(numbered, isNotEmpty,
          reason: 'no venue label starts with a number, so the reversal cannot '
              'be exercised');
    });

    testWidgets('leading-number venue labels are isolated on the Info screen', (
      tester,
    ) async {
      await tester.pumpWidget(app(locale: const Locale('fa')));
      await tester.pumpAndSettle();

      final numberLed = visibleStrings(tester).where(
        (s) => RegExp(r'^\d').hasMatch(s) && s.contains(' '),
      );
      expect(
        numberLed,
        isEmpty,
        reason: 'these labels start with a bare number and will have it moved '
            'to the wrong end in RTL: ${numberLed.toList()}',
      );
    });

    test('a numbered label survives isolation intact', () {
      // Screen-independent non-vacuity: the Info screen happens not to render a
      // label that *starts* with a digit, so asserting on its output would only
      // prove the screen's content, not the mechanism.
      const label = '17 Wally\u2019s Walk';
      expect(Bidi.isolate(label), '\u2068$label\u2069');
      // The number must stay at the front inside the isolate — that is the whole
      // point; the isolate stops the paragraph from relocating it.
      expect(Bidi.isolate(label).substring(1).startsWith('17'), isTrue);
    });
  });

  group('Bidi.isolate itself', () {
    test('wraps a sentence so the trailing stop stays inside the run', () {
      const note = 'Building-level location. Follow signage inside.';
      final isolated = Bidi.isolate(note);

      expect(isolated.startsWith('\u2068'), isTrue);
      expect(isolated.endsWith('\u2069'), isTrue);
      // The stop must be *within* the isolate, not outside it — outside, the
      // paragraph direction would move it again.
      expect(isolated, '\u2068$note\u2069');
    });

    test('an empty or null note yields nothing, not a pair of control chars', () {
      // A bare FSI+PDI would render as an invisible non-empty string, which
      // defeats `if (notes != null)` guards at the call sites.
      expect(Bidi.isolate(null), '');
      expect(Bidi.isolate(''), '');
    });
  });
}
