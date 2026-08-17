import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/section_header.dart';

/// How the programme is grouped.
enum ProgramView {
  /// Time-sliced against the clock: happening now, starting soon, later.
  /// The default, because during the event "what can I still get to" beats
  /// "what categories exist".
  tonight,

  /// The printed programme's own sections. Better for planning ahead, and it
  /// matches the paper in the visitor's other hand.
  sections,
}

final programViewProvider = NotifierProvider<ProgramViewNotifier, ProgramView>(
  ProgramViewNotifier.new,
);

class ProgramViewNotifier extends Notifier<ProgramView> {
  @override
  ProgramView build() => ProgramView.tonight;

  void set(ProgramView view) => state = view;
}

/// The full programme, with search and filters by time, category and location.
class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final filter = ref.watch(eventFilterProvider);
    final grouped = ref.watch(groupedEventsProvider);
    final total = ref.watch(filteredEventsProvider).length;
    final allTotal = ref.watch(eventsProvider).length;
    final view = ref.watch(programViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(terminologyProvider).programLabel(l)),
        actions: [
          if (!filter.isEmpty)
            TextButton(
              onPressed: () => ref.read(eventFilterProvider.notifier).clear(),
              child: Text(l.actionClear),
            ),
        ],
      ),
      // A CustomScrollView, not a Column with an Expanded list.
      //
      // The search field, filter bar, view switcher and count row stack to
      // ~512pt at 200% text on a 320-wide phone — the whole screen. Under a
      // Column that left the programme itself a 56pt window: nothing
      // overflowed, so it looked fine to an overflow check, but the list was
      // unusable. As slivers the controls simply scroll away and the programme
      // gets the full viewport, which is what a visitor is here for.
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const _SearchField(),
                const _FilterBar(),
                const _ViewSwitcher(),
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
                              ? l.programItemCount(allTotal)
                              : l.programFilteredCount(total, allTotal),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.aon.contentTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (grouped.isEmpty)
            // remainingPaintExtent lets the empty state centre itself in
            // whatever space the header left, and grow past it when the copy is
            // too tall to fit — never clipped, never floating oddly high.
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.remainingPaintExtent,
                  ),
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l.programNoMatchTitle,
                    message: l.programNoMatchBody,
                    actionLabel: l.programClearFilters,
                    onAction: () =>
                        ref.read(eventFilterProvider.notifier).clear(),
                  ),
                ),
              ),
            )
          else
            switch (view) {
              ProgramView.tonight => const _TonightSliver(),
              ProgramView.sections => _SectionsSliver(grouped: grouped),
            },
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
    final l = AonL10n.of(context);
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
          hintText: l.programSearchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _showClear
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l.programClearSearch,
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
    final l = AonL10n.of(context);
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
              label: Text(band.labelOf(l)),
              selected: filter.timeBands.contains(band),
              onSelected: (_) => notifier.toggleTimeBand(band),
              avatar: filter.timeBands.contains(band)
                  ? null
                  : const Icon(Icons.schedule_rounded, size: AonSpacing.iconSm),
            ),
            const SizedBox(width: AonSpacing.space2),
          ],

          const _ChipDivider(),

          // Categories
          for (final category in EventCategory.values) ...[
            FilterChip(
              label: Text(category.labelOf(l)),
              selected: filter.categories.contains(category),
              onSelected: (_) => notifier.toggleCategory(category),
            ),
            const SizedBox(width: AonSpacing.space2),
          ],

          const _ChipDivider(),

          // Booking
          FilterChip(
            label: Text(l.programBookedOnly),
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
                  : const Icon(Icons.place_rounded, size: AonSpacing.iconSm),
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space2,
        vertical: AonSpacing.space3,
      ),
      child: VerticalDivider(width: 1, color: context.aon.border),
    );
  }
}

/// Switches between the time-sliced view and the printed programme's sections.
class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final view = ref.watch(programViewProvider);
    final terminology = ref.watch(terminologyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space4,
        vertical: AonSpacing.space2,
      ),
      child: SegmentedButton<ProgramView>(
        segments: [
          ButtonSegment(
            value: ProgramView.tonight,
            // "Tonight" / "Today" — event vocabulary, not hardcoded.
            label: Text(
              terminology.eventPeriod(l)[0].toUpperCase() +
                  terminology.eventPeriod(l).substring(1),
            ),
            icon: const Icon(Icons.schedule_rounded, size: AonSpacing.iconSm),
          ),
          ButtonSegment(
            value: ProgramView.sections,
            label: Text(l.programSections),
            icon: const Icon(Icons.list_alt_rounded, size: AonSpacing.iconSm),
          ),
        ],
        selected: {view},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            ref.read(programViewProvider.notifier).set(s.first),
      ),
    );
  }
}

