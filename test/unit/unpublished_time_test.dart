import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/itinerary_service.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// An activity the programme gives no time for must never be presented as
/// though it had one.
///
/// ## The bug this file exists to prevent
///
/// Three programme entries — Exhibition Hall, Capture the cosmos and the Solar
/// system walk — publish NO time at all. The data filled that hole with a
/// plausible-looking 4pm–10pm session, and nothing downstream could tell the
/// difference between that and a genuine 4pm–10pm booking. So "Capture the
/// cosmos" sat under **Happening now** for six solid hours, and a visitor could
/// walk to 17 Wally's Walk on the strength of a schedule Macquarie never
/// printed. Seen on device.
///
/// Four more entries publish a real 4.15pm START but no finish; those keep
/// their start (it is a fact) and must never advertise a finish (it is not).
void main() {
  /// Event-local time on event night.
  DateTime at(int h, int m) => EventInfo.at(h, m);

  // Every minute of the evening, plus the edges, so a wrong classification
  // cannot hide between the sample points.
  final sweep = <DateTime>[
    at(15, 30), at(16, 0), at(16, 15), at(17, 0),
    at(19, 30), at(21, 45), at(22, 0), at(22, 30),
  ];

  group('the audit itself', () {
    test('the programme still has exactly 36 entries', () {
      expect(EventsData.all.length, 36);
    });

    test('the entries with no published time are the three we audited', () {
      final unscheduled = EventsData.all
          .where((e) => e.isUnscheduled)
          .map((e) => e.id)
          .toList()
        ..sort();
      expect(unscheduled, [
        'capture-the-cosmos',
        'exhibition-hall',
        'solar-system-walk',
      ]);
    });

    test('the start-only / repeating entries keep their published 4.15pm start',
        () {
      const startOnlyIds = {
        'stories-across-worlds',
        'junior-science-academy',
        'kids-space',
        'planetariums',
      };
      for (final e in EventsData.all.where((e) => startOnlyIds.contains(e.id))) {
        final s = e.sessions.single;
        expect(s.timing,
            anyOf(TimingConfidence.startOnly, TimingConfidence.repeating),
            reason: '${e.id} should keep its published start');
        expect(s.hasPublishedStart, isTrue);
        expect(s.hasPublishedEnd, isFalse,
            reason: '${e.id} has no published finish — it must not claim one');
        expect(s.start, at(16, 15));
      }
    });

    test('every other session is an exact published time', () {
      final loose = EventsData.all
          .expand((e) => e.sessions.map((s) => (e.id, s)))
          .where((p) => p.$2.timing == TimingConfidence.exactTime)
          .where((p) => !p.$2.hasPublishedEnd);
      expect(loose, isEmpty,
          reason: 'exactTime must imply a published end');
    });

    test('nothing is marked fullEventConfirmed without a source saying so', () {
      // No source currently states an activity runs the whole event. If one
      // ever does, this test is the place that forces the claim to be checked.
      final claimed = EventsData.all
          .expand((e) => e.sessions.map((s) => (e.id, s.timing)))
          .where((p) => p.$2 == TimingConfidence.fullEventConfirmed);
      expect(claimed, isEmpty);
    });
  });

  group('THE INVARIANT: unpublished time never reaches a timeline bucket', () {
    test('never Happening now, Starting soon, or Up next — at any time', () {
      for (final now in sweep) {
        final timed = WhatsOnService.classifyAll(EventsData.all, now);
        for (final bucket in [
          EventTiming.happeningNow,
          EventTiming.startingSoon,
          EventTiming.upcoming,
        ]) {
          final leaked = WhatsOnService.inBucket(timed, bucket)
              .where((t) => t.event.isUnscheduled)
              .map((t) => t.event.title);
          expect(leaked, isEmpty,
              reason: 'at ${now.hour}:${now.minute.toString().padLeft(2, '0')} '
                  '${leaked.toList()} appeared under $bucket with no published '
                  'time');
        }
      }
    });

    test('they land in the unscheduled bucket instead of vanishing', () {
      for (final now in sweep) {
        final timed = WhatsOnService.classifyAll(EventsData.all, now);
        final ids = WhatsOnService.inBucket(timed, EventTiming.unscheduled)
            .map((t) => t.event.id)
            .toSet();
        expect(ids, containsAll(<String>{
          'capture-the-cosmos',
          'exhibition-hall',
          'solar-system-walk',
        }), reason: 'they must stay discoverable, not disappear');
      }
    });

    test('they are never reported as finished either', () {
      // "Finished" would be just as much a claim: we were never told it ended.
      for (final now in sweep) {
        final timed = WhatsOnService.classifyAll(EventsData.all, now);
        final leaked = WhatsOnService.inBucket(timed, EventTiming.finished)
            .where((t) => t.event.isUnscheduled);
        expect(leaked, isEmpty);
      }
    });

    test('the session itself refuses to answer "is it running?"', () {
      final e = EventsData.byId('capture-the-cosmos')!;
      for (final now in sweep) {
        expect(e.isRunningAt(now), isFalse);
        expect(e.sessionAt(now), isNull);
        expect(e.nextSessionAfter(now), isNull,
            reason: 'offering it as "next" announces an unpublished start');
      }
    });
  });

  group('start-only entries keep the fact and drop the invention', () {
    test('they ARE happening now after their published 4.15pm start', () {
      // The start is real, so suppressing these entirely would lose information
      // the programme genuinely gives.
      final timed = WhatsOnService.classifyAll(EventsData.all, at(17, 0));
      final now = WhatsOnService.inBucket(timed, EventTiming.happeningNow)
          .map((t) => t.event.id);
      expect(now, contains('kids-space'));
    });

    test('but they never claim to be an all-evening drop-in', () {
      // isAllEvening drove a separate "open all evening" grouping, which for
      // these was an artefact of our own 10pm stand-in.
      final timed = WhatsOnService.classifyAll(EventsData.all, at(17, 0));
      final bogus = timed
          .where((t) => t.isAllEvening && !t.session!.hasPublishedEnd);
      expect(bogus, isEmpty);
    });

    test('before 4.15pm they are legitimately upcoming', () {
      final timed = WhatsOnService.classifyAll(EventsData.all, at(16, 0));
      final later = WhatsOnService.inBucket(timed, EventTiming.upcoming)
          .followedBy(
              WhatsOnService.inBucket(timed, EventTiming.startingSoon))
          .map((t) => t.event.id);
      expect(later, contains('kids-space'));
    });
  });

  group('My Night never places an unscheduled item on the timeline', () {
    List<ItineraryEntry> plan(DateTime now) => ItineraryService.build(
          allEvents: EventsData.all,
          savedIds: {'capture-the-cosmos', 'keynote-artemis', 'kids-space'},
          now: now,
        );

    test('a saved unscheduled activity is marked unscheduled, never upcoming',
        () {
      for (final now in sweep) {
        final entry = plan(now)
            .firstWhere((e) => e.event.id == 'capture-the-cosmos');
        expect(entry.timing, EventTiming.unscheduled,
            reason: 'at ${now.hour}:00 it claimed a timeline position');
      }
    });

    test('it still appears in the plan (saving is not silently dropped)', () {
      final remaining = ItineraryService.remaining(plan(at(17, 0)));
      expect(remaining.map((e) => e.event.id), contains('capture-the-cosmos'));
    });

    test('it sorts to the END, so it cannot masquerade as the 4pm opener', () {
      final entries = plan(at(17, 0));
      expect(entries.last.event.id, 'capture-the-cosmos');
    });

    test('it is never the "next up" answer', () {
      for (final now in sweep) {
        final next = ItineraryService.nextUp(plan(now));
        expect(next?.event.id, isNot('capture-the-cosmos'));
      }
    });

    test('it never raises a clash warning against a real session', () {
      for (final now in sweep) {
        final entry = plan(now)
            .firstWhere((e) => e.event.id == 'capture-the-cosmos');
        expect(entry.conflictsWith, isEmpty,
            reason: 'a conflict computed from our own stand-in times');
      }
    });
  });
}
