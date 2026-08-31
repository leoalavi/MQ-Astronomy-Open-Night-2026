import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Ordering in the What's-On buckets must be deterministic: two activities that
/// share a time must always come out in the same order, whatever order they
/// arrive in, so a rebuild or a filter toggle never reshuffles equal rows under
/// the visitor's finger. `WhatsOnService.inBucket` tie-breaks on title after
/// the primary time key; these tests pin that.
void main() {
  DateTime at(int h, int m) => DateTime(2026, 9, 19, h, m);

  AonEvent event(String id, String title, EventSession s) => AonEvent(
        id: id,
        title: title,
        description: '',
        category: EventCategory.activity,
        venueId: '1-central-courtyard',
        sessions: [s],
      );

  group('happeningNow (sorted by end, tie-broken by title)', () {
    test('two sessions ending at the same instant order by title, stably', () {
      final now = at(19, 0);
      final zebra = event('z', 'Zebra', EventSession(start: at(18, 0), end: at(20, 0)));
      final apple = event('a', 'Apple', EventSession(start: at(18, 0), end: at(20, 0)));

      // Feed both input orders; the output order must be identical (Apple first).
      for (final input in [
        [zebra, apple],
        [apple, zebra],
      ]) {
        final timed = WhatsOnService.classifyAll(input, now);
        final bucket = WhatsOnService.inBucket(timed, EventTiming.happeningNow);
        expect(bucket.map((t) => t.event.title).toList(), ['Apple', 'Zebra']);
      }
    });
  });

  group('upcoming (sorted by start, tie-broken by title)', () {
    test('two sessions starting at the same instant order by title, stably', () {
      final now = at(15, 0); // before both starts → both upcoming
      final zebra = event('z', 'Zebra', EventSession(start: at(18, 0), end: at(19, 0)));
      final apple = event('a', 'Apple', EventSession(start: at(18, 0), end: at(19, 0)));

      for (final input in [
        [zebra, apple],
        [apple, zebra],
      ]) {
        final timed = WhatsOnService.classifyAll(input, now);
        final bucket = WhatsOnService.inBucket(timed, EventTiming.upcoming);
        expect(bucket.map((t) => t.event.title).toList(), ['Apple', 'Zebra']);
      }
    });
  });

  group('real programme data', () {
    test('the two 4.30pm short talks keep a stable, title-ordered position', () {
      // t3-pope and t4-fava both start 4.30pm — a genuine collision in the
      // shipped programme. Before the event both are `upcoming`.
      final now = at(15, 0);
      final timed = WhatsOnService.classifyAll(EventsData.all, now);
      final upcoming = WhatsOnService.inBucket(timed, EventTiming.upcoming);

      final firstRun = upcoming.map((t) => t.event.id).toList();
      // Reclassifying the same programme yields byte-identical order.
      final secondRun = WhatsOnService.inBucket(
        WhatsOnService.classifyAll(EventsData.all, now),
        EventTiming.upcoming,
      ).map((t) => t.event.id).toList();
      expect(secondRun, firstRun);

      final pope = firstRun.indexOf('t3-pope');
      final fava = firstRun.indexOf('t4-fava');
      expect(pope, isNonNegative);
      expect(fava, isNonNegative);
      // "Galactic guesswork…" (t3-pope) sorts before "So you like science…"
      // (t4-fava) by title at the shared 4.30pm start.
      expect(pope, lessThan(fava));
    });
  });
}
