import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Clock-driven behaviour of Home's "Happening now" and "Up next" rails.
///
/// These drive the *providers Home actually watches* through the whole evening
/// with an injected clock, so they pin the on-screen behaviour end to end —
/// complementing `whats_on_service_test`, which pins the pure classifier.
///
/// The invariants under test (requirements §8–§10):
///   * Happening now = sessions with `start <= now < end` (half-open).
///   * Up next = sessions with `start > now`, chronological.
///   * A session is never in both at once.
///   * Sensible states before, at start, mid, near end, and after the event.
void main() {
  /// A container whose clock is pinned to [now] on the event date.
  ProviderContainer at(DateTime now) {
    final c = ProviderContainer(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(now))],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<String> ids(List<TimedEvent> ts) =>
      ts.map((t) => '${t.event.id}@${t.session?.start}').toList();

  group('before the event opens (3:30pm)', () {
    ProviderContainer c() => at(EventInfo.at(15, 30));

    test('nothing is happening now', () {
      expect(c().read(happeningNowProvider), isEmpty);
    });

    test('up next shows the first activities, chronologically', () {
      final container = c();
      final soon = container.read(startingSoonProvider);
      final upcoming = container.read(upcomingProvider);
      final shown = soon.isNotEmpty ? soon : upcoming;
      expect(shown, isNotEmpty, reason: 'the visitor should see what opens the '
          'night, not an empty screen');

      // Chronological: each start >= the previous.
      final starts = shown.map((t) => t.session!.start).toList();
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i].isBefore(starts[i - 1]), isFalse);
      }
      // The earliest programme start is 4pm; nothing "upcoming" precedes it.
      expect(starts.first.isBefore(EventInfo.at(16, 0)), isFalse);
    });

    test('the phase is pre-event (not live), so Home shows no live pill', () {
      // Doors open at 4pm; 3:30pm is inside the 2-hour "starting soon" window,
      // but crucially the event is NOT live yet.
      final phase = c().read(eventPhaseProvider);
      expect(phase.isLive, isFalse);
      expect(phase, isNot(EventPhase.ended));
    });

    test('a day earlier the phase is genuinely future', () {
      final dayBefore = at(EventInfo.at(16, 0).subtract(const Duration(days: 1)));
      expect(dayBefore.read(eventPhaseProvider), EventPhase.future);
      expect(dayBefore.read(happeningNowProvider), isEmpty);
    });
  });

  group('at the very start (4:00pm)', () {
    test('sessions starting exactly now are happening now, not up next', () {
      final container = at(EventInfo.at(16, 0));
      final now = EventInfo.at(16, 0);

      final happening = container.read(happeningNowProvider);
      final happeningIds = happening.map((t) => t.event.id).toSet();
      expect(happening, isNotEmpty);

      // Every 4pm-start session is live (start == now, half-open includes it)…
      final startingAtOpen = EventsData.all.where(
        (e) => e.sessions.any((s) => s.start == now),
      );
      expect(startingAtOpen, isNotEmpty);
      for (final e in startingAtOpen) {
        expect(happeningIds, contains(e.id),
            reason: '${e.id} starts at 4pm and must be "happening now"');
      }

      // …and NONE of them are also in up next.
      final upcomingIds = [
        ...container.read(startingSoonProvider),
        ...container.read(upcomingProvider),
      ].map((t) => t.event.id).toSet();
      expect(happeningIds.intersection(upcomingIds), isEmpty,
          reason: 'a session cannot be happening-now and up-next at once');
    });
  });

  group('mid-event (7:00pm)', () {
    ProviderContainer container() => at(EventInfo.at(19, 0));

    test('concurrent live sessions all appear in happening now', () {
      final now = EventInfo.at(19, 0);
      final live = container().read(happeningNowProvider);
      expect(live.length, greaterThan(1),
          reason: 'the programme runs many things at once mid-event');
      for (final t in live) {
        expect(t.session!.containsTime(now), isTrue);
      }
    });

    test('happening now and up next are disjoint', () {
      final c = container();
      final nowIds = c.read(happeningNowProvider).map((t) => t.event.id).toSet();
      final nextIds = {
        ...c.read(startingSoonProvider).map((t) => t.event.id),
        ...c.read(upcomingProvider).map((t) => t.event.id),
      };
      expect(nowIds.intersection(nextIds), isEmpty);
    });

    test('up next is strictly in the future and sorted', () {
      final now = EventInfo.at(19, 0);
      final upcoming = container().read(upcomingProvider);
      for (final t in upcoming) {
        expect(t.session!.start.isAfter(now), isTrue,
            reason: 'up next must not contain a session that already started');
      }
      final starts = upcoming.map((t) => t.session!.start).toList();
      final sorted = [...starts]..sort();
      expect(starts, sorted);
    });
  });

  group('near the end (9:45pm, event closes 10pm)', () {
    test('current sessions still show, only later ones remain up next', () {
      final now = EventInfo.at(21, 45);
      final container = at(now);

      for (final t in container.read(happeningNowProvider)) {
        expect(t.session!.containsTime(now), isTrue);
      }
      for (final t in container.read(upcomingProvider)) {
        expect(t.session!.start.isAfter(now), isTrue);
      }
    });
  });

  group('after the event closes (10:30pm)', () {
    ProviderContainer container() => at(EventInfo.at(22, 30));

    test('nothing is happening now and nothing is up next', () {
      final c = container();
      expect(c.read(happeningNowProvider), isEmpty);
      expect(c.read(startingSoonProvider), isEmpty);
      expect(c.read(upcomingProvider), isEmpty);
    });

    test('the phase reads as ended, so Home can show a completed state', () {
      expect(container().read(eventPhaseProvider), EventPhase.ended);
    });
  });

  group('duplication can never happen across the whole evening', () {
    test('every half hour, no event id is in two buckets', () {
      for (var h = 15; h <= 22; h++) {
        for (final m in [0, 30]) {
          final c = at(EventInfo.at(h, m));
          final now = c.read(happeningNowProvider).map((t) => t.event.id).toSet();
          final soon = c.read(startingSoonProvider).map((t) => t.event.id).toSet();
          final up = c.read(upcomingProvider).map((t) => t.event.id).toSet();
          expect(now.intersection(soon), isEmpty, reason: 'now∩soon @ $h:$m');
          expect(now.intersection(up), isEmpty, reason: 'now∩up @ $h:$m');
          expect(soon.intersection(up), isEmpty, reason: 'soon∩up @ $h:$m');
        }
      }
    });

    test('a session appears at most once within happening now', () {
      // Guards the multi-session case: an event with two sessions must not be
      // listed twice while one of them is live.
      final c = at(EventInfo.at(19, 0));
      final keys = ids(c.read(happeningNowProvider));
      expect(keys.toSet().length, keys.length);
    });
  });
}
