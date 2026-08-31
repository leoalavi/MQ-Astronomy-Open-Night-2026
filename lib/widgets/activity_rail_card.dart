import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/utils/bidi.dart';
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

  /// Width actually available to the card's content.
  ///
  /// [width] minus the left padding and the right gutter reserved for the
  /// floating save button. TimingBadge needs this to decide whether the
  /// countdown fits; at 196pt it does not, and a half-printed countdown is
  /// misinformation rather than a cosmetic clip.
  static const double contentWidth =
      width - AonSpacing.space4 - AonSpacing.minTapTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final event = timed.event;
    final venue = ref.watch(venueByIdProvider(event.venueId));
    final accent = VenueStyle.colorForEventCategory(context, event.category);

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
                        trailingText: _countdown(l),
                        maxWidth: contentWidth,
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
                            venue == null
                                ? l.infoLocationToBeConfirmed
                                : Bidi.isolate(venue.chipLabel),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.aon.contentSecondary,
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
                        Icon(
                          Icons.schedule_rounded,
                          size: AonSpacing.iconSm,
                          color: context.aon.contentTertiary,
                        ),
                        const SizedBox(width: AonSpacing.space2),
                        Expanded(
                          child: Text(
                            timed.session == null
                                ? TimeFormat.allSessionsLabel(l, event)
                                : TimeFormat.sessionLabel(l, timed.session!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.aon.contentTertiary,
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

  String? _countdown(AonL10n l) {
    final session = timed.session;
    if (session == null) return null;
    return switch (timed.timing) {
// A countdown to the finish is only honest when the finish is published.
// For a "4.15pm start, no finish time" entry the end is our own bound, so
// "ends in 2 hr" would be a number the programme never printed.
EventTiming.happeningNow => session.hasPublishedEnd
    ? TimeFormat.remaining(l, now, session.end)
    : null,
EventTiming.startingSoon => TimeFormat.until(l, now, session.start),
      // Only present a start time the programme actually published. For an
      // "open all night" activity (no set opening times) the start is a 4pm
      // stand-in, and "· 4pm" would both invent a time and contradict the
      // card's own "Open all night" line — the start-side twin of the
      // hasPublishedEnd countdown gate above.
      EventTiming.upcoming =>
        session.hasPublishedStart ? TimeFormat.time(session.start) : null,
      EventTiming.finished => null,
      EventTiming.unscheduled => null, // nothing to count down to
    };
  }
}
