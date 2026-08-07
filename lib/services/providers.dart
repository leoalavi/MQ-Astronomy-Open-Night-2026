import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/parking_area.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/models/walking_route.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/services/whats_on_service.dart';

/// Data access for the app.
///
/// Everything is a plain synchronous `Provider` over a `const` Dart list —
/// there is no repository interface, no async loading and no cache.
///
/// That is a deliberate simplification against MQ Journey, which loads
/// `buildings.json` through a `BuildingRegistrySource` with an asset bundle
/// read, a JSON decode, a versioned `SharedPreferences` cache and an
/// `AsyncValue` wrapper. MQ Journey needs that: 170 buildings is a 127 KB file
/// that would jank the first frame, and its data changes between semesters.
/// This app has ~35 events and ~20 venues that are fixed on the day, so
/// compiling them into the binary removes an entire class of loading states,
/// error states and cache-invalidation bugs for no measurable cost.
///
/// If event data ever needs to change without an app release, the seam to
/// break is *here* — swap these for `FutureProvider`s and the UI keeps working
/// as long as it already handles `AsyncValue`.

// ── Raw data ─────────────────────────────────────────────

final eventsProvider = Provider<List<AonEvent>>((ref) => EventsData.all);

final venuesProvider = Provider<List<Venue>>((ref) => VenuesData.all);

final parkingProvider =
    Provider<List<ParkingArea>>((ref) => ParkingData.all);

final routesProvider = Provider<List<WalkingRoute>>((ref) => RoutesData.all);

// ── Lookups ──────────────────────────────────────────────

/// Venue by id. Returns null rather than throwing — a missing venue must
/// degrade to "location unavailable" in the UI, never crash the programme.
final venueByIdProvider = Provider.family<Venue?, String>((ref, id) {
  for (final v in ref.watch(venuesProvider)) {
    if (v.id == id) return v;
  }
  return null;
});

final eventByIdProvider = Provider.family<AonEvent?, String>((ref, id) {
  for (final e in ref.watch(eventsProvider)) {
    if (e.id == id) return e;
  }
  return null;
});

final parkingByIdProvider = Provider.family<ParkingArea?, String>((ref, id) {
  for (final p in ref.watch(parkingProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

/// Every event scheduled at a given venue.
final eventsAtVenueProvider =
    Provider.family<List<AonEvent>, String>((ref, venueId) {
  return ref
      .watch(eventsProvider)
      .where((e) => e.venueId == venueId)
      .toList()
    ..sort((a, b) => a.firstStart.compareTo(b.firstStart));
});

/// Venues that actually host at least one event — used to build the
/// programme's location filter, so it never offers a venue with nothing on.
final venuesWithEventsProvider = Provider<List<Venue>>((ref) {
  final events = ref.watch(eventsProvider);
  final ids = events.map((e) => e.venueId).toSet();
  return ref.watch(venuesProvider).where((v) => ids.contains(v.id)).toList();
});

// ── Programme filtering ──────────────────────────────────

final eventFilterProvider =
    NotifierProvider<EventFilterNotifier, EventFilter>(EventFilterNotifier.new);

class EventFilterNotifier extends Notifier<EventFilter> {
  @override
  EventFilter build() => const EventFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleCategory(EventCategory category) {
    final next = Set<EventCategory>.from(state.categories);
    next.contains(category) ? next.remove(category) : next.add(category);
    state = state.copyWith(categories: next);
  }

  void toggleVenue(String venueId) {
    final next = Set<String>.from(state.venueIds);
    next.contains(venueId) ? next.remove(venueId) : next.add(venueId);
    state = state.copyWith(venueIds: next);
  }

  void toggleTimeBand(TimeBand band) {
    final next = Set<TimeBand>.from(state.timeBands);
    next.contains(band) ? next.remove(band) : next.add(band);
    state = state.copyWith(timeBands: next);
  }

  void setBookableOnly(bool value) =>
      state = state.copyWith(bookableOnly: value);

  void clear() => state = const EventFilter();
}

/// The programme after filters are applied.
final filteredEventsProvider = Provider<List<AonEvent>>((ref) {
  return EventFilterService.apply(
    ref.watch(eventsProvider),
    ref.watch(eventFilterProvider),
  );
});

/// Filtered programme, grouped into the printed programme's sections.
final groupedEventsProvider =
    Provider<Map<EventCategory, List<AonEvent>>>((ref) {
  return EventFilterService.groupByCategory(ref.watch(filteredEventsProvider));
});

// ── What's On Now ────────────────────────────────────────

/// The whole programme classified against the current time, refreshed as the
/// clock ticks.
final timedEventsProvider = Provider<List<TimedEvent>>((ref) {
  // currentTimeProvider re-emits every 30s, so this reclassifies with it.
  final now = ref.watch(currentTimeProvider);
  return WhatsOnService.classifyAll(ref.watch(eventsProvider), now);
});

final happeningNowProvider = Provider<List<TimedEvent>>((ref) {
  return WhatsOnService.inBucket(
    ref.watch(timedEventsProvider),
    EventTiming.happeningNow,
  );
});

final startingSoonProvider = Provider<List<TimedEvent>>((ref) {
  return WhatsOnService.inBucket(
    ref.watch(timedEventsProvider),
    EventTiming.startingSoon,
  );
});

final upcomingProvider = Provider<List<TimedEvent>>((ref) {
  return WhatsOnService.inBucket(
    ref.watch(timedEventsProvider),
    EventTiming.upcoming,
  );
});

// ── Wayfinding ───────────────────────────────────────────

/// Routes departing from the selected start point.
final routesFromProvider =
    Provider.family<List<WalkingRoute>, String>((ref, fromId) {
  return ref.watch(routesProvider).where((r) => r.fromId == fromId).toList();
});

/// The currently selected wayfinding start point (a parking or venue id).
final selectedRouteStartProvider =
    NotifierProvider<SelectedIdNotifier, String?>(SelectedIdNotifier.new);

/// The currently selected wayfinding destination (a venue id).
final selectedRouteDestinationProvider =
    NotifierProvider<SelectedIdNotifier, String?>(SelectedIdNotifier.new);

/// Holds a single nullable selection id.
///
/// Riverpod 3 removed `StateProvider`, so this tiny notifier stands in for it.
/// Shared by both wayfinding endpoints — they have identical behaviour.
class SelectedIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  /// Selects [id], or clears the selection if [id] is already selected.
  /// This is what a chip tap does, so it lives here rather than in the widget.
  void toggle(String id) => state = state == id ? null : id;

  void clear() => state = null;
}

/// The route matching the current start/destination selection, if one exists.
///
/// Returns null when either end is unselected *or* when no predefined route
/// covers that pair. The UI must distinguish those two cases — "choose a
/// destination" and "we don't have directions for that yet" are very
/// different messages to show someone standing in a car park.
final selectedRouteProvider = Provider<WalkingRoute?>((ref) {
  final from = ref.watch(selectedRouteStartProvider);
  final to = ref.watch(selectedRouteDestinationProvider);
  if (from == null || to == null) return null;
  for (final r in ref.watch(routesProvider)) {
    if (r.fromId == from && r.toId == to) return r;
  }
  return null;
});
