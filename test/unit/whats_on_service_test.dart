import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Tests for the time-dependent programme logic.
///
/// Every test pins an explicit instant. Nothing here reads the wall clock, so
/// the suite behaves identically in August 2026 and in 2030.
void main() {
  DateTime at(int hour, [int minute = 0]) => EventInfo.at(hour, minute);

  AonEvent eventWith(List<EventSession> sessions) => AonEvent(
    id: 'test',
    title: 'Test',
    description: '',
    category: EventCategory.activity,
    venueId: 'central-courtyard',
    sessions: sessions,
  );

  group('classify', () {
    test('an event running now is happeningNow', () {
      final event = eventWith([EventSession(start: at(17), end: at(18))]);

      final result = WhatsOnService.classify(event, at(17, 30));

      expect(result.timing, EventTiming.happeningNow);
      expect(result.session?.start, at(17));
    });

    test('start time is inclusive, end time is exclusive', () {
      final event = eventWith([EventSession(start: at(17), end: at(18))]);

      // Exactly at the start: running.
      expect(
        WhatsOnService.classify(event, at(17)).timing,
        EventTiming.happeningNow,
      );
      // Exactly at the end: no longer running. A half-open interval is what
      // stops back-to-back sessions both claiming the same instant.
      expect(
        WhatsOnService.classify(event, at(18)).timing,
        isNot(EventTiming.happeningNow),
      );
    });

    test('an event starting inside the soon window is startingSoon', () {
      final event = eventWith([EventSession(start: at(18), end: at(19))]);

      expect(
        WhatsOnService.classify(event, at(17, 45)).timing,
        EventTiming.startingSoon,
      );
    });

    test('an event starting beyond the soon window is upcoming', () {
      final event = eventWith([EventSession(start: at(20), end: at(21))]);

      expect(
        WhatsOnService.classify(event, at(17)).timing,
        EventTiming.upcoming,
      );
    });

    test('the soon window boundary is inclusive', () {
      final event = eventWith([EventSession(start: at(18), end: at(19))]);

      // Exactly 30 minutes before: still "soon".
      expect(
        WhatsOnService.classify(event, at(17, 30)).timing,
        EventTiming.startingSoon,
      );
      // One minute earlier: not yet.
      expect(
        WhatsOnService.classify(event, at(17, 29)).timing,
        EventTiming.upcoming,
      );
    });

    test('an event with no remaining sessions is finished', () {
      final event = eventWith([EventSession(start: at(17), end: at(18))]);

      final result = WhatsOnService.classify(event, at(21));

      expect(result.timing, EventTiming.finished);
      expect(result.session, isNull);
    });
  });

  group('multi-session events', () {
    // The Physics magic show is the real case: 5-5.45, 6.15-7, 8.45-9.30.
    final magicShow = eventWith([
      EventSession(start: at(17), end: at(17, 45)),
      EventSession(start: at(18, 15), end: at(19)),
      EventSession(start: at(20, 45), end: at(21, 30)),
    ]);

    test('is happeningNow during any session', () {
      for (final t in [at(17, 10), at(18, 30), at(21)]) {
        expect(
          WhatsOnService.classify(magicShow, t).timing,
          EventTiming.happeningNow,
          reason: 'should be running at $t',
        );
      }
    });

    test('reports the correct session in the gap between runs', () {
      // 8pm: the 6.15 run has ended, the 8.45 run has not started.
      final result = WhatsOnService.classify(magicShow, at(20));

      expect(result.timing, EventTiming.upcoming);
      expect(result.session?.start, at(20, 45));
    });

    test('appears exactly once, never once per session', () {
      final classified = WhatsOnService.classifyAll([magicShow], at(17, 10));
      expect(classified, hasLength(1));
    });
  });

  group('inBucket sorting', () {
    test('happeningNow sorts by end time, soonest-ending first', () {
      final endsLate = AonEvent(
        id: 'late',
        title: 'Late',
        description: '',
        category: EventCategory.activity,
        venueId: 'central-courtyard',
        sessions: [EventSession(start: at(17), end: at(21))],
      );
      final endsSoon = AonEvent(
        id: 'soon',
        title: 'Soon',
        description: '',
        category: EventCategory.activity,
        venueId: 'central-courtyard',
        sessions: [EventSession(start: at(17), end: at(18))],
      );

      final bucket = WhatsOnService.inBucket(
        WhatsOnService.classifyAll([endsLate, endsSoon], at(17, 30)),
        EventTiming.happeningNow,
      );

      expect(
        bucket.map((t) => t.event.id),
        ['soon', 'late'],
        reason: 'the thing about to end should be surfaced first',
      );
    });

    test('upcoming sorts by start time', () {
      final classified = WhatsOnService.classifyAll(EventsData.all, at(16, 0));
      final upcoming = WhatsOnService.inBucket(
        classified,
        EventTiming.upcoming,
      );

      for (var i = 1; i < upcoming.length; i++) {
        expect(
          upcoming[i].session!.start.isBefore(upcoming[i - 1].session!.start),
          isFalse,
          reason: 'upcoming must be in ascending start order',
        );
      }
    });
  });

  group('all-evening drop-ins', () {
    test('a six-hour activity is flagged as all-evening', () {
      final exhibition = eventWith([EventSession(start: at(16), end: at(22))]);

      final result = WhatsOnService.classify(exhibition, at(18));
      expect(result.isAllEvening, isTrue);
    });

    test('a 30-minute talk is not', () {
      final talk = eventWith([EventSession(start: at(18), end: at(18, 30))]);

      final result = WhatsOnService.classify(talk, at(18, 10));
      expect(result.isAllEvening, isFalse);
    });
  });

  group('against the real programme', () {
    test('the keynote is running at 7.45pm', () {
      final keynote = EventsData.byId('keynote-artemis')!;
      expect(
        WhatsOnService.classify(keynote, at(19, 45)).timing,
        EventTiming.happeningNow,
      );
    });

    test('nothing is happening before the event opens', () {
      final classified = WhatsOnService.classifyAll(EventsData.all, at(12, 0));
      final running = WhatsOnService.inBucket(
        classified,
        EventTiming.happeningNow,
      );

      expect(running, isEmpty);
    });

    test('everything is finished after the event closes', () {
      final classified = WhatsOnService.classifyAll(EventsData.all, at(23, 0));

      expect(classified.every((t) => t.timing == EventTiming.finished), isTrue);
    });

    test('something is on at every half hour of the event', () {
      // A smoke test over the whole evening. If any half-hour slot has
      // nothing running, either the data is wrong or the programme genuinely
      // has a gap worth telling the organisers about.
      for (var h = 16; h < 22; h++) {
        for (final m in [0, 30]) {
          final classified = WhatsOnService.classifyAll(
            EventsData.all,
            at(h, m),
          );
          final running = WhatsOnService.inBucket(
            classified,
            EventTiming.happeningNow,
          );
          expect(running, isNotEmpty, reason: 'nothing running at ${at(h, m)}');
        }
      }
    });
  });
}
