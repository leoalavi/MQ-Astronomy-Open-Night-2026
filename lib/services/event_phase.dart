import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/clock.dart';

/// Where the *whole event* is relative to now.
///
/// Distinct from [EventTiming], which answers the same question for a single
/// activity. This one drives the Home hero badge and the "the event hasn't
/// started" / "that's a wrap" screens — the visitor needs to know whether the
/// app is showing them a live night or a plan for a future one.
enum EventPhase {
  /// More than a day out.
  future,

  /// Same day, before doors.
  today,

  /// Within [EventPhaseService.soonWindow] of opening.
  startingSoon,

  /// Doors are open.
  running,

  /// Open, but within [EventPhaseService.endingWindow] of close.
  endingSoon,

  /// Closed.
  ended;

  bool get isLive => this == running || this == endingSoon;
}

abstract final class EventPhaseService {
  /// How close to doors counts as "starting soon".
  ///
  /// Two hours, not the 30 minutes used for individual activities. The unit
  /// here is a journey, not a walk across campus — someone checking at 2pm is
  /// deciding when to leave home, and that is exactly when a "starts at 4pm"
  /// nudge is useful.
  static const Duration soonWindow = Duration(hours: 2);

  /// How close to close counts as "ending soon". Long enough that a visitor
  /// still has time to reach the Observatory and back.
  static const Duration endingWindow = Duration(minutes: 45);

  static EventPhase phaseFor({
    required DateTime now,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    if (!now.isBefore(endsAt)) return EventPhase.ended;

    if (!now.isBefore(startsAt)) {
      return endsAt.difference(now) <= endingWindow
          ? EventPhase.endingSoon
          : EventPhase.running;
    }

    final untilStart = startsAt.difference(now);
    if (untilStart <= soonWindow) return EventPhase.startingSoon;

    // Same calendar day, but still hours away.
    final sameDay = now.year == startsAt.year &&
        now.month == startsAt.month &&
        now.day == startsAt.day;
    return sameDay ? EventPhase.today : EventPhase.future;
  }
}

/// The live event phase, recomputed on the clock tick.
final eventPhaseProvider = Provider<EventPhase>((ref) {
  final config = ref.watch(eventConfigProvider);
  return EventPhaseService.phaseFor(
    now: ref.watch(currentTimeProvider),
    startsAt: config.startsAt,
    endsAt: config.endsAt,
  );
});
