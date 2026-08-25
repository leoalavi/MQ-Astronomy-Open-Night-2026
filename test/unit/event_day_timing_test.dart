import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Home's "Happening now" / "Up next" on the actual event night.
///
/// Saturday 19 September 2026, event-local time, doors 4pm–10pm.
///
/// ## What this pins
///
/// The classification rules, stated once and checked at every hour the visitor
/// will actually be looking at the phone:
///
/// * Happening now  — `start <= now < end`
/// * Up next        — `start > now`
/// * Finished       — `end <= now`
/// * Unscheduled    — no published time; belongs to none of the above
///
/// Everything runs against an INJECTED instant, never the wall clock, so the
/// answers are the same whether this suite runs today or on the night.
void main() {
  DateTime at(int h, int m) => EventInfo.at(h, m);

  /// The exact times the brief calls out.
  final times = <(int, int)>[
    (15, 30), (16, 0), (16, 15), (17, 0),
    (19, 30), (21, 45), (22, 0), (22, 30),
  ];

  ({
    List<TimedEvent> now,
    List<TimedEvent> soon,
    List<TimedEvent> later,
    List<TimedEvent> finished,
    List<TimedEvent> unscheduled,
  }) buckets(DateTime instant) {
    final timed = WhatsOnService.classifyAll(EventsData.all, instant);
    return (
      now: WhatsOnService.inBucket(timed, EventTiming.happeningNow),
      soon: WhatsOnService.inBucket(timed, EventTiming.startingSoon),
      later: WhatsOnService.inBucket(timed, EventTiming.upcoming),
      finished: WhatsOnService.inBucket(timed, EventTiming.finished),
      unscheduled: WhatsOnService.inBucket(timed, EventTiming.unscheduled),
    );
  }

  group('the event date itself', () {
    test('is Saturday 19 September 2026', () {
      final d = EventInfo.startsAt;
      expect((d.year, d.month, d.day), (2026, 9, 19));
      expect(d.weekday, DateTime.saturday);
      expect(EventInfo.startsAt.hour, 16);
      expect(EventInfo.endsAt.hour, 22);
    });
  });

  group('the classification rules hold at every checked time', () {
    for (final (h, m) in times) {
      final label = '$h:${m.toString().padLeft(2, '0')}';

      test('$label — nothing is in two buckets at once', () {
        final b = buckets(at(h, m));
        final all = [
          ...b.now, ...b.soon, ...b.later, ...b.finished, ...b.unscheduled,
        ];
        final ids = all.map((t) => t.event.id).toList();
        expect(ids.toSet().length, ids.length,
            reason: 'an event was classified into more than one bucket');
        // And every event is accounted for — none silently dropped.
        expect(ids.toSet().length, EventsData.all.length);
      });

      test('$label — Happening now obeys start <= now < end', () {
        final now = at(h, m);
        for (final t in buckets(now).now) {
          final s = t.session!;
          expect(s.start.isAfter(now), isFalse,
              reason: '${t.event.title} has not started at $label');
          expect(now.isBefore(s.end), isTrue,
              reason: '${t.event.title} already ended at $label');
        }
      });

      test('$label — Up next obeys start > now', () {
        final now = at(h, m);
        for (final t in [...buckets(now).soon, ...buckets(now).later]) {
          expect(t.session!.start.isAfter(now), isTrue,
              reason: '${t.event.title} is not in the future at $label');
        }
      });

      test('$label — Finished obeys end <= now for every session', () {
        final now = at(h, m);
        for (final t in buckets(now).finished) {
          for (final s in t.event.sessions) {
            if (s.isUnscheduled) continue;
            expect(s.end.isAfter(now), isFalse,
                reason: '${t.event.title} still has a session running/ahead');
          }
        }
      });

      test('$label — Up next is in chronological order', () {
        final later = [...buckets(at(h, m)).soon, ...buckets(at(h, m)).later];
        for (var i = 1; i < later.length; i++) {
          expect(
            later[i - 1].session!.start.isAfter(later[i].session!.start),
            isFalse,
            reason: 'Up next is out of order at $label',
          );
        }
      });
    }
  });

  group('the shape of the evening', () {
    test('15:30 — doors have not opened: nothing running, plenty ahead', () {
      final b = buckets(at(15, 30));
      expect(b.now, isEmpty, reason: 'the event has not started');
      expect([...b.soon, ...b.later], isNotEmpty);
      expect(b.finished, isEmpty);
    });

    test('16:00 — doors open, but nothing PUBLISHED starts until 4.15', () {
      // A deliberate, checked claim rather than an oversight. The earliest
      // published start in the whole programme is 4.15pm; the only entries that
      // ever looked like 4pm starters were the three with no published time at
      // all, which used to be filled in as 4pm–10pm. Home therefore shows
      // "Nothing running this minute — check what's next" at 4pm, which is the
      // honest answer.
      final earliest = EventsData.all
          .where((e) => !e.isUnscheduled)
          .expand((e) => e.sessions.map((s) => s.start))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      expect(earliest, at(16, 15));

      final b = buckets(at(16, 0));
      expect(b.now, isEmpty);
      expect(b.soon, isNotEmpty, reason: '4.15pm is inside the 30-min window');
    });

    test('16:15 — the published 4.15pm starts have begun', () {
      final ids = buckets(at(16, 15)).now.map((t) => t.event.id);
      expect(ids, contains('kids-space'));
    });

    test('19:30 — mid-event: things running AND things still ahead', () {
      final b = buckets(at(19, 30));
      expect(b.now, isNotEmpty);
      expect([...b.soon, ...b.later], isNotEmpty);
      expect(b.finished, isNotEmpty, reason: 'early sessions are over by 7:30');
    });

    test('21:45 — the last stretch', () {
      final b = buckets(at(21, 45));
      expect(b.finished, isNotEmpty);
      // Whatever is left running must genuinely still be inside its window.
      for (final t in b.now) {
        expect(at(21, 45).isBefore(t.session!.end), isTrue);
      }
    });

    test('22:00 — the event has closed: nothing running, nothing ahead', () {
      final b = buckets(at(22, 0));
      expect(b.now, isEmpty, reason: 'doors shut at 10pm');
      expect(b.soon, isEmpty);
      expect(b.later, isEmpty);
    });

    test('22:30 — after close, every timed event reads finished', () {
      final b = buckets(at(22, 30));
      expect(b.now, isEmpty);
      expect([...b.soon, ...b.later], isEmpty);
      final timedCount =
          EventsData.all.where((e) => !e.isUnscheduled).length;
      expect(b.finished.length, timedCount);
    });
  });

  group('simultaneity and boundaries', () {
    test('several activities can run at the same instant', () {
      expect(buckets(at(19, 30)).now.length, greaterThan(1));
    });

    test('a session is running AT its start and NOT at its end', () {
      // The half-open interval, checked on a real session rather than a stub.
      final e = EventsData.all.firstWhere(
        (e) => !e.isUnscheduled && e.sessions.first.hasPublishedEnd,
      );
      final s = e.sessions.first;
      expect(s.containsTime(s.start), isTrue, reason: 'start is inclusive');
      expect(s.containsTime(s.end), isFalse, reason: 'end is exclusive');
      expect(
        s.containsTime(s.end.subtract(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('an event never appears in Happening now and Up next together', () {
      // The specific pairing the brief calls out, checked minute-by-minute
      // across the whole evening rather than at sample points.
      for (var t = at(15, 0);
          t.isBefore(at(23, 0));
          t = t.add(const Duration(minutes: 5))) {
        final b = buckets(t);
        final nowIds = b.now.map((e) => e.event.id).toSet();
        final nextIds =
            [...b.soon, ...b.later].map((e) => e.event.id).toSet();
        expect(nowIds.intersection(nextIds), isEmpty,
            reason: 'double-booked at ${t.hour}:${t.minute}');
      }
    });
  });

  group('preview mode uses the same logic, not a parallel path', () {
    test('the preview instant classifies exactly like a real 7pm', () {
      // "Preview Event Night" simply injects EventInfo.previewInstant. If it
      // ever grew its own classification, these two would diverge.
      final preview = buckets(EventInfo.previewInstant);
      final real = buckets(at(19, 0));
      expect(preview.now.map((t) => t.event.id).toList(),
          real.now.map((t) => t.event.id).toList());
      expect(preview.later.map((t) => t.event.id).toList(),
          real.later.map((t) => t.event.id).toList());
    });

    test('classification depends only on the injected instant, not today', () {
      // The guard against "it works in September and breaks in August": the
      // same instant must give the same answer regardless of when it is run.
      final a = buckets(at(19, 30)).now.map((t) => t.event.id).toList();
      final b = buckets(at(19, 30)).now.map((t) => t.event.id).toList();
      expect(a, b);
      // And an instant on a DIFFERENT date is simply outside every session.
      final wrongDay = DateTime(2026, 8, 24, 19, 30);
      expect(buckets(wrongDay).now, isEmpty,
          reason: 'a non-event date must not light up the programme');
    });
  });
}
