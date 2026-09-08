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
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/section_header.dart';
import 'package:aon2026/utils/haptics.dart';

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
        // Scrolling the programme puts the keyboard away too — the gesture a
        // visitor reaches for first once they have typed their query.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
        // Dismiss the keyboard when the search is submitted, and when the
        // visitor taps anywhere outside the field.
        //
        // Flutter's default tap-outside action deliberately does NOT unfocus
        // for *touch* pointers on iOS and Android (see
        // `EditableTextTapOutsideAction` in editable_text.dart) — so on a phone
        // the keyboard stayed up over the results no matter where you tapped,
        // and the only escape was the system back gesture. Reported
        // 2026-09-08. The field has to opt in.
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
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

/// Two compact filter controls under the search field: one for START TIME, one
/// for ACTIVITY. Each opens a bottom sheet of options with a checkmark on the
/// selection; the button shows the chosen value (or the placeholder when All).
///
/// This replaced a permanently-visible chip row for every band/category/venue —
/// two dropdowns read more clearly on a phone and keep the screen uncluttered,
/// and the time axis is now honest START-TIME buckets, not 2-hour overlaps.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  /// "4pm" for hour 16 — localised (Persian digits/meridiem) via [TimeFormat].
  /// Only the hour matters, so the date is arbitrary.
  static String hourLabel(int hour) => TimeFormat.time(DateTime(2026, 1, 1, hour));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final filter = ref.watch(eventFilterProvider);
    final notifier = ref.read(eventFilterProvider.notifier);
    final events = ref.watch(eventsProvider);
    final hours = EventFilterService.availableStartHours(events);
    final hasNight = EventFilterService.hasOnTheNight(events);

    final timeActive = filter.startHour != null || filter.onTheNight;
    final timeLabel = filter.onTheNight
        ? l.timingOnTheNight
        : filter.startHour != null
            ? hourLabel(filter.startHour!)
            : l.programFilterByTime;

    final activityActive = filter.categories.isNotEmpty;
    final activityLabel =
        activityActive ? filter.categories.first.labelOf(l) : l.programFilterByActivity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AonSpacing.space4,
        AonSpacing.space1,
        AonSpacing.space4,
        AonSpacing.space2,
      ),
      // IntrinsicHeight + stretch keeps both controls the same height even when
      // one label wraps to a second line (e.g. "Filter by activity" at a narrow
      // width or large text), so the pair stays visually balanced.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _FilterButton(
                keyValue: 'program-time-filter',
              icon: Icons.schedule_rounded,
              label: timeLabel,
              active: timeActive,
              onTap: () => _showFilterSheet(
                context,
                title: l.programFilterByTime,
                options: [
                  _FilterOption(
                    label: l.programAllTimes,
                    selected: !timeActive,
                    onSelect: notifier.setAllTimes,
                  ),
                  for (final h in hours)
                    _FilterOption(
                      label: hourLabel(h),
                      selected: !filter.onTheNight && filter.startHour == h,
                      onSelect: () => notifier.setStartHour(h),
                    ),
                  if (hasNight)
                    _FilterOption(
                      label: l.timingOnTheNight,
                      selected: filter.onTheNight,
                      onSelect: notifier.setOnTheNight,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: _FilterButton(
              keyValue: 'program-activity-filter',
              icon: Icons.interests_rounded,
              label: activityLabel,
              active: activityActive,
              onTap: () => _showFilterSheet(
                context,
                title: l.programFilterByActivity,
                options: [
                  _FilterOption(
                    label: l.programAllActivities,
                    selected: !activityActive,
                    onSelect: () => notifier.setCategory(null),
                  ),
                  for (final c in EventCategory.values)
                    _FilterOption(
                      label: c.labelOf(l),
                      selected: filter.categories.contains(c),
                      onSelect: () => notifier.setCategory(c),
                    ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context, {
    required String title,
    required List<_FilterOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AonSpacing.space5,
            0,
            AonSpacing.space5,
            AonNavMetrics.clearance(sheetContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: AonSpacing.space2),
              for (final o in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.label),
                  selected: o.selected,
                  trailing: o.selected
                      ? Icon(Icons.check_rounded, color: sheetContext.aon.accent)
                      : null,
                  onTap: () {
                    AonHaptics.select();
                    Navigator.of(sheetContext).pop();
                    o.onSelect();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onSelect,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelect;
}

/// A pill that shows a filter dimension and its current value. Filled-tonal when
/// a value is chosen, outlined when it is "All".
///
/// The default labels ("Filter by time" / "Filter by activity") are long for a
/// half-width control, so the button uses compact padding and a tight icon gap,
/// and the label may WRAP to a second line rather than truncate — the full text
/// is always shown. `IntrinsicHeight` on the parent Row keeps the two controls
/// the same height when only one wraps. The Row flips for RTL.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.keyValue,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String keyValue;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  // Trim the button's generous default horizontal padding so the label wins the
  // room it needs; the min tap target is preserved by the theme's visual density.
  static const ButtonStyle _compact = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: AonSpacing.space2,
        vertical: AonSpacing.space2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AonSpacing.iconSm),
        const SizedBox(width: AonSpacing.space1),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            // Two lines so the full default labels always fit; ellipsis is a
            // last resort that these labels never reach.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.arrow_drop_down_rounded),
      ],
    );
    return active
        ? FilledButton.tonal(
            key: Key(keyValue),
            style: _compact,
            onPressed: onTap,
            child: content,
          )
        : OutlinedButton(
            key: Key(keyValue),
            style: _compact,
            onPressed: onTap,
            child: content,
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
        onSelectionChanged: (s) {
          AonHaptics.select();
          ref.read(programViewProvider.notifier).set(s.first);
        },
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
    // Activities the official programme gives no time for. They stay fully
    // discoverable here — just never claimed to be running or upcoming.
    final unscheduled = WhatsOnService.inBucket(timed, EventTiming.unscheduled);

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
          // "On the night" first: these have no published clock time, so a
          // visitor cannot place them on the timeline themselves — surfacing
          // them ahead of the scheduled sessions is the honest order (§4). A
          // clock-band filter excludes them, so this only leads the no-filter
          // and "On the night" views.
          _Bucket(
            title: l.programTimeNotPublishedHeading,
            subtitle: l.programTimeNotPublishedBlurb,
            items: unscheduled,
            timing: EventTiming.unscheduled,
            now: now,
            icon: Icons.help_outline_rounded,
            iconColor: context.aon.contentTertiary,
          ),
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
