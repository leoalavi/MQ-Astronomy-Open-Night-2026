import 'package:flutter/foundation.dart';

import 'package:aon2026/models/data_confidence.dart';

/// What the OFFICIAL programme actually says about a session's timing.
///
/// ## Why this exists
///
/// Seven of the 36 programme entries do not publish a full start-and-end time,
/// and the data previously papered over that by writing plausible times into
/// [EventSession.start]/[EventSession.end] — 4pm–10pm for entries with no time
/// at all. Nothing downstream could tell those apart from a real 4pm–10pm
/// session, so "Capture the cosmos", whose programme entry publishes NO time,
/// sat in **Happening Now** for the entire evening as though that were a fact.
///
/// A visitor acting on that walks to a building on the strength of a schedule
/// the University never printed. This enum is the distinction the times alone
/// cannot carry, and [WhatsOnService] classifies against it.
enum TimingConfidence {
  /// Start AND end both printed in the programme. The overwhelming majority.
  exactTime,

  /// A published START time, but no published finish ("4.15pm start").
  /// The start is fact; the end is not, and must never be presented as one.
  startOnly,

  /// A published start plus a published repeating cadence ("sessions run about
  /// every 20 minutes from 4.15pm"). Like [startOnly], the finish is unknown.
  repeating,

  /// The source EXPLICITLY states the activity runs for the whole event. This
  /// is the only case in which a full-evening block is a fact rather than an
  /// assumption — nothing currently qualifies.
  fullEventConfirmed,

  /// No time published at all. There is no honest start or end, so the session
  /// is never classified as running or upcoming.
  timeUnpublished,
}

extension TimingConfidenceX on TimingConfidence {
  /// Whether a real, source-backed START time exists. False only for
  /// [TimingConfidence.timeUnpublished].
  bool get hasPublishedStart => this != TimingConfidence.timeUnpublished;

  /// Whether the END time is source-backed. When false the UI must qualify any
  /// finish time it shows, and must not compute a "time remaining" from it.
  bool get hasPublishedEnd =>
      this == TimingConfidence.exactTime ||
      this == TimingConfidence.fullEventConfirmed;
}

/// One scheduled run of an [AonEvent].
///
/// Several official activities run **more than once** with gaps in between —
/// the Physics magic show runs 5:00–5:45pm, 6:15–7:00pm *and* 8:45–9:30pm.
/// Modelling those as three separate events would show the same title three
/// times in the programme and break "happening now" de-duplication, so an
/// event owns a list of sessions instead.
@immutable
class EventSession {
  const EventSession({
    required this.start,
    required this.end,
    this.timing = TimingConfidence.exactTime,
    this.note,
  });

  final DateTime start;

  /// The finish time. Only meaningful when [timing] says it is published —
  /// otherwise this is a bounding stand-in (the event close) kept so list
  /// ordering and layout have something to work with, and it must NOT be shown
  /// or reasoned about as a real finish. See [hasPublishedEnd].
  final DateTime end;

  /// What the official programme actually publishes about this session.
  final TimingConfidence timing;

  /// e.g. 'Sessions run about every 20 minutes'.
  final String? note;

  /// Provenance of these times, DERIVED from [timing] so the two can never
  /// disagree. Retained because the detail screen and event card already render
  /// an "approximate — to be confirmed" badge off it.
  DataConfidence get timeConfidence => timing.hasPublishedEnd
      ? DataConfidence.confirmed
      : DataConfidence.placeholder;

  bool get hasPublishedStart => timing.hasPublishedStart;
  bool get hasPublishedEnd => timing.hasPublishedEnd;

  /// True when the programme publishes no time at all for this session, so it
  /// can be neither "happening now" nor "up next".
  bool get isUnscheduled => timing == TimingConfidence.timeUnpublished;

  Duration get duration => end.difference(start);

  /// Whether this session is running at [t].
  ///
  /// An unscheduled session is NEVER running: it has no published start, so
  /// claiming it is under way would be an invention. Everything else uses the
  /// real published start; for [TimingConfidence.startOnly] the end is a bound
  /// rather than a fact, which the UI qualifies rather than the clock.
  bool containsTime(DateTime t) {
    if (isUnscheduled) return false;
    return !t.isBefore(start) && t.isBefore(end);
  }

  bool startsWithin(DateTime now, Duration window) {
    if (isUnscheduled) return false;
    if (!start.isAfter(now)) return false;
    return start.difference(now) <= window;
  }
}

/// A single activity, talk, keynote or featured presentation.
@immutable
class AonEvent {
  const AonEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.sessions,
    required this.venueId,
    this.room,
    this.presenter,
    this.mapReference,
    this.bookingRequired = false,
    this.bookingNote,
    this.tags = const [],
    this.sourceNote,
  });

  final String id;
  final String title;
  final String description;
  final EventCategory category;

  /// One or more scheduled runs. Never empty.
  final List<EventSession> sessions;

  /// Foreign key into the venue registry.
  final String venueId;

  /// Room or theatre within the venue, where the programme states one.
  final String? room;

  /// Speaker name, for talks/keynote.
  final String? presenter;

  /// Legend letter from the official printed map (A–I), if applicable.
  final String? mapReference;

  final bool bookingRequired;
  final String? bookingNote;
  final List<String> tags;

  /// Where this record came from — quoted in `docs/data-sources.md` and
  /// surfaced in debug builds.
  final String? sourceNote;

  DateTime get firstStart =>
      sessions.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime get lastEnd =>
      sessions.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);

  bool get hasMultipleSessions => sessions.length > 1;

  /// Whether any session is running at [now].
  bool isRunningAt(DateTime now) => sessions.any((s) => s.containsTime(now));

  /// The next session that starts strictly after [now], or null.
  ///
  /// Unscheduled sessions are excluded: their `start` is a stand-in, so
  /// offering one as "next" would announce a start time nobody published.
  EventSession? nextSessionAfter(DateTime now) {
    final upcoming = sessions
        .where((s) => !s.isUnscheduled && s.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// True when the programme publishes no time for ANY session of this event,
  /// so it cannot be placed on a timeline at all.
  bool get isUnscheduled => sessions.every((s) => s.isUnscheduled);

  /// The session currently running at [now], or null.
  EventSession? sessionAt(DateTime now) {
    for (final s in sessions) {
      if (s.containsTime(now)) return s;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AonEvent && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AonEvent($id, $title)';
}

/// Programme categories, matching the section headings used in the official
/// programme so the app's language matches the printed material.
enum EventCategory {
  activity('Activities'),
  shortTalk('Short talks'),
  keynote('Keynote lecture'),
  featuredPresentation('Featured presentations');

  const EventCategory(this.label);

  final String label;
}
