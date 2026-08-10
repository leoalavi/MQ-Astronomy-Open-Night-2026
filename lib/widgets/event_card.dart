import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';
import 'package:aon2026/widgets/save_button.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// The programme's list row.
///
/// Deliberately tall (well over the 56pt tap-target minimum) with a large
/// title. This is a list you scroll while walking, so the whole card is the
/// tap target rather than a small chevron on the right.
class EventCard extends ConsumerWidget {
  const EventCard({
    required this.event,
    required this.onTap,
    this.timing,
    this.now,
    super.key,
  });

  final AonEvent event;
  final VoidCallback onTap;

  /// When supplied, a status badge is shown. Used by What's On Now.
  final EventTiming? timing;

  /// Required alongside [timing] to render the countdown.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(event.venueId));
    final accent = VenueStyle.colorForEventCategory(event.category);

    final hasPlaceholderTime = event.sessions.any(
      (s) => s.timeConfidence == DataConfidence.placeholder,
    );

    // The save button is a **sibling** of the tactile button, never a child.
    // AonTactileButton wraps its subtree in MergeSemantics, so a nested
    // control would be absorbed into the card's single button node and become
    // invisible to screen readers. A Stack keeps two distinct, separately
    // labelled actions: "open this activity" and "save it".
    return Stack(
      children: [
        AonTactileButton(
          onTap: onTap,
          // matches the themed Card's corner radius
          borderRadius: AonSpacing.radiusMd,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              // Extra right padding reserves room for the floating save
              // button so a long category label never runs underneath it.
              padding: const EdgeInsets.fromLTRB(
                AonSpacing.space4,
                AonSpacing.space4,
                AonSpacing.minTapTarget,
                AonSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category + status row ──
                  //
                  // A Wrap, not a Row: the status badge ("Happening now · in 40
                  // min") can be as wide as the whole card, so on a narrow phone it
                  // drops onto its own line below the category instead of crushing
                  // the label to one character per line.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AonSpacing.space2,
                    runSpacing: AonSpacing.space2,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            VenueStyle.iconForEventCategory(event.category),
                            size: AonSpacing.iconSm,
                            color: accent,
                          ),
                          const SizedBox(width: AonSpacing.space2),
                          Flexible(
                            child: Text(
                              event.category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (timing != null)
                        TimingBadge(
                          timing: timing!,
                          trailingText: _countdown(),
                        ),
                    ],
                  ),
                  const SizedBox(height: AonSpacing.space3),

                  // ── Title ──
                  Text(event.title, style: theme.textTheme.titleLarge),

                  if (event.presenter != null) ...[
                    const SizedBox(height: AonSpacing.space1),
                    Text(
                      event.presenter!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AonColors.contentSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: AonSpacing.space3),

                  // ── Time ──
                  _MetaRow(
                    icon: Icons.schedule_rounded,
                    text: TimeFormat.allSessions(event),
                    // Amber-flag a time we inferred rather than one that was
                    // published, so nobody plans their evening around a guess.
                    warn: hasPlaceholderTime,
                  ),

                  const SizedBox(height: AonSpacing.space2),

                  // ── Location ──
                  _MetaRow(
                    icon: Icons.place_rounded,
                    text: [
                      if (event.room != null) event.room!,
                      venue?.name ?? 'Location to be confirmed',
                    ].join(' · '),
                  ),

                  if (event.bookingRequired) ...[
                    const SizedBox(height: AonSpacing.space3),
                    Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_rounded,
                          size: AonSpacing.iconSm,
                          color: AonColors.soon,
                        ),
                        const SizedBox(width: AonSpacing.space2),
                        Expanded(
                          child: Text(
                            'Pre-booking required',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AonColors.soon,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Top-right, clear of the card's own content padding. Sized to the
        // full 56pt tap target so it stays hittable one-handed in the dark.
        Positioned(
          top: AonSpacing.space1,
          right: AonSpacing.space1,
          child: SaveButton(eventId: event.id, eventTitle: event.title),
        ),
      ],
    );
  }

  String? _countdown() {
    if (now == null || timing == null) return null;
    final session = event.sessionAt(now!) ?? event.nextSessionAfter(now!);
    if (session == null) return null;

    return switch (timing!) {
      EventTiming.happeningNow => TimeFormat.remaining(
        now!,
        session.end,
      ).replaceFirst('ends ', ''),
      EventTiming.startingSoon => TimeFormat.until(now!, session.start),
      EventTiming.upcoming => TimeFormat.time(session.start),
      EventTiming.finished => null,
    };
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.warn = false});

  final IconData icon;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AonColors.soon : AonColors.contentSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AonSpacing.iconSm, color: color),
        const SizedBox(width: AonSpacing.space2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
