import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/services/providers.dart';

/// "Preview event night" must actually move the whole app's clock, and letting
/// go of it must return the app to real time — never leave it stuck (§3).
void main() {
  ProviderContainer make() {
    // Base clock = a fixed real "now" a month before the event, so we can prove
    // the preview overrides it and that clearing restores it.
    final realNow = EventInfo.at(16, 0).subtract(const Duration(days: 30));
    final c = ProviderContainer(
      overrides: [baseClockProvider.overrideWithValue(FixedClock(realNow))],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('with no preview, the app reads the real (base) clock', () {
    final c = make();
    expect(c.read(eventPhaseProvider), EventPhase.future);
    expect(c.read(happeningNowProvider), isEmpty);
  });

  test('setting a preview time drives Happening Now / phase', () {
    final c = make();
    // Preview 7pm on the event night.
    c.read(simulatedTimeProvider.notifier).set(EventInfo.at(19, 0));

    expect(c.read(currentTimeProvider), EventInfo.at(19, 0));
    expect(c.read(eventPhaseProvider).isLive, isTrue);
    expect(c.read(happeningNowProvider), isNotEmpty,
        reason: 'mid-event preview should show live activities');
  });

  test('moving the preview time re-derives status', () {
    final c = make();
    final notifier = c.read(simulatedTimeProvider.notifier);

    notifier.set(EventInfo.at(16, 0)); // doors
    final atOpen = c.read(happeningNowProvider).length;

    notifier.set(EventInfo.at(22, 30)); // after close
    expect(c.read(happeningNowProvider), isEmpty);
    expect(c.read(eventPhaseProvider), EventPhase.ended);

    notifier.set(EventInfo.at(19, 0)); // back to mid-event
    expect(c.read(happeningNowProvider).length, greaterThan(atOpen - 100));
    expect(c.read(eventPhaseProvider).isLive, isTrue);
  });

  test('MAP #6: representative event-night times classify sanely (doors→close)', () {
    final c = make();
    final notifier = c.read(simulatedTimeProvider.notifier);
    // 4:00pm — doors: before or exactly at open, the event is not yet "ended".
    notifier.set(EventInfo.at(16, 0));
    expect(c.read(eventPhaseProvider), isNot(EventPhase.ended));
    // 5:00 / 7:00 / 9:30pm — squarely inside the running event → live.
    for (final (h, m) in const [(17, 0), (19, 0), (21, 30)]) {
      notifier.set(EventInfo.at(h, m));
      expect(c.read(eventPhaseProvider).isLive, isTrue,
          reason: '$h:$m on the night should read as live');
    }
    // 10:00pm — the event has ended; nothing is "happening now".
    notifier.set(EventInfo.at(22, 0));
    expect(c.read(eventPhaseProvider), EventPhase.ended);
    expect(c.read(happeningNowProvider), isEmpty);
  });

  test('MAP #6: an unpublished-time activity is never falsely "happening now"', () {
    // Whatever the preview clock, an activity with no published start must not be
    // classified as live off a placeholder time (honest-time contract).
    final c = make();
    c.read(simulatedTimeProvider.notifier).set(EventInfo.at(19, 0));
    final live = c.read(happeningNowProvider);
    for (final e in live) {
      expect(e.session?.hasPublishedStart, isTrue,
          reason: 'a "happening now" entry must run off a real published start, '
              'never a placeholder time');
    }
  });

  test('clearing the preview returns to real time — never stuck', () {
    final c = make();
    final notifier = c.read(simulatedTimeProvider.notifier);

    notifier.set(EventInfo.at(19, 0));
    expect(c.read(eventPhaseProvider).isLive, isTrue);

    notifier.clear();
    // Back to the real (pre-event) clock.
    expect(c.read(simulatedTimeProvider), isNull);
    expect(c.read(eventPhaseProvider), EventPhase.future);
    expect(c.read(happeningNowProvider), isEmpty);
  });
}
