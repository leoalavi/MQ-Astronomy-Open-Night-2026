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

    test('a source-confirmed full-event block prints its real range', () {
      final label =
          TimeFormat.sessionLabel(en, session(TimingConfidence.fullEventConfirmed));
      expect(label, '4pm – 10pm');
    });

    test('the label is localised — Persian, not the English stand-in', () {
      final label = TimeFormat.sessionLabel(fa, session(TimingConfidence.timeUnpublished));
      expect(label, fa.timingTimeNotPublished);
    });
  });

  group('the three audited unpublished activities never show 4pm–10pm', () {
    final unscheduled = EventsData.all.where((e) => e.isUnscheduled).toList();

    test('there are exactly the three we audited', () {
      expect(unscheduled.map((e) => e.id).toList()..sort(),
          ['capture-the-cosmos', 'exhibition-hall', 'solar-system-walk']);
    });

    for (final e in EventsData.all.where((e) => e.isUnscheduled)) {
      test('${e.id}: allSessionsLabel is "Time not published"', () {
        final label = TimeFormat.allSessionsLabel(en, e);
        expect(label, en.timingTimeNotPublished);
        expect(label, isNot(contains('4pm')));
        expect(label, isNot(contains('10pm')));
      });
    }
  });
}
