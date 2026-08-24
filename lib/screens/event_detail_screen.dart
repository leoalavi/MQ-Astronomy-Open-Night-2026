import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/save_button.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// Full detail for one programme item, plus the action to navigate to it.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final event = ref.watch(eventByIdProvider(eventId));

    // A deep link to a removed event (the cancelled Huntsman session is the
    // real case here) must land somewhere sensible, not crash.
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.detailNotFoundTitle)),
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: l.eventNotFoundTitle,
          message: l.eventNotFoundBody,
          actionLabel: l.actionBrowseProgram,
          onAction: () => context.go(Routes.program),
        ),
      );
    }

    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(event.venueId));
    final now = ref.watch(currentTimeProvider);
    final timed = WhatsOnService.classify(event, now);
    final accent = VenueStyle.colorForEventCategory(context, event.category);

    return Scaffold(
      appBar: AppBar(title: Text(event.category.labelOf(l))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonSpacing.space10,
        ),
        children: [
          // ── Status ──
          if (timed.timing != EventTiming.finished)
            // Row + Flexible gives the badge a bounded width (so it left-aligns
            // and ellipsizes rather than overflowing) without an unbounded
            // Align around it.
            Row(
              children: [
                Flexible(
                  child: TimingBadge(
                    timing: timed.timing,
                    trailingText: switch (timed.timing) {
                      EventTiming.happeningNow => TimeFormat.remaining(
                        l,
                        now,
                        timed.session!.end,
                      ),
                      EventTiming.startingSoon => TimeFormat.until(
                        l,
                        now,
                        timed.session!.start,
                      ),
                      _ => null,
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: AonSpacing.space4),

          // ── Title ──
          Text(event.title, style: theme.textTheme.displaySmall),

          if (event.presenter != null) ...[
            const SizedBox(height: AonSpacing.space2),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: AonSpacing.iconMd,
                  color: accent,
                ),
                const SizedBox(width: AonSpacing.space2),
                Expanded(
                  child: Text(
                    event.presenter!,
                    style: theme.textTheme.titleMedium?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AonSpacing.space5),

          // ── Description ──
          Text(Bidi.isolate(event.description), style: theme.textTheme.bodyLarge),

          const SizedBox(height: AonSpacing.space6),

          // ── Times ──
          _DetailBlock(
            icon: Icons.schedule_rounded,
            title: event.hasMultipleSessions
                ? l.detailSessionTimes
                : l.detailTime,
            children: [
              for (final session in event.sessions) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        TimeFormat.session(session),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (session.containsTime(now))
                      const Flexible(
                        child: TimingBadge(timing: EventTiming.happeningNow),
                      ),
                  ],
                ),
                if (session.note != null) ...[
                  const SizedBox(height: AonSpacing.space1),
                  Text(
                    Bidi.isolate(session.note),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.contentTertiary,
                    ),
                  ),
                ],
                ConfidenceNote(
                  confidence: session.timeConfidence,
                  compact: true,
                  message: l.detailUnpublishedTimes,
                ),
                const SizedBox(height: AonSpacing.space3),
              ],
            ],
          ),

          // ── Booking ──
          if (event.bookingRequired)
            Padding(
              padding: const EdgeInsets.only(bottom: AonSpacing.space4),
              child: Container(
                padding: const EdgeInsets.all(AonSpacing.space4),
                decoration: BoxDecoration(
                  color: context.aon.soon.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
                  border: Border.all(
                    color: context.aon.soon.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.confirmation_number_rounded,
                      color: context.aon.soon,
                      size: AonSpacing.iconMd,
                    ),
                    const SizedBox(width: AonSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.programPreBookingRequired,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: context.aon.soon,
                            ),
                          ),
                          if (event.bookingNote != null) ...[
                            const SizedBox(height: AonSpacing.space1),
                            Text(
                              Bidi.isolate(event.bookingNote),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.aon.contentSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Location ──
          _LocationBlock(event: event, venue: venue),

          // ── Tags ──
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: AonSpacing.space2),
            Wrap(
              spacing: AonSpacing.space2,
              runSpacing: AonSpacing.space2,
              children: [
                for (final tag in event.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
            ),
          ],

          // ── Provenance, for the team rather than attendees ──
          if (event.sourceNote != null) ...[
            const SizedBox(height: AonSpacing.space6),
            Text(
              l.eventSourceNote(event.sourceNote!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.aon.borderStrong,
              ),
            ),
          ],
        ],
      ),

      // ── Navigation action ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AonSpacing.space4),
          child: Row(
            children: [
              // Save is always available — it does not depend on the venue
              // being resolvable, so an activity with a to-be-confirmed
              // location can still be planned for.
              SaveButton.labelled(eventId: event.id, eventTitle: event.title),
              if (venue != null) ...[
                const SizedBox(width: AonSpacing.space3),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(Routes.googleNavTo('venue:${venue.id}')),
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: Text(l.actionWalkThere),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({required this.event, required this.venue});

  final AonEvent event;
  final Venue? venue;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    if (venue == null) {
      return _DetailBlock(
        icon: Icons.place_rounded,
        title: l.detailLocation,
        children: [
          Text(
            l.infoLocationToBeConfirmed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.aon.contentSecondary,
            ),
          ),
        ],
      );
    }

    final v = venue!;

    return _DetailBlock(
      icon: Icons.place_rounded,
      title: l.detailLocation,
      children: [
        if (event.room != null)
          Text(
            Bidi.isolate(event.room),
            style: theme.textTheme.titleMedium,
          ),
        Text(
          Bidi.isolate(v.name),
          style: event.room == null
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium?.copyWith(
                  color: context.aon.contentSecondary,
                ),
        ),
        if (v.building != null && v.building != v.name)
          Text(
            Bidi.isolate(v.building),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.aon.contentTertiary,
            ),
          ),
        if (event.mapReference != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.aon.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  event.mapReference!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.aon.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: Text(
                  l.eventMapReference(event.mapReference!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.aon.contentSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (v.notes != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Text(
            Bidi.isolate(v.notes),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.aon.contentSecondary,
            ),
          ),
        ],
        if (v.accessibilityNotes != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.accessible_rounded,
                size: AonSpacing.iconSm,
                color: context.aon.info,
              ),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  Bidi.isolate(v.accessibilityNotes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.aon.info,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AonSpacing.space3),
        ConfidenceNote(
          confidence: v.coordinateConfidence,
          compact: true,
          message: l.detailPositionUnconfirmed,
        ),
        const SizedBox(height: AonSpacing.space3),
        _VenueActions(venueId: v.id),
      ],
    );
  }
}

/// Map and 360° entry points for a venue.
///
/// The 360° button appears only when Raouf's panorama layer actually has a
/// tour for this venue — availability comes from `venuesWithPanoramaProvider`,
/// never from guessing an asset path. When there is no tour the button is
/// absent rather than disabled: a greyed-out control invites tapping and then
/// explains nothing.
class _VenueActions extends ConsumerWidget {
  const _VenueActions({required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final hasPanorama =
        ref.watch(featuresProvider).panorama &&
        ref.watch(venuesWithPanoramaProvider).contains(venueId);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            // Hand the venue over so the Map tab opens ON it — selected,
            // camera moved, sheet open — instead of just switching tabs.
            onPressed: () => context.go(Routes.mapFocus('venue:$venueId')),
            icon: const Icon(Icons.map_rounded, size: AonSpacing.iconSm),
            label: Text(l.actionShowOnMap),
          ),
        ),
        if (hasPanorama) ...[
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routes.panoramaFor(venueId)),
              icon: const Icon(
                Icons.threesixty_rounded,
                size: AonSpacing.iconSm,
              ),
              label: Text(l.detail360View),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AonSpacing.space4),
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space4),
        decoration: BoxDecoration(
          color: context.aon.surface,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: context.aon.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: AonSpacing.iconSm,
                  color: context.aon.contentTertiary,
                ),
                const SizedBox(width: AonSpacing.space2),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.aon.contentTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AonSpacing.space3),
            ...children,
          ],
        ),
      ),
    );
  }
}
