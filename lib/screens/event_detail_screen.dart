import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// Full detail for one programme item, plus the action to navigate to it.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventByIdProvider(eventId));

    // A deep link to a removed event (the cancelled Huntsman session is the
    // real case here) must land somewhere sensible, not crash.
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'We can’t find that activity',
          message:
              'It may have been changed or removed from the program since '
              'this link was shared.',
          actionLabel: 'Browse the program',
          onAction: () => context.go(Routes.program),
        ),
      );
    }

    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(event.venueId));
    final now = ref.watch(currentTimeProvider);
    final timed = WhatsOnService.classify(event, now);
    final accent = VenueStyle.colorForEventCategory(event.category);

    return Scaffold(
      appBar: AppBar(title: Text(event.category.label)),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TimingBadge(
                timing: timed.timing,
                trailingText: switch (timed.timing) {
                  EventTiming.happeningNow => TimeFormat.remaining(
                      now,
                      timed.session!.end,
                    ).replaceFirst('ends ', ''),
                  EventTiming.startingSoon =>
                    TimeFormat.until(now, timed.session!.start),
                  _ => null,
                },
              ),
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AonSpacing.space5),

          // ── Description ──
          Text(event.description, style: theme.textTheme.bodyLarge),

          const SizedBox(height: AonSpacing.space6),

          // ── Times ──
          _DetailBlock(
            icon: Icons.schedule_rounded,
            title: event.hasMultipleSessions ? 'Session times' : 'Time',
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
                      const TimingBadge(timing: EventTiming.happeningNow),
                  ],
                ),
                if (session.note != null) ...[
                  const SizedBox(height: AonSpacing.space1),
                  Text(
                    session.note!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AonColors.contentTertiary),
                  ),
                ],
                ConfidenceNote(
                  confidence: session.timeConfidence,
                  compact: true,
                  message: 'These times are not published in the official '
                      'program — treat them as a guide.',
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
                  color: AonColors.soon.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
                  border: Border.all(
                    color: AonColors.soon.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.confirmation_number_rounded,
                      color: AonColors.soon,
                      size: AonSpacing.iconMd,
                    ),
                    const SizedBox(width: AonSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pre-booking required',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: AonColors.soon),
                          ),
                          if (event.bookingNote != null) ...[
                            const SizedBox(height: AonSpacing.space1),
                            Text(
                              event.bookingNote!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AonColors.contentSecondary,
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
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],

          // ── Provenance, for the team rather than attendees ──
          if (event.sourceNote != null) ...[
            const SizedBox(height: AonSpacing.space6),
            Text(
              'Source: ${event.sourceNote}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AonColors.night600),
            ),
          ],
        ],
      ),

      // ── Navigation action ──
      bottomNavigationBar: venue == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AonSpacing.space4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go(Routes.map),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('Show on map'),
                      ),
                    ),
                    const SizedBox(width: AonSpacing.space3),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          Routes.wayfindingTo(venue.id),
                        ),
                        icon: const Icon(Icons.directions_walk_rounded),
                        label: const Text('Walk there'),
                      ),
                    ),
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
    final theme = Theme.of(context);

    if (venue == null) {
      return _DetailBlock(
        icon: Icons.place_rounded,
        title: 'Location',
        children: [
          Text(
            'Location to be confirmed.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AonColors.contentSecondary),
          ),
        ],
      );
    }

    final v = venue!;

    return _DetailBlock(
      icon: Icons.place_rounded,
      title: 'Location',
      children: [
        if (event.room != null)
          Text(event.room!, style: theme.textTheme.titleMedium),
        Text(
          v.name,
          style: event.room == null
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium
                  ?.copyWith(color: AonColors.contentSecondary),
        ),
        if (v.building != null && v.building != v.name)
          Text(
            v.building!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentTertiary),
          ),
        if (event.mapReference != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AonColors.amber,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  event.mapReference!,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AonColors.onAccent),
                ),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: Text(
                  'Marked ${event.mapReference} on the printed event map',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AonColors.contentSecondary),
                ),
              ),
            ],
          ),
        ],
        if (v.notes != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Text(
            v.notes!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AonColors.contentSecondary),
          ),
        ],
        if (v.accessibilityNotes != null) ...[
          const SizedBox(height: AonSpacing.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.accessible_rounded,
                size: AonSpacing.iconSm,
                color: AonColors.stellar,
              ),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  v.accessibilityNotes!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AonColors.stellar),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AonSpacing.space3),
        ConfidenceNote(
          confidence: v.coordinateConfidence,
          compact: true,
          message: 'The exact position of this location is still being '
              'confirmed. Follow signage and ask at an information point.',
        ),
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
          color: AonColors.night900,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: AonColors.night700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: AonSpacing.iconSm,
                  color: AonColors.contentTertiary,
                ),
                const SizedBox(width: AonSpacing.space2),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AonColors.contentTertiary,
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
