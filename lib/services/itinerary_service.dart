import 'package:flutter/foundation.dart';

import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// One line on the visitor's night timeline.
@immutable
class ItineraryEntry {
  const ItineraryEntry({
    required this.event,
    required this.session,
    required this.timing,
    required this.sessionIndex,
    required this.sessionCount,
    this.conflictsWith = const [],
  });

  final AonEvent event;
  final EventSession session;
  final EventTiming timing;

  /// 1-based position among this event's own sessions, and how many there are.
  /// Lets the UI say "session 2 of 3" instead of repeating a title with no
  /// explanation of why it appears three times.
  final int sessionIndex;
  final int sessionCount;

  /// Titles of other saved activities that overlap this one in time.
  ///
  /// Surfaced rather than resolved: the app does not know which one the visitor
  /// intends to attend, and silently hiding one would be worse than flagging
  /// both. Empty for the common case.
  final List<String> conflictsWith;

  bool get hasConflict => conflictsWith.isNotEmpty;

  bool get isMultiSession => sessionCount > 1;
}

/// Builds the "My Night" timeline from saved activities.
///
/// ## One entry per session, not per event
///
/// Several activities run more than once (the Physics magic show runs three
/// times). A timeline that showed the event once would have to pick a session
/// on the visitor's behalf and would be wrong two thirds of the time. So each
/// session gets its own line, tagged "session N of M".
///
/// Pure functions over an injected `now` — same rule as [WhatsOnService], for
/// the same reason: the event is in the future and this has to be testable and
/// demonstrable before the night.
abstract final class ItineraryService {
  /// Builds the timeline, sorted by start time.
  static List<ItineraryEntry> build({
    required List<AonEvent> allEvents,
    required Set<String> savedIds,
    required DateTime now,
  }) {
    final saved = allEvents.where((e) => savedIds.contains(e.id)).toList();

    final entries = <ItineraryEntry>[];
    for (final event in saved) {
      final sessions = [...event.sessions]
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        entries.add(
          ItineraryEntry(
            event: event,
            session: session,
            timing: _timingFor(session, now),
            sessionIndex: i + 1,
            sessionCount: sessions.length,
          ),
        );
      }
    }

    entries.sort((a, b) {
      final byStart = a.session.start.compareTo(b.session.start);
      if (byStart != 0) return byStart;
      return a.event.title.compareTo(b.event.title);
    });

    return _withConflicts(entries);
  }

  /// Classifies a single session against [now].
  ///
  /// Note this is per-*session*, unlike [WhatsOnService.classify] which
  /// answers for a whole event. On a timeline the visitor is looking at one
  /// specific 5:00pm slot, not "is this show on at some point".
  static EventTiming _timingFor(EventSession session, DateTime now) {
    if (session.containsTime(now)) return EventTiming.happeningNow;
    if (!session.end.isAfter(now)) return EventTiming.finished;
    if (session.startsWithin(now, WhatsOnService.soonWindow)) {
      return EventTiming.startingSoon;
    }
    return EventTiming.upcoming;
  }

  /// Annotates entries that overlap another *different* activity.
  ///
  /// Two sessions of the same event are never a conflict with each other — the
  /// visitor simply picks one — so the comparison skips same-event pairs.
  ///
  /// O(n²), which is fine: a visitor's saved list is realistically under 20
  /// entries, and the alternative (an interval tree) would be more code than
  /// the problem deserves.
  static List<ItineraryEntry> _withConflicts(List<ItineraryEntry> entries) {
    return [
      for (var i = 0; i < entries.length; i++)
        () {
          final a = entries[i];
          final clashes = <String>[];

          for (var j = 0; j < entries.length; j++) {
            if (i == j) continue;
            final b = entries[j];
            if (b.event.id == a.event.id) continue;
            if (_overlaps(a.session, b.session) &&
                !clashes.contains(b.event.title)) {
              clashes.add(b.event.title);
            }
          }

          return ItineraryEntry(
            event: a.event,
            session: a.session,
            timing: a.timing,
            sessionIndex: a.sessionIndex,
            sessionCount: a.sessionCount,
            conflictsWith: clashes,
          );
        }(),
    ];
  }

  /// Half-open overlap: sessions that merely touch (one ends exactly as the
  /// next begins) do **not** conflict. Back-to-back is a tight but achievable
  /// plan, not a clash — flagging it would cry wolf.
  static bool _overlaps(EventSession a, EventSession b) =>
      a.start.isBefore(b.end) && b.start.isBefore(a.end);

  /// The next thing the visitor should head to, or null.
  ///
  /// Prefers something running now over something upcoming — if you are
  /// already meant to be somewhere, that is the answer to "what's next".
  static ItineraryEntry? nextUp(List<ItineraryEntry> entries) {
    for (final e in entries) {
      if (e.timing == EventTiming.happeningNow) return e;
    }
    for (final e in entries) {
      if (e.timing == EventTiming.startingSoon ||
          e.timing == EventTiming.upcoming) {
        return e;
      }
    }
    return null;
  }

  /// Entries that have not finished yet — what the timeline shows by default.
  static List<ItineraryEntry> remaining(List<ItineraryEntry> entries) =>
      entries.where((e) => e.timing != EventTiming.finished).toList();

  static List<ItineraryEntry> finished(List<ItineraryEntry> entries) =>
      entries.where((e) => e.timing == EventTiming.finished).toList();
}
