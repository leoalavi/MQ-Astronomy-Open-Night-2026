import 'package:aon2026/models/event.dart';

/// Where an event sits relative to "now".
///
/// The [label] here is a **debug/diagnostic** name, not UI copy — user-facing
/// text comes from the ARB files via `EventTimingL10n.labelOf`. Keeping an
/// English label on the enum keeps test failure messages readable.
enum EventTiming {
  happeningNow('Happening now'),
  startingSoon('Starting soon'),
  upcoming('Later tonight'),
  finished('Finished'),

  /// The programme publishes NO time for this activity, so it cannot honestly
  /// be placed anywhere on the evening's timeline. Distinct from [finished]:
  /// the activity may well be running — we simply were not told when. It stays
  /// fully discoverable in the Programme, in its own clearly-labelled group.
  unscheduled('Time not published');

  const EventTiming(this.label);

  final String label;
}

/// An event paired with its timing relative to a given instant.
class TimedEvent {
  const TimedEvent({
    required this.event,
    required this.timing,
    required this.session,
  });

  final AonEvent event;
  final EventTiming timing;

  /// The session this timing refers to — the running one for
  /// [EventTiming.happeningNow], otherwise the next one to start.
  /// Null when the event is [EventTiming.finished].
  final EventSession? session;

  /// Whether this event runs for essentially the whole evening.
  ///
  /// Drop-in activities (the Exhibition Hall, the Cosmic arcade) are open for
  /// five or six hours. They are legitimately "happening now", but if they are
  /// mixed in with the timed sessions they crowd out the thing a user actually
  /// needs to know — that the keynote starts in twelve minutes. The UI groups
  /// them separately.
  /// Requires a PUBLISHED end: a session whose finish we invented only looks
  /// like an all-evening drop-in because of the stand-in time we wrote.
  bool get isAllEvening =>
      session != null &&
      session!.hasPublishedEnd &&
      session!.duration >= const Duration(hours: 4);
}

/// Classifies the programme against the current time.
///
/// Pure functions over an injected `now` — no clock access inside. That keeps
/// the whole "What's On Now" behaviour testable at any instant, which matters
/// because the event is in the future and every review of this screen before
/// September 2026 happens on a day when the real answer is "nothing".
abstract final class WhatsOnService {
  /// How far ahead counts as "starting soon".
  ///
  /// 30 minutes, chosen to match the programme's own rhythm: short talks run
  /// on a 45-minute cadence and sessions are 30 minutes long, so a 30-minute
  /// look-ahead surfaces the next slot without ever showing two consecutive
  /// slots of the same talk series at once. It is also roughly the longest
  /// walk on campus (Metro to the Observatory), so anything flagged "soon" is
  /// something you can still physically reach.
  static const Duration soonWindow = Duration(minutes: 30);

  /// Classifies a single event.
  static TimedEvent classify(AonEvent event, DateTime now) {
    // No published time anywhere → it belongs on no part of the timeline.
    // Checked FIRST so an unscheduled activity can never be reported as
    // running, starting soon, or finished, whatever its stand-in times say.
    if (event.isUnscheduled) {
      return TimedEvent(
        event: event,
        timing: EventTiming.unscheduled,
        session: event.sessions.first,
      );
    }

    final running = event.sessionAt(now);
    if (running != null) {
      return TimedEvent(
        event: event,
        timing: EventTiming.happeningNow,
        session: running,
      );
    }

    final next = event.nextSessionAfter(now);
    if (next == null) {
      return TimedEvent(
        event: event,
        timing: EventTiming.finished,
        session: null,
      );
    }

    final timing = next.startsWithin(now, soonWindow)
        ? EventTiming.startingSoon
        : EventTiming.upcoming;

    return TimedEvent(event: event, timing: timing, session: next);
  }

  /// Classifies the whole programme.
  static List<TimedEvent> classifyAll(
    List<AonEvent> events,
    DateTime now,
  ) {
    return events.map((e) => classify(e, now)).toList();
  }

  /// Events in a given timing bucket, sorted for display.
  ///
  /// Sort order differs per bucket on purpose:
  /// * **Happening now** sorts by *end* time ascending — "ending soonest
  ///   first", because that is the one you might miss.
  /// * Everything else sorts by *start* time ascending — the natural
  ///   "what's next" reading order.
  static List<TimedEvent> inBucket(
    List<TimedEvent> timed,
    EventTiming timing,
  ) {
    final result = timed.where((t) => t.timing == timing).toList();

    if (timing == EventTiming.unscheduled) {
      // No times to sort by — alphabetical is the only honest order.
      result.sort((a, b) => a.event.title.compareTo(b.event.title));
    } else if (timing == EventTiming.happeningNow) {
      result.sort((a, b) {
        final byEnd = a.session!.end.compareTo(b.session!.end);
        if (byEnd != 0) return byEnd;
        return a.event.title.compareTo(b.event.title);
      });
    } else {
      result.sort((a, b) {
        if (a.session == null || b.session == null) {
          return a.event.title.compareTo(b.event.title);
        }
        final byStart = a.session!.start.compareTo(b.session!.start);
        if (byStart != 0) return byStart;
        return a.event.title.compareTo(b.event.title);
      });
    }

    return result;
  }

  /// Whether [now] falls inside the event's opening hours.
  static bool isDuringEvent(DateTime now, DateTime opens, DateTime closes) {
    return !now.isBefore(opens) && now.isBefore(closes);
  }
}
