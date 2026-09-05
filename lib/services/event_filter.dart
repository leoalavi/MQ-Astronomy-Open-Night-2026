import 'package:flutter/foundation.dart';

import 'package:aon2026/models/event.dart';
import 'package:aon2026/data/venues_data.dart';

/// Sentinel for the programme's "On the night" time option — events with no
/// honest published start (Open all night / no time at all). Kept distinct from
/// a real start hour so the time filter never fabricates a clock time for them.
///
/// The time filter is **start-time only**: an event belongs to an hour bucket
/// purely by the clock hour a genuinely-timed session starts in (see
/// [EventFilterService.startsInHour]). Finish times, durations and the 10pm
/// stand-in end are never consulted — a 4.15pm→10pm activity is a 4pm item, not
/// a 4/5/6/7/8pm one. Available-throughout and no-time activities are excluded
/// from every hour bucket and reachable only via [EventFilter.onTheNight].

/// The state of the programme screen's filters.
@immutable
class EventFilter {
  const EventFilter({
    this.query = '',
    this.categories = const {},
    this.venueIds = const {},
    this.startHour,
    this.onTheNight = false,
    this.bookableOnly = false,
  });

  /// Free-text search over title, description, presenter, room and tags.
  final String query;

  /// Selected activity categories. Empty means "no activity filter" (show all).
  /// The redesigned Program UI drives this single-select (0 or 1 entry), but the
  /// set is kept so an empty set still reads as "everything".
  final Set<EventCategory> categories;

  /// Selected venues. Empty means all. Retained in the model (and its tests);
  /// the redesigned Program UI no longer exposes a venue chip.
  final Set<String> venueIds;

  /// The selected START-TIME bucket: the clock hour (16..20) a genuinely-timed
  /// session must start in — 16 is the 4pm bucket (4:00–4:59). Null = all times.
  /// Finish time is never involved. Mutually exclusive with [onTheNight].
  final int? startHour;

  /// The "On the night" time option — Open-all-night / no-published-time items.
  /// Never combined with [startHour] (the time control is single-select).
  final bool onTheNight;

  /// Show only events that require pre-booking. Retained in the model (and its
  /// tests); the redesigned Program UI no longer exposes a booked chip.
  final bool bookableOnly;

  bool get isEmpty =>
      query.trim().isEmpty &&
      categories.isEmpty &&
      venueIds.isEmpty &&
      startHour == null &&
      !onTheNight &&
      !bookableOnly;

  /// Number of active filter groups — drives the "N filters" badge.
  int get activeCount =>
      (query.trim().isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (venueIds.isEmpty ? 0 : 1) +
      ((startHour == null && !onTheNight) ? 0 : 1) +
      (bookableOnly ? 1 : 0);

  /// Sentinel so [copyWith] can tell "keep the current [startHour]" apart from
  /// "set it to null" (the standard nullable-copyWith problem).
  static const Object _keep = Object();

  EventFilter copyWith({
    String? query,
    Set<EventCategory>? categories,
    Set<String>? venueIds,
    Object? startHour = _keep,
    bool? onTheNight,
    bool? bookableOnly,
  }) {
    return EventFilter(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      venueIds: venueIds ?? this.venueIds,
      startHour:
          identical(startHour, _keep) ? this.startHour : startHour as int?,
      onTheNight: onTheNight ?? this.onTheNight,
      bookableOnly: bookableOnly ?? this.bookableOnly,
    );
  }

  EventFilter cleared() => const EventFilter();

  @override
  bool operator ==(Object other) =>
      other is EventFilter &&
      other.query == query &&
      setEquals(other.categories, categories) &&
      setEquals(other.venueIds, venueIds) &&
      other.startHour == startHour &&
      other.onTheNight == onTheNight &&
      other.bookableOnly == bookableOnly;

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(venueIds),
        startHour,
        onTheNight,
        bookableOnly,
      );
}

/// Applies an [EventFilter] to the programme.
abstract final class EventFilterService {
  /// Filters [events].
  ///
  /// Groups combine with AND (a category *and* a venue), values within a group
  /// combine with OR (Theatre 3 *or* Theatre 4). That is the standard
  /// faceted-search contract and matches what the chip UI implies.
  static List<AonEvent> apply(List<AonEvent> events, EventFilter filter) {
    return events.where((e) => _matches(e, filter)).toList();
  }

