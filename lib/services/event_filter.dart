import 'package:flutter/foundation.dart';

import 'package:aon2026/models/event.dart';

/// A time band used by the programme's time filter.
///
/// Bands are coarse and named for how people actually talk about the evening
/// ("we'll come after dinner"), rather than exposing an hour picker. The event
/// only runs for six hours — four buckets is enough resolution, and a chip row
/// is far easier to hit on a phone in the dark than a time slider.
enum TimeBand {
  earlyEvening('4–6pm', 16, 18),
  evening('6–8pm', 18, 20),
  lateEvening('8–10pm', 20, 22);

  const TimeBand(this.label, this.startHour, this.endHour);

  final String label;
  final int startHour;
  final int endHour;

  /// Whether any session of [event] overlaps this band on the event date.
  bool overlaps(AonEvent event) {
    for (final s in event.sessions) {
      final bandStart = DateTime(
        s.start.year,
        s.start.month,
        s.start.day,
        startHour,
      );
      final bandEnd = DateTime(
        s.start.year,
        s.start.month,
        s.start.day,
        endHour,
      );
      // Overlap test: session starts before band ends AND ends after band
      // starts. Using strict `isBefore`/`isAfter` means an event that finishes
      // exactly at 6pm does not show under the 6–8pm band.
      if (s.start.isBefore(bandEnd) && s.end.isAfter(bandStart)) {
        return true;
      }
    }
    return false;
  }
}

/// The state of the programme screen's filters.
@immutable
class EventFilter {
  const EventFilter({
    this.query = '',
    this.categories = const {},
    this.venueIds = const {},
    this.timeBands = const {},
    this.bookableOnly = false,
  });

  /// Free-text search over title, description, presenter, room and tags.
  final String query;

  /// Selected categories. Empty means "no category filter", i.e. show all.
  /// An empty set meaning "everything" rather than "nothing" is the
  /// convention throughout this class — it makes the default state
  /// (`const EventFilter()`) show the full programme, which is what a user
  /// opening the screen expects.
  final Set<EventCategory> categories;

  /// Selected venues. Empty means all.
  final Set<String> venueIds;

  /// Selected time bands. Empty means all.
  final Set<TimeBand> timeBands;

  /// Show only events that require pre-booking.
  final bool bookableOnly;

  bool get isEmpty =>
      query.trim().isEmpty &&
      categories.isEmpty &&
      venueIds.isEmpty &&
      timeBands.isEmpty &&
      !bookableOnly;

  /// Number of active filter groups — drives the "N filters" badge.
  int get activeCount =>
      (query.trim().isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (venueIds.isEmpty ? 0 : 1) +
      (timeBands.isEmpty ? 0 : 1) +
      (bookableOnly ? 1 : 0);

  EventFilter copyWith({
    String? query,
    Set<EventCategory>? categories,
    Set<String>? venueIds,
    Set<TimeBand>? timeBands,
    bool? bookableOnly,
  }) {
    return EventFilter(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      venueIds: venueIds ?? this.venueIds,
      timeBands: timeBands ?? this.timeBands,
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
      setEquals(other.timeBands, timeBands) &&
      other.bookableOnly == bookableOnly;

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(venueIds),
        Object.hashAllUnordered(timeBands),
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

  static bool _matches(AonEvent event, EventFilter filter) {
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(event.category)) {
      return false;
    }

    if (filter.venueIds.isNotEmpty &&
        !filter.venueIds.contains(event.venueId)) {
      return false;
    }

    if (filter.timeBands.isNotEmpty &&
        !filter.timeBands.any((band) => band.overlaps(event))) {
      return false;
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
    return event.title.toLowerCase().contains(q) ||
        event.description.toLowerCase().contains(q) ||
        (event.presenter?.toLowerCase().contains(q) ?? false) ||
        (event.room?.toLowerCase().contains(q) ?? false) ||
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
