import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/itinerary_service.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// "My Night" timeline logic.
///
/// Pure functions over an injected `now`, so every assertion pins an instant —
/// the same discipline as [WhatsOnService], for the same reason.
void main() {
  DateTime at(int h, [int m = 0]) => EventInfo.at(h, m);

  AonEvent event(String id, String title, List<EventSession> sessions) =>
      AonEvent(
        id: id,
        title: title,
        description: '',
        category: EventCategory.activity,
        venueId: 'central-courtyard',
        sessions: sessions,
      );

  group('build', () {
    test('only includes saved events', () {
      final a = event('a', 'A', [EventSession(start: at(17), end: at(18))]);
      final b = event('b', 'B', [EventSession(start: at(19), end: at(20))]);

      final entries = ItineraryService.build(
        allEvents: [a, b],
        savedIds: {'a'},
        now: at(16),
      );

      expect(entries, hasLength(1));
      expect(entries.single.event.id, 'a');
    });

    test('is empty when nothing is saved', () {
      expect(
        ItineraryService.build(
          allEvents: EventsData.all,
          savedIds: const {},
          now: at(19),
        ),
        isEmpty,
      );
    });

    test('ignores saved ids that no longer exist in the programme', () {
      // The real case: a saved activity is later cancelled and removed from
      // the data. It must vanish quietly, not crash the timeline.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'huntsman-exploratorium', 'keynote-artemis'},
        now: at(19),
      );

      expect(entries, hasLength(1));
      expect(entries.single.event.id, 'keynote-artemis');
    });

    test('sorts chronologically', () {
      final late_ = event('l', 'Late', [
        EventSession(start: at(21), end: at(21, 30)),
      ]);
      final early = event('e', 'Early', [
        EventSession(start: at(17), end: at(17, 30)),
      ]);

      final entries = ItineraryService.build(
        allEvents: [late_, early],
        savedIds: {'l', 'e'},
        now: at(16),
      );

      expect(entries.map((e) => e.event.id), ['e', 'l']);
    });

    test('emits one entry per session, tagged N of M', () {
      // The Physics magic show runs three times. A timeline that showed it
      // once would have to guess which session the visitor means.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'physics-magic-show'},
        now: at(16),
      );

      expect(entries, hasLength(3));
      expect(entries.map((e) => e.sessionIndex), [1, 2, 3]);
      expect(entries.every((e) => e.sessionCount == 3), isTrue);
      expect(entries.every((e) => e.isMultiSession), isTrue);
    });

    test('a single-session event is not flagged multi-session', () {
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'keynote-artemis'},
        now: at(16),
      );
      expect(entries.single.isMultiSession, isFalse);
    });
  });

  group('per-session timing', () {
    final show = event('s', 'Show', [
      EventSession(start: at(17), end: at(17, 45)),
      EventSession(start: at(20, 45), end: at(21, 30)),
    ]);

    List<ItineraryEntry> entriesAt(DateTime now) => ItineraryService.build(
          allEvents: [show],
          savedIds: {'s'},
          now: now,
        );

    test('classifies each session independently', () {
      // At 5.20pm the first session is running while the second is still
      // hours away — the whole point of a per-session timeline.
      final entries = entriesAt(at(17, 20));
      expect(entries[0].timing, EventTiming.happeningNow);
      expect(entries[1].timing, EventTiming.upcoming);
    });

    test('marks a past session finished, not upcoming', () {
      final entries = entriesAt(at(19));
      expect(entries[0].timing, EventTiming.finished);
      expect(entries[1].timing, EventTiming.upcoming);
    });

    test('uses the shared soon window', () {
      final entries = entriesAt(at(20, 20));
      expect(entries[1].timing, EventTiming.startingSoon);
    });
  });

  group('conflicts', () {
    test('flags two different activities that overlap', () {
      final a = event('a', 'Talk A', [
        EventSession(start: at(18), end: at(18, 30)),
      ]);
      final b = event('b', 'Talk B', [
        EventSession(start: at(18, 15), end: at(18, 45)),
      ]);

      final entries = ItineraryService.build(
        allEvents: [a, b],
        savedIds: {'a', 'b'},
        now: at(17),
      );

      expect(entries[0].conflictsWith, ['Talk B']);
      expect(entries[1].conflictsWith, ['Talk A']);
      expect(entries.every((e) => e.hasConflict), isTrue);
    });

    test('two sessions of the SAME event never conflict', () {
      // You attend one of them. Flagging this would cry wolf on every
      // multi-session activity in the programme.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'physics-magic-show'},
        now: at(16),
      );

      expect(entries.every((e) => e.hasConflict), isFalse);
    });

    test('back-to-back sessions do not conflict', () {
      // One ends exactly as the next begins. Tight, but achievable — a
      // half-open overlap test keeps this quiet.
      final a = event('a', 'A', [EventSession(start: at(18), end: at(19))]);
      final b = event('b', 'B', [EventSession(start: at(19), end: at(20))]);

      final entries = ItineraryService.build(
        allEvents: [a, b],
        savedIds: {'a', 'b'},
        now: at(17),
      );

      expect(entries.every((e) => e.hasConflict), isFalse);
    });

    test('a real clash in the published programme is detected', () {
      // The keynote and "The engineering behind modern astronomy" both run
      // 7.30–8.15pm, at different venues. A visitor saving both should be told.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'keynote-artemis', 'featured-engineering-astronomy'},
        now: at(17),
      );

      expect(entries.every((e) => e.hasConflict), isTrue);
    });
  });

  group('nextUp', () {
    test('prefers something running over something upcoming', () {
      final running = event('r', 'Running', [
        EventSession(start: at(18), end: at(20)),
      ]);
      final soon = event('s', 'Soon', [
        EventSession(start: at(19), end: at(19, 30)),
      ]);

      final entries = ItineraryService.build(
        allEvents: [running, soon],
        savedIds: {'r', 's'},
        now: at(18, 50),
      );

      expect(ItineraryService.nextUp(entries)?.event.id, 'r');
    });

    test('returns null when everything has finished', () {
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'keynote-artemis'},
        now: at(21, 30),
      );

      expect(ItineraryService.nextUp(entries), isNull);
    });

    test('returns null for an empty plan', () {
      expect(ItineraryService.nextUp(const []), isNull);
    });
  });

  group('remaining / finished', () {
    test('splits the timeline by completion', () {
      // 6.30pm: the 5–5.45pm run is over, the 6.15–7pm run is on, and the
      // 8.45pm run is still to come.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'physics-magic-show'},
        now: at(18, 30),
      );

      expect(ItineraryService.finished(entries), hasLength(1));
      expect(ItineraryService.remaining(entries), hasLength(2));
    });

    test('a session is finished the instant it ends', () {
      // Half-open intervals: at exactly 7pm the 6.15–7pm run is over, not
      // still running. Two of the three sessions are done by then.
      final entries = ItineraryService.build(
        allEvents: EventsData.all,
        savedIds: {'physics-magic-show'},
        now: at(19),
      );

      expect(ItineraryService.finished(entries), hasLength(2));
      expect(ItineraryService.remaining(entries), hasLength(1));
    });
  });
}
