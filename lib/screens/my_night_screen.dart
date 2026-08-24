import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/itinerary_service.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/section_header.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// The visitor's saved activities as a night timeline ("My Night").
///
/// Adapted from MQ Journey's "Your Day" concept, rebuilt for an evening event.
/// The screen answers one question — *where should I be, and when* — so it is
/// a single chronological list rather than a grouped programme. Anything
/// already finished collapses to the bottom.
class MyNightScreen extends ConsumerWidget {
  const MyNightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final terminology = ref.watch(terminologyProvider);
    final saved = ref.watch(savedEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(terminology.myPlan(l)),
        actions: [
          if ((saved.value ?? <String>{}).isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref, l),
              child: Text(l.actionClear),
            ),
        ],
      ),
      body: saved.when(
        // First read hits disk. A skeleton beats a spinner — the user sees the
        // shape of what is coming rather than an indeterminate wait.
        loading: () => const _TimelineSkeleton(),
        error: (_, _) =>
            _LoadFailed(onRetry: () => ref.invalidate(savedEventsProvider)),
        data: (_) => _Timeline(terminology: terminology),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    AonL10n l,
  ) async {
    final planName = ref.read(terminologyProvider).myPlan(l);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.myNightClearTitle(planName)),
        content: Text(l.myNightClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.actionClear),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(savedEventsProvider.notifier).clear();
    }
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.terminology});

  final EventTerminology terminology;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final remaining = ref.watch(itineraryRemainingProvider);
    final finished = ref.watch(itineraryFinishedProvider);
    final hasConflict = ref.watch(hasItineraryConflictProvider);

    if (remaining.isEmpty && finished.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline_rounded,
        title: terminology.myPlanEmpty(l),
        message: l.myNightEmptyBody,
        actionLabel: l.actionBrowseProgram,
        onAction: () => context.go(Routes.program),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AonSpacing.space4,
        AonSpacing.space2,
        AonSpacing.space4,
        AonSpacing.space16,
      ),
      children: [
        if (hasConflict) const _ConflictBanner(),

        if (remaining.isNotEmpty)
          for (final entry in remaining) ...[
            _ItineraryCard(entry: entry),
            const SizedBox(height: AonSpacing.space3),
          ]
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AonSpacing.space6),
            child: Text(
              l.myNightAllFinished,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ),

        if (finished.isNotEmpty) ...[
          SectionHeader(
            title: l.timingFinished,
            count: finished.length,
            icon: Icons.check_circle_outline_rounded,
            iconColor: context.aon.contentTertiary,
          ),
          for (final entry in finished) ...[
            _ItineraryCard(entry: entry, dimmed: true),
            const SizedBox(height: AonSpacing.space3),
          ],
        ],
      ],
    );
  }
}

/// One line on the timeline.
class _ItineraryCard extends ConsumerWidget {
  const _ItineraryCard({required this.entry, this.dimmed = false});

