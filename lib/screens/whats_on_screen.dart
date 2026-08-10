import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/event_card.dart';
import 'package:aon2026/widgets/section_header.dart';

/// Time-aware view of the programme: what is on right now, what starts soon,
/// and what is still to come.
class WhatsOnScreen extends ConsumerWidget {
  const WhatsOnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final now = ref.watch(currentTimeProvider);
    final simulated = ref.watch(simulatedTimeProvider);

    final happening = ref.watch(happeningNowProvider);
    final soon = ref.watch(startingSoonProvider);
    final upcoming = ref.watch(upcomingProvider);

    final beforeEvent = now.isBefore(EventInfo.startsAt);
    final afterEvent = !now.isBefore(EventInfo.endsAt);

    // All-evening drop-ins are split out from timed sessions. Mixing a
    // six-hour exhibition in with "keynote starts in 8 minutes" buries the
    // thing the user needs.
    final happeningTimed =
        happening.where((t) => !t.isAllEvening).toList();
    final happeningDropIn =
        happening.where((t) => t.isAllEvening).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('What’s On Now'),
        actions: [
          IconButton(
            tooltip: 'Preview event night',
            icon: Icon(
              simulated == null
                  ? Icons.science_outlined
                  : Icons.science_rounded,
              color: simulated == null ? null : context.aon.soon,
            ),
            onPressed: () => _openTimeSimulator(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space4,
          0,
          AonSpacing.space4,
          AonNavMetrics.clearance(context),
        ),
        children: [
          _NowBanner(now: now, simulated: simulated != null),

          if (beforeEvent || afterEvent)
            _OutsideEventNotice(
              beforeEvent: beforeEvent,
              onPreview: () => ref
                  .read(simulatedTimeProvider.notifier)
                  .set(EventInfo.previewInstant),
            ),

          if (!beforeEvent && !afterEvent) ...[
            if (happeningTimed.isEmpty &&
                happeningDropIn.isEmpty &&
                soon.isEmpty &&
                upcoming.isEmpty)
              const EmptyState(
                icon: Icons.nightlight_round,
                title: 'Nothing scheduled right now',
                message: 'Check the full program for the rest of the night.',
              ),

            _Bucket(
              title: l.timingHappeningNow,
              timing: EventTiming.happeningNow,
              items: happeningTimed,
              now: now,
              icon: Icons.circle,
              iconColor: context.aon.live,
            ),
            _Bucket(
              title: l.timingOpenAllEvening,
              subtitle: 'Drop in any time — no session times',
              timing: EventTiming.happeningNow,
              items: happeningDropIn,
              now: now,
              icon: Icons.all_inclusive_rounded,
              iconColor: context.aon.info,
            ),
            _Bucket(
              title: l.timingStartingSoon,
              subtitle:
                  'In the next ${WhatsOnService.soonWindow.inMinutes} minutes',
              timing: EventTiming.startingSoon,
              items: soon,
              now: now,
              icon: Icons.schedule_rounded,
              iconColor: context.aon.soon,
            ),
            _Bucket(
              title: l.timingLaterTonight,
              timing: EventTiming.upcoming,
              items: upcoming,
              now: now,
              icon: Icons.more_time_rounded,
              iconColor: context.aon.contentTertiary,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openTimeSimulator(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TimeSimulatorSheet(),
    );
  }
}

class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.title,
    required this.timing,
    required this.items,
    required this.now,
    required this.icon,
    required this.iconColor,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final EventTiming timing;
  final List<TimedEvent> items;
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
            onTap: () => context.push(
              Routes.eventDetailFor(item.event.id),
            ),
          ),
          const SizedBox(height: AonSpacing.space3),
        ],
      ],
    );
  }
}

class _NowBanner extends StatelessWidget {
  const _NowBanner({required this.now, required this.simulated});

  final DateTime now;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = simulated ? context.aon.soon : context.aon.contentTertiary;

    return Padding(
      padding: const EdgeInsets.only(top: AonSpacing.space2),
      child: Row(
        children: [
          Icon(
            simulated ? Icons.science_rounded : Icons.access_time_rounded,
            size: AonSpacing.iconSm,
            color: color,
          ),
          const SizedBox(width: AonSpacing.space2),
          Expanded(
            child: Text(
              simulated
                  ? 'Previewing ${TimeFormat.time(now)} on event night'
                  : '${TimeFormat.time(now)} · '
                      '${TimeFormat.date(now)}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutsideEventNotice extends StatelessWidget {
  const _OutsideEventNotice({
    required this.beforeEvent,
    required this.onPreview,
  });

  final bool beforeEvent;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AonSpacing.space5),
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space5),
        decoration: BoxDecoration(
          color: context.aon.surface,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: context.aon.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              beforeEvent
                  ? Icons.event_available_rounded
                  : Icons.nightlight_round,
              size: AonSpacing.iconLg,
              color: context.aon.accent,
            ),
            const SizedBox(height: AonSpacing.space3),
            Text(
              beforeEvent
                  ? 'The event hasn’t started yet'
                  : 'That’s a wrap',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AonSpacing.space2),
            Text(
              beforeEvent
                  ? 'Astronomy Open Night runs on '
                      '${TimeFormat.longDate(EventInfo.startsAt)}, '
                      '${TimeFormat.range(
                      EventInfo.startsAt,
                      EventInfo.endsAt,
                    )}. '
                      'This screen comes alive on the night.'
                  : 'Astronomy Open Night 2026 has finished. Thanks for '
                      'coming along.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
            const SizedBox(height: AonSpacing.space4),
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.science_rounded),
              label: const Text('Preview event night'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a reviewer scrub the app's clock to any point in the evening.
///
/// Ships in release builds on purpose. This is not a debug tool — the
/// organisers need to walk through the app at "8pm" during a daytime briefing
/// in August, and it doubles as a way for an attendee to plan ahead.
class _TimeSimulatorSheet extends ConsumerWidget {
  const _TimeSimulatorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final simulated = ref.watch(simulatedTimeProvider);

    // Half-hourly steps across the event window.
    final steps = <DateTime>[
      for (var h = 16; h < 22; h++) ...[
        EventInfo.at(h, 0),
        EventInfo.at(h, 30),
      ],
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AonSpacing.space5,
            0,
            AonSpacing.space5,
            AonSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preview event night', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AonSpacing.space2),
              Text(
                'Set the app’s clock to any point on '
                '${TimeFormat.date(EventInfo.startsAt)} to see what the '
                'programme looks like at that moment.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.aon.contentSecondary),
              ),
              const SizedBox(height: AonSpacing.space5),
              Wrap(
                spacing: AonSpacing.space2,
                runSpacing: AonSpacing.space2,
                children: [
                  for (final step in steps)
                    ChoiceChip(
                      label: Text(TimeFormat.time(step)),
                      selected: simulated == step,
                      onSelected: (_) =>
                          ref.read(simulatedTimeProvider.notifier).set(step),
                    ),
                ],
              ),
              const SizedBox(height: AonSpacing.space5),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(simulatedTimeProvider.notifier).clear();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Back to real time'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
