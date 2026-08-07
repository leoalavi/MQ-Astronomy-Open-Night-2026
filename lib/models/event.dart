import 'package:flutter/foundation.dart';

import 'package:aon2026/models/data_confidence.dart';

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
    this.timeConfidence = DataConfidence.confirmed,
    this.note,
  });

  final DateTime start;
  final DateTime end;

  /// Provenance of these times. `placeholder` where the programme gives a
  /// start time but no end (we assume the event close), or no time at all.
  final DataConfidence timeConfidence;

  /// e.g. 'Sessions run about every 20 minutes'.
  final String? note;

  Duration get duration => end.difference(start);

  bool containsTime(DateTime t) =>
      !t.isBefore(start) && t.isBefore(end);

  bool startsWithin(DateTime now, Duration window) {
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
  EventSession? nextSessionAfter(DateTime now) {
    final upcoming = sessions.where((s) => s.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

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
