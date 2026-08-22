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
