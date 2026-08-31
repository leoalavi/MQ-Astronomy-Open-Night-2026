import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/itinerary_service.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Timing honesty across the whole model.
///
/// ## History
///
/// Three programme entries — Exhibition Hall, Capture the cosmos and the Solar
/// system walk — originally published NO time, and the data filled the hole
/// with a 4pm–10pm stand-in, so "Capture the cosmos" sat under **Happening now**
/// for six hours off a schedule Macquarie never printed.
///
/// **Liz's 2026-08-31 update superseded that for all three:**
///  * Exhibition Hall → exact 4.15pm–10pm.
///  * Capture the cosmos → `fullEventConfirmed` ("open all night").
///  * Solar system walk → `openAllNight` (present all night, no set times).
///
/// So the real programme now has NO `timeUnpublished` entry. The model invariant
/// that a genuinely time-unpublished session never reaches the timeline is still
/// valuable, so it is exercised here with a SYNTHETIC event rather than by
/// relying on data that no longer contains one.
void main() {
  DateTime at(int h, int m) => EventInfo.at(h, m);

  final sweep = <DateTime>[
    at(15, 30), at(16, 0), at(16, 15), at(17, 0),
    at(19, 30), at(21, 45), at(22, 0), at(22, 30),
  ];

  group('the audit itself', () {
    test('the programme still has exactly 36 entries', () {
      expect(EventsData.all.length, 36);
    });

    test('Liz\'s three former-unpublished entries now carry her confirmed timing',
        () {
      final capture = EventsData.byId('capture-the-cosmos')!.sessions.single;
      expect(capture.timing, TimingConfidence.fullEventConfirmed);
      expect(capture.isFullEvent, isTrue);

      final exhibition = EventsData.byId('exhibition-hall')!.sessions.single;
      expect(exhibition.timing, TimingConfidence.exactTime);
      expect(exhibition.start, at(16, 15));
      expect(exhibition.end, at(22, 0));

      final solar = EventsData.byId('solar-system-walk')!.sessions.single;
      expect(solar.timing, TimingConfidence.openAllNight);
      expect(solar.isFullEvent, isTrue);
      // Open all night, but never a published start/finish.
      expect(solar.hasPublishedStart, isFalse);
      expect(solar.hasPublishedEnd, isFalse);
    });

    test('no real programme entry is time-unpublished any more', () {
      expect(EventsData.all.where((e) => e.isUnscheduled), isEmpty);
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

    test('exactTime always implies a published end', () {
      final loose = EventsData.all
          .expand((e) => e.sessions.map((s) => (e.id, s)))
          .where((p) => p.$2.timing == TimingConfidence.exactTime)
          .where((p) => !p.$2.hasPublishedEnd);
      expect(loose, isEmpty);
    });

    test('only Liz-confirmed activities are full-event / open-all-night', () {
      final fullEvent = EventsData.all
          .where((e) => e.sessions.any((s) => s.isFullEvent))
          .map((e) => e.id)
          .toSet();
      expect(fullEvent, {'capture-the-cosmos', 'solar-system-walk'});
    });
  });

  group('MODEL INVARIANT: a time-unpublished session never reaches a bucket', () {
    // Synthetic, because the real programme no longer contains one.
    final unpublished = AonEvent(
      id: 'synthetic-unpublished',
      title: 'Synthetic unpublished activity',
      description: '',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      sessions: [
        EventSession(
          start: at(16, 0),
          end: at(22, 0),
          timing: TimingConfidence.timeUnpublished,
        ),
      ],
    );

    test('never Happening now / Starting soon / Up next / finished — at any time',
        () {
      for (final now in sweep) {
        final t = WhatsOnService.classify(unpublished, now);
        expect(t.timing, EventTiming.unscheduled,
            reason: 'at ${now.hour}:${now.minute} it left the unscheduled bucket');
      }
    });

    test('the session refuses to answer "is it running?"', () {
      for (final now in sweep) {
        expect(unpublished.isRunningAt(now), isFalse);
        expect(unpublished.sessionAt(now), isNull);
        expect(unpublished.nextSessionAfter(now), isNull);
      }
    });
  });

  group('open-all-night activities ARE available, without inventing a schedule',
      () {
    test('Capture the cosmos is Happening now (all night), never up-next', () {
      for (final now in [at(16, 0), at(17, 0), at(19, 30), at(21, 45)]) {
        final t = WhatsOnService.classify(
            EventsData.byId('capture-the-cosmos')!, now);
        expect(t.timing, EventTiming.happeningNow,
            reason: 'open all night → live during the event');
        expect(t.isAllEvening, isTrue);
      }
    });

    test('Solar system walk is an all-night drop-in, never "starting soon"', () {
      final solar = EventsData.byId('solar-system-walk')!;
      // During the event → happening now (all night).
      expect(WhatsOnService.classify(solar, at(19, 0)).timing,
          EventTiming.happeningNow);
      // It never advertises a scheduled start.
      for (final now in sweep) {
        expect(solar.sessions.single.startsWithin(now, WhatsOnService.soonWindow),
            isFalse);
      }
    });
  });

  group('start-only entries keep the fact and drop the invention', () {
    test('they ARE happening now after their published 4.15pm start', () {
      final timed = WhatsOnService.classifyAll(EventsData.all, at(17, 0));
      final now = WhatsOnService.inBucket(timed, EventTiming.happeningNow)
          .map((t) => t.event.id);
      expect(now, contains('kids-space'));
    });

    test('a start-only entry never claims to be an all-evening drop-in', () {
      final timed = WhatsOnService.classifyAll(EventsData.all, at(17, 0));
      final bogus = timed
          .where((t) => t.session != null)
          .where((t) => t.isAllEvening && !t.session!.isFullEvent &&
              !t.session!.hasPublishedEnd);
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

  group('My Night: open-all-night activities never fake a full-evening clash',
      () {
    List<ItineraryEntry> plan(DateTime now) => ItineraryService.build(
          allEvents: EventsData.all,
          // A busy plan: two open-all-night drop-ins plus timed talks.
          savedIds: {
            'capture-the-cosmos', // fullEventConfirmed
            'solar-system-walk', // openAllNight
            'keynote-artemis', // 7.30–8.15pm
            'kids-space', // start-only
            'featured-astrophotography', // 5–5.45pm
          },
          now: now,
        );

    test('Capture the cosmos never raises a clash against a scheduled talk', () {
      for (final now in sweep) {
        final entry =
            plan(now).firstWhere((e) => e.event.id == 'capture-the-cosmos');
        expect(entry.conflictsWith, isEmpty,
            reason: 'an open-all-night drop-in blocks nothing');
      }
    });

    test('Solar system walk never raises a clash either', () {
      for (final now in sweep) {
        final entry =
            plan(now).firstWhere((e) => e.event.id == 'solar-system-walk');
        expect(entry.conflictsWith, isEmpty);
      }
    });

    test('the two real timed talks STILL clash with each other when they overlap',
        () {
      // Regression guard: relaxing conflicts for drop-ins must not switch off
      // conflict detection for genuine overlapping sessions.
      final plan2 = ItineraryService.build(
        allEvents: EventsData.all,
        // Keynote (7.30–8.15) overlaps the engineering talk (7.30–8.15).
        savedIds: {'keynote-artemis', 'featured-engineering-astronomy'},
        now: at(19, 30),
      );
      final keynote =
          plan2.firstWhere((e) => e.event.id == 'keynote-artemis');
      expect(keynote.conflictsWith, isNotEmpty,
          reason: 'two real overlapping talks must still be flagged');
    });

    test('both drop-ins still appear in the plan (saving is not dropped)', () {
      final remaining = ItineraryService.remaining(plan(at(17, 0)));
      final ids = remaining.map((e) => e.event.id);
      expect(ids, containsAll({'capture-the-cosmos', 'solar-system-walk'}));
    });
  });
}
