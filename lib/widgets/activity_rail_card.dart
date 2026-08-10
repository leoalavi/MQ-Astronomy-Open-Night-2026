import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/save_button.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// A compact activity card for Home's horizontal rails.
///
/// Narrower and shorter than the programme's [EventCard] because a rail shows
/// three or four at a glance. It carries only what decides "do I walk over
/// there right now": status, title, time, place — plus the save action, so a
/// visitor can build their night without leaving Home.
class ActivityRailCard extends ConsumerWidget {
  const ActivityRailCard({required this.timed, required this.now, super.key});

  final TimedEvent timed;
  final DateTime now;

  /// Fixed width so the rail scrolls predictably and peeks the next card,
  /// which is what tells people the row scrolls at all.
  static const double width = 268;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final event = timed.event;
    final venue = ref.watch(venueByIdProvider(event.venueId));
    final accent = VenueStyle.colorForEventCategory(event.category);

    // Same structure as EventCard: the save button is a sibling of the
    // tactile button, so both remain separately reachable to screen readers.
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          AonTactileButton(
            onTap: () => context.push(Routes.eventDetailFor(event.id)),
            borderRadius: AonSpacing.radiusMd,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AonSpacing.space4,
                  AonSpacing.space4,
                  AonSpacing.minTapTarget,
                  AonSpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TimingBadge(
                        timing: timed.timing,
                        trailingText: _countdown(),
                      ),
                    ),
                    const SizedBox(height: AonSpacing.space2),
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AonSpacing.space2),
                    Row(
                      children: [
                        Icon(
                          VenueStyle.iconForEventCategory(event.category),
                          size: AonSpacing.iconSm,
                          color: accent,
                        ),
                        const SizedBox(width: AonSpacing.space2),
                        Expanded(
                          child: Text(
                            venue?.chipLabel ?? 'Location to be confirmed',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AonColors.contentSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AonSpacing.space1),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: AonSpacing.iconSm,
                          color: AonColors.contentTertiary,
                        ),
                        const SizedBox(width: AonSpacing.space2),
                        Expanded(
                          child: Text(
                            timed.session == null
                                ? TimeFormat.allSessions(event)
                                : TimeFormat.session(timed.session!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AonColors.contentTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: AonSpacing.space1,
            right: AonSpacing.space1,
            child: SaveButton(eventId: event.id, eventTitle: event.title),
          ),
        ],
      ),
    );
  }

  String? _countdown() {
    final session = timed.session;
    if (session == null) return null;
    return switch (timed.timing) {
      EventTiming.happeningNow => TimeFormat.remaining(
        now,
        session.end,
      ).replaceFirst('ends ', ''),
      EventTiming.startingSoon => TimeFormat.until(now, session.start),
      EventTiming.upcoming => TimeFormat.time(session.start),
      EventTiming.finished => null,
    };
  }
}
