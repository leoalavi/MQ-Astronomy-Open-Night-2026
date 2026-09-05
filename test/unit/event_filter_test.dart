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

  group('start-time filter (START HOUR ONLY)', () {
    Set<String> inHour(int h) => EventFilterService.apply(
          all,
          EventFilter(startHour: h),
        ).map((e) => e.id).toSet();

    test('a 4.15pm→10pm long-running event is ONLY a 4pm item', () {
      // exhibition-hall runs 4.15pm to 10pm. Its 10pm FINISH is irrelevant to
      // the start filter — it belongs to the 4pm bucket and no other.
      expect(inHour(16), contains('exhibition-hall'));
      for (final h in [17, 18, 19, 20]) {
        expect(inHour(h), isNot(contains('exhibition-hall')),
            reason: 'a 4.15pm start must never leak into the $h:00 bucket');
      }
    });

    test('a start-only 4.15pm event (no finish) is ONLY a 4pm item', () {
      // kids-space: real 4.15pm start, finish NOT published. No fabricated 10pm
      // end is used, so it appears only under 4pm.
      final kids = EventsData.byId('kids-space')!.sessions.single;
      expect(kids.timing, TimingConfidence.startOnly);
      expect(kids.hasPublishedEnd, isFalse);
      expect(inHour(16), contains('kids-space'));
      for (final h in [17, 18, 19, 20]) {
        expect(inHour(h), isNot(contains('kids-space')));
      }
    });

    test('a 6.xx talk appears only under the 6pm bucket', () {
      // t3-pal starts 6.00pm.
      expect(inHour(18), contains('t3-pal'));
      for (final h in [16, 17, 19, 20]) {
        expect(inHour(h), isNot(contains('t3-pal')));
      }
    });

    test('a multi-session show appears in EACH hour it genuinely starts in', () {
      // physics-magic-show starts 5.00, 6.15 and 8.45 → 5pm, 6pm, 8pm only.
      expect(inHour(17), contains('physics-magic-show'));
      expect(inHour(18), contains('physics-magic-show'));
      expect(inHour(20), contains('physics-magic-show'));
      expect(inHour(16), isNot(contains('physics-magic-show')));
      expect(inHour(19), isNot(contains('physics-magic-show')));
    });

    test('Open-all-night / no-time items never enter an hour bucket', () {
      for (final h in [16, 17, 18, 19, 20]) {
        expect(inHour(h), isNot(contains('capture-the-cosmos')),
            reason: 'open-all-night has no honest start hour');
        expect(inHour(h), isNot(contains('solar-system-walk')));
      }
    });

    test('"On the night" holds exactly the full-event / no-time items', () {
      final night = EventFilterService.apply(
        all,
        const EventFilter(onTheNight: true),
      ).map((e) => e.id).toSet();
      expect(night, containsAll(['capture-the-cosmos', 'solar-system-walk']));
      for (final id in ['exhibition-hall', 'kids-space', 'physics-magic-show',
          't3-pal']) {
        expect(night, isNot(contains(id)),
            reason: '$id is genuinely timed — it belongs to an hour bucket');
      }
    });

    test('the available start hours are exactly the real ones (4pm–8pm)', () {
      // 4pm..8pm are real; there is NO 9pm start in the programme.
      expect(EventFilterService.availableStartHours(all), [16, 17, 18, 19, 20]);
      expect(EventFilterService.hasOnTheNight(all), isTrue);
    });

    test('every hour bucket and On the night are disjoint, per event', () {
      for (final e in all) {
        final inAnyHour =
            [16, 17, 18, 19, 20].any((h) => EventFilterService.startsInHour(e, h));
        final night = EventFilterService.isOnTheNight(e);
        expect(inAnyHour && night, isFalse,
            reason: '${e.id} must not be in both an hour bucket and On the night');
      }
    });
  });

  group('combined time + activity (AND)', () {
    test('6pm + Talks → only short talks starting in the 6pm hour', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(startHour: 18, categories: {EventCategory.shortTalk}),
      );
      final ids = result.map((e) => e.id).toSet();
      // The 6.xx short talks.
      expect(ids, containsAll(
          ['t3-pal', 't3-gonzalez-bolivar', 't4-de-grijs', 't4-raidani']));
      // Every result is a short talk…
      for (final e in result) {
        expect(e.category, EventCategory.shortTalk);
      }
      // …a 6.30pm Activity is excluded (wrong category)…
      expect(ids, isNot(contains('laser-graffiti')));
      // …and a 7.30pm talk is excluded (wrong hour).
      expect(ids, isNot(contains('t3-salvador-campe')));
    });

    test('All times + one activity returns every event in that activity', () {
      final result = EventFilterService.apply(
        all,
        const EventFilter(categories: {EventCategory.keynote}),
      );
      expect(result.single.id, 'keynote-artemis');
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
        startHour: 16, // 4pm
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