  /// Whether [event] belongs to the "On the night" group — it has a session
  /// that is available-throughout ([EventSession.isFullEvent]) or has no
  /// published time ([EventSession.isUnscheduled]). Start time is irrelevant.
  static bool isOnTheNight(AonEvent event) =>
      event.sessions.any((s) => s.isUnscheduled || s.isFullEvent);

  /// Whether any GENUINELY-TIMED session of [event] STARTS in clock [hour]
  /// (16 = 4pm bucket, 4:00–4:59). Uses only the session start — finish time,
  /// duration and any stand-in end are never consulted, so a 4.15pm→10pm
  /// activity is a 4pm item only. Full-event / no-time sessions are excluded
  /// (they are reachable via "On the night", never an hour bucket).
  static bool startsInHour(AonEvent event, int hour) => event.sessions.any(
        (s) => !s.isUnscheduled && !s.isFullEvent && s.start.hour == hour,
      );

  /// The distinct start hours actually present in [events] (genuinely-timed
  /// sessions only), ascending — so the time filter offers only real buckets,
  /// never an empty hour.
  static List<int> availableStartHours(List<AonEvent> events) {
    final hours = <int>{};
    for (final e in events) {
      for (final s in e.sessions) {
        if (!s.isUnscheduled && !s.isFullEvent) hours.add(s.start.hour);
      }
    }
    return hours.toList()..sort();
  }

  /// Whether any event needs the "On the night" time option.
  static bool hasOnTheNight(List<AonEvent> events) => events.any(isOnTheNight);

  static bool _matches(AonEvent event, EventFilter filter) {
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(event.category)) {
      return false;
    }

    if (filter.venueIds.isNotEmpty &&
        !filter.venueIds.contains(event.venueId)) {
      return false;
    }

    // Time — START-TIME ONLY. "On the night" and an hour bucket are mutually
    // exclusive (single-select UI); neither ever consults a finish time.
    if (filter.onTheNight) {
      if (!isOnTheNight(event)) return false;
    } else if (filter.startHour != null) {
      if (!startsInHour(event, filter.startHour!)) return false;
    }

    if (filter.bookableOnly && !event.bookingRequired) {
      return false;
    }

    final q = filter.query.trim().toLowerCase();
    if (q.isNotEmpty && !_matchesQuery(event, q)) {
      return false;
    }

    return true;
  }

  static bool _matchesQuery(AonEvent event, String q) {
    // Venue is resolved here so a visitor can search the official venue name
    // ("Observatory", "Macquarie Theatre") — the name is data the event only
    // references by id, so without this lookup those searches found nothing.
    final venue = VenuesData.byId(event.venueId);
    return event.title.toLowerCase().contains(q) ||
        event.description.toLowerCase().contains(q) ||
        (event.presenter?.toLowerCase().contains(q) ?? false) ||
        (event.room?.toLowerCase().contains(q) ?? false) ||
        (venue?.name.toLowerCase().contains(q) ?? false) ||
        (venue?.shortName?.toLowerCase().contains(q) ?? false) ||
        (venue?.building?.toLowerCase().contains(q) ?? false) ||
        // The programme's own section names ("keynote", "short talk", …).
        event.category.label.toLowerCase().contains(q) ||
        (event.mapReference?.toLowerCase() == q) ||
        event.tags.any((t) => t.toLowerCase().contains(q));
  }

  /// Groups events by category, preserving [EventCategory] declaration order
  /// so the programme screen reads in the same order as the printed one.
  static Map<EventCategory, List<AonEvent>> groupByCategory(
    List<AonEvent> events,
  ) {
    final out = <EventCategory, List<AonEvent>>{};
    for (final category in EventCategory.values) {
      final matching = events.where((e) => e.category == category).toList()
        ..sort((a, b) {
          final byStart = a.firstStart.compareTo(b.firstStart);
          if (byStart != 0) return byStart;
          return a.title.compareTo(b.title);
        });
      if (matching.isNotEmpty) out[category] = matching;
    }
    return out;
  }
}