/// The night timeline: what is on now, next, and later — the same buckets the
/// Home rails use, so the two screens can never disagree.
///
/// Applies the active filters, so search and chips work in this view too.
class _TonightSliver extends ConsumerWidget {
  const _TonightSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final now = ref.watch(currentTimeProvider);
    final filtered = ref.watch(filteredEventsProvider);
    final terminology = ref.watch(terminologyProvider);

    final timed = WhatsOnService.classifyAll(filtered, now);
    final happening = WhatsOnService.inBucket(timed, EventTiming.happeningNow);
    final soon = WhatsOnService.inBucket(timed, EventTiming.startingSoon);
    final later = WhatsOnService.inBucket(timed, EventTiming.upcoming);
    final finished = WhatsOnService.inBucket(timed, EventTiming.finished);

    // A sliver, not a ListView: ProgramScreen owns the single scroll view so
    // its header can scroll away. These children were never lazily built (this
    // was always `ListView(children:)`, which builds all of them), so nothing
    // is lost by delegating them as a list.
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AonSpacing.space4,
        0,
        AonSpacing.space4,
        AonNavMetrics.clearance(context),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _Bucket(
            title: l.timingHappeningNow,
            items: happening,
            timing: EventTiming.happeningNow,
            now: now,
            icon: Icons.circle,
            iconColor: context.aon.live,
          ),
          _Bucket(
            title: l.timingStartingSoon,
            subtitle: l.timingStartingWithin(
              WhatsOnService.soonWindow.inMinutes,
            ),
            items: soon,
            timing: EventTiming.startingSoon,
            now: now,
            icon: Icons.schedule_rounded,
            iconColor: context.aon.soon,
          ),
          _Bucket(
            title: terminology.laterLabel(
            l,
            beforeEventDay: ref.watch(eventPhaseProvider) == EventPhase.future,
          ),
            items: later,
            timing: EventTiming.upcoming,
            now: now,
            icon: Icons.more_time_rounded,
            iconColor: context.aon.contentTertiary,
          ),
          _Bucket(
            title: l.timingFinished,
            items: finished,
            timing: EventTiming.finished,
            now: now,
            icon: Icons.check_circle_outline_rounded,
            iconColor: context.aon.contentTertiary,
          ),
        ]),
      ),
    );
  }
}

class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.title,
    required this.items,
    required this.timing,
    required this.now,
    required this.icon,
    required this.iconColor,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<TimedEvent> items;
  final EventTiming timing;
  final DateTime now;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          count: items.length,
          icon: icon,
          iconColor: iconColor,
        ),
        for (final item in items) ...[
          EventCard(
            event: item.event,
            timing: timing,
            now: now,
            onTap: () => context.push(Routes.eventDetailFor(item.event.id)),
          ),
          const SizedBox(height: AonSpacing.space3),
        ],
      ],
    );
  }
}

/// The printed programme's own sections.
class _SectionsSliver extends StatelessWidget {
  const _SectionsSliver({required this.grouped});

  final Map<EventCategory, List<AonEvent>> grouped;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    // A sliver, not a ListView: ProgramScreen owns the single scroll view so
    // its header can scroll away. These children were never lazily built (this
    // was always `ListView(children:)`, which builds all of them), so nothing
    // is lost by delegating them as a list.
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AonSpacing.space4,
        0,
        AonSpacing.space4,
        AonNavMetrics.clearance(context),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final entry in grouped.entries) ...[
            SectionHeader(
              title: entry.key.labelOf(l),
              count: entry.value.length,
              icon: VenueStyle.iconForEventCategory(entry.key),
              iconColor: VenueStyle.colorForEventCategory(context, entry.key),
            ),
            for (final event in entry.value) ...[
              EventCard(
                event: event,
                onTap: () => context.push(Routes.eventDetailFor(event.id)),
              ),
              const SizedBox(height: AonSpacing.space3),
            ],
          ],
        ]),
      ),
    );
  }
}
