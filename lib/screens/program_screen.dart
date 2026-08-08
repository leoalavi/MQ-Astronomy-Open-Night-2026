import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/section_header.dart';

/// The full programme, with search and filters by time, category and location.
class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFilterProvider);
    final grouped = ref.watch(groupedEventsProvider);
    final total = ref.watch(filteredEventsProvider).length;
    final allTotal = ref.watch(eventsProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program'),
        actions: [
          if (!filter.isEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(eventFilterProvider.notifier).clear(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          const _SearchField(),
          const _FilterBar(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AonSpacing.space4,
              vertical: AonSpacing.space2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filter.isEmpty
                        ? '$allTotal items in the program'
                        : '$total of $allTotal shown',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AonColors.contentTertiary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches',
                    message:
                        'Try removing a filter or searching for something '
                        'else.',
                    actionLabel: 'Clear filters',
                    onAction: () =>
                        ref.read(eventFilterProvider.notifier).clear(),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      AonSpacing.space4,
                      0,
                      AonSpacing.space4,
                      AonNavMetrics.clearance(context),
                    ),
                    children: [
                      for (final entry in grouped.entries) ...[
                        SectionHeader(
                          title: entry.key.label,
                          count: entry.value.length,
                          icon: VenueStyle.iconForEventCategory(entry.key),
                          iconColor:
                              VenueStyle.colorForEventCategory(entry.key),
                        ),
                        for (final event in entry.value) ...[
                          EventCard(
                            event: event,
                            onTap: () => context.push(
                              Routes.eventDetailFor(event.id),
                            ),
                          ),
                          const SizedBox(height: AonSpacing.space3),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(eventFilterProvider).query,
    );
    _showClear = _controller.text.isNotEmpty;
    // Rebuild only when the field flips between empty and non-empty, so the
    // clear button appears and disappears in step with what the user types.
    // Nothing else here watches the field, so without this the clear button
    // would show stale state until an unrelated rebuild happened to occur.
    _controller.addListener(_syncClearButton);
  }

  void _syncClearButton() {
    final show = _controller.text.isNotEmpty;
    if (show != _showClear) setState(() => _showClear = show);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncClearButton);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync when the filter is cleared from elsewhere
    // (the app-bar Clear button), without fighting the user's own typing.
    ref.listen(eventFilterProvider, (previous, next) {
      if (next.query != _controller.text) {
        _controller.text = next.query;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AonSpacing.space4,
        AonSpacing.space2,
        AonSpacing.space4,
        AonSpacing.space2,
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) =>
            ref.read(eventFilterProvider.notifier).setQuery(value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search talks, activities, presenters',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _showClear
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    ref.read(eventFilterProvider.notifier).setQuery('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// Horizontally scrolling filter chips.
///
/// Chips rather than a filter sheet: with only three filter dimensions and a
/// handful of values each, a sheet would add a round-trip for no benefit, and
/// chips keep the active filters permanently visible — important when someone
/// puts the phone away mid-filter and comes back confused about why the
/// programme looks short.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(eventFilterProvider);
    final notifier = ref.read(eventFilterProvider.notifier);
    final venues = ref.watch(venuesWithEventsProvider);

    return SizedBox(
      height: 52,
      child: ListView(
        // Keyed so widget tests can scroll this specific horizontal list —
        // the screen has several Scrollables and `.first` is ambiguous.
        key: const Key('program-filter-bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AonSpacing.space4),
        children: [
          // Time bands
          for (final band in TimeBand.values) ...[
            FilterChip(
              label: Text(band.label),
              selected: filter.timeBands.contains(band),
              onSelected: (_) => notifier.toggleTimeBand(band),
              avatar: filter.timeBands.contains(band)
                  ? null
                  : const Icon(
                      Icons.schedule_rounded,
                      size: AonSpacing.iconSm,
                    ),
            ),
            const SizedBox(width: AonSpacing.space2),
          ],

          const _ChipDivider(),

          // Categories
          for (final category in EventCategory.values) ...[
            FilterChip(
              label: Text(category.label),
              selected: filter.categories.contains(category),
              onSelected: (_) => notifier.toggleCategory(category),
            ),
            const SizedBox(width: AonSpacing.space2),
          ],

          const _ChipDivider(),

          // Booking
          FilterChip(
            label: const Text('Pre-booked only'),
            selected: filter.bookableOnly,
            onSelected: notifier.setBookableOnly,
          ),
          const SizedBox(width: AonSpacing.space2),

          const _ChipDivider(),

          // Locations
          for (final venue in venues) ...[
            FilterChip(
              label: Text(venue.chipLabel),
              selected: filter.venueIds.contains(venue.id),
              onSelected: (_) => notifier.toggleVenue(venue.id),
              avatar: filter.venueIds.contains(venue.id)
                  ? null
                  : const Icon(
                      Icons.place_rounded,
                      size: AonSpacing.iconSm,
                    ),
            ),
            const SizedBox(width: AonSpacing.space2),
          ],
        ],
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AonSpacing.space2,
        vertical: AonSpacing.space3,
      ),
      child: VerticalDivider(width: 1, color: AonColors.night700),
    );
  }
}