  final ItineraryEntry entry;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(entry.event.venueId));
    final accent = VenueStyle.colorForEventCategory(
      context,
      entry.event.category,
    );
    final now = ref.watch(currentTimeProvider);

    final titleColour = dimmed
        ? context.aon.contentTertiary
        : context.aon.contentPrimary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.eventDetailFor(entry.event.id)),
        child: Padding(
          padding: const EdgeInsets.all(AonSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Time + status ──
              // A Wrap, not a Row: Persian renders longer time strings, and a
              // Row here forced the session time and the status badge to share
              // a line they cannot both fit on. Wrapping drops the badge to the
              // next line instead of overflowing.
              Wrap(
                spacing: AonSpacing.space2,
                runSpacing: AonSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    TimeFormat.session(entry.session),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: dimmed ? context.aon.contentTertiary : accent,
                    ),
                  ),
                  TimingBadge(
                    timing: entry.timing,
                    trailingText: switch (entry.timing) {
                      EventTiming.happeningNow => TimeFormat.remaining(
                        l,
                        now,
                        entry.session.end,
                      ),
                      EventTiming.startingSoon => TimeFormat.until(
                        l,
                        now,
                        entry.session.start,
                      ),
                      _ => null,
                    },
                  ),
                ],
              ),

              const SizedBox(height: AonSpacing.space2),

              // ── Title ──
              Text(
                entry.event.title,
                style: theme.textTheme.titleLarge?.copyWith(color: titleColour),
              ),

              if (entry.isMultiSession) ...[
                const SizedBox(height: 2),
                Text(
                  l.myNightSessionOf(entry.sessionIndex, entry.sessionCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.aon.contentTertiary,
                  ),
                ),
              ],

              const SizedBox(height: AonSpacing.space2),

              // ── Where ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: AonSpacing.iconSm,
                    color: context.aon.contentSecondary,
                  ),
                  const SizedBox(width: AonSpacing.space2),
                  Expanded(
                    child: Text(
                      Bidi.joinIsolated([
                        Bidi.isolate(entry.event.room),
                        venue?.name ?? l.infoLocationToBeConfirmed,
                      ]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.aon.contentSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              if (entry.hasConflict) ...[
                const SizedBox(height: AonSpacing.space3),
                _ConflictNote(titles: entry.conflictsWith),
              ],

              const SizedBox(height: AonSpacing.space3),
              const Divider(height: 1),
              const SizedBox(height: AonSpacing.space2),

              // ── Actions ──
              Row(
                children: [
                  if (venue != null)
                    // Flexible: the localised label ("مسیر پیاده") is wider
                    // than the English one and must be allowed to ellipsize
                    // rather than push the delete button off the card.
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push(Routes.googleNavTo('venue:${venue.id}')),
                        icon: const Icon(
                          Icons.directions_walk_rounded,
                          size: AonSpacing.iconSm,
                        ),
                        label: Text(
                          l.actionWalkThere,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: l.actionRemoveFromPlan,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: context.aon.contentSecondary,
                    constraints: const BoxConstraints(
                      minWidth: AonSpacing.minTapTarget,
                      minHeight: AonSpacing.minTapTarget,
                    ),
                    onPressed: () => _remove(context, ref, l),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, AonL10n l) async {
    final planName = ref.read(terminologyProvider).myPlan(l);
    final id = entry.event.id;
    await ref.read(savedEventsProvider.notifier).remove(id);
    if (!context.mounted) return;

    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l.snackRemovedFrom(planName)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          // Undo matters here: the remove button sits next to "Walk there" on
          // a card being tapped in the dark.
          action: SnackBarAction(
            label: l.actionUndo,
            onPressed: () => ref.read(savedEventsProvider.notifier).toggle(id),
          ),
        ),
      );
  }
}

class _ConflictNote extends StatelessWidget {
  const _ConflictNote({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final list = titles.length == 1
        ? titles.single
        : l.listAnd(titles.take(titles.length - 1).join(', '), titles.last);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: AonSpacing.iconSm,
          color: context.aon.soon,
        ),
        const SizedBox(width: AonSpacing.space2),
        Expanded(
          child: Text(
            l.myNightConflictOverlaps(list),
            style: theme.textTheme.bodySmall?.copyWith(color: context.aon.soon),
          ),
        ),
      ],
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner();

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AonSpacing.space4),
      padding: const EdgeInsets.all(AonSpacing.space4),
      decoration: BoxDecoration(
        color: context.aon.soon.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        border: Border.all(color: context.aon.soon.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.aon.soon,
            size: AonSpacing.iconMd,
          ),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: Text(
              l.myNightConflictBanner,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder cards shown while the saved set loads from disk.
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AonSpacing.space4),
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AonSpacing.space3),
            child: Container(
              height: 132,
              decoration: BoxDecoration(
                color: context.aon.surface,
                borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
                border: Border.all(color: context.aon.border),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: l.myNightLoadFailedTitle,
      // No stack trace, no storage terminology — just what happened and what
      // the visitor can do about it.
      message: l.myNightLoadFailedBody,
      actionLabel: l.actionRetry,
      onAction: onRetry,
    );
  }
}
