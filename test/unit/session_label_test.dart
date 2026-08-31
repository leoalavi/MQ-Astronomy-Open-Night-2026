import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/utils/time_format.dart';

/// A displayed session time must never fabricate a time the programme did not
/// publish.
///
/// ## The bug this file exists to prevent
///
/// Field report (Pouya, 2026-08-28): the Program's "Time not published"
/// section showed activities whose time row read "4pm – 10pm". The 4pm–10pm is
/// a bounding *stand-in* kept only so lists lay out — `TimeFormat.session`
/// printed it verbatim, so an unpublished time masqueraded as a confirmed one.
/// A [TimingConfidence.startOnly] session likewise printed a "10pm" finish the
/// programme never published.
void main() {
  final AonL10n en = AonL10nEn();
  final AonL10n fa = AonL10nFa();

  EventSession session(TimingConfidence timing) => EventSession(
        start: DateTime(2026, 9, 19, 16, 0),
        end: DateTime(2026, 9, 19, 22, 0),
        timing: timing,
      );

  group('sessionLabel is honest about what the programme published', () {
    test('no published time → "Time not published", never a range', () {
      final label = TimeFormat.sessionLabel(en, session(TimingConfidence.timeUnpublished));
      expect(label, en.timingTimeNotPublished);
      expect(label, isNot(contains('–')));
      expect(label, isNot(contains('10pm')));
      expect(label, isNot(contains('4pm')));
    });

    test('published start, no published finish → start + "finish not published"',
        () {
      // The real 4pm start is kept; the 10pm stand-in end is NOT shown.
      final label = TimeFormat.sessionLabel(en, session(TimingConfidence.startOnly));
      expect(label, contains('4pm'));
      expect(label, contains(en.timingEndNotPublished));
      expect(label, isNot(contains('10pm')),
          reason: 'the 10pm bound is a stand-in, never a published finish');
      expect(label, isNot(contains('–')),
          reason: 'a start-only session must not read as a closed range');
    });

    test('repeating cadence is treated like start-only (finish unknown)', () {
      final label = TimeFormat.sessionLabel(en, session(TimingConfidence.repeating));
      expect(label, contains(en.timingEndNotPublished));
      expect(label, isNot(contains('10pm')));
    });

    test('a fully published session still prints the real range', () {
      final label = TimeFormat.sessionLabel(en, session(TimingConfidence.exactTime));
      expect(label, '4pm – 10pm');
    });

    test('a source-confirmed full-event block reads "Open all night"', () {
      // Liz 2026-08-31: "open all night" — the label communicates availability,
      // never a scheduled 4pm–10pm range that could read as a booking.
      final label =
          TimeFormat.sessionLabel(en, session(TimingConfidence.fullEventConfirmed));
      expect(label, en.timingOpenAllEvening);
      expect(label, isNot(contains('–')));
    });

    test('an open-all-night (no set times) session reads "Open all night" too',
        () {
      final label =
          TimeFormat.sessionLabel(en, session(TimingConfidence.openAllNight));
      expect(label, en.timingOpenAllEvening);
      expect(label, isNot(contains('–')));
      expect(label, isNot(contains('4pm')));
    });

    test('the label is localised — Persian, not the English stand-in', () {
      final label = TimeFormat.sessionLabel(fa, session(TimingConfidence.timeUnpublished));
      expect(label, fa.timingTimeNotPublished);
    });
  });

  group('Liz\'s three former-unpublished activities read correctly now', () {
    test('Capture the cosmos → "Open all night" (never a fabricated range)', () {
      final e = EventsData.byId('capture-the-cosmos')!;
      final label = TimeFormat.allSessionsLabel(en, e);
      expect(label, en.timingOpenAllEvening);
      expect(label, isNot(contains('–')));
    });

    test('Solar system walk → "Open all night" (never "Time not published")', () {
      final e = EventsData.byId('solar-system-walk')!;
      final label = TimeFormat.allSessionsLabel(en, e);
      expect(label, en.timingOpenAllEvening);
      expect(label, isNot(equals(en.timingTimeNotPublished)));
    });

    test('Exhibition Hall → the real 4.15pm–10pm range', () {
      final e = EventsData.byId('exhibition-hall')!;
      final label = TimeFormat.allSessionsLabel(en, e);
      expect(label, contains('4.15pm'));
      expect(label, contains('10pm'));
    });

    test('no entry shows the contradictory "Time not published" + a range', () {
      for (final e in EventsData.all) {
        final label = TimeFormat.allSessionsLabel(en, e);
        final contradiction =
            label.contains(en.timingTimeNotPublished) && label.contains('–');
        expect(contradiction, isFalse, reason: '${e.id}: "$label"');
      }
    });
  });
}
