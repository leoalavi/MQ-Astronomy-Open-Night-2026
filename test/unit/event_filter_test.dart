import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/event_filter.dart';

void main() {
  final all = EventsData.all;

  group('empty filter', () {
    test('returns the whole programme', () {
      expect(
        EventFilterService.apply(all, const EventFilter()),
        hasLength(all.length),
      );
    });

    test('an empty category set means "all", not "none"', () {
      // This is the convention the chip UI depends on — worth pinning.
      const filter = EventFilter(categories: {});
      expect(EventFilterService.apply(all, filter), hasLength(all.length));
    });
  });

  group('category filter', () {
    test('narrows to one category', () {
      const filter = EventFilter(categories: {EventCategory.keynote});
      final result = EventFilterService.apply(all, filter);

      expect(result, hasLength(1));
      expect(result.single.id, 'keynote-artemis');
    });

    test('values within a group combine with OR', () {
      const filter = EventFilter(
        categories: {EventCategory.keynote, EventCategory.shortTalk},
      );
      final result = EventFilterService.apply(all, filter);

      expect(result.length, 13); // 12 short talks + 1 keynote
    });
  });

  group('venue filter', () {
    test('narrows to one venue', () {
      const filter = EventFilter(venueIds: {'astronomical-observatory'});
      final result = EventFilterService.apply(all, filter);

      expect(result, hasLength(1));
      expect(result.single.id, 'telescope-park');
    });
  });

  group('time band filter', () {
    test('an event fully inside a band matches it', () {
      const filter = EventFilter(timeBands: {TimeBand.evening}); // 6-8pm
      final result = EventFilterService.apply(all, filter);

      expect(result.map((e) => e.id), contains('keynote-artemis'));
    });

    test('an event that only overlaps a band still matches', () {
      // Telescope Park runs 4.15pm-9.30pm, so it spans all three bands.
      for (final band in TimeBand.values) {
        final result = EventFilterService.apply(
          all,
          EventFilter(timeBands: {band}),
        );
        expect(
          result.map((e) => e.id),
          contains('telescope-park'),
          reason: 'should overlap ${band.label}',
        );
      }
    });

    test('an event ending exactly at the band boundary does not match', () {
      // Fun with Fizzics runs 5pm-8pm. It should NOT appear under 8-10pm.
      final result = EventFilterService.apply(
        all,
        const EventFilter(timeBands: {TimeBand.lateEvening}),
      );

      expect(result.map((e) => e.id), isNot(contains('fun-with-fizzics')));
    });

    test('a multi-session event matches any band a session touches', () {
      // Physics magic show: 5-5.45, 6.15-7, 8.45-9.30 — hits all three.
      for (final band in TimeBand.values) {
        final result = EventFilterService.apply(
          all,
          EventFilter(timeBands: {band}),
        );
        expect(result.map((e) => e.id), contains('physics-magic-show'));
      }
    });

    test('a published-start / no-published-finish session is NOT inferred into later bands',
        () {
      // Kids' space publishes a 4.15pm start but NO finish (startOnly), so its
      // `end` is a 10pm stand-in, not a fact. The old filter did a plain
      // start/end overlap and so matched it against 6-8pm and 8-10pm as if it
      // were proven to run that late — objectively wrong. It must match ONLY the
      // band that contains its published start (4-6pm).
      final kids = EventsData.byId('kids-space')!.sessions.single;
      expect(kids.timing, TimingConfidence.startOnly);
      expect(kids.hasPublishedEnd, isFalse);

      bool inBand(TimeBand b) => EventFilterService.apply(
            all,
            EventFilter(timeBands: {b}),
          ).map((e) => e.id).contains('kids-space');

      expect(inBand(TimeBand.earlyEvening), isTrue,
          reason: '4.15pm start falls inside 4-6pm');
      expect(inBand(TimeBand.evening), isFalse,
          reason: 'finish unpublished — must not be inferred into 6-8pm');
      expect(inBand(TimeBand.lateEvening), isFalse,
          reason: 'finish unpublished — must not be inferred into 8-10pm');
    });

    // Reproduces the 6–8pm screen from the bug report and pins exactly which
    // "4pm" items may and may not appear, so the contract can't silently drift.
    test('6–8pm shows only sessions genuinely on at 6–8pm', () {
      final evening = EventFilterService.apply(
        all,
        const EventFilter(timeBands: {TimeBand.evening}),
      ).map((e) => e.id).toSet();

      // MUST NOT appear: 4.15pm start with no published finish. Their start is
      // in 4–6pm and nothing proves they run into 6–8pm.
      for (final id in ['kids-space', 'stories-across-worlds',
          'junior-science-academy', 'planetariums']) {
        expect(evening, isNot(contains(id)),
            reason: '$id is start-only (no published finish) — 4–6pm only');
      }

      // MAY appear even though they "start at 4pm": these publish a real finish
      // of 9–10pm, so they are genuinely open during 6–8pm (interval overlap).
      for (final id in ['exhibition-hall', 'telescope-park', 'scientist-spotlight']) {
        expect(evening, contains(id),
            reason: '$id runs 4.15pm→9–10pm, so it IS on at 6–8pm');
      }

      // Open-all-night items appear in every band — the intended contract.
      expect(evening, containsAll(['capture-the-cosmos', 'solar-system-walk']));

      // A multi-session show is in 6–8pm because it has a real 6.15pm session,
      // not because a 5pm one was stretched.
      expect(evening, contains('physics-magic-show'));
    });
  });

  group('search', () {
    test('matches on title', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(query: 'planetarium'),
      );
      expect(result.map((e) => e.id), contains('planetariums'));
    });

    test('matches on presenter', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(query: 'Fred Watson'),
      );
      expect(result.map((e) => e.id), contains('keynote-artemis'));
    });

    test('matches on room', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(query: 'Theatre 4'),
      );
      expect(result, isNotEmpty);
      expect(result.every((e) => e.room == 'Theatre 4'), isTrue);
    });

    test('is case-insensitive and trims whitespace', () {
      final a = EventFilterService.apply(
        all,
        const EventFilter(query: '  ROBOTICS  '),
      );
      final b = EventFilterService.apply(
        all,
        const EventFilter(query: 'robotics'),
      );
      expect(a.map((e) => e.id), b.map((e) => e.id));
    });

    test('a query matching nothing returns empty, not everything', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(query: 'zzzzzz-no-such-thing'),
      );
      expect(result, isEmpty);
    });

    test('does not resurrect the cancelled Huntsman session', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(query: 'huntsman'),
      );
      expect(result, isEmpty);
    });
  });

  group('booking filter', () {
    test('narrows to pre-booked events only', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(bookableOnly: true),
      );

      expect(result, isNotEmpty);
      expect(result.every((e) => e.bookingRequired), isTrue);
      expect(result.map((e) => e.id), contains('physics-magic-show'));
    });
  });

  group('combining filter groups', () {
    test('groups combine with AND', () {
      const filter = EventFilter(
        categories: {EventCategory.shortTalk},
        venueIds: {'astronomical-observatory'},
      );

      // Short talks are at 14 SCO, never at the Observatory.
      expect(EventFilterService.apply(all, filter), isEmpty);
    });

    test('a realistic combination narrows sensibly', () {
      const filter = EventFilter(
        categories: {EventCategory.shortTalk},
        timeBands: {TimeBand.earlyEvening},
      );
      final result = EventFilterService.apply(all, filter);

      expect(result, isNotEmpty);
      expect(
        result.every((e) => e.category == EventCategory.shortTalk),
        isTrue,
      );
    });
  });

  group('EventFilter value semantics', () {
    test('two filters with the same contents are equal', () {
      expect(
        const EventFilter(categories: {EventCategory.keynote}),
        const EventFilter(categories: {EventCategory.keynote}),
      );
    });

    test('activeCount counts groups, not values', () {
      const filter = EventFilter(
        categories: {EventCategory.keynote, EventCategory.shortTalk},
        query: 'test',
      );
      expect(filter.activeCount, 2);
    });

    test('a whitespace-only query does not count as active', () {
      expect(const EventFilter(query: '   ').isEmpty, isTrue);
    });
  });

  group('groupByCategory', () {
    test('preserves the printed programme order', () {
      final grouped = EventFilterService.groupByCategory(all);
      expect(
        grouped.keys.toList(),
        EventCategory.values.where(grouped.containsKey).toList(),
      );
    });

    test('omits categories with no matches', () {
      final grouped = EventFilterService.groupByCategory(
        EventFilterService.apply(
          all,
          const EventFilter(categories: {EventCategory.keynote}),
        ),
      );
      expect(grouped.keys, [EventCategory.keynote]);
    });

    test('sorts within a category by start time', () {
      final grouped = EventFilterService.groupByCategory(all);
      final talks = grouped[EventCategory.shortTalk]!;

      for (var i = 1; i < talks.length; i++) {
        expect(talks[i].firstStart.isBefore(talks[i - 1].firstStart), isFalse);
      }
    });
  });
}
